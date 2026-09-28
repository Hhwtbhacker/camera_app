import 'package:flutter/foundation.dart';

/// 全局配置
class AppConfig {
  // ================= 网络地址配置 =================
  // 局域网地址：手机与 pi 在同一 WiFi 下时使用
  static const String lanHost = '10.72.0.56';

  // 公网地址：手机在外网访问时使用（经 cpolar 内网穿透）。
  // 当前是 cpolar 免费版随机域名，Pi 重启 / 隧道重连后可能变化。
  // 变化后在 Pi 上执行下面命令拿一个「已验证可用」的地址，再同步到这里：
  //   ~/camera/cpolar-url.sh
  // 或（pi_systemd/cpolar-url.sh）
  static const String wanHost = 'fbf7f07.r19.vip.cpolar.cn';

  // ================= 协议与端口 =================
  // 局域网：pi_server.py 直接提供 http 明文服务
  static const String lanScheme = 'http';
  static const int lanPort = 8080;

  // 公网：走 cpolar 的 https 入口（默认 443，由 cpolar 侧终止 TLS 后转发到 8080）
  static const String wanScheme = 'https';
  static const int wanPort = 443;
  // ================================================

  /// 当前使用的 host（局域网/公网），切换时自动通知监听者刷新界面
  static final ValueNotifier<String> currentHost =
      ValueNotifier<String>(lanHost);

  /// 当前模式使用的协议
  static String get scheme => isLan ? lanScheme : wanScheme;

  /// 当前模式使用的端口
  static int get port => isLan ? lanPort : wanPort;

  static String get baseUrl {
    final host = currentHost.value;
    // 80/443 是 http/https 默认端口，URL 里省略更规范
    final defaultPort = scheme == 'https' ? 443 : 80;
    final portPart = port == defaultPort ? '' : ':$port';
    return '$scheme://$host$portPart';
  }

  /// MJPEG 流地址
  static String get streamUrl => '$baseUrl/stream';

  /// 视频列表 API
  static String get videosApi => '$baseUrl/api/videos';

  /// 视频文件地址
  static String videoUrl(String name) => '$baseUrl/videos/$name';

  /// 当前是否局域网模式
  static bool get isLan => currentHost.value == lanHost;

  /// 当前模式标签
  static String get modeLabel => isLan ? '局域网' : '公网';

  /// 切换局域网/公网
  static void toggleNetwork() {
    currentHost.value = isLan ? wanHost : lanHost;
  }

  // ================= OTA 应用内更新 =================
  /// GitHub 仓库（owner/repo）：新版本信息与 APK 都取自它的 Releases。
  /// 仓库必须是 Public，否则 APK 无法在有认证的情况下下载。
  static const String githubRepo = 'Hhwtbhacker/camera_app';

  /// 启动时自动检查更新（单元测试里会关掉）
  static bool autoCheckUpdate = true;

  /// 最新 Release 信息接口（GitHub API）
  static String get latestReleaseApi =>
      'https://api.github.com/repos/$githubRepo/releases/latest';

  /// APK 下载源（按顺序尝试，空串表示直连 GitHub）。
  /// GitHub Release 资产实际托管在 release-assets.githubusercontent.com，
  /// 国内网络经常连不通，因此默认再挂两个公共加速镜像兜底。
  /// 安全性：无论走哪个源，下载完成后都会用 Release body 里的 SHA-256 校验，
  /// 而该 hash 来自 api.github.com 的官方响应，镜像无法篡改内容。
  static const List<String> apkDownloadProxies = <String>[
    '', // 直连 github.com
    'https://ghfast.top/', // 公共加速镜像
    'https://ghproxy.net/', // 公共加速镜像（备用）
  ];
}
