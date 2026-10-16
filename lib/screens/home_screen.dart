import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/album_art_widget.dart';
import '../widgets/integrated_nav_bar.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_tile.dart';
import 'favorites_screen.dart';
import 'group_songs_screen.dart';
import 'player_screen.dart';
import 'playlist_detail_screen.dart';
import 'settings_screen.dart';
import 'sources_screen.dart';

/// 首页外壳 - 底部菜单（音乐 / 音源 / 设置）
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  static const List<IntegratedNavItem> _navItems = [
    IntegratedNavItem(
        icon: Icons.library_music_outlined,
        activeIcon: Icons.library_music_rounded,
        label: '音乐'),
    IntegratedNavItem(
        icon: Icons.cloud_outlined,
        activeIcon: Icons.cloud_rounded,
        label: '音源'),
    IntegratedNavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        label: '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _navIndex,
        children: const [
          MusicLibraryPage(),
          SourcesScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniPlayer(onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlayerScreen()),
            );
          }),
          IntegratedNavBar(
            currentIndex: _navIndex,
            items: _navItems,
            onTap: (i) => setState(() => _navIndex = i),
          ),
        ],
      ),
    );
  }
}

/// 音乐库页面 - 歌曲 / 专辑 / 艺术家 / 歌单
class MusicLibraryPage extends StatefulWidget {
  const MusicLibraryPage({super.key});

  @override
  State<MusicLibraryPage> createState() => _MusicLibraryPageState();
}

class _MusicLibraryPageState extends State<MusicLibraryPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MusicProvider>().scanLocalMusic();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final palette = provider.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MelodyFlow'),
        actions: [
          // 右上角「扫描歌曲」功能
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed:
                  provider.isScanning ? null : () => provider.scanLocalMusic(),
              icon: provider.isScanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.radar_rounded, size: 18),
              label: Text(provider.isScanning ? '扫描中' : '扫描歌曲'),
              style: TextButton.styleFrom(
                foregroundColor: palette.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                      color: palette.primary.withValues(alpha: 0.4)),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              // 搜索框
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TextField(
                  controller: _searchController,
                  onChanged: provider.search,
                  decoration: const InputDecoration(
                    hintText: '搜索歌曲、艺术家、专辑...',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(24)),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
              // 分类标签
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: palette.primary,
                unselectedLabelColor:
                    Theme.of(context).textTheme.bodySmall?.color,
                indicatorColor: palette.primary,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: '歌曲'),
                  Tab(text: '专辑'),
                  Tab(text: '艺术家'),
                  Tab(text: '歌单'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: provider.isScanning
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _SongsTab(provider: provider),
                _AlbumsTab(provider: provider),
                _ArtistsTab(provider: provider),
                _PlaylistsTab(provider: provider),
              ],
            ),
    );
  }
}

/// 歌曲标签页
class _SongsTab extends StatelessWidget {
  final MusicProvider provider;
  const _SongsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.songs.isEmpty) {
      return _EmptyState(
        icon: Icons.library_music_rounded,
        text: '还没有找到音乐',
        subtext: '点击右上角「扫描歌曲」扫描本地音乐',
        onAction: () => provider.scanLocalMusic(),
        actionLabel: '扫描本地音乐',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: provider.songs.length,
      itemBuilder: (context, index) {
        return SongTile(song: provider.songs[index], index: index);
      },
    );
  }
}

/// 专辑标签页
class _AlbumsTab extends StatelessWidget {
  final MusicProvider provider;
  const _AlbumsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final albums = provider.albums;
    if (albums.isEmpty) {
      return const _EmptyState(
        icon: Icons.album_rounded,
        text: '暂无专辑',
        subtext: '扫描音乐后将按专辑分类',
      );
    }
    final entries = albums.entries.toList();
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final name = entries[index].key;
        final songs = entries[index].value;
        return _AlbumCard(name: name, songs: songs);
      },
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final String name;
  final List<Song> songs;
  const _AlbumCard({required this.name, required this.songs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupSongsScreen(
            title: name,
            subtitle: '${songs.length} 首歌曲',
            songs: songs,
            coverSong: songs.first,
            fallbackIcon: Icons.album_rounded,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: AlbumArtWidget(
                song: songs.first,
                size: double.infinity,
                borderRadius: 0,
                placeholderIcon: Icons.album_rounded,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            '${songs.first.artist} · ${songs.length} 首',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// 艺术家标签页
class _ArtistsTab extends StatelessWidget {
  final MusicProvider provider;
  const _ArtistsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final artists = provider.artists;
    if (artists.isEmpty) {
      return const _EmptyState(
        icon: Icons.person_rounded,
        text: '暂无艺术家',
        subtext: '扫描音乐后将按艺术家分类',
      );
    }
    final entries = artists.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final name = entries[index].key;
        final songs = entries[index].value;
        return ListTile(
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: Colors.transparent,
            child: GradientAvatar(name: name, size: 52),
          ),
          title:
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${songs.length} 首歌曲'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupSongsScreen(
                title: name,
                subtitle: '${songs.length} 首歌曲',
                songs: songs,
                coverSong: songs.first,
                fallbackIcon: Icons.person_rounded,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 渐变头像（用于艺术家）
class GradientAvatar extends StatelessWidget {
  final String name;
  final double size;
  const GradientAvatar({super.key, required this.name, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final palette = context.read<MusicProvider>().palette;
    final hash = name.codeUnits.fold(0, (a, b) => a + b);
    final colors = palette.coverPlaceholder;
    final startIdx = hash % colors.length;
    final endIdx = (startIdx + 1) % colors.length;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [colors[startIdx], colors[endIdx]],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.38,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// 歌单标签页（置顶「我喜爱」系统歌单）
class _PlaylistsTab extends StatelessWidget {
  final MusicProvider provider;
  const _PlaylistsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final playlists = provider.playlists;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            // 置顶：我喜爱（系统歌单）
            _FavoritesTile(count: provider.favoriteSongs.length),
            if (playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: _EmptyState(
                  icon: Icons.playlist_play_rounded,
                  text: '还没有自建歌单',
                  subtext: '点击右下角按钮创建你的第一个歌单',
                ),
              )
            else
              ...playlists.map((p) => _PlaylistTile(playlist: p)),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => _showCreateDialog(context),
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }

  void _showCreateDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建歌单'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '歌单名称'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              context.read<MusicProvider>().createPlaylist(ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}

/// 「我喜爱」置顶入口
class _FavoritesTile extends StatelessWidget {
  final int count;
  const _FavoritesTile({required this.count});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          gradient: const LinearGradient(
            colors: [AppColors.favorite, AppColors.favoriteAlt],
          ),
        ),
        child: const Icon(Icons.favorite_rounded, color: Colors.white),
      ),
      title:
          const Text('我喜爱', style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('$count 首歌曲 · 系统歌单'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FavoritesScreen()),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  const _PlaylistTile({required this.playlist});

  @override
  Widget build(BuildContext context) {
    final palette = context.read<MusicProvider>().palette;
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: playlist.songs.isNotEmpty
            ? AlbumArtWidget(
                song: playlist.songs.first,
                size: 52,
                borderRadius: 0,
                placeholderIcon: Icons.playlist_play_rounded,
              )
            : Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: palette.coverPlaceholder),
                ),
                child: const Icon(Icons.playlist_play_rounded,
                    color: Colors.white70),
              ),
      ),
      title:
          Text(playlist.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${playlist.songs.length} 首歌曲'),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'rename') _rename(context);
          if (v == 'delete') {
            context.read<MusicProvider>().deletePlaylist(playlist.id);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'rename', child: Text('重命名')),
          PopupMenuItem(
              value: 'delete',
              child: Text('删除', style: TextStyle(color: AppColors.danger))),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlaylistDetailScreen(playlist: playlist),
        ),
      ),
    );
  }

  void _rename(BuildContext context) {
    final ctrl = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名歌单'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '歌单名称'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              context
                  .read<MusicProvider>()
                  .renamePlaylist(playlist.id, ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

/// 空状态组件
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final String subtext;
  final VoidCallback? onAction;
  final String? actionLabel;

  const _EmptyState({
    required this.icon,
    required this.text,
    required this.subtext,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.read<MusicProvider>().palette;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: palette.gradient),
            ),
            child: Icon(icon, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(text,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(subtext, style: Theme.of(context).textTheme.bodyMedium),
          if (onAction != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel ?? '操作'),
            ),
          ],
        ],
      ),
    );
  }
}
