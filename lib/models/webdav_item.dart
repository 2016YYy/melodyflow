/// WebDAV 文件项
class WebdavItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int? size;

  const WebdavItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
  });
}
