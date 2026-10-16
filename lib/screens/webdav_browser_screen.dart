import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_source.dart';
import '../models/webdav_item.dart';
import '../providers/music_provider.dart';

/// WebDAV 文件夹浏览器
class WebdavBrowserScreen extends StatefulWidget {
  final MusicSource source;
  const WebdavBrowserScreen({super.key, required this.source});

  @override
  State<WebdavBrowserScreen> createState() => _WebdavBrowserScreenState();
}

class _WebdavBrowserScreenState extends State<WebdavBrowserScreen> {
  final List<String> _pathStack = [''];
  List<WebdavItem> _items = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadFolder('');
  }

  Future<void> _loadFolder(String path) async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final items = await context
          .read<MusicProvider>()
          .listWebdavFolder(widget.source, path);
      // 过滤掉自身（当前目录）
      final filtered = items.where((i) {
        if (path.isEmpty) return i.path != widget.source.url;
        return true;
      }).toList();
      // 排序：文件夹在前，然后按名称
      filtered.sort((a, b) {
        if (a.isDirectory != b.isDirectory) {
          return a.isDirectory ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      setState(() {
        _items = filtered;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败: $e';
        _loading = false;
      });
    }
  }

  Future<void> _scanAndPlay(String path) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final songs = await context
          .read<MusicProvider>()
          .loadSourceSongs(widget.source);
      // 过滤出当前路径下的歌曲
      final currentPath = path.endsWith('/') ? path : '$path/';
      final folderSongs = songs
          .where((s) => s.uri.contains(currentPath) || s.uri.endsWith(path))
          .toList();
      // 如果没有匹配到，用全部
      final list = folderSongs.isNotEmpty ? folderSongs : songs;
      if (!mounted) return;
      Navigator.pop(context);
      if (list.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该文件夹没有音乐文件')),
        );
        return;
      }
      // 播放
      if (!mounted) return;
      await context.read<MusicProvider>().playPlaylist(list);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已加载 ${list.length} 首歌曲')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('扫描失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.read<MusicProvider>().palette;
    final currentPath = _pathStack.last;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.source.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_play_rounded),
            tooltip: '扫描并播放当前文件夹',
            onPressed: () => _scanAndPlay(currentPath),
          ),
        ],
      ),
      body: Column(
        children: [
          // 路径面包屑
          if (_pathStack.length > 1)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: palette.primary.withValues(alpha:0.08),
              child: Wrap(
                spacing: 4,
                children: [
                  for (int i = 0; i < _pathStack.length; i++) ...[
                    if (i > 0) const Icon(Icons.chevron_right, size: 16),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _pathStack.removeRange(i + 1, _pathStack.length);
                        });
                        _loadFolder(_pathStack.last);
                      },
                      child: Text(
                        i == 0 ? '根目录' : _segmentName(_pathStack[i]),
                        style: TextStyle(
                          color: i == _pathStack.length - 1
                              ? palette.primary
                              : null,
                          fontWeight: i == _pathStack.length - 1
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Text(_error))
                    : _items.isEmpty
                        ? const Center(child: Text('空文件夹'))
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 20),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return ListTile(
                                leading: Icon(
                                  item.isDirectory
                                      ? Icons.folder_rounded
                                      : _fileIcon(item.name),
                                  color: item.isDirectory
                                      ? palette.primary
                                      : null,
                                ),
                                title: Text(item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: item.isDirectory
                                    ? const Text('文件夹')
                                    : null,
                                trailing: item.isDirectory
                                    ? const Icon(Icons.chevron_right_rounded)
                                    : null,
                                onTap: () {
                                  if (item.isDirectory) {
                                    setState(() {
                                      _pathStack.add(item.path);
                                    });
                                    _loadFolder(item.path);
                                  }
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _scanAndPlay(currentPath),
        backgroundColor: palette.primary,
        icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
        label: const Text('扫描播放',
            style: TextStyle(color: Colors.white)),
      ),
    );
  }

  String _segmentName(String path) {
    final clean = path.replaceAll(RegExp(r'/+$'), '');
    return clean.split('/').last;
  }

  IconData _fileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.mp3') ||
        lower.endsWith('.flac') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.m4a')) {
      return Icons.audio_file_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }
}
