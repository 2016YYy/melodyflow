import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../theme/app_theme.dart';

/// 歌曲列表项
class SongTile extends StatelessWidget {
  final Song song;
  final int? index;
  final VoidCallback? onMore;

  const SongTile({
    super.key,
    required this.song,
    this.index,
    this.onMore,
  });

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MusicProvider>();
    final isCurrent = provider.currentSong?.id == song.id;

    return ListTile(
      leading: _SongArtwork(song: song),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          color: isCurrent ? AppTheme.primary : null,
        ),
      ),
      subtitle: Text(
        '${song.artist} · ${song.album}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (song.duration.inSeconds > 0)
            Text(
              _formatDuration(song.duration),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (song.sourceType != MusicSourceType.local) ...[
            const SizedBox(width: 8),
            Icon(
              _sourceIcon(song.sourceType),
              size: 16,
              color: AppTheme.primary,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            onPressed: onMore,
          ),
        ],
      ),
      onTap: () => provider.playSong(song),
    );
  }

  IconData _sourceIcon(MusicSourceType type) {
    switch (type) {
      case MusicSourceType.webdav:
        return Icons.cloud;
      case MusicSourceType.network:
        return Icons.language;
      case MusicSourceType.smb:
        return Icons.folder_shared;
      default:
        return Icons.music_note;
    }
  }
}

/// 歌曲封面组件
class _SongArtwork extends StatelessWidget {
  final Song song;
  const _SongArtwork({required this.song});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    return SizedBox(
      width: 48,
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<Uint8List?>(
          future: provider.getArtwork(song),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Image.memory(snapshot.data!, fit: BoxFit.cover);
            }
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppTheme.coverPlaceholder,
                ),
              ),
              child: const Icon(Icons.music_note, color: Colors.white, size: 24),
            );
          },
        ),
      ),
    );
  }
}
