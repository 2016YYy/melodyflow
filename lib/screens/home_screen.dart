import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_tile.dart';
import 'player_screen.dart';
import 'sources_screen.dart';
import 'settings_screen.dart';

/// 首页 - 包含本地音乐列表、搜索
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MusicProvider>().scanLocalMusic();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MelodyFlow'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新扫描',
            onPressed: () => provider.scanLocalMusic(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: provider.search,
              decoration: InputDecoration(
                hintText: '搜索歌曲、艺术家、专辑...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ),
      ),
      body: provider.isScanning
          ? const Center(child: CircularProgressIndicator())
          : provider.songs.isEmpty
              ? _EmptyState(onScan: () => provider.scanLocalMusic())
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: provider.songs.length,
                  itemBuilder: (context, index) {
                    return SongTile(song: provider.songs[index], index: index);
                  },
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
          NavigationBar(
            selectedIndex: _currentTab,
            onDestinationSelected: (i) {
              setState(() => _currentTab = i);
              if (i == 1) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SourcesScreen()),
                );
              } else if (i == 2) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              }
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.music_note), label: '音乐'),
              NavigationDestination(icon: Icon(Icons.cloud), label: '音源'),
              NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
            ],
          ),
        ],
      ),
    );
  }
}

/// 空状态
class _EmptyState extends StatelessWidget {
  final VoidCallback onScan;
  const _EmptyState({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.gradient,
            ),
            child: const Icon(Icons.library_music, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const Text(
            '还没有找到音乐',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text('点击下方按钮扫描本地音乐'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.search),
            label: const Text('扫描本地音乐'),
          ),
        ],
      ),
    );
  }
}
