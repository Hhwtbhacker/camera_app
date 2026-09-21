import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/video_item.dart';

class ApiService {
  static Future<List<VideoItem>> fetchVideos() async {
    final resp = await http.get(Uri.parse(AppConfig.videosApi));
    if (resp.statusCode != 200) {
      throw Exception('获取视频列表失败: ${resp.statusCode}');
    }
    final list = jsonDecode(resp.body) as List;
    return list
        .map((e) => VideoItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
