import 'package:flutter/material.dart';

import '../config.dart';
import '../widgets/mjpeg_stream_player.dart';
import '../widgets/network_switch.dart';
import '../widgets/update_check_button.dart';

/// 实时画面页：MJPEG 长连接流（帧率高、闪烁少）
class LivePage extends StatelessWidget {
  const LivePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('实时画面'),
        actions: const [
          UpdateCheckButton(),
          NetworkSwitchButton(),
          _StreamBadge(),
          _LiveBadge(),
        ],
      ),
      body: Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        // 切换局域网/公网后 streamUrl 会变化，MjpegStreamPlayer 据此自动重连
        child: ValueListenableBuilder<String>(
          valueListenable: AppConfig.currentHost,
          builder: (context, host, _) =>
              MjpegStreamPlayer(streamUrl: AppConfig.streamUrl),
        ),
      ),
    );
  }
}

/// 当前播放方式徽章
class _StreamBadge extends StatelessWidget {
  const _StreamBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00E5FF), width: 1),
      ),
      child: const Text(
        'MJPEG',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF00E5FF),
        ),
      ),
    );
  }
}

/// 直播状态徽章
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            'LIVE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
