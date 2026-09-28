import 'dart:typed_data';

/// MJPEG 字节流解析结果。
class MjpegParseResult {
  /// 解析出的最新完整 JPEG 帧；没有完整帧时为 null。
  final Uint8List? frame;

  /// 需要保留到下一次解析的剩余字节（不完整的帧头/帧体）。
  final Uint8List remaining;

  const MjpegParseResult({required this.frame, required this.remaining});
}

/// 从 [start] 开始查找 `0xFF [marker]` 标记，返回 `0xFF` 所在下标；未找到返回 -1。
int findJpegMarker(Uint8List bytes, int start, int marker) {
  for (var i = start; i < bytes.length - 1; i++) {
    if (bytes[i] == 0xFF && bytes[i + 1] == marker) {
      return i;
    }
  }
  return -1;
}

/// 从字节缓冲中提取所有完整 JPEG 帧（SOI `0xFFD8` ~ EOI `0xFFD9`）。
///
/// 返回最后一个完整帧以及尚未消费的尾部数据。扫描游标 [cursor] 必须单调递增，
/// 否则会重复提取同一帧而陷入死循环、阻塞调用线程。
///
/// 说明：JPEG 熵编码数据里不会出现裸的 `0xFFD8`/`0xFFD9`（0xFF 后跟 D8/D9 时
/// 会被转义为 `0xFF 0x00`），因此按这两个标记切分是安全且业界通用的做法。
MjpegParseResult parseMjpegFrames(Uint8List bytes) {
  if (bytes.isEmpty) {
    return MjpegParseResult(frame: null, remaining: Uint8List(0));
  }

  Uint8List? latestFrame;
  var cursor = 0;    // 当前扫描位置，必须单调递增
  var keepFrom = 0;  // 需要保留的数据起始位置

  while (cursor < bytes.length - 1) {
    final soi = findJpegMarker(bytes, cursor, 0xD8);
    if (soi == -1) {
      // 没有新的帧头：丢弃无效数据，但保留末尾可能是半个 SOI 的 0xFF
      keepFrom = bytes.last == 0xFF ? bytes.length - 1 : bytes.length;
      break;
    }

    final eoi = findJpegMarker(bytes, soi + 2, 0xD9);
    if (eoi == -1) {
      // 找到帧头但帧体不完整：保留从 SOI 开始的尾部，等待下一块数据
      keepFrom = soi;
      break;
    }

    latestFrame = Uint8List.sublistView(bytes, soi, eoi + 2);
    cursor = eoi + 2;
    keepFrom = cursor;
  }

  final remaining = keepFrom < bytes.length
      ? Uint8List.sublistView(bytes, keepFrom)
      : Uint8List(0);

  return MjpegParseResult(frame: latestFrame, remaining: remaining);
}
