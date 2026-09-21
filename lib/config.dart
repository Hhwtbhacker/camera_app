import 'package:flutter/foundation.dart';

/// 全局配置
class AppConfig {
  // ================= 网络地址配置 =================
  // 局域网地址：手机与 pi 在同一 WiFi 下时使用
  static const String lanHost = '10.210.49.67';

  // 公网地址：手机在外网访问时使用（需 pi 已做端口映射/内网穿透）。
  // 改成你的公网 IP 或域名，例如 'example.com' 或 '123.45.67.89'
  static const String wanHost = 'your-public-domain.com';

  static const int port = 8080;
  // ================================================

  /// 当前使用的 host（局域网/公网），切换时自动通知监听者刷新界面
  static final ValueNotifier<String> currentHost =
      ValueNotifier<String>(lanHost);

  static String get baseUrl => 'http://${currentHost.value}:$port';

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
