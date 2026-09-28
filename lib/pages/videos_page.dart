import 'package:flutter/material.dart';

import '../models/video_item.dart';
import '../services/api_service.dart';
import '../widgets/network_switch.dart';
import '../widgets/update_check_button.dart';
import 'player_page.dart';

class VideosPage extends StatefulWidget {
  const VideosPage({super.key});

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> {
  late Future<List<VideoItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.fetchVideos();
  }

  Future<void> _refresh() async {
    final f = ApiService.fetchVideos();
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('视频回放'),
        actions: const [UpdateCheckButton(), NetworkSwitchButton()],
      ),
      body: FutureBuilder<List<VideoItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MessageView(
              icon: Icons.error_outline,
              text: '加载失败\n${snapshot.error}',
              onRefresh: _refresh,
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return _MessageView(
              icon: Icons.video_library_outlined,
              text: '暂无存储视频',
              onRefresh: _refresh,
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, i) => _VideoCard(item: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final VideoItem item;
  const _VideoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: const Color(0xFF1A1E27),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
        ),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${item.timeText}  ·  ${item.sizeText}',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerPage(videoName: item.name),
            ),
          );
        },
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  final IconData icon;
  final String text;
  final Future<void> Function() onRefresh;
  const _MessageView(
      {required this.icon, required this.text, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: Colors.white24),
          const SizedBox(height: 16),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新'),
          ),
        ],
      ),
    );
  }
}
