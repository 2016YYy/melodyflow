import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../widgets/collection_header.dart';
import '../widgets/song_tile.dart';

/// 「我喜爱」系统歌单页
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final songs = provider.favoriteSongs;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CollectionCoverAppBar(
            title: '我喜爱',
            coverSong: songs.isNotEmpty ? songs.first : null,
            fallbackIcon: Icons.favorite_rounded,
          ),
          SliverToBoxAdapter(
            child: CollectionInfoBar(
              subtitle: '${songs.length} 首歌曲 · 系统歌单',
              onPlayAll:
                  songs.isEmpty ? null : () => provider.playPlaylist(songs),
              onShuffle: songs.isEmpty
                  ? null
                  : () => provider.playPlaylist(_shuffled(songs)),
            ),
          ),
          const SliverToBoxAdapter(child: Divider(height: 1)),
          if (songs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyFavorites(
                primary: Theme.of(context).colorScheme.primary,
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
                    background: _dismissBackground(
                      const Icon(Icons.heart_broken_rounded,
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

Widget _dismissBackground(Widget icon) {
  return Container(
    alignment: Alignment.centerRight,
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
    padding: const EdgeInsets.only(right: 20),
    decoration: BoxDecoration(
      color: const Color(0xFFE5484D),
      borderRadius: BorderRadius.circular(18),
    ),
    child: icon,
  );
}

class _EmptyFavorites extends StatelessWidget {
  final Color primary;
  const _EmptyFavorites({required this.primary});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withValues(alpha: 0.12),
            ),
            child: Icon(Icons.favorite_border_rounded,
                size: 44, color: primary),
          ),
          const SizedBox(height: 18),
          const Text('还没有喜欢的歌曲',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('点击歌曲或播放页的爱心即可加入「我喜爱」',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
