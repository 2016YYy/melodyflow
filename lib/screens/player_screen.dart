import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/lyric.dart';
import '../providers/music_provider.dart';
import '../services/audio_player_service.dart' show PlaylistMode;
import '../theme/app_theme.dart';
import '../widgets/lyrics_view.dart';

/// 播放器全屏界面
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  bool _showLyrics = false;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final song = provider.currentSong;

    if (song == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('暂无播放')),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16162A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部栏
              _buildTopBar(context),
              // 封面 / 歌词
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showLyrics = !_showLyrics),
                  child: _showLyrics
                      ? LyricsView(
                          lyrics: provider.currentLyrics,
                          currentPosition: provider.position,
                          onSeek: (pos) => provider.seek(pos),
                        )
                      : _buildCover(context, song),
                ),
              ),
              // 歌曲信息
              _buildSongInfo(song),
              // 进度条
              _buildProgress(provider),
              // 控制按钮
              _buildControls(provider),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            '正在播放',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildCover(BuildContext context, dynamic song) {
    final provider = context.watch<MusicProvider>();
    return Center(
      child: SizedBox(
        width: 280,
        height: 280,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: FutureBuilder<Uint8List?>(
            future: provider.getArtwork(song),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return Image.memory(snapshot.data!, fit: BoxFit.cover);
              }
              // 尝试在线封面
              return FutureBuilder<String?>(
                future: provider.getOnlineArtUrl(song),
                builder: (context, urlSnapshot) {
                  if (urlSnapshot.hasData && urlSnapshot.data != null) {
                    return Image.network(urlSnapshot.data!, fit: BoxFit.cover);
                  }
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: AppTheme.coverPlaceholder),
                    ),
                    child: const Icon(Icons.music_note,
                        size: 120, color: Colors.white54),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSongInfo(dynamic song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  song.artist,
                  style: const TextStyle(color: Colors.white60, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              context.read<MusicProvider>().isFavorite(song)
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: context.read<MusicProvider>().isFavorite(song)
                  ? Colors.red
                  : Colors.white60,
            ),
            onPressed: () => context.read<MusicProvider>().toggleFavorite(song),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress(MusicProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Slider(
            value: provider.duration.inMilliseconds > 0
                ? provider.position.inMilliseconds /
                    provider.duration.inMilliseconds
                : 0,
            onChanged: (v) {
              provider.seek(Duration(
                  milliseconds: (v * provider.duration.inMilliseconds).toInt()));
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(provider.position),
                    style: const TextStyle(color: Colors.white54)),
                Text(_fmt(provider.duration),
                    style: const TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(MusicProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              provider.shuffle ? Icons.shuffle_on : Icons.shuffle,
              color: provider.shuffle ? AppTheme.primary : Colors.white60,
            ),
            onPressed: () => provider.toggleShuffle(),
          ),
          IconButton(
            iconSize: 40,
            icon: const Icon(Icons.skip_previous, color: Colors.white),
            onPressed: () => provider.previous(),
          ),
          GestureDetector(
            onTap: () => provider.playPause(),
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.gradient,
              ),
              child: Icon(
                provider.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            iconSize: 40,
            icon: const Icon(Icons.skip_next, color: Colors.white),
            onPressed: () => provider.next(),
          ),
          IconButton(
            icon: Icon(
              _repeatIcon(provider.repeatMode),
              color: provider.repeatMode != PlaylistMode.none
                  ? AppTheme.primary
                  : Colors.white60,
            ),
            onPressed: () => provider.cycleRepeat(),
          ),
        ],
      ),
    );
  }

  IconData _repeatIcon(PlaylistMode mode) {
    switch (mode) {
      case PlaylistMode.single:
        return Icons.repeat_one;
      case PlaylistMode.loop:
        return Icons.repeat;
      default:
        return Icons.repeat;
    }
  }
}
