import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/audio_effects.dart';
import '../providers/music_provider.dart';
import '../theme/app_theme.dart';

/// 音频效果页面：16 段均衡器、响度归一化、交叉淡化、变速、睡眠定时
class AudioEffectsScreen extends StatefulWidget {
  const AudioEffectsScreen({super.key});

  @override
  State<AudioEffectsScreen> createState() => _AudioEffectsScreenState();
}

class _AudioEffectsScreenState extends State<AudioEffectsScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final palette = provider.palette;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('音频效果')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // === 均衡器 ===
          _SectionHeader('均衡器', icon: Icons.equalizer_rounded),
          SwitchListTile(
            secondary: Icon(Icons.graphic_eq_rounded, color: palette.primary),
            title: const Text('启用均衡器'),
            subtitle: const Text('16 段参数均衡，精细调节各频段'),
            value: provider.eqEnabled,
            activeThumbColor: palette.primary,
            activeTrackColor: palette.primary.withValues(alpha: 0.5),
            onChanged: (v) => provider.setEqEnabled(v),
          ),
          if (provider.eqEnabled) ...[
            // 预设选择
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: EqPresets.all.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final preset = EqPresets.all[i];
                  final isFlat = preset.name == '平直';
                  return ChoiceChip(
                    label: Text(preset.name),
                    selected: _isPresetActive(provider, preset),
                    selectedColor: palette.primary.withValues(alpha: 0.18),
                    onSelected: (_) {
                      if (isFlat) {
                        provider.setEqGains(EqPresets.flat.gains);
                      } else {
                        provider.applyEqPreset(preset);
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // 16 段滑块
            SizedBox(
              height: 220,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(EqBands.count, (i) {
                    return Expanded(
                      child: _EqBandSlider(
                        band: EqBands.bands[i],
                        gain: provider.eqGains[i],
                        onChanged: (v) => provider.setEqBand(i, v),
                      ),
                    );
                  }),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${EqBands.minGain.toStringAsFixed(0)} dB',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text('增益范围',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text('+${EqBands.maxGain.toStringAsFixed(0)} dB',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
          const Divider(height: 1, indent: 16, endIndent: 16),

          // === 响度归一化 ===
          SwitchListTile(
            secondary: Icon(Icons.auto_graph_rounded, color: palette.primary),
            title: const Text('响度归一化'),
            subtitle: const Text('自动统一不同歌曲的响度（ReplayGain 风格）'),
            value: provider.loudnessEnabled,
            activeThumbColor: palette.primary,
            activeTrackColor: palette.primary.withValues(alpha: 0.5),
            onChanged: (v) => provider.setLoudnessEnabled(v),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),

          // === 交叉淡化 ===
          SwitchListTile(
            secondary: Icon(Icons.all_inclusive_rounded, color: palette.primary),
            title: const Text('交叉淡入淡出'),
            subtitle: const Text('播放/暂停与切歌时平滑过渡音量'),
            value: provider.crossfadeEnabled,
            activeThumbColor: palette.primary,
            activeTrackColor: palette.primary.withValues(alpha: 0.5),
            onChanged: (v) => provider.setCrossfadeEnabled(v),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),

          // === 播放速度 ===
          _SectionHeader('播放速度', icon: Icons.speed_rounded),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: provider.playbackRate,
                        min: 0.25,
                        max: 4.0,
                        divisions: 15,
                        activeColor: palette.primary,
                        label: '${provider.playbackRate.toStringAsFixed(2)}x',
                        onChanged: (v) => provider.setPlaybackRate(v),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${provider.playbackRate.toStringAsFixed(2)}x',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: palette.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((r) {
                    final selected =
                        (provider.playbackRate - r).abs() < 0.01;
                    return ActionChip(
                      label: Text('${r.toStringAsFixed(r == 1.0 ? 1 : 2)}x'),
                      backgroundColor: selected
                          ? palette.primary.withValues(alpha: 0.18)
                          : null,
                      side: BorderSide(
                        color: selected
                            ? palette.primary
                            : scheme.outlineVariant,
                      ),
                      onPressed: () => provider.setPlaybackRate(r),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  '变速不变调：使用 scaletempo 算法，改变播放速度时保持原始音高',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, indent: 16, endIndent: 16),

          // === 睡眠定时 ===
          _SleepTimerSection(provider: provider),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  bool _isPresetActive(MusicProvider provider, EqPreset preset) {
    final gains = provider.eqGains;
    for (int i = 0; i < EqBands.count; i++) {
      if ((gains[i] - preset.gains[i]).abs() > 0.05) return false;
    }
    return true;
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader(this.title, {required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Row(
        children: [
          Icon(icon,
              size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个均衡器频段滑块（垂直）
class _EqBandSlider extends StatefulWidget {
  final EqBand band;
  final double gain;
  final ValueChanged<double> onChanged;

  const _EqBandSlider({
    required this.band,
    required this.gain,
    required this.onChanged,
  });

  @override
  State<_EqBandSlider> createState() => _EqBandSliderState();
}

class _EqBandSliderState extends State<_EqBandSlider> {
  @override
  Widget build(BuildContext context) {
    final palette = context.read<MusicProvider>().palette;
    final normalized =
        (widget.gain - EqBands.minGain) / (EqBands.maxGain - EqBands.minGain);

    return Column(
      children: [
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: palette.primary,
                inactiveTrackColor:
                    Theme.of(context).colorScheme.outlineVariant,
                thumbColor: palette.primary,
              ),
              child: Slider(
                value: widget.gain,
                min: EqBands.minGain,
                max: EqBands.maxGain,
                divisions: 24,
                onChanged: widget.onChanged,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          height: 16,
          alignment: Alignment.center,
          child: Text(
            widget.band.label,
            style: TextStyle(
              fontSize: 9.5,
              color: normalized > 0.5
                  ? palette.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: normalized > 0.5 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

/// 睡眠定时区块
class _SleepTimerSection extends StatelessWidget {
  final MusicProvider provider;
  const _SleepTimerSection({required this.provider});

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = provider.palette;
    final remaining = provider.sleepTimerRemaining;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('睡眠定时', icon: Icons.bedtime_rounded),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (provider.sleepTimerActive && remaining != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_rounded,
                          color: palette.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('定时关闭中',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: palette.primary)),
                            Text('剩余 ${_fmt(remaining)} 后暂停播放',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => provider.cancelSleepTimer(),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('取消'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text('选择定时时长：',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SleepTimerPresets.minutes.map((m) {
                  return ActionChip(
                    avatar: const Icon(Icons.timer_outlined, size: 16),
                    label: Text('$m 分钟'),
                    onPressed: () =>
                        provider.setSleepTimer(Duration(minutes: m)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                '到点后将自动暂停播放，适合睡前听音乐使用',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
