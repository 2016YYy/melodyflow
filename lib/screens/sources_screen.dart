import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_source.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';
import 'webdav_browser_screen.dart';

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
            icon: const Icon(Icons.add_rounded),
            tooltip: '添加音源',
            onPressed: () => _showAddSourceDialog(context),
          ),
        ],
      ),
      body: provider.sources.isEmpty
          ? _EmptySources(onAdd: () => _showAddSourceDialog(context))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: provider.sources.length,
              itemBuilder: (context, index) {
                final source = provider.sources[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SourceCard(
                    source: source,
                    onTap: () => _loadSourceSongs(context, source),
                    onLongPress: () =>
                        _showSourceOptions(context, source),
                  ),
                );
              },
            ),
    );
  }

  IconData _sourceIcon(MusicSourceType type) {
    switch (type) {
      case MusicSourceType.webdav:
        return Icons.cloud_done_rounded;
      case MusicSourceType.network:
        return Icons.language_rounded;
      case MusicSourceType.smb:
        return Icons.folder_shared_rounded;
      default:
        return Icons.music_note_rounded;
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

  /// 加载音源歌曲列表 / 进入 WebDAV 浏览器
  Future<void> _loadSourceSongs(
      BuildContext context, MusicSource source) async {
    // WebDAV 源进入文件夹浏览器
    if (source.type == MusicSourceType.webdav) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WebdavBrowserScreen(source: source),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final songs = await context.read<MusicProvider>().loadSourceSongs(source);
      if (!context.mounted) return;
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
      if (!context.mounted) return;
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Icon(_sourceIcon(source.type),
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(source.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        Text(_typeName(source.type),
                            style: Theme.of(ctx).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('测试连接'),
              onTap: () async {
                Navigator.pop(ctx);
                final ok =
                    await context.read<MusicProvider>().testSource(source);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? '连接成功' : '连接失败')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                context.read<MusicProvider>().removeSource(source.id);
              },
            ),
            const SizedBox(height: 8),
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
                  initialValue: type,
                  decoration: const InputDecoration(labelText: '类型'),
                  items: MusicSourceType.values
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(_typeName(t))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => type = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: '地址',
                    hintText: 'https://example.com/dav',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(labelText: '用户名（可选）'),
                ),
                const SizedBox(height: 12),
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

/// 音源卡片
class _SourceCard extends StatelessWidget {
  final MusicSource source;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SourceCard({
    required this.source,
    required this.onTap,
    required this.onLongPress,
  });

  IconData _icon(MusicSourceType type) {
    switch (type) {
      case MusicSourceType.webdav:
        return Icons.cloud_done_rounded;
      case MusicSourceType.network:
        return Icons.language_rounded;
      case MusicSourceType.smb:
        return Icons.folder_shared_rounded;
      default:
        return Icons.music_note_rounded;
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.read<MusicProvider>().palette;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  gradient: LinearGradient(colors: palette.gradient),
                ),
                child: Icon(_icon(source.type), color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_typeName(source.type)} · ${source.url}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: source.enabled ? scheme.primary : scheme.outlineVariant,
                ),
              ),
            ],
          ),
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
        padding: const EdgeInsets.only(top: 4, bottom: 100),
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
        icon: const Icon(Icons.play_arrow_rounded),
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
    final palette = context.read<MusicProvider>().palette;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: palette.gradient),
            ),
            child:
                const Icon(Icons.cloud_rounded, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 22),
          const Text('还没有添加第三方音源',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('支持 WebDAV、HTTP API、SMB 等',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('添加音源'),
          ),
        ],
      ),
    );
  }
}
