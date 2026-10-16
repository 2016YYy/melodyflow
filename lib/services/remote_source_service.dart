import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/music_source.dart';
import '../models/song.dart';
import '../models/webdav_item.dart';

/// 第三方服务器 / 网盘音源服务
/// 支持: 自定义 HTTP API, WebDAV
class RemoteSourceService {
  final Dio _dio = Dio();

  static const List<String> _audioExtensions = [
    '.mp3', '.flac', '.wav', '.aac', '.ogg', '.m4a',
    '.wma', '.ape', '.alac', '.opus',
  ];

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
  Future<List<Song>> fetchSongs(MusicSource source, {String? path}) async {
    switch (source.type) {
      case MusicSourceType.webdav:
        return await _fetchWebdavSongs(source, path: path);
      case MusicSourceType.network:
      case MusicSourceType.smb:
      default:
        return await _fetchApiSongs(source);
    }
  }

  /// WebDAV 方式获取
  Future<List<Song>> _fetchWebdavSongs(MusicSource source, {String? path}) async {
    final List<Song> songs = [];
    try {
      final baseUrl = source.url.endsWith('/')
          ? source.url.substring(0, source.url.length - 1)
          : source.url;
      final targetPath = (path ?? '').replaceAll(RegExp(r'^/+'), '');
      final fullUrl = targetPath.isEmpty ? baseUrl : '$baseUrl/$targetPath';

      final response = await _dio.request(
        fullUrl,
        options: Options(
          method: 'PROPFIND',
          headers: {
            ..._buildHeaders(source),
            'Depth': '1',
            'Content-Type': 'application/xml',
          },
        ),
      );

      final items = _parseWebdavResponse(response.data.toString(), source.url);
      final streamHeaders = _buildHeaders(source);
      for (final item in items) {
        if (!item.isDirectory) {
          final lower = item.name.toLowerCase();
          final isAudio = _audioExtensions.any((ext) => lower.endsWith(ext));
          if (isAudio) {
            final name = item.name.split('.').first;
            songs.add(Song(
              id: 'webdav_${source.id}_${item.path}',
              title: name,
              artist: '未知艺术家',
              album: source.name,
              duration: Duration.zero,
              uri: item.path,
              sourceType: MusicSourceType.webdav,
              sourceId: source.id,
              httpHeaders: streamHeaders,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('WebDAV 获取失败: $e');
    }
    return songs;
  }

  /// 列出 WebDAV 文件夹内容
  Future<List<WebdavItem>> listWebdavFolder(
      MusicSource source, String path) async {
    try {
      final baseUrl = source.url.endsWith('/')
          ? source.url.substring(0, source.url.length - 1)
          : source.url;
      final targetPath = path.replaceAll(RegExp(r'^/+'), '');
      final fullUrl = targetPath.isEmpty ? baseUrl : '$baseUrl/$targetPath';

      final response = await _dio.request(
        fullUrl,
        options: Options(
          method: 'PROPFIND',
          headers: {
            ..._buildHeaders(source),
            'Depth': '1',
            'Content-Type': 'application/xml',
          },
        ),
      );
      return _parseWebdavResponse(response.data.toString(), source.url);
    } catch (e) {
      debugPrint('WebDAV 列表获取失败: $e');
      return [];
    }
  }

  /// 解析 WebDAV PROPFIND XML 响应
  List<WebdavItem> _parseWebdavResponse(String body, String sourceUrl) {
    final List<WebdavItem> items = [];
    final baseUrl = sourceUrl.endsWith('/')
        ? sourceUrl.substring(0, sourceUrl.length - 1)
        : sourceUrl;

    // 匹配每个 response 块
    final responseReg = RegExp(
      r'<[Dd]:response>(.*?)</[Dd]:response>',
      dotAll: true,
    );
    final hrefReg = RegExp(r'<[Dd]:href>([^<]+)</[Dd]:href>');
    final collectionReg = RegExp(r'<[Dd]:collection\s*/>', caseSensitive: false);
    final displayNameReg = RegExp(
        r'<[Dd]:displayname>([^<]*)</[Dd]:displayname>',
        dotAll: true);

    for (final match in responseReg.allMatches(body)) {
      final block = match.group(1)!;
      final hrefMatch = hrefReg.firstMatch(block);
      if (hrefMatch == null) continue;

      var href = Uri.decodeComponent(hrefMatch.group(1)!);
      // 去掉源 URL 前缀得到相对路径
      String relPath;
      if (href.startsWith(baseUrl)) {
        relPath = href.substring(baseUrl.length);
      } else if (href.startsWith('/')) {
        relPath = href;
      } else {
        relPath = '/$href';
      }
      relPath = relPath.replaceAll(RegExp(r'^/+'), '');

      final isDir = collectionReg.hasMatch(block) || href.endsWith('/');
      var name = '';
      final dnMatch = displayNameReg.firstMatch(block);
      if (dnMatch != null && dnMatch.group(1)!.isNotEmpty) {
        name = dnMatch.group(1)!.trim();
      } else {
        final clean = relPath.replaceAll(RegExp(r'/+$'), '');
        name = clean.split('/').last;
      }

      if (name.isEmpty) continue;

      items.add(WebdavItem(
        name: name,
        path: href,
        isDirectory: isDir,
      ));
    }
    return items;
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
