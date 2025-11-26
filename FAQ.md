# 常见问题 (FAQ)

## 1. 为什么使用 Electron + Python 架构？

我们需要 Python 强大的生态来处理音频分析 (Librosa/Pandas)、TTS 接口对接和 FFmpeg 复杂调用，同时需要 Electron + React 提供现代化的拖拽交互和 UI 体验。采用 Sidecar 模式可以兼得两者之长。

## 2. 如何切换 Python 环境？

本项目使用 Conda 管理环境。在 `Makefile` 中修改 `CONDA_ENV` 变量即可。默认环境名为 `piraeus-banter`。

## 3. 为什么启动时有两个终端窗口？

`make dev` 会同时启动 Vite (前端热更新服务器) 和 Uvicorn (后端 API 服务器)。在 Electron 窗口弹出前，确保这两个服务都已 Ready。

## 4. 关于 FFmpeg

本项目依赖本地 FFmpeg。

- Windows: 请确保 `ffmpeg.exe` 在系统 PATH 中，或放入 `resources/bin/` 目录。
- WSL2: `sudo apt install ffmpeg`。
