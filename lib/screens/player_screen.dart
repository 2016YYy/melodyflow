import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../services/audio_player_service.dart' show PlaylistMode;
import '../theme/app_theme.dart';
import '../widgets/album_art_widget.dart';
import '../widgets/gradient_progress_bar.dart';
import '../widgets/lyrics_view.dart';

/// 播放器全屏界面 - 支持多皮肤、封面长按放大、渐变进度条
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  bool _showLyrics = false;
  double _dragValue = -1;
  bool _dragging = false;

  String _fmt(Duration d) {
    if (d.inSeconds == 0) return '00:00';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final song = provider.currentSong;
    final palette = provider.palette;
    final skin = provider.playerSkin;

    if (song == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('暂无播放')),
      );
    }

    // 根据皮肤决定背景
    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: skin.name == 'minimal'
          ? [const Color(0xFF0A0A14), const Color(0xFF0A0A14)]
          : [palette.coverPlaceholder[0].withValues(alpha:0.35), const Color(0xFF12121F)],
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context, provider, palette),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showLyrics = !_showLyrics),
                  onLongPress: () => _showArtworkViewer(context, song),
                  child: _showLyrics
                      ? LyricsView(
                          lyrics: provider.currentLyrics,
                          currentPosition: provider.position,
                          onSeek: (pos) => provider.seek(pos),
                        )
                      : _buildCover(context, song, skin, palette),
                ),
              ),
              _buildSongInfo(song, palette),
              _buildProgress(provider, palette),
              _buildControls(provider, palette),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, MusicProvider provider,
      ThemePalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          Column(
            children: [
              const Text('正在播放',
                  style: TextStyle(fontSize: 13, color: Colors.white60)),
              Text(
                provider.playerSkin.label,
                style: TextStyle(
                    fontSize: 11,
                    color: palette.primary,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.palette_rounded),
                tooltip: '切换皮肤',
                onPressed: () => _showSkinPicker(context, provider),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCover(BuildContext context, Song song, PlayerSkin skin,
      ThemePalette palette) {
    // 黑胶皮肤：旋转唱片
    if (skin.name == 'vinyl') {
      return _VinylCover(song: song, palette: palette);
    }

    double coverSize = skin.name == 'minimal' ? 260 : 300;
    double radius = skin.name == 'minimal' ? 24 : 20;

    return Center(
      child: SizedBox(
        width: coverSize,
        height: coverSize,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: AlbumArtWidget(
            song: song,
            size: double.infinity,
            borderRadius: 0,
            placeholderIcon: Icons.music_note_rounded,
          ),
        ),
      ),
    );
  }

  Widget _buildSongInfo(Song song, ThemePalette palette) {
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
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  song.artist,
                  style:
                      const TextStyle(color: Colors.white60, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _FavoriteButton(song: song),
        ],
      ),
    );
  }

  Widget _buildProgress(MusicProvider provider, ThemePalette palette) {
    final duration = provider.duration.inMilliseconds;
    final position = provider.position.inMilliseconds;
    final value = duration > 0 ? position / duration : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          GradientProgressBar(
            value: _dragging ? _dragValue : value,
            gradientColors: palette.gradient,
            height: 6,
            onChanged: (v) {
              setState(() {
                _dragging = true;
                _dragValue = v;
              });
            },
            onChangeEnd: (v) {
              provider.seek(Duration(milliseconds: (v * duration).toInt()));
              setState(() {
                _dragging = false;
                _dragValue = -1;
              });
            },
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(provider.position),
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                Text(_fmt(provider.duration),
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(MusicProvider provider, ThemePalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              provider.shuffle ? Icons.shuffle_on_rounded : Icons.shuffle_rounded,
              color: provider.shuffle ? palette.primary : Colors.white60,
            ),
            onPressed: () => provider.toggleShuffle(),
          ),
          IconButton(
            iconSize: 42,
            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
            onPressed: () => provider.previous(),
          ),
          GestureDetector(
            onTap: () => provider.playPause(),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: palette.gradient),
                boxShadow: [
                  BoxShadow(
                    color: palette.primary.withValues(alpha:0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                provider.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 42,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            iconSize: 42,
            icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
            onPressed: () => provider.next(),
          ),
          IconButton(
            icon: Icon(
              _repeatIcon(provider.repeatMode),
              color: provider.repeatMode != PlaylistMode.none
                  ? palette.primary
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
        return Icons.repeat_one_rounded;
      case PlaylistMode.loop:
        return Icons.repeat_rounded;
      default:
        return Icons.repeat_rounded;
    }
  }

  /// 皮肤选择器
  void _showSkinPicker(BuildContext context, MusicProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('播放器皮肤',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.2,
                children: PlayerSkin.all.map((skin) {
                  final selected =
                      provider.playerSkin.name == skin.name;
                  return GestureDetector(
                    onTap: () {
                      provider.setPlayerSkin(skin.name);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? provider.palette.primary
                              : Colors.white12,
                          width: selected ? 2 : 1,
                        ),
                        color: selected
                            ? provider.palette.primary.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.05),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(_skinIcon(skin.name),
                              color: selected
                                  ? provider.palette.primary
                                  : Colors.white54),
                          const SizedBox(width: 8),
                          Text(skin.label,
                              style: TextStyle(
                                color: selected
                                    ? provider.palette.primary
                                    : Colors.white70,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  IconData _skinIcon(String name) {
    switch (name) {
      case 'classic':
        return Icons.music_note_rounded;
      case 'modern':
        return Icons.album_rounded;
      case 'minimal':
        return Icons.remove_rounded;
      case 'vinyl':
        return Icons.disc_full_rounded;
      default:
        return Icons.album_rounded;
    }
  }

  /// 长按封面 - 全屏查看
  void _showArtworkViewer(BuildContext context, Song song) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) =>
            _ArtworkViewer(song: song),
      ),
    );
  }
}

/// 收藏爱心按钮 - 带弹跳动画，加入「我喜爱」歌单
class _FavoriteButton extends StatefulWidget {
  final Song song;
  const _FavoriteButton({required this.song});

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.45)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.45, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final isFav = provider.isFavorite(widget.song);

    return IconButton(
      iconSize: 30,
      tooltip: isFav ? '取消喜欢' : '喜欢',
      icon: ScaleTransition(
        scale: _scale,
        child: Icon(
          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFav ? const Color(0xFFFF4E7A) : Colors.white60,
        ),
      ),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        await provider.toggleFavorite(widget.song);
        if (!mounted) return;
        _ctrl.forward(from: 0);
        final nowFav = provider.isFavorite(widget.song);
        messenger.showSnackBar(
          SnackBar(
            content: Text(nowFav ? '已添加到「我喜爱」' : '已从「我喜爱」移除'),
            duration: const Duration(milliseconds: 1200),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }
}

/// 黑胶唱片封面（旋转动画）
class _VinylCover extends StatefulWidget {
  final Song song;
  final ThemePalette palette;
  const _VinylCover({required this.song, required this.palette});

  @override
  State<_VinylCover> createState() => _VinylCoverState();
}

class _VinylCoverState extends State<_VinylCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = context.watch<MusicProvider>().isPlaying;
    if (isPlaying && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!isPlaying && _ctrl.isAnimating) {
      _ctrl.stop();
    }

    return Center(
      child: RotationTransition(
        turns: _ctrl,
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 黑胶唱片
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFF2a2a2a),
                      Color(0xFF1a1a1a),
                      Color(0xFF0a0a0a),
                    ],
                  ),
                ),
                child: CustomPaint(
                  painter: _VinylGroovesPainter(),
                ),
              ),
              // 中心封面
              SizedBox(
                width: 140,
                height: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(70),
                  child: AlbumArtWidget(
                    song: widget.song,
                    size: double.infinity,
                    borderRadius: 0,
                    placeholderIcon: Icons.music_note_rounded,
                  ),
                ),
              ),
              // 中心孔
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 黑胶纹路绘制
class _VinylGroovesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.black.withValues(alpha:0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (double r = 50; r < size.width / 2 - 10; r += 6) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 全屏封面查看器
class _ArtworkViewer extends StatefulWidget {
  final Song song;
  const _ArtworkViewer({required this.song});

  @override
  State<_ArtworkViewer> createState() => _ArtworkViewerState();
}

class _ArtworkViewerState extends State<_ArtworkViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _close() {
    _ctrl.reverse().then((_) => Navigator.pop(context));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _close,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha:0.92),
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: _close,
                ),
              ),
              Expanded(
                child: Center(
                  child: ScaleTransition(
                    scale: _scale,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: AlbumArtWidget(
                          song: widget.song,
                          size: double.infinity,
                          borderRadius: 0,
                          placeholderIcon: Icons.music_note_rounded,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(widget.song.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(widget.song.artist,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white60)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
