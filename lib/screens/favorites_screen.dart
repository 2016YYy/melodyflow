import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../widgets/album_art_widget.dart';
import '../widgets/song_tile.dart';

/// 「我喜爱」系统歌单页
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final palette = provider.palette;
    final songs = provider.favoriteSongs;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                '我喜爱',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (songs.isNotEmpty)
                    AlbumArtWidget(
                      song: songs.first,
                      size: double.infinity,
                      borderRadius: 0,
                      placeholderIcon: Icons.favorite_rounded,
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: palette.gradient,
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.favorite_rounded,
                            size: 88, color: Colors.white70),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.72),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('我喜爱',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium),
                        const SizedBox(height: 4),
                        Text('${songs.length} 首歌曲',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  if (songs.isNotEmpty) ...[
                    IconButton(
                      onPressed: () =>
                          provider.playPlaylist(_shuffled(songs)),
                      icon: const Icon(Icons.shuffle_rounded),
                      color: palette.primary,
                      tooltip: '随机播放',
                    ),
                    FloatingActionButton.extended(
                      heroTag: 'fav_play',
                      onPressed: () => provider.playPlaylist(songs),
                      backgroundColor: palette.primary,
                      icon: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white),
                      label: const Text('播放全部',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ],
              ),
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
                    Icon(Icons.favorite_border_rounded,
                        size: 64, color: palette.primary.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text('还没有喜欢的歌曲'),
                    const SizedBox(height: 4),
                    Text('点击歌曲或播放页的爱心即可加入「我喜爱」',
                        style: Theme.of(context).textTheme.bodySmall),
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
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.red,
                      child: const Icon(Icons.heart_broken_rounded,
                          color: Colors.white),
                    ),
                    onDismissed: (_) => provider.removeFavorite(song),
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

  static List<Song> _shuffled(List<Song> songs) {
    final list = List<Song>.from(songs)..shuffle();
    return list;
  }
}
