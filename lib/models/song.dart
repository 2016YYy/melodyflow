/// 歌曲数据模型
class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? albumId;
  final Duration duration;
  final String uri; // 文件路径或网络URL
  final String? coverUri; // 封面图路径或URL
  final String? lyrics; // 内嵌歌词
  final Map<String, String>? metadata; // 其他元数据
  final MusicSourceType sourceType; // 来源类型
  final String? sourceId; // 第三方源ID
  final int? size; // 文件大小字节
  final String? mimeType;
  final Map<String, String>? httpHeaders; // 流媒体请求头（WebDAV等认证用）
  final String? format; // 音频格式（如 MP3/FLAC/WAV）
  final int? bitrate; // 比特率（bps）
  final int? sampleRate; // 采样率（Hz）
  final int? track; // 曲目编号
  final int? dateAdded; // 添加时间戳（秒）
  final int? dateModified; // 修改时间戳（秒）
  final int? playedTimes; // 播放次数

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.albumId,
    required this.duration,
    required this.uri,
    this.coverUri,
    this.lyrics,
    this.metadata,
    this.sourceType = MusicSourceType.local,
    this.sourceId,
    this.size,
    this.mimeType,
    this.httpHeaders,
    this.format,
    this.bitrate,
    this.sampleRate,
    this.track,
    this.dateAdded,
    this.dateModified,
    this.playedTimes,
  });

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '未知歌曲',
      artist: map['artist']?.toString() ?? '未知艺术家',
      album: map['album']?.toString() ?? '未知专辑',
      albumId: map['albumId']?.toString(),
      duration: Duration(milliseconds: (map['duration'] as num?)?.toInt() ?? 0),
      uri: map['uri']?.toString() ?? '',
      coverUri: map['coverUri']?.toString(),
      lyrics: map['lyrics']?.toString(),
      metadata: map['metadata'] as Map<String, String>?,
      sourceType: MusicSourceType.values.firstWhere(
        (e) => e.name == map['sourceType'],
        orElse: () => MusicSourceType.local,
      ),
      sourceId: map['sourceId']?.toString(),
      size: (map['size'] as num?)?.toInt(),
      mimeType: map['mimeType']?.toString(),
      httpHeaders: map['httpHeaders'] as Map<String, String>?,
      format: map['format']?.toString(),
      bitrate: (map['bitrate'] as num?)?.toInt(),
      sampleRate: (map['sampleRate'] as num?)?.toInt(),
      track: (map['track'] as num?)?.toInt(),
      dateAdded: (map['dateAdded'] as num?)?.toInt(),
      dateModified: (map['dateModified'] as num?)?.toInt(),
      playedTimes: (map['playedTimes'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'albumId': albumId,
      'duration': duration.inMilliseconds,
      'uri': uri,
      'coverUri': coverUri,
      'lyrics': lyrics,
      'metadata': metadata,
      'sourceType': sourceType.name,
      'sourceId': sourceId,
      'size': size,
      'mimeType': mimeType,
      'httpHeaders': httpHeaders,
      'format': format,
      'bitrate': bitrate,
      'sampleRate': sampleRate,
      'track': track,
      'dateAdded': dateAdded,
      'dateModified': dateModified,
      'playedTimes': playedTimes,
    };
  }

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? albumId,
    Duration? duration,
    String? uri,
    String? coverUri,
    String? lyrics,
    Map<String, String>? metadata,
    MusicSourceType? sourceType,
    String? sourceId,
    int? size,
    String? mimeType,
    Map<String, String>? httpHeaders,
    String? format,
    int? bitrate,
    int? sampleRate,
    int? track,
    int? dateAdded,
    int? dateModified,
    int? playedTimes,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      duration: duration ?? this.duration,
      uri: uri ?? this.uri,
      coverUri: coverUri ?? this.coverUri,
      lyrics: lyrics ?? this.lyrics,
      metadata: metadata ?? this.metadata,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      size: size ?? this.size,
      mimeType: mimeType ?? this.mimeType,
      httpHeaders: httpHeaders ?? this.httpHeaders,
      format: format ?? this.format,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      track: track ?? this.track,
      dateAdded: dateAdded ?? this.dateAdded,
      dateModified: dateModified ?? this.dateModified,
      playedTimes: playedTimes ?? this.playedTimes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 音乐来源类型
enum MusicSourceType {
  local, // 本地
  network, // 第三方服务器
  webdav, // WebDAV网盘
  smb, // SMB共享
}
