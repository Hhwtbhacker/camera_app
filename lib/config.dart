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

  /// 实时快照地址（带时间戳防缓存）
  static String get snapshotUrl =>
      '$baseUrl/snapshot?t=${DateTime.now().millisecondsSinceEpoch}';

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
}
