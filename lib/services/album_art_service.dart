import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';

/// 专辑封面在线获取服务
class AlbumArtService {
  final Dio _dio = Dio();

  /// 获取专辑封面 - 返回图片URL
  Future<String?> fetchAlbumArtUrl(Song song) async {
    // 优先使用本地封面
    if (song.coverUri != null && song.coverUri!.isNotEmpty) {
      return song.coverUri;
    }

    // 在线获取
    try {
      return await _fetchFromNetease(song.title, song.artist, song.album);
    } catch (e) {
      debugPrint('获取专辑封面失败: $e');
      return null;
    }
  }

  /// 网易云封面
  Future<String?> _fetchFromNetease(String title, String artist, String album) async {
    final query = album != '未知专辑' ? '$title $album' : '$title $artist';
    final url =
        'https://music.163.com/api/search/get?s=${Uri.encodeQueryComponent(query)}&type=10&limit=1';
    final response = await _dio.get(url);
    final data = response.data;
    final albums = data['result']?['albums'];
    if (albums != null && albums.isNotEmpty) {
      final picUrl = albums[0]['picUrl'];
      if (picUrl != null) {
        return picUrl.toString().replaceFirst('http://', 'https://');
      }
    }

    // 回退到搜索歌曲
    final songUrl =
        'https://music.163.com/api/search/get?s=${Uri.encodeQueryComponent('$title $artist')}&type=1&limit=1';
    final songResponse = await _dio.get(songUrl);
    final songData = songResponse.data;
    final songs = songData['result']?['songs'];
    if (songs != null && songs.isNotEmpty) {
      final albumArt = songs[0]['album']?['picUrl'];
      if (albumArt != null) {
        return albumArt.toString().replaceFirst('http://', 'https://');
      }
    }
    return null;
  }

  /// 下载封面图片
  Future<Uint8List?> downloadImage(String url) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data as Uint8List;
    } catch (e) {
      return null;
    }
  }
}
