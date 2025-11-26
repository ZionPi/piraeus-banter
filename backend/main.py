from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import os
import uvicorn
from backend.tts_bytedance import save_audio_to_file
from backend.config import config

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 允许所有来源 (http://localhost:5173 等)
    allow_credentials=True,
    allow_methods=["*"],  # 允许所有方法 (GET, POST, etc.)
    allow_headers=["*"],  # 允许所有 Header
)

# 定义请求体格式
class TTSRequest(BaseModel):
    text: str
    speaker: str
    project_path: str # 项目根目录，音频将存在 project_path/audio/ 下
    bubble_id: str
    app_key: str
    access_token: str

@app.get("/")
def read_root():
    return {"status": "Piraeus Banter Backend is Running"}

@app.post("/api/generate")
async def generate_audio(req: TTSRequest):
    try:
        # 优先使用前端传来的 Key，否则用环境变量
        app_key = req.app_key if req.app_key else config.BYTEDANCE_APPKEY
        token = req.access_token if req.access_token else config.BYTEDANCE_ACCESS_TOKEN
        
        if not app_key:
             raise HTTPException(status_code=400, detail="Missing ByteDance AppKey")

        # 构造路径
        audio_dir = os.path.join(req.project_path, "audio")
        # 确保 audio 文件夹存在
        if not os.path.exists(audio_dir):
            os.makedirs(audio_dir)
            
        filename = f"{req.bubble_id}.mp3"
        output_path = os.path.join(audio_dir, filename)
        
        # 调用新的 TTS 逻辑
        await save_audio_to_file(
            text=req.text,
            speaker=req.speaker,
            output_path=output_path,
            appkey=app_key,
            token=token # 虽然新逻辑主要依赖 appkey，但保留 token 参数以防万一
        )
        
        return {
            "success": True,
            "audio_path": output_path,
            "duration": 0 
        }
        
    except Exception as e:
        print(f"Error generating audio: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)