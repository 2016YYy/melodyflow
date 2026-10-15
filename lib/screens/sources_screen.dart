import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_source.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';

/// 第三方音源管理界面
class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('音乐源'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加音源',
            onPressed: () => _showAddSourceDialog(context),
          ),
        ],
      ),
      body: provider.sources.isEmpty
          ? _EmptySources(onAdd: () => _showAddSourceDialog(context))
          : ListView.builder(
              itemCount: provider.sources.length,
              itemBuilder: (context, index) {
                final source = provider.sources[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: AppTheme.gradient,
                      ),
                      child: Icon(_sourceIcon(source.type),
                          color: Colors.white),
                    ),
                    title: Text(source.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${_typeName(source.type)} · ${source.url}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: source.enabled
                        ? const Icon(Icons.check_circle,
                            color: Colors.green, size: 20)
                        : const Icon(Icons.cancel, color: Colors.grey),
                    onTap: () => _loadSourceSongs(context, source),
                    onLongPress: () => _showSourceOptions(context, source),
                  ),
                );
              },
            ),
    );
  }

  IconData _sourceIcon(MusicSourceType type) {
    switch (type) {
      case MusicSourceType.webdav:
        return Icons.cloud_done;
      case MusicSourceType.network:
        return Icons.language;
      case MusicSourceType.smb:
        return Icons.folder_shared;
      default:
        return Icons.music_note;
    }
  }

  String _typeName(MusicSourceType type) {
    switch (type) {
      case MusicSourceType.webdav:
        return 'WebDAV';
      case MusicSourceType.network:
        return 'HTTP API';
      case MusicSourceType.smb:
        return 'SMB';
      default:
        return '本地';
    }
  }

  /// 加载音源歌曲列表
  Future<void> _loadSourceSongs(
      BuildContext context, MusicSource source) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final songs = await context.read<MusicProvider>().loadSourceSongs(source);
      if (!mounted) return;
      Navigator.pop(context);
      if (songs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该音源暂无歌曲')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SourceSongsScreen(source: source, songs: songs),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载失败: $e')),
      );
    }
  }

  void _showSourceOptions(BuildContext context, MusicSource source) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('测试连接'),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await context
                    .read<MusicProvider>()
                    .testSource(source);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? '连接成功' : '连接失败')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                context.read<MusicProvider>().removeSource(source.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSourceDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    MusicSourceType type = MusicSourceType.webdav;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('添加音乐源'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<MusicSourceType>(
                  value: type,
                  decoration: const InputDecoration(labelText: '类型'),
                  items: MusicSourceType.values
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(_typeName(t))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => type = v!),
                ),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: '地址',
                    hintText: 'https://example.com/dav',
                  ),
                ),
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(labelText: '用户名（可选）'),
                ),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '密码（可选）'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isEmpty || urlCtrl.text.isEmpty) return;
                final source = MusicSource(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text,
                  type: type,
                  url: urlCtrl.text,
                  username: userCtrl.text.isEmpty ? null : userCtrl.text,
                  password: passCtrl.text.isEmpty ? null : passCtrl.text,
                );
                context.read<MusicProvider>().addSource(source);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('音源已添加')),
                );
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 音源歌曲列表
class SourceSongsScreen extends StatelessWidget {
  final MusicSource source;
  final List<Song> songs;
  const SourceSongsScreen(
      {super.key, required this.source, required this.songs});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MusicProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(source.name)),
      body: ListView.builder(
        itemCount: songs.length,
        itemBuilder: (context, index) {
          return SongTile(
            song: songs[index],
            onMore: null,
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => provider.playPlaylist(songs),
        icon: const Icon(Icons.play_arrow),
        label: const Text('播放全部'),
      ),
    );
  }
}

class _EmptySources extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptySources({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.gradient,
            ),
            child: const Icon(Icons.cloud, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text('还没有添加第三方音源'),
          const SizedBox(height: 8),
          const Text('支持 WebDAV、HTTP API、SMB 等',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('添加音源'),
          ),
        ],
      ),
    );
  }
}
