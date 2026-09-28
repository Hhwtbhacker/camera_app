import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// 与 Android 端 MainActivity 对应的通道：读版本 / 取下载目录 / 拉起安装器
const MethodChannel _updaterChannel = MethodChannel('camera_mobile/updater');

/// 当前安装包的版本信息
typedef CurrentVersion = ({String version, int build});

/// 下载进度回调：`total` 未知时为 null；返回 false 表示取消下载
typedef ProgressCallback = bool Function(int received, int? total);

/// 用户主动取消下载
class UpdateCancelled implements Exception {
  const UpdateCancelled();

  @override
  String toString() => '已取消下载';
}

/// GitHub Release 里解析出的新版本信息
class UpdateInfo {
  /// 标签，形如 `v1.0.1+2`
  final String tag;

  /// 版本名，形如 `1.0.1`
  final String versionName;

  /// 构建号，形如 `2`
  final int buildNumber;

  /// 更新说明（已剔除内部的 sha256 行）
  final String notes;

  /// APK 下载地址
  final String apkUrl;

  /// APK 字节数（GitHub 未返回时为 0）
  final int apkSize;

  /// Release 中声明的 SHA-256，为空表示不校验
  final String? sha256;

  const UpdateInfo({
    required this.tag,
    required this.versionName,
    required this.buildNumber,
    required this.notes,
    required this.apkUrl,
    required this.apkSize,
    this.sha256,
  });

  /// 展示用版本号，如 `1.0.1+2`
  String get versionText => '$versionName+$buildNumber';

  /// 展示用体积，如 `18.6 MB`
  String get sizeText => apkSize <= 0
      ? '大小未知'
      : '${(apkSize / 1024 / 1024).toStringAsFixed(1)} MB';
}

/// 应用内 OTA 更新：检查 GitHub Releases、下载 APK、校验并安装
class UpdateService {
  static const Duration _timeout = Duration(seconds: 20);

  /// GitHub API 必须带 User-Agent，否则会被拒绝
  static const Map<String, String> _apiHeaders = {
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'camera_mobile',
  };

  /// 读取当前安装包版本
  static Future<CurrentVersion> currentVersion() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('仅 Android 支持应用内更新');
    }
    final map = await _updaterChannel.invokeMapMethod<String, dynamic>('getVersion');
    if (map == null) {
      throw StateError('读取版本号失败');
    }
    return (
      version: (map['versionName'] as String?) ?? '0.0.0',
      build: (map['buildNumber'] as num?)?.toInt() ?? 0,
    );
  }

  /// 查询是否有新版本，没有则返回 null。
  /// 仓库还没有发布过 Release 时（404）同样返回 null。
  static Future<UpdateInfo?> checkForUpdate(CurrentVersion current) async {
    final resp = await http
        .get(Uri.parse(AppConfig.latestReleaseApi), headers: _apiHeaders)
        .timeout(_timeout);
    if (resp.statusCode == 404) return null;
    if (resp.statusCode != 200) {
      throw Exception('GitHub 返回 HTTP ${resp.statusCode}');
    }
    final info = parseRelease(resp.body);
    if (info == null || !isNewer(info, current)) return null;
    return info;
  }
  /// 下载 APK 到本地并校验，返回文件（取消/失败时抛出异常，并清理残包）
  static Future<File> downloadApk(
    UpdateInfo info,
    ProgressCallback onProgress,
  ) async {
    final dir = await _updateDir();
    final file = File('${dir.path}/${_apkFileName(info)}');
    if (file.existsSync()) file.deleteSync();

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(info.apkUrl));
      final resp = await client.send(request).timeout(_timeout);
      if (resp.statusCode != 200) {
        throw Exception('下载失败：HTTP ${resp.statusCode}');
      }
      final total = resp.contentLength ?? (info.apkSize > 0 ? info.apkSize : null);

      var received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in resp.stream) {
          received += chunk.length;
          sink.add(chunk);
          if (!onProgress(received, total)) {
            throw const UpdateCancelled();
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (total != null && total > 0 && received != total) {
        throw Exception('下载不完整：$received / $total 字节');
      }
      final expected = info.sha256;
      if (expected != null && expected.isNotEmpty) {
        final actual =
            (await sha256.bind(file.openRead()).first).toString().toLowerCase();
        if (actual != expected.toLowerCase()) {
          throw Exception('安装包校验未通过，可能已损坏，请重试');
        }
      }
      return file;
    } catch (_) {
      if (file.existsSync()) file.deleteSync();
      rethrow;
    } finally {
      client.close();
    }
  }

  /// 拉起系统安装器（安装完成后由系统替换当前版本，数据保留）
  static Future<void> installApk(File file) async {
    if (!file.existsSync()) {
      throw Exception('安装包不存在，请重新下载');
    }
    await _updaterChannel.invokeMethod<void>('installApk', {'path': file.path});
  }

  /// APK 下载目录（Android 端 cache/update）
  static Future<Directory> _updateDir() async {
    final path = await _updaterChannel.invokeMethod<String>('getUpdateDir');
    if (path == null || path.isEmpty) {
      throw StateError('获取下载目录失败');
    }
    final dir = Directory(path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static String _apkFileName(UpdateInfo info) =>
      'camera_mobile-${info.versionName}.apk';

  /// 解析 GitHub Release 响应（暴露出来便于单元测试）
  static UpdateInfo? parseRelease(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final tag = (json['tag_name'] as String? ?? '').trim();
    if (tag.isEmpty) return null;

    // 标签约定：v<versionName>+<buildNumber>，例如 v1.0.1+2
    final plain = tag.startsWith('v') ? tag.substring(1) : tag;
    final plus = plain.indexOf('+');
    final versionName = plus > 0 ? plain.substring(0, plus) : plain;
    final buildNumber =
        plus > 0 ? (int.tryParse(plain.substring(plus + 1)) ?? 0) : 0;

    // 找到 APK 资产
    final assets = (json['assets'] as List?) ?? const [];
    Map<String, dynamic>? apk;
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) {
        apk = asset;
        break;
      }
    }
    final apkUrl = apk?['browser_download_url'] as String?;
    if (apkUrl == null || apkUrl.isEmpty) return null;

    final releaseBody = (json['body'] as String? ?? '').trim();
    final shaMatch =
        RegExp(r'sha256:\s*([0-9a-fA-F]{64})').firstMatch(releaseBody);
    final notes = releaseBody
        .replaceAll(RegExp(r'^sha256:.*$', multiLine: true), '')
        .trim();

    return UpdateInfo(
      tag: tag,
      versionName: versionName,
      buildNumber: buildNumber,
      notes: notes.isEmpty ? '本次更新内容详见 Release 页面' : notes,
      apkUrl: apkUrl,
      apkSize: (apk?['size'] as num?)?.toInt() ?? 0,
      sha256: shaMatch?.group(1),
    );
  }

  /// 新版本判定：先比构建号，构建号相同再比语义化版本号（暴露出来便于单元测试）
  static bool isNewer(UpdateInfo info, CurrentVersion current) {
    if (info.buildNumber != current.build) {
      return info.buildNumber > current.build;
    }
    return compareVersion(info.versionName, current.version) > 0;
  }

  /// 语义化版本比较：1.2.10 > 1.2.9（返回 1 / 0 / -1）
  static int compareVersion(String a, String b) {
    final pa = a.split('.');
    final pb = b.split('.');
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? (int.tryParse(pa[i]) ?? 0) : 0;
      final vb = i < pb.length ? (int.tryParse(pb[i]) ?? 0) : 0;
      if (va != vb) return va > vb ? 1 : -1;
    }
    return 0;
  }
}

