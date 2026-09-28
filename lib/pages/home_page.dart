import 'package:flutter/material.dart';

import '../config.dart';
import '../widgets/update_check_button.dart';
import 'live_page.dart';
import 'videos_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // 启动后自动检查一次更新（静默失败，仅发现新版本时弹窗）
    if (AppConfig.autoCheckUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) checkUpdate(context, manual: false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppConfig.currentHost,
      builder: (context, host, _) {
        // 切换网络模式时，通过 key 重建页面，触发重新加载数据
        return Scaffold(
          body: IndexedStack(
            index: _index,
            children: [
              LivePage(key: ValueKey('live-$host')),
              VideosPage(key: ValueKey('videos-$host')),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.videocam_outlined),
                selectedIcon: Icon(Icons.videocam),
                label: '实时画面',
              ),
              NavigationDestination(
                icon: Icon(Icons.video_library_outlined),
                selectedIcon: Icon(Icons.video_library),
                label: '视频回放',
              ),
            ],
          ),
        );
      },
    );
  }
}
