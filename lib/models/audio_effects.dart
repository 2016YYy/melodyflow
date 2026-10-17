// 音频效果相关模型：均衡器频段、预设、响度归一化、交叉淡化、睡眠定时

/// 16 段参数均衡器频段定义（ISO 标准 1/3 倍频程中心点）
class EqBand {
  final double frequency; // 中心频率 Hz
  final String label; // 显示标签
  const EqBand({required this.frequency, required this.label});
}

/// 16 段均衡器频段
class EqBands {
  static const List<EqBand> bands = [
    EqBand(frequency: 25, label: '25'),
    EqBand(frequency: 40, label: '40'),
    EqBand(frequency: 63, label: '63'),
    EqBand(frequency: 100, label: '100'),
    EqBand(frequency: 160, label: '160'),
    EqBand(frequency: 250, label: '250'),
    EqBand(frequency: 400, label: '400'),
    EqBand(frequency: 630, label: '630'),
    EqBand(frequency: 1000, label: '1k'),
    EqBand(frequency: 1600, label: '1.6k'),
    EqBand(frequency: 2500, label: '2.5k'),
    EqBand(frequency: 4000, label: '4k'),
    EqBand(frequency: 6300, label: '6.3k'),
    EqBand(frequency: 10000, label: '10k'),
    EqBand(frequency: 16000, label: '16k'),
    EqBand(frequency: 20000, label: '20k'),
  ];

  static const int count = 16;
  static const double minGain = -12.0;
  static const double maxGain = 12.0;
}

/// 均衡器预设
class EqPreset {
  final String name;
  final List<double> gains; // 长度 16，对应 EqBands.bands

  const EqPreset({required this.name, required this.gains});
}

/// 内置均衡器预设（各频段增益 dB，顺序与 EqBands.bands 一致）
class EqPresets {
  /// 平直
  static const EqPreset flat = EqPreset(
    name: '平直',
    gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  );

  /// 流行
  static const EqPreset pop = EqPreset(
    name: '流行',
    gains: [-1, -1, 0, 2, 4, 4, 3, 1, 0, -1, -1, 0, 1, 2, 2, 1],
  );

  /// 摇滚
  static const EqPreset rock = EqPreset(
    name: '摇滚',
    gains: [5, 4, 3, 1, 0, -1, -1, 0, 1, 3, 4, 5, 5, 4, 3, 2],
  );

  /// 爵士
  static const EqPreset jazz = EqPreset(
    name: '爵士',
    gains: [3, 2, 1, 2, -1, -1, 0, 1, 2, 2, 1, 2, 3, 3, 2, 1],
  );

  /// 古典
  static const EqPreset classical = EqPreset(
    name: '古典',
    gains: [4, 3, 2, 1, 0, 0, 0, 1, 2, 3, 3, 4, 4, 3, 2, 1],
  );

  /// 人声
  static const EqPreset vocal = EqPreset(
    name: '人声',
    gains: [-2, -2, -1, 0, 2, 4, 5, 4, 3, 2, 1, 0, -1, -1, -2, -2],
  );

  /// 低音增强
  static const EqPreset bass = EqPreset(
    name: '低音增强',
    gains: [7, 7, 6, 5, 3, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  );

  /// 高音增强
  static const EqPreset treble = EqPreset(
    name: '高音增强',
    gains: [0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 7],
  );

  /// 电子
  static const EqPreset electronic = EqPreset(
    name: '电子',
    gains: [6, 5, 4, 2, 0, -1, -1, 0, 2, 4, 5, 4, 3, 4, 5, 4],
  );

  /// 原声
  static const EqPreset acoustic = EqPreset(
    name: '原声',
    gains: [2, 3, 3, 2, 1, 0, 1, 2, 3, 3, 2, 2, 3, 3, 2, 1],
  );

  /// 舞曲
  static const EqPreset dance = EqPreset(
    name: '舞曲',
    gains: [6, 5, 4, 2, 0, -1, -1, 0, 1, 3, 5, 5, 4, 3, 2, 2],
  );

  static const List<EqPreset> all = [
    flat,
    pop,
    rock,
    jazz,
    classical,
    vocal,
    bass,
    treble,
    electronic,
    acoustic,
    dance,
  ];

  static EqPreset fromName(String name) =>
      all.firstWhere((p) => p.name == name, orElse: () => flat);
}

/// 睡眠定时剩余状态
class SleepTimerState {
  final bool active;
  final Duration remaining;

  const SleepTimerState({required this.active, required this.remaining});

  const SleepTimerState.off()
      : active = false,
        remaining = Duration.zero;

  SleepTimerState copyWith({bool? active, Duration? remaining}) =>
      SleepTimerState(
        active: active ?? this.active,
        remaining: remaining ?? this.remaining,
      );
}

/// 睡眠定时预设时长（分钟）
class SleepTimerPresets {
  static const List<int> minutes = [15, 30, 45, 60, 90, 120];
}
