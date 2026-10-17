import 'dart:async';
import 'package:media_kit/media_kit.dart';
import '../models/audio_effects.dart';
import '../models/song.dart';

/// 音频播放服务 - 基于 media_kit 引擎
/// 支持 MP3, FLAC, WAV, AAC, OGG, M4A, WMA, ALAC, APE 等多种格式
/// 并支持 16 段参数均衡器、响度归一化、交叉淡入淡出、变速不变调
class AudioPlayerService {
  late final Player _player;
  Song? _currentSong;
  List<Song> _playlist = [];
  int _currentIndex = -1;
  PlaylistMode _repeatMode = PlaylistMode.none;
  bool _shuffle = false;

  // === 音频效果状态 ===
  List<double> _eqGains = List.filled(EqBands.count, 0.0);
  bool _eqEnabled = true;
  bool _loudnessEnabled = false;
  bool _crossfadeEnabled = false;
  double _rate = 1.0;
  double _targetVolume = 100.0;

  // === 通知栏 / 锁屏控制回调（由 audio_service 装配后在外部设置） ===
  /// 曲目切换时回调，用于同步通知栏媒体信息
  void Function(Song? song)? onSongChanged;

  /// 播放状态 / 进度变化时回调，用于同步通知栏按钮与系统播放状态
  void Function(bool playing, Duration position, Duration duration)? onPlaybackChanged;

  // 播放状态流
  final StreamController<PlaybackState> _stateController =
      StreamController<PlaybackState>.broadcast();
  Stream<PlaybackState> get playbackStateStream => _stateController.stream;

  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  Stream<Duration> get positionStream => _positionController.stream;

  final StreamController<Song?> _songController =
      StreamController<Song?>.broadcast();
  Stream<Song?> get currentSongStream => _songController.stream;

  AudioPlayerService() {
    _player = Player(
      configuration: const PlayerConfiguration(
        // 启用音高修正，配合 scaletempo 实现变速不变调
        pitch: true,
        title: 'MelodyFlow',
      ),
    );
    _setupListeners();
  }

  void _setupListeners() {
    // 播放位置
    _player.stream.position.listen((pos) {
      _positionController.add(pos);
    });

    // 播放状态
    _player.stream.playing.listen((playing) {
      _emitState();
    });

    _player.stream.completed.listen((completed) {
      if (completed) {
        _onPlaybackComplete();
      }
    });

    _player.stream.duration.listen((_) => _emitState());
    _player.stream.volume.listen((_) => _emitState());
    _player.stream.rate.listen((_) => _emitState());
  }

  /// 把当前播放状态推送到通知栏 / 锁屏控制
  void _notifyPlaybackChanged([bool? playing]) {
    onPlaybackChanged?.call(
      playing ?? _player.state.playing,
      _player.state.position,
      _player.state.duration,
    );
  }

  void _emitState() {
    _stateController.add(PlaybackState(
      isPlaying: _player.state.playing,
      position: _player.state.position,
      duration: _player.state.duration,
      volume: _player.state.volume,
      rate: _rate,
      repeatMode: _repeatMode,
      shuffle: _shuffle,
      currentIndex: _currentIndex,
      playlistLength: _playlist.length,
    ));
    onPlaybackChanged?.call(
      _player.state.playing,
      _player.state.position,
      _player.state.duration,
    );
  }

  /// 跳转到队列中的指定位置播放
  Future<void> playAt(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    _currentIndex = index;
    await _playCurrent();
  }

  /// 从队列移除指定位置的歌曲；若移除的是当前歌曲则自动播放下一首
  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    if (_playlist.length == 1) {
      // 队列仅剩一首歌：停止并清空
      await _player.stop();
      _playlist = [];
      _currentIndex = -1;
      _currentSong = null;
      _songController.add(null);
      onSongChanged?.call(null);
      _emitState();
      return;
    }
    _playlist.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex--;
      _emitState();
    } else if (index == _currentIndex) {
      // 移除当前播放歌曲：播放原位置的下一首（末尾则回绕）
      _currentIndex = _currentIndex % _playlist.length;
      await _playCurrent();
    } else {
      _emitState();
    }
  }

  /// 清空队列并停止播放
  Future<void> clearQueue() async {
    await _player.stop();
    _playlist = [];
    _currentIndex = -1;
    _currentSong = null;
    _songController.add(null);
    onSongChanged?.call(null);
    _emitState();
  }

  /// 播放歌单
  Future<void> playPlaylist(List<Song> playlist, {int startIndex = 0}) async {
    _playlist = List.from(playlist);
    _currentIndex = startIndex.clamp(0, _playlist.length - 1);
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    if (_currentIndex < 0 || _currentIndex >= _playlist.length) return;
    _currentSong = _playlist[_currentIndex];
    _songController.add(_currentSong);
    onSongChanged?.call(_currentSong);

    // 构建请求头：WebDAV / 网络音源需要认证
    Map<String, String>? headers;
    if (_currentSong!.httpHeaders != null &&
        _currentSong!.httpHeaders!.isNotEmpty) {
      headers = _currentSong!.httpHeaders;
    } else if (_currentSong!.sourceType == MusicSourceType.network) {
      headers = {'User-Agent': 'MelodyFlow'};
    }

    final media = Media(_currentSong!.uri, httpHeaders: headers);
    await _player.open(media, play: true);

    // 切换曲目后重新应用音频滤镜链
    await _applyAudioFilters();

    // 交叉淡化：淡入
    if (_crossfadeEnabled) {
      await _fadeIn();
    }

    _emitState();
  }

  /// 播放/暂停
  Future<void> playPause() async {
    if (_player.state.playing) {
      if (_crossfadeEnabled) await _fadeOut();
      await _player.pause();
      _notifyPlaybackChanged(false);
    } else {
      await _player.play();
      if (_crossfadeEnabled) await _fadeIn();
      _notifyPlaybackChanged(true);
    }
  }

  Future<void> play() async {
    await _player.play();
    if (_crossfadeEnabled) await _fadeIn();
    _notifyPlaybackChanged(true);
  }

  Future<void> pause() async {
    if (_crossfadeEnabled) await _fadeOut();
    await _player.pause();
    _notifyPlaybackChanged(false);
  }

  /// 下一首
  Future<void> next() async {
    if (_playlist.isEmpty) return;
    if (_shuffle) {
      _currentIndex = _getRandomIndex();
    } else {
      _currentIndex = (_currentIndex + 1) % _playlist.length;
    }
    await _playCurrent();
  }

  /// 上一首
  Future<void> previous() async {
    if (_playlist.isEmpty) return;
    if (_shuffle) {
      _currentIndex = _getRandomIndex();
    } else {
      _currentIndex = (_currentIndex - 1) % _playlist.length;
    }
    await _playCurrent();
  }

  int _getRandomIndex() {
    if (_playlist.length == 1) return 0;
    int idx;
    do {
      idx = DateTime.now().microsecondsSinceEpoch % _playlist.length;
    } while (idx == _currentIndex);
    return idx;
  }

  void _onPlaybackComplete() {
    switch (_repeatMode) {
      case PlaylistMode.none:
        if (_currentIndex < _playlist.length - 1) {
          next();
        } else {
          pause();
        }
        break;
      case PlaylistMode.single:
        _player.seek(Duration.zero);
        play();
        break;
      case PlaylistMode.loop:
        next();
        break;
    }
  }

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _notifyPlaybackChanged(_player.state.playing);
  }

  /// 设置音量（0-100）
  Future<void> setVolume(double volume) async {
    _targetVolume = volume.clamp(0.0, 100.0);
    await _player.setVolume(_targetVolume);
    _emitState();
  }

  /// 设置播放速度（变速不变调，0.25 - 4.0）
  Future<void> setRate(double rate) async {
    _rate = rate.clamp(0.25, 4.0);
    await _applyAudioFilters();
    _emitState();
  }

  /// 切换循环模式
  PlaylistMode cycleRepeatMode() {
    _repeatMode = PlaylistMode.values[
        (_repeatMode.index + 1) % PlaylistMode.values.length];
    _emitState();
    return _repeatMode;
  }

  /// 切换随机播放
  bool toggleShuffle() {
    _shuffle = !_shuffle;
    _emitState();
    return _shuffle;
  }

  // ==================== 音频效果 ====================

  /// 当前均衡器增益（16 段）
  List<double> get eqGains => List.unmodifiable(_eqGains);
  bool get eqEnabled => _eqEnabled;
  bool get loudnessEnabled => _loudnessEnabled;
  bool get crossfadeEnabled => _crossfadeEnabled;
  double get rate => _rate;

  /// 设置均衡器开关
  Future<void> setEqEnabled(bool enabled) async {
    _eqEnabled = enabled;
    await _applyAudioFilters();
  }

  /// 设置单个频段增益（dB）
  Future<void> setEqBand(int index, double gain) async {
    if (index < 0 || index >= EqBands.count) return;
    _eqGains[index] = gain.clamp(EqBands.minGain, EqBands.maxGain);
    await _applyAudioFilters();
  }

  /// 批量设置所有频段增益
  Future<void> setEqGains(List<double> gains) async {
    if (gains.length != EqBands.count) return;
    _eqGains =
        gains.map((g) => g.clamp(EqBands.minGain, EqBands.maxGain)).toList();
    await _applyAudioFilters();
  }

  /// 应用预设
  Future<void> applyEqPreset(EqPreset preset) async {
    await setEqGains(preset.gains);
  }

  /// 切换响度归一化
  Future<void> setLoudnessEnabled(bool enabled) async {
    _loudnessEnabled = enabled;
    await _applyAudioFilters();
  }

  /// 切换交叉淡入淡出
  void setCrossfadeEnabled(bool enabled) {
    _crossfadeEnabled = enabled;
    if (!enabled) {
      _player.setVolume(_targetVolume);
    }
  }

  /// 构建并应用音频滤镜链（scaletempo + equalizer + loudnorm）
  Future<void> _applyAudioFilters() async {
    final native = _player.platform;
    if (native is! NativePlayer) return;

    final filters = <String>[];

    // 1. 变速不变调：scaletempo 按比例拉伸，配合 pitch 保持音高
    if ((_rate - 1.0).abs() > 0.001) {
      filters.add('scaletempo:scale=${_rate.toStringAsFixed(4)}');
    }

    // 2. 16 段参数均衡器
    if (_eqEnabled && _eqGains.any((g) => g.abs() > 0.01)) {
      final eqParts = <String>[];
      for (int i = 0; i < EqBands.count; i++) {
        final f = EqBands.bands[i].frequency;
        final g = _eqGains[i];
        eqParts.add('f=${f.toInt()}:t=q:w=1.0:g=${g.toStringAsFixed(2)}');
      }
      filters.add('equalizer=${eqParts.join(',')}');
    }

    // 3. 响度归一化（ReplayGain 风格，统一不同音源响度）
    if (_loudnessEnabled) {
      filters.add('lavfi=[loudnorm=I=-16:TP=-1.5:LRA=11]');
    }

    try {
      await native.setProperty('af', filters.isEmpty ? '' : filters.join(','));
    } catch (e) {
      // 滤镜设置失败时忽略，避免影响正常播放
    }
  }

  // ==================== 淡入淡出 ====================

  Future<void> _fadeIn() async {
    const steps = 10;
    const stepMs = 30;
    final target = _targetVolume;
    await _player.setVolume(0);
    for (int i = 1; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: stepMs));
      await _player.setVolume(target * i / steps);
    }
  }

  Future<void> _fadeOut() async {
    const steps = 10;
    const stepMs = 20;
    final start = _player.state.volume;
    for (int i = steps - 1; i >= 0; i--) {
      await Future.delayed(const Duration(milliseconds: stepMs));
      await _player.setVolume(start * i / steps);
    }
  }

  // ==================== Getters ====================

  Song? get currentSong => _currentSong;
  List<Song> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  PlaylistMode get repeatMode => _repeatMode;
  bool get shuffle => _shuffle;
  Duration get position => _player.state.position;
  Duration get duration => _player.state.duration;
  bool get isPlaying => _player.state.playing;

  Future<void> dispose() async {
    await _stateController.close();
    await _positionController.close();
    await _songController.close();
    await _player.dispose();
  }
}

/// 循环模式
enum PlaylistMode {
  none, // 不循环
  single, // 单曲循环
  loop, // 列表循环
}

/// 播放状态
class PlaybackState {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double volume;
  final double rate;
  final PlaylistMode repeatMode;
  final bool shuffle;
  final int currentIndex;
  final int playlistLength;

  const PlaybackState({
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.volume,
    required this.rate,
    required this.repeatMode,
    required this.shuffle,
    required this.currentIndex,
    required this.playlistLength,
  });

  double get progress {
    if (duration.inMilliseconds == 0) return 0;
    return position.inMilliseconds / duration.inMilliseconds;
  }
}