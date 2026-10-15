import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/music_source.dart';
import '../models/song.dart';

/// 第三方服务器 / 网盘音源服务
/// 支持: 自定义 HTTP API, WebDAV
class RemoteSourceService {
  final Dio _dio = Dio();

  /// 测试连接
  Future<bool> testConnection(MusicSource source) async {
    try {
      final response = await _dio.get(
        source.url,
        options: Options(
          headers: _buildHeaders(source),
          validateStatus: (status) => status! < 500,
        ),
      );
      return response.statusCode == 200 || response.statusCode == 401;
    } catch (e) {
      debugPrint('连接测试失败: $e');
      return false;
    }
  }

  /// 获取远程歌曲列表
  Future<List<Song>> fetchSongs(MusicSource source) async {
    switch (source.type) {
      case MusicSourceType.webdav:
        return await _fetchWebdavSongs(source);
      case MusicSourceType.network:
      case MusicSourceType.smb:
      default:
        return await _fetchApiSongs(source);
    }
  }

  /// WebDAV 方式获取
  Future<List<Song>> _fetchWebdavSongs(MusicSource source) async {
    final List<Song> songs = [];
    try {
      final response = await _dio.request(
        source.url,
        options: Options(
          method: 'PROPFIND',
          headers: {
            ..._buildHeaders(source),
            'Depth': '1',
            'Content-Type': 'application/xml',
          },
        ),
      );

      // 解析 WebDAV XML 响应
      final body = response.data.toString();
      final hrefReg = RegExp(r'<D:href>([^<]+)</D:href>');
      final matches = hrefReg.allMatches(body);

      final audioExtensions = [
        '.mp3', '.flac', '.wav', '.aac', '.ogg', '.m4a',
        '.wma', '.ape', '.alac', '.opus'
      ];

      for (final match in matches) {
        final href = Uri.decodeComponent(match.group(1)!);
        final isAudio = audioExtensions.any((ext) =>
            href.toLowerCase().endsWith(ext));
        if (isAudio) {
          final fileName = href.split('/').last;
          final name = fileName.split('.').first;
          final url = source.url.endsWith('/')
              ? '${source.url}$fileName'
              : '${source.url}/$fileName';

          songs.add(Song(
            id: 'webdav_${source.id}_$name',
            title: name,
            artist: '未知艺术家',
            album: source.name,
            duration: Duration.zero,
            uri: url,
            sourceType: MusicSourceType.webdav,
            sourceId: source.id,
          ));
        }
      }
    } catch (e) {
      debugPrint('WebDAV 获取失败: $e');
    }
    return songs;
  }

  /// 自定义 HTTP API 方式
  /// 期望 API 返回 JSON: {"songs": [{"id","title","artist","album","duration","url","cover"}]}
  Future<List<Song>> _fetchApiSongs(MusicSource source) async {
    final List<Song> songs = [];
    try {
      final response = await _dio.get(
        source.url,
        options: Options(headers: _buildHeaders(source)),
      );

      dynamic data = response.data;
      if (data is String) data = jsonDecode(data);

      final List songList = data['songs'] ?? data['data'] ?? data['list'] ?? [];
      for (final item in songList) {
        songs.add(Song(
          id: item['id']?.toString() ?? item['url'] ?? '',
          title: item['title'] ?? item['name'] ?? '未知歌曲',
          artist: item['artist'] ?? '未知艺术家',
          album: item['album'] ?? '未知专辑',
          duration: Duration(
              milliseconds: (item['duration'] as num?)?.toInt() ?? 0),
          uri: item['url'] ?? item['uri'] ?? '',
          coverUri: item['cover'] ?? item['coverUrl'],
          sourceType: MusicSourceType.network,
          sourceId: source.id,
        ));
      }
    } catch (e) {
      debugPrint('API 获取失败: $e');
    }
    return songs;
  }

  Map<String, String> _buildHeaders(MusicSource source) {
    final headers = Map<String, String>.from(source.headers);
    if (source.token != null && source.token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${source.token}';
    }
    if (source.username != null && source.password != null) {
      final basic = base64Encode(
          utf8.encode('${source.username}:${source.password}'));
      headers['Authorization'] = 'Basic $basic';
    }
    return headers;
  }

  /// 为网络歌曲获取流地址（带认证头）
  Map<String, String> getStreamHeaders(MusicSource source) =>
      _buildHeaders(source);
}
