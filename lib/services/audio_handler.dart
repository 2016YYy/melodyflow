import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

import '../models/song.dart';

/// 后台播放与通知栏 / 锁屏控制处理器
///
/// 基于 [audio_service]，把 [AudioPlayerService] 的播放状态同步到
/// 系统通知栏、锁屏媒体控制与耳机线控。
///
/// 使用方式：
/// 在 `main()` 中调用 [initAudioService] 完成 audio_session 初始化，
/// 再调用 [AudioService.init] 装配后台播放能力。
class AudioServiceHandler extends BaseAudioHandler with SeekHandler {
  /// 播放控制回调：通知栏 / 锁屏的播放、暂停、上下首、拖拽进度，由此驱动播放引擎。
  /// 由 MusicProvider 在装配时注入（因为播放器由其持有）。
  Future<void> Function()? onPlay;
  Future<void> Function()? onPause;
  Future<void> Function()? onNext;
  Future<void> Function()? onPrevious;
  Future<void> Function(Duration)? onSeek;

  AudioServiceHandler({
    this.onPlay,
    this.onPause,
    this.onNext,
    this.onPrevious,
    this.onSeek,
  });

  @override
  Future<void> play() async => onPlay?.call();

  @override
  Future<void> pause() async => onPause?.call();

  @override
  Future<void> skipToNext() async => onNext?.call();

  @override
  Future<void> skipToPrevious() async => onPrevious?.call();

  @override
  Future<void> seek(Duration position) async => onSeek?.call(position);

  /// 更新通知栏显示的媒体信息（标题 / 歌手 / 专辑 / 时长）
  void updateMedia(Song? song) {
    if (song == null) {
      queue.value = const [];
      mediaItem.add(null);
      return;
    }
    mediaItem.add(MediaItem(
      id: song.uri,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
      artUri: song.coverUri != null ? Uri.tryParse(song.coverUri!) : null,
    ));
  }

  /// 更新播放 / 暂停状态（控制通知栏按钮图标与系统播放状态）
  void updatePlaybackState({
    required bool playing,
    required Duration position,
    required Duration duration,
  }) {
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.ready,
      playing: playing,
      updatePosition: position,
      bufferedPosition: duration,
      speed: 1.0,
      queueIndex: 0,
    ));
  }
}

/// 后台播放处理器全局单例
///
/// 在 `main()` 中调用 [setupAudioService] 后被赋值，
/// 供 `MusicProvider` 等业务层读取并装配状态同步，避免循环导入。
AudioServiceHandler? audioServiceHandler;

/// 初始化全局音频会话（处理音频焦点、耳机拔出暂停等）
Future<AudioSession> initAudioSession() async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  return session;
}

/// 初始化后台播放服务；返回可在应用任意位置使用的处理器单例
Future<AudioServiceHandler> setupAudioService({
  Future<void> Function()? onPlay,
  Future<void> Function()? onPause,
  Future<void> Function()? onNext,
  Future<void> Function()? onPrevious,
  Future<void> Function(Duration)? onSeek,
}) async {
  final handler = AudioServiceHandler(
    onPlay: onPlay,
    onPause: onPause,
    onNext: onNext,
    onPrevious: onPrevious,
    onSeek: onSeek,
  );
  await AudioService.init(
    builder: () => handler,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.melodyflow.playback',
      androidNotificationChannelName: 'MelodyFlow 播放',
      androidNotificationChannelDescription: '音乐播放控制',
      // audio_service 0.18.19 的 AudioServiceConfig 有断言：
      //   !androidNotificationOngoing || androidStopForegroundOnPause
      // 即 androidNotificationOngoing: true 必须搭配 androidStopForegroundOnPause: true
      // （不可滑走的常驻通知只在暂停后仍保持前台时才成立）。此前写反导致 const 求值期
      // 断言失败，报 "Constant evaluation error: The androidNotificationOngoing will make
      // no effect with androidStopForegroundOnPause set to false"。
      // 这里改成：暂停后退出前台（省电、可被系统回收），通知仍保留控制按钮。
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'drawable/ic_stat_music_note',
    ),
  );
  audioServiceHandler = handler;
  return handler;
}
