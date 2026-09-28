import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import '../widgets/double_buffered_image.dart';
import '../widgets/mjpeg_stream_player.dart';
import '../widgets/network_switch.dart';
import '../widgets/update_check_button.dart';

/// 实时画面模式
enum _LiveMode {
  /// MJPEG 长连接流（推荐，帧率高、闪烁少）
  mjpeg,

  /// HTTP 快照轮询（兼容性更好，可作为降级方案）
  snapshot,
}

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  Timer? _timer;
  String _snapshotUrl = AppConfig.snapshotUrl;
  _LiveMode _mode = _LiveMode.mjpeg;

  @override
  void initState() {
    super.initState();
    _startSnapshotTimer();
  }

  /// 快照模式需要定时刷新 URL；MJPEG 模式不需要。
  void _startSnapshotTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted && _mode == _LiveMode.snapshot) {
        setState(() => _snapshotUrl = AppConfig.snapshotUrl);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == _LiveMode.mjpeg ? _LiveMode.snapshot : _LiveMode.mjpeg;
      if (_mode == _LiveMode.snapshot) {
        _snapshotUrl = AppConfig.snapshotUrl;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('实时画面'),
        actions: [
          const UpdateCheckButton(),
          const NetworkSwitchButton(),
          _ModeBadge(mode: _mode),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, size: 10, color: Colors.white),
                SizedBox(width: 6),
                Text('LIVE',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: _mode == _LiveMode.mjpeg
            ? MjpegStreamPlayer(streamUrl: AppConfig.streamUrl)
            : DoubleBufferedImage(imageUrl: _snapshotUrl),
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _toggleMode,
        tooltip: _mode == _LiveMode.mjpeg ? '切换到快照模式' : '切换到 MJPEG 流',
        child: Icon(
          _mode == _LiveMode.mjpeg ? Icons.burst_mode : Icons.videocam,
        ),
      ),
    );
  }
}

/// 当前模式标识徽章
class _ModeBadge extends StatelessWidget {
  final _LiveMode mode;
  const _ModeBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    final label = mode == _LiveMode.mjpeg ? 'MJPEG' : '快照';
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: mode == _LiveMode.mjpeg
            ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
            : Colors.white24,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: mode == _LiveMode.mjpeg
              ? const Color(0xFF00E5FF)
              : Colors.white54,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: mode == _LiveMode.mjpeg
              ? const Color(0xFF00E5FF)
              : Colors.white70,
        ),
      ),
    );
  }
}
