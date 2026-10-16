import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../screens/playlist_detail_screen.dart';
import 'album_art_widget.dart';

/// 歌曲列表项
class SongTile extends StatelessWidget {
  final Song song;
  final int? index;
  final VoidCallback? onMore;
  final bool showIndex;

  const SongTile({
    super.key,
    required this.song,
    this.index,
    this.onMore,
    this.showIndex = false,
  });

  String _formatDuration(Duration d) {
    if (d.inSeconds == 0) return '--:--';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MusicProvider>();
    final isCurrent = provider.currentSong?.id == song.id;
    final palette = provider.palette;

    return Material(
      color: isCurrent
          ? palette.primary.withValues(alpha:0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: () => provider.playSong(song),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (showIndex && index != null)
                SizedBox(
                  width: 28,
                  child: Text(
                    '${index! + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isCurrent ? palette.primary : null,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                AlbumArtWidget(song: song, size: 48, borderRadius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.w500,
                        color: isCurrent ? palette.primary : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${song.artist} · ${song.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (isCurrent && provider.isPlaying)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _PlayingIndicator(color: palette.primary),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (song.duration.inSeconds > 0)
                    Text(
                      _formatDuration(song.duration),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (song.sourceType != MusicSourceType.local) ...[
                    const SizedBox(width: 8),
                    Icon(_sourceIcon(song.sourceType),
                        size: 16, color: palette.primary),
                  ],
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onPressed: onMore ?? () => _showMoreMenu(context, provider, song),
                    splashRadius: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _sourceIcon(MusicSourceType type) {
    switch (type) {
      case MusicSourceType.webdav:
        return Icons.cloud_rounded;
      case MusicSourceType.network:
        return Icons.language_rounded;
      case MusicSourceType.smb:
        return Icons.folder_shared_rounded;
      default:
        return Icons.music_note_rounded;
    }
  }

  /// 更多操作菜单
  static void _showMoreMenu(
      BuildContext context, MusicProvider provider, Song song) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('添加到歌单'),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => PlaylistPickerDialog(song: song),
                );
              },
            ),
            ListTile(
              leading: Icon(
                provider.isFavorite(song)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: provider.isFavorite(song) ? Colors.red : null,
              ),
              title: Text(provider.isFavorite(song) ? '取消收藏' : '收藏'),
              onTap: () {
                provider.toggleFavorite(song);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('歌曲信息'),
              onTap: () {
                Navigator.pop(ctx);
                _showSongInfo(context, song);
              },
            ),
          ],
        ),
      ),
    );
  }

  static void _showSongInfo(BuildContext context, Song song) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('歌曲信息'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _infoRow('标题', song.title),
              _infoRow('艺术家', song.artist),
              _infoRow('专辑', song.album),
              _infoRow(
                  '时长',
                  song.duration.inSeconds > 0
                      ? '${song.duration.inMinutes}:${(song.duration.inSeconds % 60).toString().padLeft(2, '0')}'
                      : '未知'),
              _infoRow('来源', song.sourceType.name),
              _infoRow('路径', song.uri),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭')),
        ],
      ),
    );
  }

  static Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.grey),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// 播放中动画指示器（三条跳动竖线）
class _PlayingIndicator extends StatelessWidget {
  final Color color;
  const _PlayingIndicator({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          return _Bar(delay: i * 0.15, color: color);
        }),
      ),
    );
  }
}

class _Bar extends StatefulWidget {
  final double delay;
  final Color color;
  const _Bar({required this.delay, required this.color});

  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          width: 3,
          height: 4 + _ctrl.value * 12,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }
}
