/// 歌词行
class LyricLine {
  final Duration time;
  final String text;
  final String? translation; // 翻译

  const LyricLine({
    required this.time,
    required this.text,
    this.translation,
  });

  @override
  String toString() =>
      '[${time.inMilliseconds}] $text${translation != null ? " / $translation" : ""}';
}

/// 歌词解析工具
class LyricParser {
  /// 解析 LRC 格式歌词
  static List<LyricLine> parseLrc(String lrcContent) {
    final lines = lrcContent.split('\n');
    final List<LyricLine> result = [];
    final RegExp timeReg = RegExp(r'\[(\d+):(\d+)(?:[.:](\d+))?\]');

    for (final line in lines) {
      final matches = timeReg.allMatches(line);
      if (matches.isEmpty) continue;

      // 移除所有时间戳，得到纯文本
      String text = line;
      for (final m in matches) {
        text = text.replaceFirst(m.group(0)!, '');
      }
      text = text.trim();
      if (text.isEmpty) continue;

      // 每个时间戳对应一行歌词
      for (final m in matches) {
        final minutes = int.parse(m.group(1)!);
        final seconds = int.parse(m.group(2)!);
        final msStr = m.group(3);
        final milliseconds = msStr != null
            ? int.parse(msStr.padRight(3, '0'))
            : 0;

        result.add(LyricLine(
          time: Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
          ),
          text: text,
        ));
      }
    }

    // 按时间排序
    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }

  /// 格式化时间为 mm:ss
  static String formatTime(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
