import 'package:flutter/material.dart';

import 'pages/home_page.dart';

void main() {
  runApp(const CameraApp());
}

class CameraApp extends StatelessWidget {
  const CameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pi 摄像头',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F1115),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161A22),
          elevation: 0,
        ),
      ),
      home: const HomePage(),
    );
  }
}
