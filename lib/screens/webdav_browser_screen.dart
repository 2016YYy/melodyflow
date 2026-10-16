import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_source.dart';
import '../models/webdav_item.dart';
import '../providers/music_provider.dart';
import '../theme/app_theme.dart';

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
          if (_pathStack.length > 1) _buildBreadcrumb(palette),
          Expanded(child: _buildBody(palette)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _scanAndPlay(currentPath),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('扫描播放'),
      ),
    );
  }

  Widget _buildBreadcrumb(ThemePalette palette) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < _pathStack.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 18, color: scheme.onSurfaceVariant),
                ),
              _CrumbChip(
                label: i == 0 ? '根目录' : _segmentName(_pathStack[i]),
                active: i == _pathStack.length - 1,
                palette: palette,
                onTap: () {
                  setState(() {
                    _pathStack.removeRange(i + 1, _pathStack.length);
                  });
                  _loadFolder(_pathStack.last);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemePalette palette) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(_error, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _loadFolder(_pathStack.last),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            const Text('空文件夹'),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 100),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: item.isDirectory
                  ? () {
                      setState(() => _pathStack.add(item.path));
                      _loadFolder(item.path);
                    }
                  : null,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      item.isDirectory
                          ? Icons.folder_rounded
                          : _fileIcon(item.name),
                      color: item.isDirectory
                          ? palette.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                          if (item.isDirectory)
                            Text('文件夹',
                                style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    if (item.isDirectory)
                      Icon(Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

/// 面包屑胶囊
class _CrumbChip extends StatelessWidget {
  final String label;
  final bool active;
  final ThemePalette palette;
  final VoidCallback onTap;

  const _CrumbChip({
    required this.label,
    required this.active,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? palette.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? palette.primary : scheme.onSurfaceVariant,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
