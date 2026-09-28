import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:camera_mobile/main.dart';

void main() {
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
    // 取消 HTTP 连接、轮询定时器和重连定时器。
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
