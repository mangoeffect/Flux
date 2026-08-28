import 'dart:convert';

import 'proxy_config.dart';

/// frpc Admin webServer 注入配置(127.0.0.1 + 随机端口/口令),持久化以便重启后端口不变。
class WebServerConfig {
  WebServerConfig({required this.port, required this.user, required this.password});

  int port;
  String user;
  String password;

  Map<String, dynamic> toJson() =>
      {'port': port, 'user': user, 'password': password};

  factory WebServerConfig.fromJson(Map<String, dynamic> json) => WebServerConfig(
        port: json['port'] as int,
        user: json['user'] as String,
        password: json['password'] as String,
      );
}

/// 一套 frpc 配置(服务器 + 代理列表),对应一个 TOML 文件。
class Profile {
  Profile({
    required this.id,
    required this.name,
    required this.serverAddr,
    this.serverPort = 7000,
    this.user,
    this.token,
    this.loginFailExit = false,
    this.dnsServer = const [],
    List<ProxyConfig>? proxies,
    Map<String, Object>? extraClient,
    List<Map<String, Object>>? visitors,
    this.adminWebServer,
    DateTime? createdAt,
  })  : proxies = proxies ?? [],
        extraClient = extraClient ?? {},
        visitors = visitors ?? [],
        createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;

  String serverAddr;
  int serverPort;

  /// frp 多用户名(顶层 user 字段)。
  String? user;

  /// auth.token。
  String? token;

  /// 网络未就绪时自动重试(Android/开机场景),默认 false。
  bool loginFailExit;

  List<String> dnsServer;

  List<ProxyConfig> proxies;

  /// 客户端高级字段(transport.*、auth.* 其余项等),结构化保留。
  Map<String, Object> extraClient;

  /// [[visitors]] 原样保留(导入回写不丢)。
  List<Map<String, Object>> visitors;

  /// Admin API 注入配置,为 null 时由 ConfigService 生成。
  WebServerConfig? adminWebServer;

  DateTime createdAt;

  List<ProxyConfig> get enabledProxies =>
      proxies.where((p) => p.enabled).toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'serverAddr': serverAddr,
        'serverPort': serverPort,
        'user': user,
        'token': token,
        'loginFailExit': loginFailExit,
        'dnsServer': dnsServer,
        'proxies': proxies.map((p) => p.toJson()).toList(),
        'extraClient': extraClient,
        'visitors': visitors,
        'adminWebServer': adminWebServer?.toJson(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        name: json['name'] as String,
        serverAddr: json['serverAddr'] as String? ?? '',
        serverPort: json['serverPort'] as int? ?? 7000,
        user: json['user'] as String?,
        token: json['token'] as String?,
        loginFailExit: json['loginFailExit'] as bool? ?? false,
        dnsServer: (json['dnsServer'] as List?)?.cast<String>() ?? const [],
        proxies: (json['proxies'] as List? ?? [])
            .map((e) => ProxyConfig.fromJson(e as Map<String, dynamic>))
            .toList(),
        extraClient: _castMap(json['extraClient'] as Map? ?? {}),
        visitors: (json['visitors'] as List? ?? [])
            .map((e) => _castMap(e as Map))
            .toList(),
        adminWebServer: json['adminWebServer'] == null
            ? null
            : WebServerConfig.fromJson(
                json['adminWebServer'] as Map<String, dynamic>),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  static Map<String, Object> _castMap(Map m) =>
      m.map((k, v) => MapEntry(k.toString(), v as Object));

  Profile copy() =>
      Profile.fromJson(jsonDecode(jsonEncode(toJson())) as Map<String, dynamic>);
}
