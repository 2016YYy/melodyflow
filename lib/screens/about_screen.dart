import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/music_provider.dart';
import '../widgets/section_tiles.dart';
import '../widgets/update_dialogs.dart';

/// 关于页 - 分组列表样式
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '-';
  String _buildNumber = '';
  String _osInfo = '-';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final info = await PackageInfo.fromPlatform();
    String osInfo;
    try {
      final di = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await di.androidInfo;
        final abi = a.supportedAbis.isNotEmpty ? a.supportedAbis.first : '';
        osInfo = 'Android ${a.version.release} (SDK ${a.version.sdkInt})'
            '${abi.isNotEmpty ? ' · $abi' : ''}';
      } else if (Platform.isIOS) {
        final i = await di.iosInfo;
        osInfo = '${i.systemName} ${i.systemVersion}';
      } else {
        osInfo =
            '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      }
    } catch (_) {
      osInfo =
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    }
    if (!mounted) return;
    setState(() {
      _version = info.version;
      _buildNumber = info.buildNumber;
      _osInfo = osInfo;
    });
  }

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    await runUpdateCheck(context);
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开链接: $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    final palette = provider.palette;
    final versionText =
        _version + (_buildNumber.isNotEmpty ? ' ($_buildNumber)' : '');

    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 顶部品牌区
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: palette.gradient),
                    boxShadow: [
                      BoxShadow(
                        color: palette.primary.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.music_note_rounded,
                      size: 60, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text(
                  'MelodyFlow',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '开源跨平台音乐播放器',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          // 系统信息
          const SectionHeader('系统信息'),
          const InfoRow(label: '产品名称', value: 'MelodyFlow'),
          const Divider(height: 1, indent: 16, endIndent: 16),
          InfoRow(label: '版本', value: versionText),
          const Divider(height: 1, indent: 16, endIndent: 16),
          InfoRow(label: '操作系统', value: _osInfo),

          // 应用更新
          const SectionHeader('应用更新'),
          ActionTile(
            icon: Icons.download_rounded,
            title: '检查更新',
            subtitle: '从 GitHub 检查新版本',
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
            icon: Icons.science_rounded,
            title: '包含预发布版本',
            subtitle: '在正式版之前获取测试版',
            value: provider.includePrerelease,
            palette: palette,
            onChanged: provider.setIncludePrerelease,
          ),

          // 外部链接
          const SectionHeader('外部链接'),
          ActionTile(
            icon: Icons.language_rounded,
            title: '项目主页',
            subtitle: 'github.com/2016YYy/melodyflow',
            palette: palette,
            onTap: () => _open('https://github.com/2016YYy/melodyflow'),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ActionTile(
            icon: Icons.alternate_email_rounded,
            title: '问题反馈',
            subtitle: '提交 Issue 反馈问题',
            palette: palette,
            onTap: () =>
                _open('https://github.com/2016YYy/melodyflow/issues'),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ActionTile(
            icon: Icons.balance_rounded,
            title: '开源软件许可',
            subtitle: 'MelodyFlow 使用的第三方软件',
            palette: palette,
            onTap: () => showLicensePage(context: context),
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              '© 2025 MelodyFlow 开源项目',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
