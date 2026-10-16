import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../services/update_controller.dart';
import '../services/update_service.dart';

/// 检查更新流程：有新版本时弹出更新弹窗
Future<void> runUpdateCheck(BuildContext context) async {
  final service = UpdateService();
  final messenger = ScaffoldMessenger.of(context);
  final release = await service.checkForUpdates();
  if (!context.mounted) return;
  if (release == null) {
    messenger.showSnackBar(const SnackBar(content: Text('已是最新版本')));
  } else {
    showUpdateAvailableDialog(
      context,
      release: release,
      onDownload: () => runUpdateDownload(context, release),
    );
  }
}

/// 下载更新流程：显示进度弹窗，完成后提示安装
Future<void> runUpdateDownload(BuildContext context, ReleaseInfo release) async {
  final controller = UpdateDownloadController();
  final messenger = ScaffoldMessenger.of(context);
  final future = controller.start(release);
  unawaited(showDownloadProgressDialog(context, controller));
  await future;
  if (controller.resultPath != null) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('更新包已下载到:\n${controller.resultPath}\n请在系统安装器中完成安装'),
        duration: const Duration(seconds: 6),
      ),
    );
  } else if (controller.error != null) {
    messenger.showSnackBar(SnackBar(content: Text(controller.error!)));
  } else if (controller.cancelled) {
    messenger.showSnackBar(const SnackBar(content: Text('已取消下载')));
  }
  controller.dispose();
}

/// 有可用更新弹窗（圆角居中卡片样式）
Future<void> showUpdateAvailableDialog(
  BuildContext context, {
  required ReleaseInfo release,
  required VoidCallback onDownload,
}) {
  final palette = context.read<MusicProvider>().palette;
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.download_rounded, size: 46, color: palette.primary),
            const SizedBox(height: 14),
            const Text(
              '有可用更新',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              '发现新版本 ${release.tagName}。',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                child: Text(
                  release.body.isEmpty ? '暂无更新说明' : release.body,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: Theme.of(ctx).textTheme.bodySmall?.color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('跳过此版本'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onDownload();
                  },
                  child: Text(
                    '下载并安装',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: palette.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// 下载进度弹窗（支持「隐藏」后台继续下载）
Future<void> showDownloadProgressDialog(
  BuildContext context,
  UpdateDownloadController controller,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => _DownloadProgressDialog(controller: controller),
  );
}

class _DownloadProgressDialog extends StatefulWidget {
  final UpdateDownloadController controller;
  const _DownloadProgressDialog({required this.controller});

  @override
  State<_DownloadProgressDialog> createState() =>
      _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  void _onChange() {
    if (!widget.controller.downloading && mounted) {
      // 下载完成 / 失败后自动关闭，结果由调用方提示
      Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.read<MusicProvider>().palette;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.download_rounded, size: 46, color: palette.primary),
              const SizedBox(height: 14),
              const Text(
                '正在下载更新',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                '正在下载安装包，完成后将自动安装。',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: widget.controller.progress,
                  minHeight: 8,
                  backgroundColor: palette.primary.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(palette.primary),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.controller.status,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('隐藏'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
