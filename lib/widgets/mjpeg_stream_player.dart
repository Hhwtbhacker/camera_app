import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../utils/mjpeg_parser.dart';

/// MJPEG 流播放器。
///
/// 通过长连接持续接收 multipart/x-mixed-replace 流，按 JPEG 帧边界（SOI 0xFFD8 /
/// EOI 0xFFD9）拆分并逐帧显示。相比轮询快照，长连接避免了重复的 TCP/TLS 握手与
/// HTTP 头开销，帧率更高、闪烁更少。
class MjpegStreamPlayer extends StatefulWidget {
  /// 流地址，例如 http://pi:8080/stream
  final String streamUrl;

  /// 图片填充方式
  final BoxFit fit;

  /// 断线后自动重连间隔
  final Duration reconnectDelay;

  const MjpegStreamPlayer({
    super.key,
    required this.streamUrl,
    this.fit = BoxFit.contain,
    this.reconnectDelay = const Duration(seconds: 3),
  });

  @override
  State<MjpegStreamPlayer> createState() => _MjpegStreamPlayerState();
}

class _MjpegStreamPlayerState extends State<MjpegStreamPlayer> {
  http.Client _client = http.Client();
  final BytesBuilder _buffer = BytesBuilder();
  Uint8List? _frame;
  String? _error;
  bool _isLoading = true;
  StreamSubscription<List<int>>? _subscription;
  Timer? _reconnectTimer;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(covariant MjpegStreamPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _disconnect();
      _connect();
    }
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  void _connect() {
    if (!mounted) return;
    setState(() {
      _error = null;
      _isLoading = true;
    });
    _buffer.clear();

    final request = http.Request('GET', Uri.parse(widget.streamUrl));
    request.headers['Accept'] = 'multipart/x-mixed-replace';

    _client.send(request).then((response) {
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      _subscription = response.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: true,
      );
    }).catchError(_onError);
  }

  void _onData(List<int> chunk) {
    _buffer.add(chunk);
    _extractFrames();
  }

  /// 解析缓冲区中的完整 JPEG 帧，只把最后一帧交给 UI，未完整的尾部留待下次。
  void _extractFrames() {
    final result = parseMjpegFrames(_buffer.toBytes());

    _buffer.clear();
    if (result.remaining.isNotEmpty) {
      _buffer.add(result.remaining);
    }

    if (result.frame != null && mounted) {
      setState(() {
        _frame = result.frame;
        _isLoading = false;
        _error = null;
      });
    }

    // 防止因长时间找不到帧边界导致内存无限增长（>10MB 时丢弃）
    if (_buffer.length > 10 * 1024 * 1024) {
      _buffer.clear();
    }
  }

  void _onError(Object error, [StackTrace? stackTrace]) {
    if (!mounted) return;
    // 已显示过画面时保持最后一帧并静默重连，避免画面闪断；
    // 只有从未收到任何帧时才展示错误界面。
    if (_frame == null) {
      setState(() => _error = error.toString());
    }
    _scheduleReconnect();
  }

  void _onDone() {
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(widget.reconnectDelay, () {
      if (mounted) {
        _disconnect();
        _connect();
      }
    });
  }

  void _disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _buffer.clear();
    _client.close();
    _client = http.Client();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, size: 64, color: Colors.white38),
            const SizedBox(height: 12),
            Text(
              '连接失败: $_error',
              style: const TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_isLoading || _frame == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }

    return Image.memory(
      _frame!,
      gaplessPlayback: true,
      fit: widget.fit,
      filterQuality: FilterQuality.low,
    );
  }
}
