import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import '../widgets/network_switch.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  Timer? _timer;
  String _url = AppConfig.snapshotUrl;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) {
        setState(() => _url = AppConfig.snapshotUrl);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('实时画面'),
        actions: [
          const NetworkSwitchButton(),
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
        child: Image.network(
          _url,
          key: ValueKey(_url),
          gaplessPlayback: true,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            );
          },
          errorBuilder: (context, error, stack) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_off, size: 64, color: Colors.white38),
                  SizedBox(height: 12),
                  Text('无法连接摄像头',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
