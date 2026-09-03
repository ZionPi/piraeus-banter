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

Release APK 使用仓库内的 `android/app/upload-keystore.jks` 签名，配置在
`android/key.properties`。这是为了保证任意开发机或 CI checkout 后都能构建出
可安装、签名一致的 APK。

> 当前签名密码是提交到仓库的非生产默认值，仅用于内部测试和直接分发 APK；正式上架
> Google Play 或其他商店前，应替换为不提交到仓库的生产签名。
