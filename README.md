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

修改 `lib/config.dart` 中的网络地址：

| 配置项 | 说明 | 当前值 |
| ---- | ---- | ---- |
| `lanHost` | 局域网地址（手机与 pi 同一 WiFi 时使用） | `10.72.0.56` |
| `wanHost` | 公网地址（经 cpolar 内网穿透） | `fbf7f07.r19.vip.cpolar.cn` |
| `lanScheme` / `lanPort` | 局域网协议与端口 | `http` / `8080` |
| `wanScheme` / `wanPort` | 公网协议与端口（cpolar https 入口） | `https` / `443` |

应用右上角的「局域网/公网」按钮可切换使用的地址。

### 公网地址会变（cpolar 免费版）

免费版每次隧道重连都可能被分配新的随机域名，且新域名在边缘节点上有时要等一会儿才生效。地址变化后，在 Pi 上跑辅助脚本拿一个**已验证可用（HTTP 200）**的地址：

```bash
~/camera/cpolar-url.sh
```

脚本会自动重试、必要时重启 cpolar 服务，只在真正能访问时打印地址。把输出的域名同步到 `wanHost` 即可。

需要固定域名时，在 cpolar 后台「预留」二级子域名，再在 `/usr/local/etc/cpolar/cpolar.yml` 的 `camera` 隧道下加 `subdomain: <你的名字>`。

## 依赖的 pi 端服务

需要 pi 上运行 HTTP 服务（见 pi 端 `camera/src/pi_server.py`）：

| 接口 | 说明 |
| ---- | ---- |
| `GET /snapshot` | 实时快照（JPEG） |
| `GET /stream` | MJPEG 实时流 |
| `GET /api/videos` | 视频列表 JSON |
| `GET /videos/<name>` | 视频流式传输（支持 Range） |
