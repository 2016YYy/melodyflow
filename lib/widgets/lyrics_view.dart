import 'package:flutter/material.dart';
import '../models/lyric.dart';

/// 歌词滚动视图 - 当前行高亮并自动居中，点击可跳转
class LyricsView extends StatefulWidget {
  final List<LyricLine> lyrics;
  final Duration currentPosition;
  final ValueChanged<Duration>? onSeek;

  const LyricsView({
    super.key,
    required this.lyrics,
    required this.currentPosition,
    this.onSeek,
  });

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final ScrollController _scrollController = ScrollController();
  int _currentIndex = -1;

  @override
  void didUpdateWidget(covariant LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateCurrentLine();
  }

  void _updateCurrentLine() {
    if (widget.lyrics.isEmpty) return;
    int newIndex = -1;
    for (int i = widget.lyrics.length - 1; i >= 0; i--) {
      if (widget.currentPosition >= widget.lyrics[i].time) {
        newIndex = i;
        break;
      }
    }
    if (newIndex != _currentIndex) {
      setState(() => _currentIndex = newIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent(newIndex));
    }
  }

  void _scrollToCurrent(int index) {
    if (index < 0 || !_scrollController.hasClients) return;
    // 每行行高约 52，居中显示
    final viewport = _scrollController.position.viewportDimension;
    final offset = index * 52.0 - viewport / 2 + 26;
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (widget.lyrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lyrics_outlined,
                size: 46, color: scheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(
              '暂无歌词',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 140),
      itemCount: widget.lyrics.length,
      itemBuilder: (context, index) {
        final line = widget.lyrics[index];
        final isActive = index == _currentIndex;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onSeek?.call(line.time),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            style: TextStyle(
              fontSize: isActive ? 20 : 16,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? scheme.primary : scheme.onSurfaceVariant,
              height: 1.5,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              child: Text(line.text, textAlign: TextAlign.center),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
