import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/lyric.dart';
import '../models/music_source.dart';
import '../models/song.dart';
import '../services/album_art_service.dart';
import '../services/audio_player_service.dart' show AudioPlayerService, PlaybackState, PlaylistMode;
import '../services/lyrics_service.dart';
import '../services/music_scanner_service.dart';
import '../services/remote_source_service.dart';
import '../services/storage_service.dart';

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
  List<MusicSource> _sources = [];
  List<LyricLine> _currentLyrics = [];
  Map<String, Uint8List> _artworkCache = {};
  Map<String, String> _onlineArtCache = {};
  bool _isLoading = false;
  bool _isScanning = false;
  String _searchQuery = '';
  PlaybackState? _playbackState;
  Duration _position = Duration.zero;

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
      }
      notifyListeners();
    });

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

  // === 收藏 ===
  void toggleFavorite(Song song) {
    _storage.toggleFavorite(song.id);
    notifyListeners();
  }

  bool isFavorite(Song song) => _storage.isFavorite(song.id);

  // === 搜索 ===
  void search(String query) {
    _searchQuery = query;
    _applyFilter();
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredSongs = List.from(_songs);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredSongs = _songs
          .where((s) =>
              s.title.toLowerCase().contains(q) ||
              s.artist.toLowerCase().contains(q) ||
              s.album.toLowerCase().contains(q))
          .toList();
    }
    notifyListeners();
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
    _player.dispose();
    super.dispose();
  }
}
