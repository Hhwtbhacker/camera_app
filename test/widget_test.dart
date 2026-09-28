import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:camera_mobile/config.dart';
import 'package:camera_mobile/main.dart';

void main() {
  setUp(() {
    // 单元测试里不做网络请求（AppConfig.autoCheckUpdate 会触发 GitHub API 检查）
    AppConfig.autoCheckUpdate = false;
  });

  testWidgets('CameraApp 构建并显示底部导航', (WidgetTester tester) async {
    await tester.pumpWidget(const CameraApp());
    await tester.pump();

    // 底部导航包含两个入口
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(2));

    // “实时画面” 同时出现在 LivePage 的 AppBar 标题和底部导航标签中，故为 2 个
    expect(find.text('实时画面'), findsNWidgets(2));
    expect(find.text('视频回放'), findsWidgets);

    // 清空 widget 树，触发 LivePage / MjpegStreamPlayer dispose，
    // 取消 HTTP 连接与重连定时器。
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
