# 泊睿妙语 Mobile（Android）

这是 Piraeus Banter 的 Flutter Android 版本，结构参考同机 `localshare` 项目。

## 当前范围

- Android only；
- 本地保存当前项目；
- 支持主持人/嘉宾双人气泡编辑；
- 支持粘贴导入桌面端兼容 JSON（`dialogue_list`）；
- 支持直接从 Android 端调用 ByteDance/Sami WebSocket TTS 生成 MP3；
- 支持播放单条已生成音频。

暂未移植桌面端的 FFmpeg 音频合并、SRT/视频导出、项目列表管理。

## 构建

```bash
make deps
make release-apk
```

产物：`build/app/outputs/flutter-apk/app-release.apk`

> 当前 release 使用 debug signing，便于先安装测试；正式分发前应替换为正式签名。
