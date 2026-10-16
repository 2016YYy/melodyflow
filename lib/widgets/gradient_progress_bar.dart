import 'package:flutter/material.dart';

/// 精美渐变进度条 - 带圆角轨道、渐变进度、光晕滑块
class GradientProgressBar extends StatefulWidget {
  final double value; // 0.0 ~ 1.0
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final Duration duration;
  final double height;
  final List<Color>? gradientColors;

  const GradientProgressBar({
    super.key,
    required this.value,
    this.onChanged,
    this.onChangeEnd,
    this.duration = const Duration(milliseconds: 200),
    this.height = 6,
    this.gradientColors,
  });

  @override
  State<GradientProgressBar> createState() => _GradientProgressBarState();
}

class _GradientProgressBarState extends State<GradientProgressBar> {
  double _dragValue = -1;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 未显式传入时使用主题主色
    final colors = widget.gradientColors ?? [scheme.primary, scheme.primary];
    final trackColor = scheme.outlineVariant.withValues(alpha: 0.5);
    final displayValue = _dragging
        ? _dragValue
        : widget.value.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final thumbSize = widget.height + 14;
        final thumbLeft = (displayValue * width) - thumbSize / 2;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) {
            setState(() {
              _dragging = true;
              _dragValue = (d.localPosition.dx / width).clamp(0.0, 1.0);
            });
            widget.onChanged?.call(_dragValue);
          },
          onHorizontalDragUpdate: (d) {
            setState(() {
              _dragValue = (d.localPosition.dx / width).clamp(0.0, 1.0);
            });
            widget.onChanged?.call(_dragValue);
          },
          onHorizontalDragEnd: (_) {
            setState(() => _dragging = false);
            widget.onChangeEnd?.call(_dragValue);
          },
          onTapUp: (d) {
            final v = (d.localPosition.dx / width).clamp(0.0, 1.0);
            widget.onChanged?.call(v);
            widget.onChangeEnd?.call(v);
          },
          child: SizedBox(
            height: thumbSize + 8,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 轨道
                Container(
                  height: widget.height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.height),
                    color: trackColor,
                  ),
                ),
                // 渐变进度
                Positioned(
                  left: 0,
                  child: Container(
                    height: widget.height,
                    width: displayValue * width,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.height),
                      gradient: LinearGradient(colors: colors),
                    ),
                  ),
                ),
                // 滑块
                AnimatedPositioned(
                  duration: _dragging
                      ? Duration.zero
                      : widget.duration,
                  curve: Curves.easeOut,
                  left: thumbLeft.clamp(0.0, width - thumbSize),
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: colors.first.withValues(alpha:0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: colors),
                      ),
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
}
