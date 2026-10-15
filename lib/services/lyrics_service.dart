import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/lyric.dart';
import '../models/song.dart';

/// 在线歌词获取服务
/// 通过公开的歌词 API 获取歌词（仅用于个人学习研究）
class LyricsService {
  final Dio _dio = Dio();

  /// 获取歌词 - 尝试多个公开 API 源
  Future<List<LyricLine>> fetchLyrics(Song song) async {
    // 优先使用内嵌歌词
    if (song.lyrics != null && song.lyrics!.isNotEmpty) {
      final parsed = LyricParser.parseLrc(song.lyrics!);
      if (parsed.isNotEmpty) return parsed;
    }

    // 在线获取
    try {
      final lrc = await _fetchFromNetease(song.title, song.artist);
      if (lrc != null) {
        return LyricParser.parseLrc(lrc);
      }
    } catch (e) {
      debugPrint('网易歌词获取失败: $e');
    }

    try {
      final lrc = await _fetchFromQQ(song.title, song.artist);
      if (lrc != null) {
        return LyricParser.parseLrc(lrc);
      }
    } catch (e) {
      debugPrint('QQ歌词获取失败: $e');
    }

    return [];
  }

  /// 网易云音乐歌词 API
  Future<String?> _fetchFromNetease(String title, String artist) async {
    // 搜索歌曲
    final searchUrl =
        'https://music.163.com/api/search/get?s=${Uri.encodeQueryComponent('$title $artist')}&type=1&limit=1';
    final response = await _dio.get(searchUrl);
    final data = response.data;
    final songs = data['result']?['songs'];
    if (songs == null || songs.isEmpty) return null;

    final songId = songs[0]['id'];
    // 获取歌词
    final lyricUrl = 'https://music.163.com/api/song/lyric?id=$songId&lv=1';
    final lyricResponse = await _dio.get(lyricUrl);
    final lyricData = lyricResponse.data;
    return lyricData['lrc']?['lyric'];
  }

  /// QQ 音乐歌词 API
  Future<String?> _fetchFromQQ(String title, String artist) async {
    final searchUrl =
        'https://c.y.qq.com/soso/fcgi-bin/client_search_cp?w=${Uri.encodeQueryComponent('$title $artist')}&format=json&n=1';
    final response = await _dio.get(searchUrl);
    final data = response.data is String ? jsonDecode(response.data) : response.data;
    final songList = data['data']?['song']?['list'];
    if (songList == null || songList.isEmpty) return null;

    final songMid = songList[0]['songmid'];
    final lyricUrl =
        'https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=$songMid&format=json&nobase64=1';
    final lyricResponse = await _dio.get(
      lyricUrl,
      options: Options(headers: {'Referer': 'https://y.qq.com/'}),
    );
    final lyricData = lyricResponse.data is String
        ? jsonDecode(lyricResponse.data)
        : lyricResponse.data;
    return lyricData['lyric'];
  }
}
