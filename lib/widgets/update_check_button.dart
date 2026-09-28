import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../services/update_service.dart';

/// AppBar 上的「检查更新」按钮（点击后手动检查 GitHub 上的最新版本）
class UpdateCheckButton extends StatelessWidget {
  const UpdateCheckButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.system_update_alt),
      color: Colors.white,
      tooltip: '检查更新',
      onPressed: () => checkUpdate(context),
    );
  }
}

/// 检查更新主流程。
///
/// [manual] 为 true（用户点击）：显示检查中动画与结果提示；
/// [manual] 为 false（启动自动检查）：静默失败，仅在有新版本时弹窗。
Future<void> checkUpdate(BuildContext context, {bool manual = true}) async {
  final messenger = ScaffoldMessenger.of(context);

  if (!Platform.isAndroid) {
    if (manual) _toast(messenger, '当前平台暂不支持应用内更新');
    return;
  }

  // 手动检查时给出「检查中」反馈
  final closeLoading = manual
      ? _showBlockingDialog(context, (_) => const _CheckingDialog())
      : null;

  UpdateInfo? info;
  CurrentVersion? current;
  String? error;
  try {
    current = await UpdateService.currentVersion();
    info = await UpdateService.checkForUpdate(current);
  } catch (e) {
    error = e.toString();
  }
  closeLoading?.call();

  if (error != null) {
    if (manual) _toast(messenger, '检查更新失败：$error');
    return;
  }
  if (info == null) {
    if (manual && current != null) {
      _toast(messenger, '已是最新版本 ${current.version}+${current.build}');
    }
    return;
  }
  if (!context.mounted) return;

  final shouldUpdate = await showDialog<bool>(
    context: context,
    builder: (_) => _UpdateDialog(info: info!, current: current!),
  );
  if (shouldUpdate != true || !context.mounted) return;

  await _downloadAndInstall(context, info);
}

/// 下载（带进度、可取消）并调起系统安装器
Future<void> _downloadAndInstall(BuildContext context, UpdateInfo info) async {
  final messenger = ScaffoldMessenger.of(context);
  final progress = ValueNotifier<double>(0);
  final status = ValueNotifier<String>('正在连接…');
  var cancelled = false;

  final closeDialog = _showBlockingDialog(
    context,
    (_) => _DownloadDialog(
      progress: progress,
      status: status,
      onCancel: () => cancelled = true,
    ),
  );

  void finish() {
    closeDialog();
    // 等弹窗动画结束再释放，避免 ValueListenableBuilder 继续监听已释放的对象
    Future.delayed(const Duration(milliseconds: 400), () {
      progress.dispose();
      status.dispose();
    });
  }

  try {
    final file = await UpdateService.downloadApk(info, (received, total) {
      if (cancelled) return false;
      if (total != null && total > 0) {
        progress.value = (received / total).clamp(0.0, 1.0);
        status.value = '${_mb(received)} / ${_mb(total)}';
      } else {
        status.value = '已下载 ${_mb(received)}';
      }
      return true;
    });
    finish();
    await UpdateService.installApk(file);
    _toast(messenger, '已调起系统安装器，确认后即可完成更新');
  } on UpdateCancelled {
    finish();
    _toast(messenger, '已取消下载');
  } catch (e) {
    finish();
    _toast(messenger, '更新失败：$e');
  }
}

/// 弹出一个不可取消的浮层，返回关闭函数。
/// 基于 Route 而不是弹窗内部 context，避免「弹窗首帧还没构建就要关闭」的时序问题。
VoidCallback _showBlockingDialog(BuildContext context, WidgetBuilder builder) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: builder,
  );
  unawaited(navigator.push(route));
  return () {
    if (route.isActive) navigator.removeRoute(route);
  };
}

String _mb(int bytes) => '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

void _toast(ScaffoldMessengerState messenger, String text) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// 「检查中」弹窗
class _CheckingDialog extends StatelessWidget {
  const _CheckingDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 16),
          Text('正在检查更新…'),
        ],
      ),
    );
  }
}
/// 「发现新版本」弹窗
class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.info, required this.current});

  final UpdateInfo info;
  final CurrentVersion current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('发现新版本'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'v${info.versionText}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '当前版本 ${current.version}+${current.build}  ·  ${info.sizeText}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: Text(info.notes),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('稍后'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.download),
          label: const Text('立即更新'),
        ),
      ],
    );
  }
}

/// 「下载中」弹窗（进度 + 体积，可取消）
class _DownloadDialog extends StatelessWidget {
  const _DownloadDialog({
    required this.progress,
    required this.status,
    required this.onCancel,
  });

  final ValueNotifier<double> progress;
  final ValueNotifier<String> status;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('正在下载更新'),
      content: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (context, value, _) => ValueListenableBuilder<String>(
          valueListenable: status,
          builder: (context, text, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: value == 0 ? null : value,
                minHeight: 6,
              ),
              const SizedBox(height: 12),
              Text(text),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: onCancel, child: const Text('取消下载')),
      ],
    );
  }
}

