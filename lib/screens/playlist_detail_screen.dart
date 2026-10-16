import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../widgets/album_art_widget.dart';
import '../widgets/collection_header.dart';
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
    final songs = livePlaylist.songs;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CollectionCoverAppBar(
            title: livePlaylist.name,
            coverSong: songs.isNotEmpty ? songs.first : null,
            fallbackIcon: Icons.playlist_play_rounded,
          ),
          SliverToBoxAdapter(
            child: CollectionInfoBar(
              subtitle: '${songs.length} 首歌曲',
              onPlayAll:
                  songs.isEmpty ? null : () => provider.playPlaylist(songs),
              onShuffle: songs.isEmpty
                  ? null
                  : () => provider.playPlaylist(
                      List<Song>.from(songs)..shuffle()),
            ),
          ),
          const SliverToBoxAdapter(child: Divider(height: 1)),
          if (songs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.playlist_add_rounded,
                        size: 56,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.5)),
                    const SizedBox(height: 14),
                    const Text('歌单还是空的',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('在歌曲列表中点击更多按钮添加歌曲',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = songs[index];
                  return Dismissible(
                    key: ValueKey(song.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 1),
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5484D),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.delete_rounded,
                          color: Colors.white),
                    ),
                    onDismissed: (_) => provider.removeSongFromPlaylist(
                        livePlaylist.id, song.id),
                    child: SongTile(song: song, index: index),
                  );
                },
                childCount: songs.length,
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('添加到歌单', style: Theme.of(context).textTheme.titleLarge),
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
                    final contains = pl.songs.any((s) => s.id == song.id);
                    return ListTile(
                      leading: pl.songs.isNotEmpty
                          ? AlbumArtWidget(
                              song: pl.songs.first,
                              size: 44,
                              borderRadius: 12,
                              placeholderIcon: Icons.playlist_play_rounded,
                            )
                          : const Icon(Icons.playlist_play_rounded),
                      title: Text(pl.name),
                      subtitle: Text('${pl.songs.length} 首'),
                      trailing: contains
                          ? Icon(Icons.check_rounded,
                              color: provider.palette.primary)
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
