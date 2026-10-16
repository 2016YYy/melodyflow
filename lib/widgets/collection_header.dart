import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import 'album_art_widget.dart';

/// 集合页（专辑 / 艺术家 / 歌单 / 我喜爱）统一的顶部封面头图
class CollectionCoverAppBar extends StatelessWidget {
  final String title;
  final Song? coverSong;
  final IconData fallbackIcon;
  final double expandedHeight;

  const CollectionCoverAppBar({
    super.key,
    required this.title,
    this.coverSong,
    this.fallbackIcon = Icons.album_rounded,
    this.expandedHeight = 250,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.read<MusicProvider>().palette;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        titlePadding: const EdgeInsetsDirectional.only(
            start: 56, end: 16, bottom: 14),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
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
                      size: 84, color: Colors.white.withValues(alpha: 0.7)),
                ),
              ),
            // 渐变遮罩，保证白色文字与图标始终可读
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.72),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 集合页信息栏：数量 + 随机播放 + 播放全部
class CollectionInfoBar extends StatelessWidget {
  final String subtitle;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffle;

  const CollectionInfoBar({
    super.key,
    required this.subtitle,
    this.onPlayAll,
    this.onShuffle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              subtitle,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
          if (onShuffle != null)
            IconButton(
              onPressed: onShuffle,
              icon: const Icon(Icons.shuffle_rounded),
              color: scheme.primary,
              tooltip: '随机播放',
            ),
          if (onPlayAll != null)
            FilledButton.icon(
              onPressed: onPlayAll,
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: const Text('播放全部'),
            ),
        ],
      ),
    );
  }
}
