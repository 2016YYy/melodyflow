import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'update_service.dart';

/// 更新下载控制器
/// 支持后台下载（关闭进度弹窗后继续），并暴露进度/结果状态
class UpdateDownloadController extends ChangeNotifier {
  final UpdateService _service = UpdateService();
  CancelToken? _cancelToken;

  /// 设置下载镜像源
  void setMirror(GithubMirror mirror) => _service.mirror = mirror;

  bool _downloading = false;
  double _progress = 0;
  String _status = '';
  String? _resultPath;
  String? _error;

  bool get downloading => _downloading;
  double get progress => _progress;
  String get status => _status;
  String? get resultPath => _resultPath;
  String? get error => _error;
  bool get cancelled => _cancelToken?.isCancelled ?? false;

  /// 开始下载更新包
  Future<void> start(ReleaseInfo release) async {
    final asset = _service.matchAssetForPlatform(release.assets);
    if (asset == null) {
      _error = '未找到当前平台的安装包';
      _status = '下载失败';
      notifyListeners();
      return;
    }

    _downloading = true;
    _progress = 0;
    _error = null;
    _resultPath = null;
    _status = '准备下载...';
    notifyListeners();

    _cancelToken = CancelToken();
    final path = await _service.downloadUpdate(
      asset,
      cancelToken: _cancelToken,
      onProgress: (received, total) {
        if (total > 0) {
          _progress = received / total;
          _status = '下载中 ${(_progress * 100).toStringAsFixed(1)}%';
          notifyListeners();
        }
      },
    );

    _downloading = false;

    if (path != null) {
      // SHA-256 完整性校验
      final expected = _service.parseHashFromBody(release.body, asset.name);
      if (expected != null) {
        final valid = await _service.verifyUpdateIntegrity(path, expected);
        if (!valid) {
          _error = '文件校验失败，可能已被篡改';
          _status = '校验失败';
          notifyListeners();
          return;
        }
      }
      _resultPath = path;
      _status = '下载完成';
    } else if (_cancelToken?.isCancelled ?? false) {
      _status = '已取消';
    } else {
      _error = '下载失败，请稍后重试';
      _status = '下载失败';
    }
    notifyListeners();
  }

  /// 取消 / 中断下载
  void cancel() {
    if (_downloading) {
      _cancelToken?.cancel();
    }
  }

  @override
  void dispose() {
    if (_downloading) {
      _cancelToken?.cancel();
    }
    super.dispose();
  }
}
