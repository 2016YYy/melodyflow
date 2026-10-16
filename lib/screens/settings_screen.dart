import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/section_tiles.dart';
import '../widgets/update_dialogs.dart';
import 'about_screen.dart';

/// 设置界面 - 分组列表样式
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _appVersion = info.version);
  }

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    await runUpdateCheck(context);
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final palette = provider.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 外观
          const SectionHeader('外观'),
          SwitchTile(
            icon: Icons.dark_mode_rounded,
            title: '深色模式',
            subtitle: '切换深色 / 浅色主题',
            value: provider.darkMode,
            palette: palette,
            onChanged: provider.setDarkMode,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ActionTile(
            icon: Icons.palette_rounded,
            title: '主题配色',
            subtitle: provider.palette.label,
            palette: palette,
            trailing: _PaletteDot(palette: provider.palette),
            onTap: () => _showPalettePicker(context, provider),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ActionTile(
            icon: Icons.style_rounded,
            title: '播放器皮肤',
            subtitle: provider.playerSkin.label,
            palette: palette,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showSkinPicker(context, provider),
          ),

          // 应用更新
          const SectionHeader('应用更新'),
          ActionTile(
            icon: Icons.download_rounded,
            title: '检查更新',
            subtitle: '当前版本 ${_appVersion.isEmpty ? '-' : _appVersion}',
            palette: palette,
            trailing: _checking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _checking ? null : _checkUpdate,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchTile(
            icon: Icons.update_rounded,
            title: '启动时自动检查更新',
            subtitle: '打开应用时自动检查新版本',
            value: provider.storage.isAutoUpdateCheck(),
            palette: palette,
            onChanged: (v) {
              provider.storage.setAutoUpdateCheck(v);
              setState(() {});
            },
          ),

          // 关于
          const SectionHeader('关于'),
          ActionTile(
            icon: Icons.info_outline_rounded,
            title: '关于 MelodyFlow',
            subtitle: '版本 ${_appVersion.isEmpty ? '-' : _appVersion}',
            palette: palette,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ActionTile(
            icon: Icons.gavel_rounded,
            title: '免责声明',
            subtitle: '使用前请阅读相关条款',
            palette: palette,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _showDisclaimer,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ActionTile(
            icon: Icons.description_rounded,
            title: '开源软件许可',
            subtitle: '查看第三方开源许可',
            palette: palette,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLicensePage(context: context),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 主题配色选择器
  void _showPalettePicker(BuildContext context, MusicProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('主题配色',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: ThemePalettes.all.map((p) {
                  final selected = provider.palette.name == p.name;
                  return GestureDetector(
                    onTap: () {
                      provider.setPalette(p.name);
                      Navigator.pop(ctx);
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: p.gradient),
                            border: selected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                        color:
                                            p.primary.withValues(alpha: 0.5),
                                        blurRadius: 12)
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(p.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: selected ? p.primary : null,
                            )),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// 播放器皮肤选择器
  void _showSkinPicker(BuildContext context, MusicProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('播放器皮肤',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...PlayerSkin.all.map((skin) {
                final selected = provider.playerSkin.name == skin.name;
                return ListTile(
                  leading: Icon(
                    skin.name == 'classic'
                        ? Icons.music_note_rounded
                        : skin.name == 'modern'
                            ? Icons.album_rounded
                            : skin.name == 'minimal'
                                ? Icons.remove_rounded
                                : Icons.disc_full_rounded,
                    color: selected ? provider.palette.primary : null,
                  ),
                  title: Text(skin.label,
                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: selected ? provider.palette.primary : null,
                      )),
                  trailing: selected
                      ? Icon(Icons.check_rounded,
                          color: provider.palette.primary)
                      : null,
                  onTap: () {
                    provider.setPlayerSkin(skin.name);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showDisclaimer() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('免责声明'),
        content: const SingleChildScrollView(
          child: Text(
            '1. MelodyFlow 是开源免费软件，仅供个人学习研究使用。\n\n'
            '2. 本软件不提供任何音乐资源，所有音乐均来自用户本地或用户自行配置的第三方服务器。\n\n'
            '3. 用户应确保其使用的音乐资源已获得合法授权，因版权问题产生的法律责任由用户自行承担。\n\n'
            '4. 在线歌词与封面数据来源于公开 API，仅供学习交流，请勿用于商业用途。\n\n'
            '5. 本软件不对第三方音源的内容、可用性、安全性做任何保证。\n\n'
            '6. 使用本软件即表示您已阅读并同意以上条款。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }
}

/// 主题配色圆点指示器
class _PaletteDot extends StatelessWidget {
  final ThemePalette palette;
  const _PaletteDot({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: palette.gradient),
      ),
    );
  }
}
