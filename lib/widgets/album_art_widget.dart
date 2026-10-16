import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../theme/app_theme.dart';

/// 专辑封面组件 - 自动加载内嵌/在线封面，无封面时显示精美渐变占位
class AlbumArtWidget extends StatelessWidget {
  final Song song;
  final double size;
  final double borderRadius;
  final IconData placeholderIcon;
  final bool showOnlineArt;

  const AlbumArtWidget({
    super.key,
    required this.song,
    this.size = 48,
    this.borderRadius = 10,
    this.placeholderIcon = Icons.music_note_rounded,
    this.showOnlineArt = true,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final palette = provider.palette;

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: FutureBuilder<Uint8List?>(
          future: provider.getArtwork(song),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Image.memory(snapshot.data!, fit: BoxFit.cover);
            }
            if (showOnlineArt) {
              return FutureBuilder<String?>(
                future: provider.getOnlineArtUrl(song),
                builder: (context, urlSnapshot) {
                  if (urlSnapshot.hasData && urlSnapshot.data != null) {
                    return Image.network(
                      urlSnapshot.data!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _placeholder(palette),
                    );
                  }
                  return _placeholder(palette);
                },
              );
            }
            return _placeholder(palette);
          },
        ),
      ),
    );
  }

  Widget _placeholder(ThemePalette palette) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.coverPlaceholder,
        ),
      ),
      child: Center(
        child: Icon(
          placeholderIcon,
          color: Colors.white.withValues(alpha:0.85),
          size: size * 0.45,
        ),
      ),
    );
  }
}

/// 纯渐变占位封面（用于无 Song 对象的场景，如歌单默认封面）
class GradientCoverPlaceholder extends StatelessWidget {
  final double size;
  final double borderRadius;
  final IconData icon;
  final List<Color>? colors;

  const GradientCoverPlaceholder({
    super.key,
    this.size = 48,
    this.borderRadius = 10,
    this.icon = Icons.music_note_rounded,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<MusicProvider>().palette;
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors ?? palette.coverPlaceholder,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha:0.85),
              size: size * 0.42,
            ),
          ),
        ),
      ),
    );
  }
}
