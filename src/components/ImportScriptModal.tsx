import React, { useState, useRef } from "react";
import { useProjectStore } from "@/store/projectStore";

interface ImportScriptModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const ImportScriptModal: React.FC<ImportScriptModalProps> = ({
  isOpen,
  onClose,
}) => {
  const [text, setText] = useState("");
  const importScript = useProjectStore((state) => state.importScript);
  const fileInputRef = useRef<HTMLInputElement>(null);

  if (!isOpen) return null;

  // 处理粘贴/手动输入导入
  const handleTextImport = () => {
    if (!text.trim()) {
      alert("Please paste some JSON content first.");
      return;
    }
    importScript(text);
    onClose();
    setText(""); // 清空
  };

  // 处理文件导入
  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      const content = event.target?.result as string;
      if (content) {
        importScript(content);
        onClose();
      }
    };
    reader.readAsText(file);
    e.target.value = ""; // 重置 input
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4 animate-in fade-in duration-200">
      <div
        className="w-full max-w-2xl rounded-xl border border-secondary bg-[#FEFEFE] shadow-2xl flex flex-col overflow-hidden"
        style={{
          backgroundImage: `url('data:image/svg+xml,%3Csvg width="60" height="60" viewBox="0 0 60 60" xmlns="http://www.w3.org/2000/svg"%3E%3Cg fill="none" fill-rule="evenodd"%3E%3Cg fill="%23DCD3C3" fill-opacity="0.1"%3E%3Cpath d="M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z"/%3E%3C/g%3E%3C/g%3E%3C/svg%3E')`,
        }}
      >
        {/* 标题栏 */}
        <div className="flex items-center justify-between border-b border-secondary/30 p-5 bg-white/50">
          <div>
            <h2 className="font-display text-2xl font-bold text-text-primary">
              Import Script
            </h2>
            <p className="text-sm text-text-secondary">
              Paste JSON text directly or upload a file.
            </p>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-full hover:bg-secondary/20 text-text-secondary hover:text-text-primary transition-colors"
          >
            <span className="material-symbols-outlined">close</span>
          </button>
        </div>

        {/* 内容区 */}
        <div className="p-6 space-y-4">
          {/* 文本输入区域 */}
          <div className="relative">
            <textarea
              className="w-full h-64 p-4 bg-background-light/50 border border-secondary rounded-lg focus:ring-2 focus:ring-primary focus:border-transparent font-mono text-sm resize-none outline-none text-text-primary placeholder:text-text-secondary/50"
              placeholder='Paste your JSON here...&#10;{ "dialogue_list": [ ... ] }'
              value={text}
              onChange={(e) => setText(e.target.value)}
            ></textarea>

            {/* 快捷按钮：从剪贴板粘贴 */}
            <button
              onClick={async () => {
                try {
                  const clipText = await navigator.clipboard.readText();
                  setText(clipText);
                } catch (err) {
                  alert("Failed to read clipboard");
                }
              }}
              className="absolute bottom-4 right-4 px-3 py-1.5 text-xs bg-white border border-secondary rounded shadow-sm hover:bg-secondary/10 text-text-secondary font-bold"
            >
              Paste from Clipboard
            </button>
          </div>

          {/* 分隔线 */}
          <div className="relative flex items-center py-2">
            <div className="flex-grow border-t border-secondary/30"></div>
            <span className="flex-shrink-0 mx-4 text-text-secondary text-sm font-bold">
              OR
            </span>
            <div className="flex-grow border-t border-secondary/30"></div>
          </div>

          {/* 底部操作栏 */}
          <div className="flex justify-between items-center">
            {/* 文件上传按钮 */}
            <div>
              <input
                type="file"
                ref={fileInputRef}
                className="hidden"
                accept=".json,.txt"
                onChange={handleFileChange}
              />
              <button
                onClick={() => fileInputRef.current?.click()}
                className="flex items-center gap-2 px-4 py-2 text-sm font-bold text-text-primary bg-white border border-secondary rounded-lg hover:bg-secondary/10 transition-colors"
              >
                <span className="material-symbols-outlined text-lg">
                  upload_file
                </span>
                Select File...
              </button>
            </div>

            {/* 确认导入按钮 */}
            <div className="flex gap-3">
              <button
                onClick={onClose}
                className="px-4 py-2 text-sm font-bold text-text-secondary hover:text-text-primary transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleTextImport}
                className="px-6 py-2 text-sm font-bold text-white bg-primary rounded-lg hover:bg-opacity-90 shadow-md transition-transform active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed"
                disabled={!text.trim()}
              >
                Parse & Import
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
