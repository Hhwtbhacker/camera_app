import 'dart:io';

import 'package:camera_mobile/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpdateService.compareVersion', () {
    test('数值比较而非字符串比较', () {
      expect(UpdateService.compareVersion('1.2.10', '1.2.9'), 1);
      expect(UpdateService.compareVersion('1.2.9', '1.2.10'), -1);
    });

    test('位数不同时按缺省 0 补齐', () {
      expect(UpdateService.compareVersion('1.2', '1.2.0'), 0);
      expect(UpdateService.compareVersion('1.3', '1.2.9'), 1);
      expect(UpdateService.compareVersion('2.0.0', '1.9.9'), 1);
    });

    test('相同版本返回 0', () {
      expect(UpdateService.compareVersion('1.0.0', '1.0.0'), 0);
    });
  });

  group('UpdateService.isNewer', () {
    UpdateInfo info(String version, int build) => UpdateInfo(
          tag: 'v$version+$build',
          versionName: version,
          buildNumber: build,
          notes: '',
          apkUrl: 'https://example.com/a.apk',
          apkSize: 0,
        );

    test('构建号更大即为新版本', () {
      expect(UpdateService.isNewer(info('1.0.0', 2), (version: '1.0.0', build: 1)), isTrue);
    });

    test('构建号更小不是新版本', () {
      expect(UpdateService.isNewer(info('1.0.0', 1), (version: '1.0.0', build: 2)), isFalse);
    });

    test('构建号相同则比版本号', () {
      expect(UpdateService.isNewer(info('1.0.1', 2), (version: '1.0.0', build: 2)), isTrue);
      expect(UpdateService.isNewer(info('1.0.0', 2), (version: '1.0.0', build: 2)), isFalse);
    });
  });

  group('UpdateService.parseRelease', () {
    const sha = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
    const json = '''
    {
      "tag_name": "v1.0.1+2",
      "body": "1. 新增应用内更新\\n\\nsha256: $sha",
      "assets": [
        {"name": "camera_mobile-1.0.1.apk",
         "browser_download_url": "https://github.com/o/r/releases/download/v1.0.1+2/camera_mobile-1.0.1.apk",
         "size": 19531234},
        {"name": "notes.txt", "browser_download_url": "https://example.com/n.txt", "size": 10}
      ]
    }
    ''';

    test('解析标签、APK 资产与 sha256', () {
      final info = UpdateService.parseRelease(json)!;

      expect(info.tag, 'v1.0.1+2');
      expect(info.versionName, '1.0.1');
      expect(info.buildNumber, 2);
      expect(info.versionText, '1.0.1+2');
      expect(info.apkUrl, endsWith('camera_mobile-1.0.1.apk'));
      expect(info.apkSize, 19531234);
      expect(info.sizeText, '18.6 MB');
      expect(info.sha256, sha);
      // 说明里不应残留 sha256 行
      expect(info.notes.contains('sha256'), isFalse);
      expect(info.notes, contains('新增应用内更新'));
    });

    test('没有 APK 资产时返回 null', () {
      final info = UpdateService.parseRelease(
        '{"tag_name":"v1.0.1+2","body":"x","assets":[]}',
      );
      expect(info, isNull);
    });

    test('没有 sha256 时不校验', () {
      final info = UpdateService.parseRelease('''
        {"tag_name":"v1.0.1+2","body":"只有说明","assets":[
          {"name":"a.apk","browser_download_url":"https://example.com/a.apk","size":1}]}
      ''')!;
      expect(info.sha256, isNull);
      expect(info.notes, '只有说明');
    });

    test('没有更新说明时用默认文案', () {
      final info = UpdateService.parseRelease('''
        {"tag_name":"v1.0.1+2","body":"","assets":[
          {"name":"a.apk","browser_download_url":"https://example.com/a.apk","size":1}]}
      ''')!;
      expect(info.notes, isNotEmpty);
    });
  });

  group('解析真实 GitHub Release 报文', () {
    // fixtures 里的内容取自线上真实响应：
    // https://api.github.com/repos/Hhwtbhacker/camera_app/releases/latest
    late String body;

    setUp(() {
      body =
          File('test/fixtures/github_release_latest.json').readAsStringSync();
    });

    test('字段解析正确', () {
      final info = UpdateService.parseRelease(body)!;

      expect(info.tag, 'v1.0.1+2');
      expect(info.versionText, '1.0.1+2');
      expect(info.apkUrl, endsWith('/camera_mobile-1.0.1.apk'));
      expect(info.apkSize, 49840924);
      expect(info.sizeText, '47.5 MB');
      expect(
        info.sha256,
        '0f49c5d50d7385c7be657f4b935068d2dc600e2cab917b96aef7bdae1999b2c5',
      );
      expect(info.notes.contains('sha256'), isFalse);
      expect(info.notes, contains('OTA'));
    });

    test('对 1.0.0+1 判定为新版本，对 1.0.1+2 不再提示', () {
      final info = UpdateService.parseRelease(body)!;
      expect(UpdateService.isNewer(info, (version: '1.0.0', build: 1)), isTrue);
      expect(UpdateService.isNewer(info, (version: '1.0.1', build: 2)), isFalse);
    });
  });

  group('UpdateService.resolveDownloadUrl', () {
    const url = 'https://github.com/o/r/releases/download/v1.0.1+2/a.apk';

    test('前缀为空表示直连 GitHub', () {
      expect(UpdateService.resolveDownloadUrl(url, ''), url);
    });

    test('加速镜像拼在原始 URL 之前', () {
      expect(
        UpdateService.resolveDownloadUrl(url, 'https://ghfast.top/'),
        'https://ghfast.top/$url',
      );
    });
  });
}
