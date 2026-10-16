import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../services/audio_player_service.dart' show PlaylistMode;
import '../theme/app_theme.dart';
import '../widgets/album_art_widget.dart';
import '../widgets/gradient_progress_bar.dart';
import '../widgets/lyrics_view.dart';

/// 播放器全屏界面 - 沉浸式模糊封面背景、多皮肤、动态主题、封面长按放大
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (song == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('暂无播放')),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(context, song, isDark),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context, provider, skin, scheme),
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
                        : _buildCover(song, skin),
                  ),
                ),
                _buildSongInfo(context, song, scheme),
                const SizedBox(height: 6),
                _buildProgress(provider, palette, scheme),
                const SizedBox(height: 8),
                _buildControls(context, provider, palette, scheme),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 沉浸式背景：模糊封面 + 渐隐到主题底色
  Widget _buildBackground(BuildContext context, Song song, bool isDark) {
    final base = Theme.of(context).scaffoldBackgroundColor;
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 64, sigmaY: 64),
            child: Transform.scale(
              scale: 1.4,
              child: AlbumArtWidget(
                song: song,
                size: double.infinity,
                borderRadius: 0,
                placeholderIcon: Icons.music_note_rounded,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  base.withValues(alpha: isDark ? 0.30 : 0.50),
                  base.withValues(alpha: 0.86),
                  base,
                ],
                stops: const [0.0, 0.5, 0.9],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    MusicProvider provider,
    PlayerSkin skin,
    ColorScheme scheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
            color: scheme.onSurface,
            onPressed: () => Navigator.pop(context),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '正在播放',
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                skin.label,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.palette_rounded),
            color: scheme.onSurface,
            tooltip: '切换皮肤',
            onPressed: () => _showSkinPicker(context, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildCover(Song song, PlayerSkin skin) {
    switch (skin.name) {
      case 'vinyl':
        return _VinylCover(song: song);
      case 'classic':
        return _ClassicCover(song: song);
      case 'minimal':
        return _MinimalCover(song: song);
      case 'modern':
      default:
        return _ModernCover(song: song);
    }
  }

  Widget _buildSongInfo(BuildContext context, Song song, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  song.artist,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 15,
                  ),
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

  Widget _buildProgress(
    MusicProvider provider,
    ThemePalette palette,
    ColorScheme scheme,
  ) {
    final duration = provider.duration.inMilliseconds;
    final position = provider.position.inMilliseconds;
    final value = duration > 0 ? position / duration : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          GradientProgressBar(
            value: _dragging ? _dragValue : value,
            gradientColors: palette.gradient,
            height: 5,
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
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(provider.position),
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12)),
                Text(_fmt(provider.duration),
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(
    BuildContext context,
    MusicProvider provider,
    ThemePalette palette,
    ColorScheme scheme,
  ) {
    final active = scheme.primary;
    final inactive = scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            iconSize: 26,
            icon: Icon(
              provider.shuffle
                  ? Icons.shuffle_on_rounded
                  : Icons.shuffle_rounded,
              color: provider.shuffle ? active : inactive,
            ),
            onPressed: () => provider.toggleShuffle(),
          ),
          IconButton(
            iconSize: 42,
            icon: Icon(Icons.skip_previous_rounded, color: scheme.onSurface),
            onPressed: () => provider.previous(),
          ),
          _PlayButton(
            isPlaying: provider.isPlaying,
            palette: palette,
            onTap: () => provider.playPause(),
          ),
          IconButton(
            iconSize: 42,
            icon: Icon(Icons.skip_next_rounded, color: scheme.onSurface),
            onPressed: () => provider.next(),
          ),
          IconButton(
            iconSize: 26,
            icon: Icon(
              _repeatIcon(provider.repeatMode),
              color: provider.repeatMode != PlaylistMode.none
                  ? active
                  : inactive,
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
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('播放器皮肤', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.3,
                children: PlayerSkin.all.map((skin) {
                  final selected = provider.playerSkin.name == skin.name;
                  return GestureDetector(
                    onTap: () {
                      provider.setPlayerSkin(skin.name);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: selected
                              ? scheme.primary
                              : scheme.outlineVariant,
                          width: selected ? 2 : 1,
                        ),
                        color: selected
                            ? scheme.primary.withValues(alpha: 0.10)
                            : Colors.transparent,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(
                            skin.icon,
                            color: selected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            skin.label,
                            style: TextStyle(
                              color: selected
                                  ? scheme.primary
                                  : scheme.onSurface,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
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

/// 主播放按钮 - 渐变填充圆形
class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final ThemePalette palette;
  final VoidCallback onTap;

  const _PlayButton({
    required this.isPlaying,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: palette.gradient),
          boxShadow: [
            BoxShadow(
              color: palette.primary.withValues(alpha: 0.42),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            key: ValueKey(isPlaying),
            size: 42,
            color: Colors.white,
          ),
        ),
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
    final scheme = Theme.of(context).colorScheme;
    final isFav = provider.isFavorite(widget.song);

    return IconButton(
      iconSize: 28,
      tooltip: isFav ? '取消喜欢' : '喜欢',
      icon: ScaleTransition(
        scale: _scale,
        child: Icon(
          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFav ? AppColors.favorite : scheme.onSurfaceVariant,
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
          ),
        );
      },
    );
  }
}

/// 现代皮肤封面 - 大圆角方块 + 玻璃高光 + 大阴影
class _ModernCover extends StatelessWidget {
  final Song song;
  const _ModernCover({required this.song});

  @override
  Widget build(BuildContext context) {
    const double coverSize = 296;
    const double radius = AppRadius.xl;

    return Center(
      child: Container(
        width: coverSize,
        height: coverSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 40,
              spreadRadius: 2,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AlbumArtWidget(
                song: song,
                size: double.infinity,
                borderRadius: 0,
                placeholderIcon: Icons.music_note_rounded,
              ),
              // 顶部高光，模拟唱片玻璃质感
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 经典皮肤封面 - 唱片从方形纸袋封套右侧露出
class _ClassicCover extends StatelessWidget {
  final Song song;
  const _ClassicCover({required this.song});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const double coverSize = 264;
    const double discSize = 236;
    const double peek = 60;

    return Center(
      child: SizedBox(
        width: coverSize + peek,
        height: coverSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 黑胶唱片 - 位于封套右后方，露出边缘
            Positioned(
              right: 0,
              top: (coverSize - discSize) / 2,
              child: Container(
                width: discSize,
                height: discSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFF2C2C2C),
                      Color(0xFF161616),
                      Color(0xFF060606),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(6, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: discSize * 0.36,
                    height: discSize * 0.36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF0A0A0A),
                    ),
                  ),
                ),
              ),
            ),
            // 方形纸袋封套
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: coverSize,
                height: coverSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.30),
                      blurRadius: 30,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: AlbumArtWidget(
                    song: song,
                    size: double.infinity,
                    borderRadius: 0,
                    placeholderIcon: Icons.music_note_rounded,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 极简皮肤封面 - 无阴影、细描边、内缩留白
class _MinimalCover extends StatelessWidget {
  final Song song;
  const _MinimalCover({required this.song});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const double coverSize = 248;

    return Center(
      child: Container(
        width: coverSize,
        height: coverSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
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
}

/// 黑胶唱片封面（旋转动画）
class _VinylCover extends StatefulWidget {
  final Song song;
  const _VinylCover({required this.song});

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

    const double discSize = 296;

    return Center(
      child: RotationTransition(
        turns: _ctrl,
        child: Container(
          width: discSize,
          height: discSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 34,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 黑胶唱片
              Container(
                width: discSize,
                height: discSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFF2A2A2A),
                      Color(0xFF1A1A1A),
                      Color(0xFF0A0A0A),
                    ],
                  ),
                ),
                child: CustomPaint(painter: _VinylGroovesPainter()),
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
      ..color = Colors.black.withValues(alpha: 0.3)
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
    _ctrl.reverse().then((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _close,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.92),
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
                        borderRadius: BorderRadius.circular(AppRadius.xl),
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
