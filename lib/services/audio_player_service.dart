import 'dart:async';
import 'package:media_kit/media_kit.dart';
import '../models/song.dart';

/// 音频播放服务 - 基于 media_kit 引擎
/// 支持 MP3, FLAC, WAV, AAC, OGG, M4A, WMA, ALAC, APE 等多种格式
class AudioPlayerService {
  late final Player _player;
  Song? _currentSong;
  List<Song> _playlist = [];
  int _currentIndex = -1;
  PlaylistMode _repeatMode = PlaylistMode.none;
  bool _shuffle = false;

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
        // 启用 gapless 播放和硬件加速
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

  void _emitState() {
    _stateController.add(PlaybackState(
      isPlaying: _player.state.playing,
      position: _player.state.position,
      duration: _player.state.duration,
      volume: _player.state.volume,
      rate: _player.state.rate,
      repeatMode: _repeatMode,
      shuffle: _shuffle,
      currentIndex: _currentIndex,
      playlistLength: _playlist.length,
    ));
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
    _emitState();
  }

  /// 播放/暂停
  Future<void> playPause() async {
    if (_player.state.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();

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
  Future<void> seek(Duration position) => _player.seek(position);

  /// 设置音量
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  /// 设置播放速度
  Future<void> setRate(double rate) => _player.setRate(rate);

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
