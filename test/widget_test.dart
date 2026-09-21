import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:camera_mobile/main.dart';

void main() {
  testWidgets('CameraApp 构建并显示底部导航', (WidgetTester tester) async {
    await tester.pumpWidget(const CameraApp());
    await tester.pump();

    expect(find.text('实时画面'), findsOneWidget);
    expect(find.text('视频回放'), findsOneWidget);

    // 清空 widget 树，触发 LivePage dispose 取消 Timer
    await tester.pumpWidget(const SizedBox());
  });
}
