# camera_mobile - OrangePi 摄像头手机端 App

基于 Flutter 开发的手机端客户端，用于远程查看 OrangePi 摄像头。

## 功能

- **实时画面**：MJPEG 长连接流（默认，帧率高、无闪烁），可一键切到 HTTP 快照轮询
- **视频回放**：获取 pi 本地存储的视频列表，在线播放
- **进度控制**：支持拖动进度条 seek、播放/暂停
- **应用内更新（OTA）**：启动自动检查 + 手动检查，直接从 GitHub Releases 下载并安装新版本
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
| `githubRepo` | OTA 更新源仓库（owner/repo） | `Hhwtbhacker/camera_app` |
| `autoCheckUpdate` | 启动时是否自动检查更新 | `true` |
| `apkDownloadProxies` | APK 下载源（依次尝试，空串=直连） | 直连 + 两个公共加速镜像 |

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

## 应用内更新（OTA）

App 内置了从 **GitHub Releases** 检查并安装新版本的能力（仅 Android），不需要应用商店。

### 使用方式

- **自动**：App 启动后静默检查一次，发现新版本会弹窗显示版本号 / 更新说明 / 包体大小
- **手动**：实时画面页与视频回放页右上角的 ⬆️ 按钮（`Icons.system_update_alt`）

点击「立即更新」后：下载（带进度、可取消）→ 校验 SHA-256 → 调起系统安装器，确认后覆盖安装，应用数据保留。

首次安装更新时，系统会要求允许本应用「安装未知应用」（Android 8.0+），在弹窗里点允许即可。

### 如何发布一个新版本

```bash
# 1) 配置一次即可：PAT 需要仓库的 Contents: Read and write 权限
git config --local github.token <你的 PAT>
# 或每次发布前 export GITHUB_TOKEN=<你的 PAT>

# 2) 一键发布（会自动改版本号、analyze/test、构建、提交、打标签、建 Release 并上传 APK）
./scripts/release.sh 1.0.1 2 "1. 新增应用内更新；2. 修复 xxx"
```

脚本约定：

| 项 | 说明 |
| ---- | ---- |
| 标签格式 | `v<版本名>+<构建号>`，例如 `v1.0.1+2`，与 `pubspec.yaml` 的 `version` 一致 |
| Release 资产 | `camera_mobile-<版本名>.apk` |
| 更新说明 | 取自命令第三个参数；脚本会自动追加一行 `sha256: <哈希>` 供 App 校验 |
| 版本判定 | 先比构建号，构建号相同再比语义化版本号（1.2.10 > 1.2.9） |

### 注意事项

- 仓库必须是 **Public**，否则 App 无法免认证下载 APK（token 不应打进客户端）
- 更新检查走 `api.github.com`，未认证限流 60 次/小时/IP，超出或断网时启动检查静默失败（不打扰使用）
- 完整性：HTTPS + Release body 中的 SHA-256 校验；安装时 Android 还会校验 APK 签名必须与已安装版本一致，因此被篡改的包无法覆盖安装
- 发布用的 APK 目前用 debug 签名（模板默认）。如需长期稳定升级，建议在 `android/app/build.gradle.kts` 配置自己的 release 签名，**更换签名会导致无法覆盖安装**

