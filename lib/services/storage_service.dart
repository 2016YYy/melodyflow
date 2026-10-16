import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_source.dart';
import '../models/playlist.dart';
import '../models/song.dart';

/// 本地存储服务
class StorageService {
  static const String _sourcesKey = 'music_sources';
  static const String _favoritesKey = 'favorite_songs';
  static const String _themeKey = 'theme_mode';
  static const String _paletteKey = 'theme_palette';
  static const String _playerSkinKey = 'player_skin';
  static const String _playlistsKey = 'playlists';
  static const String _autoUpdateKey = 'auto_update_check';
  static const String _lastSongKey = 'last_playing_song';
  static const String _lastPositionKey = 'last_position';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // === 音乐源 ===
  List<MusicSource> getSources() {
    final data = _prefs.getStringList(_sourcesKey) ?? [];
    return data
        .map((s) => MusicSource.fromMap(jsonDecode(s)))
        .toList();
  }

  Future<void> saveSources(List<MusicSource> sources) async {
    final data = sources.map((s) => jsonEncode(s.toMap())).toList();
    await _prefs.setStringList(_sourcesKey, data);
  }

  Future<void> addSource(MusicSource source) async {
    final sources = getSources();
    sources.removeWhere((s) => s.id == source.id);
    sources.add(source);
    await saveSources(sources);
  }

  Future<void> removeSource(String id) async {
    final sources = getSources()..removeWhere((s) => s.id == id);
    await saveSources(sources);
  }

  // === 收藏 ===
  List<String> getFavoriteIds() {
    return _prefs.getStringList(_favoritesKey) ?? [];
  }

  Future<void> toggleFavorite(String songId) async {
    final favs = getFavoriteIds();
    if (favs.contains(songId)) {
      favs.remove(songId);
    } else {
      favs.add(songId);
    }
    await _prefs.setStringList(_favoritesKey, favs);
  }

  bool isFavorite(String songId) => getFavoriteIds().contains(songId);

  // === 主题 ===
  bool isDarkMode() => _prefs.getBool(_themeKey) ?? true;
  Future<void> setDarkMode(bool dark) => _prefs.setBool(_themeKey, dark);

  String getPalette() => _prefs.getString(_paletteKey) ?? 'purple';
  Future<void> setPalette(String name) => _prefs.setString(_paletteKey, name);

  String getPlayerSkin() => _prefs.getString(_playerSkinKey) ?? 'modern';
  Future<void> setPlayerSkin(String name) =>
      _prefs.setString(_playerSkinKey, name);

  // === 歌单 ===
  List<Playlist> getPlaylists() {
    final data = _prefs.getStringList(_playlistsKey) ?? [];
    return data.map((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return Playlist(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        songs: (map['songs'] as List?)
                ?.map((e) => Song.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [],
        coverUri: map['coverUri']?.toString(),
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
            DateTime.now(),
        description: map['description']?.toString(),
        isSystem: map['isSystem'] as bool? ?? false,
      );
    }).toList();
  }

  Future<void> savePlaylists(List<Playlist> lists) async {
    final data = lists.map((p) {
      return jsonEncode({
        'id': p.id,
        'name': p.name,
        'songs': p.songs.map((s) => s.toMap()).toList(),
        'coverUri': p.coverUri,
        'createdAt': p.createdAt.toIso8601String(),
        'updatedAt': p.updatedAt.toIso8601String(),
        'description': p.description,
        'isSystem': p.isSystem,
      });
    }).toList();
    await _prefs.setStringList(_playlistsKey, data);
  }

  // === 自动更新 ===
  bool isAutoUpdateCheck() => _prefs.getBool(_autoUpdateKey) ?? true;
  Future<void> setAutoUpdateCheck(bool v) =>
      _prefs.setBool(_autoUpdateKey, v);

  // === 上次播放 ===
  Future<void> saveLastPlaying(Song? song, Duration position) async {
    if (song != null) {
      await _prefs.setString(_lastSongKey, jsonEncode(song.toMap()));
      await _prefs.setInt(_lastPositionKey, position.inMilliseconds);
    }
  }

  Map<String, dynamic>? getLastPlaying() {
    final s = _prefs.getString(_lastSongKey);
    final pos = _prefs.getInt(_lastPositionKey);
    if (s == null) return null;
    return {
      'song': Song.fromMap(jsonDecode(s)),
      'position': Duration(milliseconds: pos ?? 0),
    };
  }
}
