import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../widgets/collection_header.dart';
import '../widgets/song_tile.dart';

/// 歌曲集合详情页（专辑 / 艺术家）
class GroupSongsScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Song> songs;
  final Song? coverSong; // 用于显示封面的代表歌曲
  final IconData fallbackIcon;

  const GroupSongsScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.songs,
    this.coverSong,
    this.fallbackIcon = Icons.album_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CollectionCoverAppBar(
            title: title,
            coverSong: coverSong,
            fallbackIcon: fallbackIcon,
          ),
          SliverToBoxAdapter(
            child: CollectionInfoBar(
              subtitle: subtitle,
              onPlayAll:
                  songs.isEmpty ? null : () => provider.playPlaylist(songs),
              onShuffle: songs.isEmpty
                  ? null
                  : () => provider.playPlaylist(
                      List<Song>.from(songs)..shuffle()),
            ),
          ),
          const SliverToBoxAdapter(child: Divider(height: 1)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return SongTile(
                  song: songs[index],
                  index: index,
                  showIndex: true,
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
