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
import 'audio_effects_screen.dart';
import 'queue_screen.dart';

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
                const SizedBox(height: 6),
                _buildBottomToolbar(context, provider, scheme),
                const SizedBox(height: 14),
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
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            color: scheme.onSurfaceVariant,
            tooltip: '歌曲信息',
            onPressed: () => _showSongDetail(context, song),
          ),
          _FavoriteButton(song: song),
        ],
      ),
    );
  }

  /// 歌曲详情：展示完整音频元数据
  void _showSongDetail(BuildContext context, Song song) {
    String fmtSize(int? bytes) {
      if (bytes == null || bytes <= 0) return '未知';
      final mb = bytes / (1024 * 1024);
      if (mb >= 1) return '${mb.toStringAsFixed(2)} MB';
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }

    String fmtBitrate(int? bps) {
      if (bps == null || bps <= 0) return '未知';
      return '${(bps / 1000).toStringAsFixed(0)} kbps';
    }

    String fmtSampleRate(int? hz) {
      if (hz == null || hz <= 0) return '未知';
      return '${(hz / 1000).toStringAsFixed(1)} kHz';
    }

    String fmtDuration(Duration d) {
      final m = d.inMinutes;
      final s = d.inSeconds.remainder(60);
      return '$m 分 ${s.toString().padLeft(2, '0')} 秒';
    }

    String fmtDate(int? epochSeconds) {
      if (epochSeconds == null || epochSeconds <= 0) return '未知';
      final dt = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')}';
    }

    final rows = <MapEntry<String, String>>[
      MapEntry('标题', song.title),
      MapEntry('艺术家', song.artist),
      MapEntry('专辑', song.album),
      if (song.track != null) MapEntry('音轨', '${song.track}'),
      MapEntry('时长', fmtDuration(song.duration)),
      MapEntry('格式', song.format ?? '未知'),
      MapEntry('比特率', fmtBitrate(song.bitrate)),
      MapEntry('采样率', fmtSampleRate(song.sampleRate)),
      MapEntry('文件大小', fmtSize(song.size)),
      MapEntry('添加时间', fmtDate(song.dateAdded)),
      MapEntry('修改时间', fmtDate(song.dateModified)),
      MapEntry('文件路径', song.uri),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text('歌曲信息',
                        style: Theme.of(ctx).textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: rows.map((e) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 80,
                                child: Text(
                                  e.key,
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  e.value,
                                  style: const TextStyle(fontSize: 13.5),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  /// 底部工具条：播放队列 / 倍速 / 睡眠定时
  Widget _buildBottomToolbar(
      BuildContext context, MusicProvider provider, ColorScheme scheme) {
    final rate = provider.playbackRate;
    final timerActive = provider.sleepTimerActive;
    final remaining = provider.sleepTimerRemaining;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ToolbarItem(
            icon: Icons.queue_music_rounded,
            label: '队列',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QueueScreen()),
            ),
          ),
          _ToolbarItem(
            icon: Icons.equalizer_rounded,
            label: '音效',
            active: provider.eqEnabled && provider.eqGains.any((g) => g.abs() > 0.01) ||
                provider.loudnessEnabled ||
                provider.crossfadeEnabled,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AudioEffectsScreen()),
            ),
          ),
          _ToolbarItem(
            icon: Icons.speed_rounded,
            label: rate == 1.0
                ? '倍速'
                : '${rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 2)}x',
            active: rate != 1.0,
            onTap: () => _showRatePicker(context, provider),
          ),
          _ToolbarItem(
            icon: Icons.bedtime_rounded,
            label: timerActive
                ? (provider.sleepStopAfterCurrent
                    ? '播完本首'
                    : remaining != null
                        ? '${remaining.inMinutes + 1}分钟'
                        : '定时')
                : '定时',
            active: timerActive,
            onTap: () => _showSleepTimerSheet(context, provider),
          ),
        ],
      ),
    );
  }

  /// 倍速选择
  void _showRatePicker(BuildContext context, MusicProvider provider) {
    const rates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final current = provider.playbackRate;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('倍速播放', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: rates.map((r) {
                    final selected = (r - current).abs() < 0.001;
                    return ChoiceChip(
                      label: Text('${r}x'),
                      selected: selected,
                      labelStyle: TextStyle(
                        color:
                            selected ? scheme.onPrimary : scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) {
                        provider.setPlaybackRate(r);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 睡眠定时器面板
  void _showSleepTimerSheet(BuildContext context, MusicProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        Widget option(IconData icon, String label, VoidCallback onTap) {
          return ListTile(
            leading: Icon(icon, color: scheme.primary),
            title: Text(label),
            onTap: () {
              onTap();
              Navigator.pop(ctx);
            },
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text('睡眠定时',
                      style: Theme.of(ctx).textTheme.titleLarge),
                ),
                option(Icons.timer_outlined, '15 分钟',
                    () => provider.setSleepTimer(const Duration(minutes: 15))),
                option(Icons.timer_outlined, '30 分钟',
                    () => provider.setSleepTimer(const Duration(minutes: 30))),
                option(Icons.timer_outlined, '45 分钟',
                    () => provider.setSleepTimer(const Duration(minutes: 45))),
                option(Icons.timer_outlined, '60 分钟',
                    () => provider.setSleepTimer(const Duration(minutes: 60))),
                option(Icons.music_note_rounded, '播完当前歌曲',
                    () => provider.setSleepTimer(null, stopAfterCurrent: true)),
                if (provider.sleepTimerActive)
                  ListTile(
                    leading:
                        const Icon(Icons.close_rounded, color: AppColors.danger),
                    title: const Text('取消定时',
                        style: TextStyle(color: AppColors.danger)),
                    onTap: () {
                      provider.cancelSleepTimer();
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
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

/// 底部工具条项
class _ToolbarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToolbarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.primary : scheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
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
