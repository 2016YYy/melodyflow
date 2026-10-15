import 'song.dart';

/// 歌单模型
class Playlist {
  final String id;
  final String name;
  final List<Song> songs;
  final String? coverUri;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;
  final bool isSystem; // 系统歌单（如最近播放、收藏）

  const Playlist({
    required this.id,
    required this.name,
    this.songs = const [],
    this.coverUri,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.isSystem = false,
  });

  int get songCount => songs.length;

  Duration get totalDuration => songs.fold(
        Duration.zero,
        (prev, song) => prev + song.duration,
      );

  Playlist copyWith({
    String? name,
    List<Song>? songs,
    String? coverUri,
    String? description,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      songs: songs ?? this.songs,
      coverUri: coverUri ?? this.coverUri,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      description: description ?? this.description,
      isSystem: isSystem,
    );
  }
}
