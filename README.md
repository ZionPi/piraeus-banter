# Piraeus Banter (泊睿妙语)

> **Where Wisdom Plays.**  
> 智趣交锋，启迪人生。

Piraeus Banter 是一款现代化的桌面端内容创作工具，旨在将文本对话脚本快速转化为高质量的**多角色播客音频**及**带字幕的视频内容**。

## ✨ 核心特性

- **双模式编辑**：支持类似聊天软件的双人对谈模式 (Dual Mode) 和单人独白模式 (Single Mode)。
- **多 TTS 引擎**：集成 Google Gemini, ByteDance (Sami), TTSFM 等多种语音合成引擎。
- **智能导入**：一键导入 LLM 生成的 JSON 剧本，自动解析角色与话题。
- **视频化生产**：自动生成 SRT 字幕，并利用 FFmpeg 合成带波形和字幕的 MP4 视频。
- **本地优先**：数据存储在本地，安全可控。

## 🛠️ 技术栈

- **Frontend**: Electron, React, TypeScript, TailwindCSS
- **Backend (Sidecar)**: Python 3.13, FastAPI
- **Media**: FFmpeg

## 🚀 快速开始 (WSL2 / Linux / Mac)

### 前置要求

- Node.js & pnpm
- Conda
- FFmpeg

### 开发运行

1. **环境初始化**

   ```bash
   make setup    # 创建 Conda 环境
   make install  # 安装前后端依赖
   ```

2. **启动应用**
   ```bash
   make dev
   ```

## 📄 许可证

MIT License
