import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';

/// 最近播放页 - 按播放时间倒序展示，可一键播放全部
class RecentScreen extends StatelessWidget {
  const RecentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final songs = provider.recentSongs;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('最近播放（${songs.length}）'),
        actions: [
          if (songs.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, provider),
              child: const Text('清空',
                  style: TextStyle(color: AppColors.danger)),
            ),
        ],
      ),
      body: songs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded,
                      size: 72, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  const Text('还没有播放记录',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: songs.length,
              itemBuilder: (context, index) =>
                  SongTile(song: songs[index], index: index, queue: songs),
            ),
      floatingActionButton: songs.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => provider.playPlaylist(songs),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('播放全部'),
            ),
    );
  }

  void _confirmClear(BuildContext context, MusicProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空最近播放'),
        content: const Text('将清除全部播放记录，确定吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white),
            onPressed: () {
              provider.clearRecentSongs();
              Navigator.pop(ctx);
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}
