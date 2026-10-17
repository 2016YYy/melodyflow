import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/album_art_widget.dart';

/// 播放队列页 - 查看当前队列、点击跳转、滑动移除、清空
class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final queue = provider.queue;
    final currentIndex = provider.queueIndex;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('播放队列（${queue.length}）'),
        actions: [
          if (queue.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, provider),
              child: Text('清空', style: TextStyle(color: AppColors.danger)),
            ),
        ],
      ),
      body: queue.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.queue_music_rounded,
                      size: 72, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  const Text('播放队列为空',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('去音乐库挑几首歌吧',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final song = queue[index];
                final isCurrent = index == currentIndex;
                return Dismissible(
                  key: ValueKey('${song.id}_$index'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: AppColors.danger,
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Colors.white),
                  ),
                  onDismissed: (_) => provider.removeFromQueue(index),
                  child: ListTile(
                    leading: AlbumArtWidget(
                      song: song,
                      size: 46,
                      borderRadius: AppRadius.sm,
                    ),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isCurrent ? scheme.primary : null,
                      ),
                    ),
                    subtitle: Text(song.artist,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: isCurrent
                        ? Icon(Icons.equalizer_rounded,
                            color: scheme.primary)
                        : null,
                    onTap: () => provider.playQueueAt(index),
                  ),
                );
              },
            ),
    );
  }

  void _confirmClear(BuildContext context, MusicProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空播放队列'),
        content: const Text('将停止当前播放并清空整个队列，确定吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white),
            onPressed: () {
              provider.clearQueue();
              Navigator.pop(ctx);
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}
