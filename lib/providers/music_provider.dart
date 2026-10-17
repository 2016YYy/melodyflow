import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/audio_effects.dart';
import '../models/lyric.dart';
import '../models/music_source.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../models/webdav_item.dart';
import '../services/album_art_service.dart';
import '../services/audio_player_service.dart'
    show AudioPlayerService, PlaybackState, PlaylistMode;
import '../services/lyrics_service.dart';
import '../services/music_scanner_service.dart';
import '../services/remote_source_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// 全局音乐状态提供者
class MusicProvider extends ChangeNotifier {
  final MusicScannerService _scanner = MusicScannerService();
  final AudioPlayerService _player = AudioPlayerService();
  final LyricsService _lyricsService = LyricsService();
  final AlbumArtService _albumArtService = AlbumArtService();
  final RemoteSourceService _remoteService = RemoteSourceService();
  final StorageService _storage = StorageService();

  List<Song> _songs = [];
  List<Song> _filteredSongs = [];
  List<Song> _recentSongs = [];
  SongSortMode _sortMode = SongSortMode.title;

  // 睡眠定时器
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndAt;
  bool _sleepStopAfterCurrent = false;

  // 音频效果
  List<double> _eqGains = List.filled(EqBands.count, 0.0);
  bool _eqEnabled = true;
  bool _loudnessEnabled = false;
  bool _crossfadeEnabled = false;
  List<MusicSource> _sources = [];
  List<Playlist> _playlists = [];
  List<Song> _favoriteSongs = [];
  List<LyricLine> _currentLyrics = [];
  final Map<String, Uint8List> _artworkCache = {};
  final Map<String, String> _onlineArtCache = {};
  final bool _isLoading = false;
  bool _isScanning = false;
  String _searchQuery = '';
  PlaybackState? _playbackState;
  Duration _position = Duration.zero;

  // 主题状态
  bool _darkMode = true;
  String _paletteName = 'purple';
  String _playerSkinName = 'modern';
  bool _includePrerelease = false;

  // 流订阅
  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _songSub;

  MusicProvider() {
    _init();
  }

  Future<void> _init() async {
    await _storage.init();
    _sources = _storage.getSources();
    _playlists = _storage.getPlaylists();
    _favoriteSongs = _storage.getFavoriteSongs();
    _recentSongs = _storage.getRecentSongs();
    _darkMode = _storage.isDarkMode();
    _paletteName = _storage.getPalette();
    _playerSkinName = _storage.getPlayerSkin();
    _includePrerelease = _storage.isIncludePrerelease();

    // 恢复音频效果设置并应用到播放引擎
    _eqGains = _storage.getEqGains();
    _eqEnabled = _storage.isEqEnabled();
    _loudnessEnabled = _storage.isLoudnessEnabled();
    _crossfadeEnabled = _storage.isCrossfadeEnabled();
    final savedRate = _storage.getPlaybackRate();
    await _player.setEqGains(_eqGains);
    await _player.setEqEnabled(_eqEnabled);
    await _player.setLoudnessEnabled(_loudnessEnabled);
    _player.setCrossfadeEnabled(_crossfadeEnabled);
    if (savedRate != 1.0) {
      await _player.setRate(savedRate);
    }

    // 订阅播放服务
    _stateSub = _player.playbackStateStream.listen((state) {
      _playbackState = state;
      notifyListeners();
    });
    _posSub = _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    _songSub = _player.currentSongStream.listen((song) {
      if (song != null) {
        _loadLyrics(song);
        _storage.saveLastPlaying(song, _position);
        _recordRecent(song);
        // 「播完当前歌曲停止」模式下，切歌意味着上一首已播完
        if (_sleepStopAfterCurrent && _sleepTimer == null) {
          _sleepStopAfterCurrent = false;
          _player.pause();
        }
      }
      notifyListeners();
    });

    notifyListeners();
  }

  // === 主题 ===
  ThemePalette get palette => ThemePalettes.fromName(_paletteName);
  PlayerSkin get playerSkin => PlayerSkin.fromName(_playerSkinName);
  bool get darkMode => _darkMode;

  Future<void> setDarkMode(bool v) async {
    _darkMode = v;
    await _storage.setDarkMode(v);
    notifyListeners();
  }

  Future<void> setPalette(String name) async {
    _paletteName = name;
    await _storage.setPalette(name);
    notifyListeners();
  }

  Future<void> setPlayerSkin(String name) async {
    _playerSkinName = name;
    await _storage.setPlayerSkin(name);
    notifyListeners();
  }

  bool get includePrerelease => _includePrerelease;

  Future<void> setIncludePrerelease(bool v) async {
    _includePrerelease = v;
    await _storage.setIncludePrerelease(v);
    notifyListeners();
  }

  // === 扫描 ===
  Future<void> scanLocalMusic() async {
    _isScanning = true;
    notifyListeners();
    try {
      final hasPerm = await _scanner.checkAndRequestPermission();
      if (hasPerm) {
        _songs = await _scanner.scanLocalMusic();
        _applyFilter();
      }
    } catch (e) {
      debugPrint('扫描失败: $e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  // === 播放 ===
  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    final list = playlist ?? _filteredSongs;
    final index = list.indexWhere((s) => s.id == song.id);
    await _player.playPlaylist(list, startIndex: index < 0 ? 0 : index);
  }

  Future<void> playPlaylist(List<Song> list, {int index = 0}) =>
      _player.playPlaylist(list, startIndex: index);

  Future<void> playPause() => _player.playPause();
  Future<void> next() => _player.next();
  Future<void> previous() => _player.previous();
  Future<void> seek(Duration pos) => _player.seek(pos);
  PlaylistMode cycleRepeat() {
    final m = _player.cycleRepeatMode();
    notifyListeners();
    return m;
  }

  bool toggleShuffle() {
    final s = _player.toggleShuffle();
    notifyListeners();
    return s;
  }

  // === 播放队列 ===
  List<Song> get queue => _player.playlist;
  int get queueIndex => _player.currentIndex;

  Future<void> playQueueAt(int index) => _player.playAt(index);

  Future<void> removeFromQueue(int index) async {
    await _player.removeAt(index);
    notifyListeners();
  }

  Future<void> clearQueue() async {
    await _player.clearQueue();
    notifyListeners();
  }

  // === 倍速播放 ===
  double get playbackRate => _playbackState?.rate ?? 1.0;

  Future<void> setPlaybackRate(double rate) async {
    await _player.setRate(rate);
    await _storage.setPlaybackRate(rate);
    notifyListeners();
  }

  // === 音频效果（均衡器 / 响度 / 交叉淡化）===
  List<double> get eqGains => List.unmodifiable(_eqGains);
  bool get eqEnabled => _eqEnabled;
  bool get loudnessEnabled => _loudnessEnabled;
  bool get crossfadeEnabled => _crossfadeEnabled;

  Future<void> setEqEnabled(bool enabled) async {
    _eqEnabled = enabled;
    await _storage.setEqEnabled(enabled);
    await _player.setEqEnabled(enabled);
    notifyListeners();
  }

  Future<void> setEqBand(int index, double gain) async {
    if (index < 0 || index >= EqBands.count) return;
    _eqGains[index] = gain.clamp(EqBands.minGain, EqBands.maxGain);
    await _storage.setEqGains(_eqGains);
    await _player.setEqBand(index, _eqGains[index]);
    notifyListeners();
  }

  Future<void> setEqGains(List<double> gains) async {
    if (gains.length != EqBands.count) return;
    _eqGains =
        gains.map((g) => g.clamp(EqBands.minGain, EqBands.maxGain)).toList();
    await _storage.setEqGains(_eqGains);
    await _player.setEqGains(_eqGains);
    notifyListeners();
  }

  Future<void> applyEqPreset(EqPreset preset) => setEqGains(preset.gains);

  Future<void> setLoudnessEnabled(bool enabled) async {
    _loudnessEnabled = enabled;
    await _storage.setLoudnessEnabled(enabled);
    await _player.setLoudnessEnabled(enabled);
    notifyListeners();
  }

  Future<void> setCrossfadeEnabled(bool enabled) async {
    _crossfadeEnabled = enabled;
    await _storage.setCrossfadeEnabled(enabled);
    _player.setCrossfadeEnabled(enabled);
    notifyListeners();
  }

  // === 睡眠定时器 ===
  /// 剩余时间（null 表示未开启）
  Duration? get sleepTimerRemaining {
    if (_sleepTimerEndAt == null) return null;
    final remain = _sleepTimerEndAt!.difference(DateTime.now());
    return remain.isNegative ? Duration.zero : remain;
  }

  bool get sleepTimerActive =>
      _sleepTimer != null || _sleepStopAfterCurrent;
  bool get sleepStopAfterCurrent => _sleepStopAfterCurrent;

  /// 设置睡眠定时：duration 为 null 表示「播完当前歌曲」
  void setSleepTimer(Duration? duration, {bool stopAfterCurrent = false}) {
    cancelSleepTimer(notify: false);
    if (stopAfterCurrent) {
      _sleepStopAfterCurrent = true;
    } else if (duration != null) {
      _sleepTimerEndAt = DateTime.now().add(duration);
      _sleepTimer = Timer(duration, () {
        _player.pause();
        cancelSleepTimer(notify: false);
      });
    }
    notifyListeners();
  }

  void cancelSleepTimer({bool notify = true}) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndAt = null;
    _sleepStopAfterCurrent = false;
    if (notify) notifyListeners();
  }

  // === 最近播放 ===
  List<Song> get recentSongs => List.unmodifiable(_recentSongs);

  Future<void> _recordRecent(Song song) async {
    _recentSongs.removeWhere((s) => s.id == song.id);
    _recentSongs.insert(0, song);
    if (_recentSongs.length > StorageService.recentLimit) {
      _recentSongs = _recentSongs.sublist(0, StorageService.recentLimit);
    }
    await _storage.saveRecentSongs(_recentSongs);
  }

  Future<void> clearRecentSongs() async {
    _recentSongs = [];
    await _storage.saveRecentSongs(_recentSongs);
    notifyListeners();
  }

  // === 封面 ===
  Future<Uint8List?> getArtwork(Song song) async {
    if (_artworkCache.containsKey(song.id)) return _artworkCache[song.id];
    final art = await _scanner.getSongArtwork(song.id);
    if (art != null) _artworkCache[song.id] = art;
    return art;
  }

  Future<String?> getOnlineArtUrl(Song song) async {
    if (_onlineArtCache.containsKey(song.id)) return _onlineArtCache[song.id];
    final url = await _albumArtService.fetchAlbumArtUrl(song);
    if (url != null) _onlineArtCache[song.id] = url;
    return url;
  }

  // === 歌词 ===
  Future<void> _loadLyrics(Song song) async {
    _currentLyrics = [];
    notifyListeners();
    try {
      _currentLyrics = await _lyricsService.fetchLyrics(song);
      notifyListeners();
    } catch (e) {
      debugPrint('歌词加载失败: $e');
    }
  }

  // === 远程源 ===
  Future<List<Song>> loadSourceSongs(MusicSource source) async {
    return await _remoteService.fetchSongs(source);
  }

  Future<List<WebdavItem>> listWebdavFolder(
          MusicSource source, String path) async =>
      _remoteService.listWebdavFolder(source, path);

  Future<bool> testSource(MusicSource source) =>
      _remoteService.testConnection(source);

  Future<void> addSource(MusicSource source) async {
    await _storage.addSource(source);
    _sources = _storage.getSources();
    notifyListeners();
  }

  Future<void> removeSource(String id) async {
    await _storage.removeSource(id);
    _sources = _storage.getSources();
    notifyListeners();
  }

  // === 歌单 ===
  List<Playlist> get playlists => _playlists;

  Future<void> createPlaylist(String name, {String? description}) async {
    final list = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      description: description,
    );
    _playlists.add(list);
    await _storage.savePlaylists(_playlists);
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await _storage.savePlaylists(_playlists);
    notifyListeners();
  }

  Future<void> renamePlaylist(String id, String name) async {
    final idx = _playlists.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      _playlists[idx] = _playlists[idx].copyWith(name: name);
      await _storage.savePlaylists(_playlists);
      notifyListeners();
    }
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx >= 0) {
      final list = _playlists[idx];
      if (!list.songs.any((s) => s.id == song.id)) {
        _playlists[idx] = list.copyWith(songs: [...list.songs, song]);
        await _storage.savePlaylists(_playlists);
        notifyListeners();
      }
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx >= 0) {
      final list = _playlists[idx];
      _playlists[idx] =
          list.copyWith(songs: list.songs.where((s) => s.id != songId).toList());
      await _storage.savePlaylists(_playlists);
      notifyListeners();
    }
  }

  // === 专辑 / 艺术家 分组 ===
  Map<String, List<Song>> get albums {
    final map = <String, List<Song>>{};
    for (final s in _songs) {
      final key = s.album.isEmpty ? '未知专辑' : s.album;
      map.putIfAbsent(key, () => []).add(s);
    }
    return map;
  }

  Map<String, List<Song>> get artists {
    final map = <String, List<Song>>{};
    for (final s in _songs) {
      final key = s.artist.isEmpty ? '未知艺术家' : s.artist;
      map.putIfAbsent(key, () => []).add(s);
    }
    return map;
  }

  // === 收藏（「我喜爱」歌单）===
  List<Song> get favoriteSongs => _favoriteSongs;

  Future<void> toggleFavorite(Song song) async {
    final idx = _favoriteSongs.indexWhere((s) => s.id == song.id);
    if (idx >= 0) {
      _favoriteSongs.removeAt(idx);
    } else {
      _favoriteSongs.insert(0, song);
    }
    await _storage.saveFavoriteSongs(_favoriteSongs);
    notifyListeners();
  }

  Future<void> removeFavorite(Song song) async {
    _favoriteSongs.removeWhere((s) => s.id == song.id);
    await _storage.saveFavoriteSongs(_favoriteSongs);
    notifyListeners();
  }

  bool isFavorite(Song song) => _favoriteSongs.any((s) => s.id == song.id);

  // === 搜索 ===
  void search(String query) {
    _searchQuery = query;
    _applyFilter();
  }

  void _applyFilter() {
    List<Song> list;
    if (_searchQuery.isEmpty) {
      list = List.from(_songs);
    } else {
      final q = _searchQuery.toLowerCase();
      list = _songs
          .where((s) =>
              s.title.toLowerCase().contains(q) ||
              s.artist.toLowerCase().contains(q) ||
              s.album.toLowerCase().contains(q))
          .toList();
    }
    switch (_sortMode) {
      case SongSortMode.title:
        list.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SongSortMode.artist:
        list.sort((a, b) {
          final c = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
          return c != 0
              ? c
              : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
      case SongSortMode.duration:
        list.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case SongSortMode.recentAdded:
        // 保持扫描原始顺序（一般为系统媒体库倒序）
        break;
    }
    _filteredSongs = list;
    notifyListeners();
  }

  SongSortMode get sortMode => _sortMode;

  void setSortMode(SongSortMode mode) {
    _sortMode = mode;
    _applyFilter();
  }

  // === Getters ===
  List<Song> get songs => _filteredSongs;
  List<Song> get allSongs => _songs;
  List<MusicSource> get sources => _sources;
  List<LyricLine> get currentLyrics => _currentLyrics;
  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;
  Song? get currentSong => _player.currentSong;
  bool get isPlaying => _player.isPlaying;
  Duration get position => _position;
  Duration get duration => _player.duration;
  PlaybackState? get playbackState => _playbackState;
  PlaylistMode get repeatMode => _player.repeatMode;
  bool get shuffle => _player.shuffle;
  StorageService get storage => _storage;

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _songSub?.cancel();
    _sleepTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}

/// 歌曲排序方式
enum SongSortMode {
  title, // 按标题
  artist, // 按艺术家
  duration, // 按时长（长→短）
  recentAdded, // 默认（扫描顺序）
}
