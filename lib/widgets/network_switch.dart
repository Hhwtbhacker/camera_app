import 'package:flutter/material.dart';

import '../config.dart';

/// 网络模式切换按钮（局域网/公网）
class NetworkSwitchButton extends StatelessWidget {
  const NetworkSwitchButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppConfig.currentHost,
      builder: (context, host, _) {
        return TextButton.icon(
          onPressed: AppConfig.toggleNetwork,
          icon: Icon(
            AppConfig.isLan ? Icons.wifi : Icons.public,
            size: 18,
            color: Colors.white,
          ),
          label: Text(
            AppConfig.modeLabel,
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );
  }
}
