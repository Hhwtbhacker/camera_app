# camera_mobile - OrangePi 摄像头手机端 App

基于 Flutter 开发的手机端客户端，用于远程查看 OrangePi 摄像头。

## 功能

- **实时画面**：通过 HTTP 快照轮询显示 pi 的实时画面（约 5fps）
- **视频回放**：获取 pi 本地存储的视频列表，在线播放
- **进度控制**：支持拖动进度条 seek、播放/暂停
- **精美暗色 UI**：Material 3 暗色主题

## 环境要求

- Flutter SDK 3.x
- Dart 3.x
- JDK 17
- Android SDK（构建 APK 用）

## 运行

```bash
flutter pub get
flutter run          # 连接真机/模拟器
flutter build apk    # 构建 APK
```

## 配置

修改 `lib/config.dart` 中的 `piHost` 为你的 OrangePi 实际 IP 地址。

## 依赖的 pi 端服务

需要 pi 上运行 HTTP 服务（见 pi 端 `camera/src/pi_server.py`）：

| 接口 | 说明 |
| ---- | ---- |
| `GET /snapshot` | 实时快照（JPEG） |
| `GET /stream` | MJPEG 实时流 |
| `GET /api/videos` | 视频列表 JSON |
| `GET /videos/<name>` | 视频流式传输（支持 Range） |
