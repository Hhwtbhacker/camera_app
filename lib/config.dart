/// 全局配置
class AppConfig {
  // OrangePi 摄像头 HTTP 服务地址（改成你的 pi 实际 IP）
  static const String piHost = '10.210.49.67';
  static const int piPort = 8080;

  static String get baseUrl => 'http://$piHost:$piPort';

  /// 实时快照地址（带时间戳防缓存）
  static String get snapshotUrl =>
      '$baseUrl/snapshot?t=${DateTime.now().millisecondsSinceEpoch}';

  /// MJPEG 流地址
  static String get streamUrl => '$baseUrl/stream';

  /// 视频列表 API
  static String get videosApi => '$baseUrl/api/videos';

  /// 视频文件地址
  static String videoUrl(String name) => '$baseUrl/videos/$name';
}
