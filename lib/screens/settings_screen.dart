import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

/// 设置界面 - 包含关于、检查更新、主题
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final UpdateService _updateService = UpdateService();
  String _appVersion = '';
  bool _checking = false;
  ReleaseInfo? _latestRelease;
  bool _downloading = false;
  double _downloadProgress = 0;
  String _downloadStatus = '';
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _appVersion = info.version);
  }

  /// 检查更新
  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    final release = await _updateService.checkForUpdates();
    setState(() {
      _checking = false;
      _latestRelease = release;
    });
    if (!mounted) return;
    if (release == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已是最新版本')),
      );
    } else {
      _showUpdateDialog(release);
    }
  }

  void _showUpdateDialog(ReleaseInfo release) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('发现新版本 ${release.tagName}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(release.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(release.body.isEmpty ? '暂无更新说明' : release.body),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _downloadUpdate(release);
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  /// 下载更新（可挂后台）
  Future<void> _downloadUpdate(ReleaseInfo release) async {
    final asset = _updateService.matchAssetForPlatform(release.assets);
    if (asset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到当前平台的安装包')),
      );
      return;
    }

    setState(() {
      _downloading = true;
      _downloadProgress = 0;
      _downloadStatus = '准备下载...';
    });

    _cancelToken = CancelToken();
    final path = await _updateService.downloadUpdate(
      asset,
      cancelToken: _cancelToken,
      onProgress: (received, total) {
        if (total > 0) {
          setState(() {
            _downloadProgress = received / total;
            _downloadStatus =
                '下载中 ${(received / total * 100).toStringAsFixed(1)}%';
          });
        }
      },
    );

    if (!mounted) return;
    setState(() {
      _downloading = false;
      _downloadStatus = path != null ? '下载完成' : '下载失败';
    });

    if (path != null) {
      // 校验哈希
      final expectedHash =
          _updateService.parseHashFromBody(release.body, asset.name);
      if (expectedHash != null) {
        final valid =
            await _updateService.verifyUpdateIntegrity(path, expectedHash);
        if (!mounted) return;
        if (!valid) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件校验失败，可能已被篡改')),
          );
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已下载到: $path，请手动安装（后续版本将支持自动安装）')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MusicProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // 关于
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于 MelodyFlow'),
            subtitle: Text('版本 $_appVersion'),
            onTap: () => _showAboutDialog(),
          ),
          const Divider(),
          // 检查更新
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('检查更新'),
            subtitle: Text(_downloading ? _downloadStatus : '当前版本 $_appVersion'),
            trailing: _checking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _downloading ? null : _checkUpdate,
          ),
          if (_downloading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  LinearProgressIndicator(value: _downloadProgress),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_downloadStatus,
                          style: const TextStyle(fontSize: 12)),
                      TextButton(
                        onPressed: () {
                          _cancelToken?.cancel();
                          setState(() {
                            _downloading = false;
                            _downloadStatus = '已取消';
                          });
                        },
                        child: const Text('取消',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const Divider(),
          // 主题切换
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('深色模式'),
            value: provider.storage.isDarkMode(),
            onChanged: (v) {
              provider.storage.setDarkMode(v);
              setState(() {});
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.update),
            title: const Text('启动时自动检查更新'),
            value: provider.storage.isAutoUpdateCheck(),
            onChanged: (v) {
              provider.storage.setAutoUpdateCheck(v);
              setState(() {});
            },
          ),
          const Divider(),
          // 免责声明
          ListTile(
            leading: const Icon(Icons.gavel),
            title: const Text('免责声明'),
            onTap: () => _showDisclaimer(),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('开源许可'),
            onTap: () => showLicensePage(context: context),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'MelodyFlow',
      applicationVersion: _appVersion,
      applicationIcon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: AppTheme.gradient,
        ),
        child: const Icon(Icons.music_note, color: Colors.white, size: 36),
      ),
      applicationLegalese: '© 2025 MelodyFlow 开源项目',
      children: const [
        Text('开源跨平台音乐播放器，支持本地音乐扫描、第三方音源、在线歌词与封面。'),
      ],
    );
  }

  void _showDisclaimer() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
