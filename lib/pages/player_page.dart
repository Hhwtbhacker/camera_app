import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../config.dart';

class PlayerPage extends StatefulWidget {
  final String videoName;
  const PlayerPage({super.key, required this.videoName});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(AppConfig.videoUrl(widget.videoName)),
    )..initialize().then((_) {
        if (mounted) {
          setState(() => _ready = true);
          _controller.play();
        }
      }).catchError((Object e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('播放失败：$e')),
          );
        }
      });
    _controller.addListener(_onTick);
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final pos = _controller.value.position;
    final dur = _controller.value.duration;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.videoName, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: !_ready
                  ? const CircularProgressIndicator()
                  : AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
            ),
          ),
          _buildControls(pos, dur),
        ],
      ),
    );
  }

  Widget _buildControls(Duration pos, Duration dur) {
    final max = dur.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    final value = pos.inMilliseconds.toDouble().clamp(0.0, max);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      color: const Color(0xFF161A22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Slider(
            value: value,
            max: max,
            activeColor: const Color(0xFF00E5FF),
            onChanged: (v) {
              _controller.seekTo(Duration(milliseconds: v.round()));
            },
          ),
          Row(
            children: [
              Text(_fmt(pos), style: const TextStyle(color: Colors.white70)),
              const Spacer(),
              Text(_fmt(dur), style: const TextStyle(color: Colors.white70)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 44,
                icon: Icon(
                  _controller.value.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
