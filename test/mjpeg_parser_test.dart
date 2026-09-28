import 'dart:typed_data';

import 'package:camera_mobile/utils/mjpeg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// 构造一帧伪 JPEG：SOI + payload(全部 < 0x80，不会误撞帧标记) + EOI
Uint8List _jpeg(int payloadLen, int seed) {
  final b = BytesBuilder();
  b.add([0xFF, 0xD8]);
  for (var i = 0; i < payloadLen; i++) {
    b.addByte((seed + i) & 0x7F);
  }
  b.add([0xFF, 0xD9]);
  return b.toBytes();
}

void main() {
  group('parseMjpegFrames', () {
    test('空数据返回空结果', () {
      final r = parseMjpegFrames(Uint8List(0));
      expect(r.frame, isNull);
      expect(r.remaining, isEmpty);
    });

    test('单帧：完整提取且无剩余', () {
      final f = _jpeg(10, 1);
      final r = parseMjpegFrames(f);
      expect(r.frame, isNotNull);
      expect(r.frame!.length, f.length);
      expect(r.frame!.first, 0xFF);
      expect(r.frame![1], 0xD8);
      expect(r.frame![r.frame!.length - 2], 0xFF);
      expect(r.frame![r.frame!.length - 1], 0xD9);
      expect(r.remaining, isEmpty);
    });

    test('多帧：只返回最后一帧', () {
      final f1 = _jpeg(10, 1);
      final f2 = _jpeg(20, 2);
      final input = Uint8List.fromList([...f1, ...f2]);
      final r = parseMjpegFrames(input);
      expect(r.frame, isNotNull);
      expect(r.frame!.length, f2.length);
      expect(r.remaining, isEmpty);
    });

    test('不完整帧：保留在 remaining 中', () {
      final f = _jpeg(100, 3);
      final partial = Uint8List.fromList(Uint8List.sublistView(f, 0, 50));
      final r = parseMjpegFrames(partial);
      expect(r.frame, isNull);
      expect(r.remaining.length, 50);
    });

    test('分块到达：拼接后能还原完整帧', () {
      final f = _jpeg(100, 5);
      var r = parseMjpegFrames(Uint8List.fromList(Uint8List.sublistView(f, 0, 60)));
      expect(r.frame, isNull);

      final combined = Uint8List.fromList(
        [...r.remaining, ...Uint8List.sublistView(f, 60)],
      );
      r = parseMjpegFrames(combined);
      expect(r.frame, isNotNull);
      expect(r.frame!.length, f.length);
      expect(r.remaining, isEmpty);
    });

    test('multipart 头部会被自动跳过', () {
      final f = _jpeg(10, 4);
      final header = Uint8List.fromList(
        '--frame\r\nContent-Type: image/jpeg\r\nContent-Length: 12\r\n\r\n'
            .codeUnits,
      );
      final input = Uint8List.fromList([...header, ...f]);
      final r = parseMjpegFrames(input);
      expect(r.frame, isNotNull);
      expect(r.frame!.length, f.length);
      expect(r.remaining, isEmpty);
    });

    test('末尾半个 SOI（0xFF）会被保留', () {
      final input = Uint8List.fromList([0x01, 0x02, 0xFF]);
      final r = parseMjpegFrames(input);
      expect(r.frame, isNull);
      expect(r.remaining, [0xFF]);
    });

    test('纯垃圾数据（无帧头）会被丢弃', () {
      final input = Uint8List.fromList(List.filled(64, 0x41)); // 'AAAA...'
      final r = parseMjpegFrames(input);
      expect(r.frame, isNull);
      expect(r.remaining, isEmpty);
    });

    // 回归测试：旧实现中扫描游标未推进，会重复提取同一帧而陷入死循环，
    // 导致 Dart 事件循环被阻塞、App 卡死。此处确保大批量帧能被快速处理完。
    test('大批量帧不会死循环（性能回归）', () {
      final builder = BytesBuilder();
      for (var i = 0; i < 500; i++) {
        builder.add(_jpeg(512, i));
      }
      final input = builder.toBytes();

      final sw = Stopwatch()..start();
      final r = parseMjpegFrames(input);
      sw.stop();

      expect(r.frame, isNotNull);
      expect(r.frame!.length, 516); // 2 (SOI) + 512 (payload) + 2 (EOI)
      expect(r.remaining, isEmpty);
      // 500 帧线性扫描应在很短时间内完成
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
  });
}
