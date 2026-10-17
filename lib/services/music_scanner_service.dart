import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../models/song.dart';

/// 本地音乐扫描服务
class MusicScannerService {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  bool _hasPermission = false;

  /// 检查并请求权限
  Future<bool> checkAndRequestPermission() async {
    if (Platform.isAndroid || Platform.isIOS) {
      bool permissionStatus = await _audioQuery.permissionsStatus();
      if (!permissionStatus) {
        permissionStatus = await _audioQuery.permissionsRequest();
      }
      _hasPermission = permissionStatus;
      return permissionStatus;
    }
    // Windows/Linux 不需要特殊权限
    _hasPermission = true;
    return true;
  }

  /// 扫描本地音乐
  Future<List<Song>> scanLocalMusic({
    SongSortType sortType = SongSortType.DISPLAY_NAME,
    OrderType orderType = OrderType.ASC_OR_SMALLER,
    UriType? uriType,
  }) async {
    if (!_hasPermission) {
      await checkAndRequestPermission();
    }

    try {
      final List<SongModel> songs = await _audioQuery.querySongs(
        sortType: sortType,
        orderType: orderType,
        uriType: uriType,
      );

      return songs.map((s) {
        // 估算比特率：文件大小(字节) * 8 / 时长(秒) = bps
        int? estimatedBitrate;
        final dur = s.duration ?? 0;
        if (s.size > 0 && dur > 0) {
          estimatedBitrate = ((s.size * 8) / (dur / 1000)).round();
        }
        return Song(
          id: s.id.toString(),
          title: s.title,
          artist: s.artist ?? '未知艺术家',
          album: s.album ?? '未知专辑',
          albumId: s.albumId?.toString(),
          duration: Duration(milliseconds: dur),
          uri: s.uri ?? s.data,
          size: s.size,
          sourceType: MusicSourceType.local,
          format: s.fileExtension.toUpperCase().isNotEmpty
              ? s.fileExtension.toUpperCase()
              : null,
          bitrate: estimatedBitrate,
          track: s.track,
          dateAdded: s.dateAdded,
          dateModified: s.dateModified,
        );
      }).toList();
    } catch (e) {
      debugPrint('扫描本地音乐失败: $e');
      rethrow;
    }
  }

  /// 获取歌曲封面（本地）
  Future<Uint8List?> getSongArtwork(String songId, {int size = 200}) async {
    try {
      return await _audioQuery.queryArtwork(
        int.tryParse(songId) ?? 0,
        ArtworkType.AUDIO,
        size: size,
      );
    } catch (e) {
      debugPrint('获取封面失败: $e');
      return null;
    }
  }

  /// 获取专辑封面
  Future<Uint8List?> getAlbumArtwork(String albumId, {int size = 300}) async {
    try {
      return await _audioQuery.queryArtwork(
        int.tryParse(albumId) ?? 0,
        ArtworkType.ALBUM,
        size: size,
      );
    } catch (e) {
      return null;
    }
  }

  /// 获取所有艺术家
  Future<List<ArtistModel>> getArtists() async {
    return _audioQuery.queryArtists();
  }

  /// 获取所有专辑
  Future<List<AlbumModel>> getAlbums() async {
    return _audioQuery.queryAlbums();
  }
}
