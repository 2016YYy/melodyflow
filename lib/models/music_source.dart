import 'song.dart';

/// 第三方音乐源配置
class MusicSource {
  final String id;
  final String name;
  final MusicSourceType type;
  final String url; // 服务器地址
  final String? username;
  final String? password;
  final String? token; // 认证token
  final Map<String, String> headers; // 自定义请求头
  final bool enabled;
  final int priority; // 优先级

  const MusicSource({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
    this.username,
    this.password,
    this.token,
    this.headers = const {},
    this.enabled = true,
    this.priority = 0,
  });

  factory MusicSource.fromMap(Map<String, dynamic> map) {
    return MusicSource(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      type: MusicSourceType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MusicSourceType.network,
      ),
      url: map['url']?.toString() ?? '',
      username: map['username']?.toString(),
      password: map['password']?.toString(),
      token: map['token']?.toString(),
      headers: Map<String, String>.from(map['headers'] ?? {}),
      enabled: map['enabled'] as bool? ?? true,
      priority: (map['priority'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'url': url,
      'username': username,
      'password': password,
      'token': token,
      'headers': headers,
      'enabled': enabled,
      'priority': priority,
    };
  }

  MusicSource copyWith({
    String? name,
    MusicSourceType? type,
    String? url,
    String? username,
    String? password,
    String? token,
    Map<String, String>? headers,
    bool? enabled,
    int? priority,
  }) {
    return MusicSource(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      url: url ?? this.url,
      username: username ?? this.username,
      password: password ?? this.password,
      token: token ?? this.token,
      headers: headers ?? this.headers,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
    );
  }
}
