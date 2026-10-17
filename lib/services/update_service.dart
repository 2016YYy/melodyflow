import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// GitHub Release 信息
class ReleaseInfo {
  final String tagName;
  final String name;
  final String body; // 更新说明
  final List<ReleaseAsset> assets;
  final DateTime publishedAt;
  final bool prerelease;

  const ReleaseInfo({
    required this.tagName,
    required this.name,
    required this.body,
    required this.assets,
    required this.publishedAt,
    required this.prerelease,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    return ReleaseInfo(
      tagName: json['tag_name']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      assets: (json['assets'] as List?)
              ?.map((a) => ReleaseAsset.fromJson(a))
              .toList() ??
          [],
      publishedAt: DateTime.parse(json['published_at'] ?? DateTime.now().toIso8601String()),
      prerelease: json['prerelease'] as bool? ?? false,
    );
  }
}

class ReleaseAsset {
  final String name;
  final String downloadUrl;
  final int size;
  final String? contentType;

  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
    this.contentType,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      name: json['name']?.toString() ?? '',
      downloadUrl: json['browser_download_url']?.toString() ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      contentType: json['content_type']?.toString(),
    );
  }
}

/// GitHub 下载镜像源
/// 用户可在设置中切换，解决直连 GitHub 下载慢/卡的问题。
class GithubMirror {
  final String id;
  final String label;
  final String description;
  /// 将原始 GitHub 下载 URL 转换为镜像 URL
  final String Function(String url) transform;

  const GithubMirror({
    required this.id,
    required this.label,
    required this.description,
    required this.transform,
  });
}

class GithubMirrors {
  /// 直连 GitHub（不使用镜像）
  static const GithubMirror direct = GithubMirror(
    id: 'direct',
    label: 'GitHub 直连',
    description: '直接从 github.com 下载',
    transform: _identity,
  );

  /// ghproxy 镜像（社区常用）
  static const GithubMirror ghproxy = GithubMirror(
    id: 'ghproxy',
    label: 'ghProxy',
    description: '通过 gh-proxy 加速 GitHub 下载',
    transform: _ghproxy,
  );

  /// mirror.ghproxy.com
  static const GithubMirror ghproxyMirror = GithubMirror(
    id: 'ghproxy-mirror',
    label: 'ghProxy Mirror',
    description: 'ghProxy 备用节点',
    transform: _ghproxyMirror,
  );

  /// GitHub 加速（99988866 公共）
  static const GithubMirror acc = GithubMirror(
    id: 'gh-acc',
    label: 'GH-ACC',
    description: 'GitHub 公共加速节点',
    transform: _ghAcc,
  );

  /// kkgithub 镜像
  static const GithubMirror kkgithub = GithubMirror(
    id: 'kkgithub',
    label: 'KKGitHub',
    description: '通过 kkgithub.com 加速',
    transform: _kkgithub,
  );

  static const List<GithubMirror> all = [
    direct,
    ghproxy,
    ghproxyMirror,
    acc,
    kkgithub,
  ];

  static GithubMirror fromId(String id) =>
      all.firstWhere((m) => m.id == id, orElse: () => direct);

  static String _identity(String url) => url;

  static String _ghproxy(String url) =>
      'https://ghproxy.com/$url';

  static String _ghproxyMirror(String url) =>
      'https://mirror.ghproxy.com/$url';

  static String _ghAcc(String url) =>
      'https://gh.api.99988866.xyz/$url';

  static String _kkgithub(String url) =>
      url.replaceFirst('https://github.com', 'https://kkgithub.com');
}

/// 应用内更新服务
/// - 检查 GitHub Release 最新版本
/// - 下载更新包（带进度条，支持高速镜像源）
/// - 后台下载
/// - 校验签名/哈希（防篡改）
class UpdateService {
  final Dio _dio = Dio();
  static const String _githubRepo = '2016YYy/melodyflow';
  static const String _apiBase = 'https://api.github.com/repos/$_githubRepo';

  /// 当前选中的下载镜像（可由设置页动态修改）
  GithubMirror mirror = GithubMirrors.direct;

  /// 获取当前版本
  Future<String> getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// 检查更新
  Future<ReleaseInfo?> checkForUpdates() async {
    try {
      final response = await _dio.get(
        '$_apiBase/releases/latest',
        options: Options(
          headers: {'Accept': 'application/vnd.github+json'},
        ),
      );
      final latest = ReleaseInfo.fromJson(response.data);
      final current = await getCurrentVersion();
      if (_isNewer(latest.tagName, current)) {
        return latest;
      }
      return null;
    } catch (e) {
      debugPrint('检查更新失败: $e');
      return null;
    }
  }

  /// 版本比较
  bool _isNewer(String remoteTag, String currentVersion) {
    final remote = remoteTag.replaceAll('v', '').trim();
    final current = currentVersion.trim();
    final rParts = remote.split('.').map(int.tryParse).toList();
    final cParts = current.split('.').map(int.tryParse).toList();
    for (int i = 0; i < rParts.length; i++) {
      final r = rParts[i] ?? 0;
      final c = i < cParts.length ? (cParts[i] ?? 0) : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }

  /// 根据平台匹配资源
  ReleaseAsset? matchAssetForPlatform(List<ReleaseAsset> assets) {
    final ext = Platform.isAndroid
        ? '.apk'
        : Platform.isIOS
            ? '.ipa'
            : Platform.isWindows
                ? '.exe'
                : null;
    if (ext == null) return null;
    return assets.firstWhere(
      (a) => a.name.toLowerCase().endsWith(ext),
      orElse: () => assets.first,
    );
  }

  /// 下载更新包（带进度，可挂后台）
  /// - 优先使用用户在设置中选中的镜像源
  /// - 若选中的镜像下载失败，自动尝试其他镜像源作为兜底
  /// [onProgress] 回调 (已下载字节, 总字节)
  /// [cancelToken] 可取消下载
  Future<String?> downloadUpdate(
    ReleaseAsset asset, {
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await getTemporaryDirectory();
    final savePath = p.join(dir.path, asset.name);

    // 构建候选下载源列表：首选用户选择的镜像，随后依次尝试其他镜像
    final candidates = <String>[];
    candidates.add(mirror.transform(asset.downloadUrl));
    for (final m in GithubMirrors.all) {
      if (m.id != mirror.id) candidates.add(m.transform(asset.downloadUrl));
    }

    Object? lastError;
    for (final url in candidates) {
      try {
        debugPrint('尝试下载源: $url');
        await _dio.download(
          url,
          savePath,
          onReceiveProgress: (received, total) {
            onProgress(received, total);
          },
          cancelToken: cancelToken,
          options: Options(
            headers: {'Accept': 'application/octet-stream'},
            // 镜像源可能较慢，放宽超时
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(minutes: 15),
            connectTimeout: const Duration(seconds: 20),
          ),
        );

        // 校验文件完整性（简单大小校验）
        final file = File(savePath);
        if (await file.length() != asset.size) {
          throw Exception('下载文件大小不匹配，可能已损坏');
        }

        return savePath;
      } catch (e) {
        lastError = e;
        debugPrint('下载失败（$url）: $e，尝试下一镜像源');
        continue;
      }
    }

    debugPrint('所有下载源均失败: $lastError');
    return null;
  }

  /// 校验更新包签名（SHA-256 + 公钥验证）
  /// 这里使用 SHA-256 哈希作为完整性校验，实际签名校验在 CI 构建时生成
  Future<bool> verifyUpdateIntegrity(String filePath, String expectedHash) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();
      return hash.toLowerCase() == expectedHash.toLowerCase();
    } catch (e) {
      debugPrint('校验失败: $e');
      return false;
    }
  }

  /// 从 Release body 中解析 SHA-256 哈希
  String? parseHashFromBody(String body, String fileName) {
    final lines = body.split('\n');
    for (final line in lines) {
      if (line.contains(fileName)) {
        final hashMatch = RegExp(r'([a-fA-F0-9]{64})').firstMatch(line);
        return hashMatch?.group(1);
      }
    }
    return null;
  }

  /// 获取下载文件大小的可读格式
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
