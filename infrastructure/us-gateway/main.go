package main

import (
	"bytes"
	"context"
	"crypto/subtle"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

const (
	maxRequestBytes   = 2 << 20
	maxUploadBytes    = 25 << 20
	maxImageBytes     = 15 << 20
	maxExtractedBytes = 2 << 20
)

var (
	modelPattern  = regexp.MustCompile(`^[A-Za-z0-9._-]{1,100}$`)
	client        = &http.Client{}
	forwardClient = &http.Client{Timeout: 130 * time.Second}
	slots         = make(chan struct{}, 2)
	fileSlot      = make(chan struct{}, 1)
)

type generateRequest struct {
	Model   string          `json:"model"`
	Payload json.RawMessage `json:"payload"`
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/api/health", health)
	mux.HandleFunc("/api/gemini/generate", generate)
	mux.HandleFunc("/api/url-to-text", proxyWarsaw("/api/url-to-text", 64<<10))
	mux.HandleFunc("/api/convert-to-text", proxyWarsaw("/api/convert-to-text", maxUploadBytes+(1<<20)))
	mux.HandleFunc("/api/dialogize", dialogize)
	server := &http.Server{
		Addr:              "127.0.0.1:" + env("PORT", "3270"),
		Handler:           securityHeaders(mux),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       180 * time.Second,
		WriteTimeout:      180 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	log.Printf("Gemini test proxy listening on %s", server.Addr)
	log.Fatal(server.ListenAndServe())
}

func health(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":                true,
		"configured":        strings.TrimSpace(os.Getenv("GEMINI_API_KEY")) != "",
		"warsaw_configured": strings.TrimSpace(os.Getenv("WARSAW_PROXY_TOKEN")) != "",
	})
}

func generate(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	if !authorized(r) {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "proxy authentication failed"})
		return
	}
	apiKey := strings.TrimSpace(os.Getenv("GEMINI_API_KEY"))
	if apiKey == "" {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "Gemini is not configured"})
		return
	}
	select {
	case slots <- struct{}{}:
		defer func() { <-slots }()
	default:
		w.Header().Set("Retry-After", "5")
		writeJSON(w, http.StatusTooManyRequests, map[string]string{"error": "too many requests"})
		return
	}

	var input generateRequest
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxRequestBytes))
	if err := decoder.Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	input.Model = strings.TrimSpace(input.Model)
	if !modelPattern.MatchString(input.Model) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid model"})
		return
	}
	if len(input.Payload) == 0 || !json.Valid(input.Payload) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "payload must be valid json"})
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 90*time.Second)
	defer cancel()
	response, usedModel, err := requestGemini(ctx, input.Model, apiKey, input.Payload)
	if err != nil {
		log.Printf("Gemini upstream failed for model %q: %v", input.Model, err)
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": "Gemini upstream unavailable"})
		return
	}
	defer response.Body.Close()
	body, err := io.ReadAll(io.LimitReader(response.Body, 8<<20))
	if err != nil {
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": "failed to read Gemini response"})
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("X-Gemini-Model", usedModel)
	w.WriteHeader(response.StatusCode)
	_, _ = w.Write(body)
}

func requestGemini(ctx context.Context, selectedModel, apiKey string, payload []byte) (*http.Response, string, error) {
	models := fallbackModels(selectedModel)
	for index, model := range models {
		target := fmt.Sprintf(
			"https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent",
			url.PathEscape(model),
		)
		request, err := http.NewRequestWithContext(ctx, http.MethodPost, target, bytes.NewReader(payload))
		if err != nil {
			return nil, model, err
		}
		request.Header.Set("Content-Type", "application/json")
		request.Header.Set("X-Goog-Api-Key", apiKey)
		response, err := client.Do(request)
		if err == nil && (!retryable(response.StatusCode) || index == len(models)-1) {
			return response, model, nil
		}
		if err == nil {
			log.Printf("Gemini model %q returned %d; falling back", model, response.StatusCode)
			_, _ = io.Copy(io.Discard, io.LimitReader(response.Body, 32<<10))
			response.Body.Close()
		} else {
			log.Printf("Gemini model %q failed: %v; falling back", model, err)
		}
		select {
		case <-ctx.Done():
			return nil, model, ctx.Err()
		default:
		}
	}
	return nil, selectedModel, errors.New("all Gemini models failed")
}

func fallbackModels(selected string) []string {
	models := []string{selected, "gemini-3.6-flash", "gemini-3.5-flash"}
	seen := make(map[string]bool, len(models))
	result := make([]string, 0, len(models))
	for _, model := range models {
		if model == "" || seen[model] {
			continue
		}
		seen[model] = true
		result = append(result, model)
	}
	return result
}

func retryable(status int) bool {
	return status == http.StatusRequestTimeout || status == http.StatusTooManyRequests || status >= 500
}

func proxyWarsaw(path string, maxBytes int64) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
			return
		}
		if !authorized(r) {
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "proxy authentication failed"})
			return
		}
		if strings.TrimSpace(os.Getenv("WARSAW_PROXY_TOKEN")) == "" {
			writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "Warsaw upstream is not configured"})
			return
		}
		select {
		case fileSlot <- struct{}{}:
			defer func() { <-fileSlot }()
		default:
			w.Header().Set("Retry-After", "5")
			writeJSON(w, http.StatusTooManyRequests, map[string]string{"error": "another file request is running"})
			return
		}
		r.Body = http.MaxBytesReader(w, r.Body, maxBytes)
		response, err := warsawRequest(r.Context(), path, r.Header.Get("Content-Type"), r.Body)
		if err != nil {
			writeJSON(w, http.StatusBadGateway, map[string]string{"error": "Warsaw upstream unavailable"})
			return
		}
		defer response.Body.Close()
		copyResponseHeaders(w.Header(), response.Header)
		w.WriteHeader(response.StatusCode)
		_, _ = io.Copy(w, io.LimitReader(response.Body, 101<<20))
	}
}

func warsawRequest(ctx context.Context, path, contentType string, body io.Reader) (*http.Response, error) {
	base := strings.TrimRight(env("WARSAW_BASE_URL", "https://api.zionpi.serv00.net"), "/")
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, base+path, body)
	if err != nil {
		return nil, err
	}
	request.Header.Set("Content-Type", contentType)
	request.Header.Set("X-Piraeus-Token", strings.TrimSpace(os.Getenv("WARSAW_PROXY_TOKEN")))
	return forwardClient.Do(request)
}

func copyResponseHeaders(target, source http.Header) {
	for _, name := range []string{"Content-Type", "Content-Disposition", "Retry-After"} {
		if value := source.Get(name); value != "" {
			target.Set(name, value)
		}
	}
}

type dialogueItem struct {
	Content            string `json:"content"`
	ID                 int    `json:"id"`
	NonEssentialSpeech bool   `json:"non_essential_speech"`
	Speaker            string `json:"speaker"`
	TopicID            int    `json:"topic_id"`
	ContentType        string `json:"content_type"`
}

type dialogueResponse struct {
	Title        string         `json:"title"`
	DialogueList []dialogueItem `json:"dialogue_list"`
}

func dialogize(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	if !authorized(r) {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "proxy authentication failed"})
		return
	}
	if strings.TrimSpace(os.Getenv("GEMINI_API_KEY")) == "" ||
		strings.TrimSpace(os.Getenv("WARSAW_PROXY_TOKEN")) == "" {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "upstream services are not configured"})
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxUploadBytes+(1<<20))
	if err := r.ParseMultipartForm(1 << 20); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid multipart upload"})
		return
	}
	if r.MultipartForm != nil {
		defer r.MultipartForm.RemoveAll()
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "missing multipart field: file"})
		return
	}
	defer file.Close()
	model := strings.TrimSpace(r.FormValue("model"))
	if model == "" {
		model = env("DIALOGIZE_MODEL", "gemini-3.8-flash")
	}
	if !modelPattern.MatchString(model) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid model"})
		return
	}
	additional := strings.TrimSpace(r.FormValue("additionalText"))
	styleName := strings.TrimSpace(r.FormValue("styleName"))
	systemPrompt := strings.TrimSpace(r.FormValue("systemInstruction"))
	userPrompt := strings.TrimSpace(r.FormValue("userPrompt"))
	if len(additional) > 64<<10 || len(systemPrompt)+len(userPrompt) > 96<<10 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "prompt fields are too large"})
		return
	}
	select {
	case fileSlot <- struct{}{}:
		defer func() { <-fileSlot }()
	default:
		w.Header().Set("Retry-After", "5")
		writeJSON(w, http.StatusTooManyRequests, map[string]string{"error": "another file request is running"})
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 170*time.Second)
	defer cancel()
	ext := strings.ToLower(filepath.Ext(header.Filename))
	var parts []map[string]any
	if mimeType, ok := map[string]string{
		".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp",
	}[ext]; ok {
		body, readErr := io.ReadAll(io.LimitReader(file, maxImageBytes+1))
		if readErr != nil || len(body) == 0 || len(body) > maxImageBytes {
			writeJSON(w, http.StatusUnprocessableEntity, map[string]string{"error": "invalid or oversized image"})
			return
		}
		prompt := joinPrompt(userPrompt, additional,
			fmt.Sprintf("文件名：%s\n\n请准确识别图片中的信息并转成中文双人对话，不要臆造。", filepath.Base(header.Filename)))
		parts = []map[string]any{
			{"text": prompt},
			{"inline_data": map[string]string{"mime_type": mimeType, "data": base64.StdEncoding.EncodeToString(body)}},
		}
	} else {
		text, status, convertErr := convertThroughWarsaw(ctx, header)
		if convertErr != nil {
			writeJSON(w, status, map[string]string{"error": convertErr.Error()})
			return
		}
		prompt := joinPrompt(userPrompt, additional,
			fmt.Sprintf("文件名：%s\n\n请把以下文本转成 12 至 36 条连贯中文双人对话，最多输出 36 条：\n\n%s", filepath.Base(header.Filename), text))
		parts = []map[string]any{{"text": prompt}}
	}
	result, status, err := generateDialogue(ctx, model, systemPrompt, styleName, parts)
	if err != nil {
		writeJSON(w, status, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func convertThroughWarsaw(ctx context.Context, header *multipart.FileHeader) (string, int, error) {
	input, err := header.Open()
	if err != nil {
		return "", http.StatusBadRequest, errors.New("failed to open upload")
	}
	defer input.Close()
	reader, writer := io.Pipe()
	multipartWriter := multipart.NewWriter(writer)
	go func() {
		part, partErr := multipartWriter.CreateFormFile("file", filepath.Base(header.Filename))
		if partErr == nil {
			_, partErr = io.Copy(part, io.LimitReader(input, maxUploadBytes+1))
		}
		closeErr := multipartWriter.Close()
		if partErr == nil {
			partErr = closeErr
		}
		_ = writer.CloseWithError(partErr)
	}()
	response, err := warsawRequest(ctx, "/api/convert-to-text", multipartWriter.FormDataContentType(), reader)
	if err != nil {
		return "", http.StatusBadGateway, errors.New("Warsaw conversion unavailable")
	}
	defer response.Body.Close()
	body, readErr := io.ReadAll(io.LimitReader(response.Body, maxExtractedBytes+1))
	if readErr != nil {
		return "", http.StatusBadGateway, errors.New("failed to read converted text")
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return "", response.StatusCode, errors.New("Warsaw could not convert the file")
	}
	if len(body) > maxExtractedBytes || strings.TrimSpace(string(body)) == "" {
		return "", http.StatusUnprocessableEntity, errors.New("converted text is empty or exceeds 2 MiB")
	}
	return string(body), http.StatusOK, nil
}

func joinPrompt(stylePrompt, additional, task string) string {
	var sections []string
	if stylePrompt != "" {
		sections = append(sections, stylePrompt)
	}
	if additional != "" {
		sections = append(sections, "用户补充说明："+additional)
	}
	return strings.Join(append(sections, task), "\n\n")
}

func generateDialogue(ctx context.Context, model, systemPrompt, styleName string, parts []map[string]any) (*dialogueResponse, int, error) {
	if systemPrompt == "" {
		systemPrompt = "严格依据材料生成中文双人对话，不添加材料中没有的事实。"
	}
	systemPrompt += "\n输出必须符合 JSON Schema。title 为 4 至 20 个中文字符且不含风格名；speaker 只能是 Speaker 1 或 Speaker 2。"
	if styleName != "" {
		systemPrompt += "\n采用“" + styleName + "”风格。"
	}
	schema := map[string]any{
		"type": "object",
		"properties": map[string]any{
			"title": map[string]any{"type": "string"},
			"dialogue_list": map[string]any{
				"type": "array",
				"items": map[string]any{
					"type": "object",
					"properties": map[string]any{
						"content": map[string]any{"type": "string"}, "id": map[string]any{"type": "integer"},
						"non_essential_speech": map[string]any{"type": "boolean"},
						"speaker":              map[string]any{"type": "string", "enum": []string{"Speaker 1", "Speaker 2"}},
						"topic_id":             map[string]any{"type": "integer"},
						"content_type":         map[string]any{"type": "string", "enum": []string{"question", "answer", "other"}},
					},
					"required": []string{"content", "id", "non_essential_speech", "speaker", "topic_id", "content_type"},
				},
			},
		},
		"required": []string{"title", "dialogue_list"},
	}
	payload, err := json.Marshal(map[string]any{
		"system_instruction": map[string]any{"parts": []map[string]string{{"text": systemPrompt}}},
		"contents":           []map[string]any{{"role": "user", "parts": parts}},
		"generationConfig": map[string]any{
			"temperature": .8, "maxOutputTokens": 16384,
			"responseMimeType": "application/json", "responseSchema": schema,
		},
	})
	if err != nil {
		return nil, http.StatusInternalServerError, errors.New("failed to build Gemini request")
	}
	response, usedModel, err := requestGemini(ctx, model, strings.TrimSpace(os.Getenv("GEMINI_API_KEY")), payload)
	if err != nil {
		log.Printf("Dialogize Gemini upstream failed for model %q: %v", model, err)
		return nil, http.StatusBadGateway, errors.New("Gemini upstream unavailable")
	}
	if usedModel != model {
		log.Printf("Dialogize used fallback model %q instead of %q", usedModel, model)
	}
	defer response.Body.Close()
	body, err := io.ReadAll(io.LimitReader(response.Body, 8<<20))
	if err != nil {
		return nil, http.StatusBadGateway, errors.New("failed to read Gemini response")
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return nil, response.StatusCode, fmt.Errorf("Gemini returned HTTP %d", response.StatusCode)
	}
	var envelope struct {
		Candidates []struct {
			Content struct {
				Parts []struct {
					Text string `json:"text"`
				} `json:"parts"`
			} `json:"content"`
		} `json:"candidates"`
	}
	if json.Unmarshal(body, &envelope) != nil || len(envelope.Candidates) == 0 {
		return nil, http.StatusBadGateway, errors.New("Gemini returned no candidate")
	}
	var text strings.Builder
	for _, part := range envelope.Candidates[0].Content.Parts {
		text.WriteString(part.Text)
	}
	var result dialogueResponse
	if json.Unmarshal([]byte(strings.TrimSpace(text.String())), &result) != nil || result.Title == "" || len(result.DialogueList) == 0 {
		return nil, http.StatusBadGateway, errors.New("Gemini did not return a valid dialogue")
	}
	return &result, http.StatusOK, nil
}

func authorized(r *http.Request) bool {
	expected := strings.TrimSpace(os.Getenv("PIRAEUS_PROXY_TOKEN"))
	provided := strings.TrimSpace(r.Header.Get("X-Piraeus-Token"))
	return expected != "" && len(expected) == len(provided) &&
		subtle.ConstantTimeCompare([]byte(expected), []byte(provided)) == 1
}

func securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("Cache-Control", "no-store")
		next.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func env(name, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(name)); value != "" {
		return value
	}
	return fallback
}
