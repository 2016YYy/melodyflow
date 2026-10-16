import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../widgets/album_art_widget.dart';
import '../widgets/song_tile.dart';

/// 歌曲集合详情页（专辑/艺术家/歌单）
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
    final provider = context.read<MusicProvider>();
    final palette = provider.palette;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverSong != null)
                    AlbumArtWidget(
                      song: coverSong!,
                      size: double.infinity,
                      borderRadius: 0,
                      placeholderIcon: fallbackIcon,
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: palette.coverPlaceholder,
                        ),
                      ),
                      child: Center(
                        child: Icon(fallbackIcon,
                            size: 80, color: Colors.white.withValues(alpha:0.7)),
                      ),
                    ),
                  // 渐变遮罩
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
                        Text(title,
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  FloatingActionButton.extended(
                    onPressed: () => provider.playPlaylist(songs),
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
