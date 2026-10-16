import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../widgets/album_art_widget.dart';
import '../widgets/song_tile.dart';

/// 歌单详情页
class PlaylistDetailScreen extends StatelessWidget {
  final Playlist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final livePlaylist = provider.playlists.firstWhere(
      (p) => p.id == playlist.id,
      orElse: () => playlist,
    );
    final palette = provider.palette;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                livePlaylist.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (livePlaylist.songs.isNotEmpty)
                    AlbumArtWidget(
                      song: livePlaylist.songs.first,
                      size: double.infinity,
                      borderRadius: 0,
                      placeholderIcon: Icons.playlist_play_rounded,
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: palette.coverPlaceholder),
                      ),
                      child: const Icon(Icons.playlist_play_rounded,
                          size: 80, color: Colors.white70),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha:0.1),
                          Colors.black.withValues(alpha:0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(livePlaylist.name,
                            style:
                                Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 4),
                        Text(
                          '${livePlaylist.songs.length} 首歌曲',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (livePlaylist.songs.isNotEmpty)
                    FloatingActionButton.extended(
                      onPressed: () =>
                          provider.playPlaylist(livePlaylist.songs),
                      backgroundColor: palette.primary,
                      icon: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white),
                      label: const Text('播放全部',
                          style: TextStyle(color: Colors.white)),
                    ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: Divider(height: 1)),
          if (livePlaylist.songs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.playlist_add_rounded,
                        size: 64, color: palette.primary.withValues(alpha:0.5)),
                    const SizedBox(height: 12),
                    const Text('歌单还是空的'),
                    const SizedBox(height: 4),
                    Text('在歌曲列表中点击更多按钮添加歌曲',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = livePlaylist.songs[index];
                  return Dismissible(
                    key: ValueKey(song.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.red,
                      child: const Icon(Icons.delete_rounded,
                          color: Colors.white),
                    ),
                    onDismissed: (_) => provider.removeSongFromPlaylist(
                        livePlaylist.id, song.id),
                    child: SongTile(song: song, index: index),
                  );
                },
                childCount: livePlaylist.songs.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

/// 选择歌单对话框（用于将歌曲添加到歌单）
class PlaylistPickerDialog extends StatelessWidget {
  final Song song;
  const PlaylistPickerDialog({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final playlists = provider.playlists;

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('添加到歌单',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('暂无歌单，请先创建')),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final pl = playlists[index];
                    final contains =
                        pl.songs.any((s) => s.id == song.id);
                    return ListTile(
                      leading: pl.songs.isNotEmpty
                          ? AlbumArtWidget(
                              song: pl.songs.first,
                              size: 44,
                              borderRadius: 8,
                              placeholderIcon:
                                  Icons.playlist_play_rounded,
                            )
                          : const Icon(Icons.playlist_play_rounded),
                      title: Text(pl.name),
                      subtitle: Text('${pl.songs.length} 首'),
                      trailing: contains
                          ? const Icon(Icons.check_rounded,
                              color: Colors.green)
                          : null,
                      onTap: () {
                        if (!contains) {
                          provider.addSongToPlaylist(pl.id, song);
                        }
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _createAndAdd(context, provider);
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('新建歌单并添加'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createAndAdd(BuildContext context, MusicProvider provider) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建歌单'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '歌单名称'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await provider.createPlaylist(ctrl.text.trim());
              if (ctx.mounted) {
                final pl = provider.playlists.last;
                provider.addSongToPlaylist(pl.id, song);
                Navigator.pop(ctx);
              }
            },
            child: const Text('创建并添加'),
          ),
        ],
      ),
    );
  }
}
