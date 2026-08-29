import 'dart:convert';

/// frpc 支持的代理类型。
enum ProxyType {
  tcp,
  udp,
  http,
  https,
  stcp,
  xtcp,
  sudp;

  String get label => name;

  static ProxyType parse(String s) =>
      ProxyType.values.firstWhere((t) => t.name == s, orElse: () => ProxyType.tcp);
}

/// 单条代理配置。
///
/// 常用字段强类型化;其余高级字段(transport.*、plugin.*、healthCheck 等)
/// 原样保存在 [extra] 中,生成 TOML 时按点号键写回,保证导入/导出不丢字段。
class ProxyConfig {
  ProxyConfig({
    required this.name,
    required this.type,
    this.localIp = '127.0.0.1',
    required this.localPort,
    this.remotePort,
    this.customDomains = const [],
    this.subdomain,
    this.locations = const [],
    this.basicAuthUser,
    this.basicAuthPassword,
    this.secretKey,
    this.serverName,
    this.enabled = true,
    Map<String, Object>? extra,
  }) : extra = extra ?? {};

  String name;
  ProxyType type;

  /// 本地服务地址与端口。
  String localIp;
  int localPort;

  /// 远端端口(tcp/udp/sudp)。
  int? remotePort;

  /// http/https 自定义域名。
  List<String> customDomains;
  String? subdomain;

  /// http 路由 location。
  List<String> locations;

  String? basicAuthUser;
  String? basicAuthPassword;

  /// stcp/xtcp/sudp 共享密钥。
  String? secretKey;

  /// https TLS SNI。
  String? serverName;

  /// 本地概念:frp 无此字段,生成配置时跳过禁用的代理。
  bool enabled;

  /// 其余高级字段,结构化保留。
  Map<String, Object> extra;

  // frp 0.71: tcp/udp 用 remotePort;stcp/xtcp/sudp 为 secret 型代理,不接受 remotePort
  bool get needsRemotePort =>
      type == ProxyType.tcp || type == ProxyType.udp;
  bool get needsDomain =>
      type == ProxyType.http || type == ProxyType.https;
  bool get needsSecretKey =>
      type == ProxyType.stcp || type == ProxyType.xtcp || type == ProxyType.sudp;

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        'localIp': localIp,
        'localPort': localPort,
        'remotePort': remotePort,
        'customDomains': customDomains,
        'subdomain': subdomain,
        'locations': locations,
        'basicAuthUser': basicAuthUser,
        'basicAuthPassword': basicAuthPassword,
        'secretKey': secretKey,
        'serverName': serverName,
        'enabled': enabled,
        'extra': extra,
      };

  factory ProxyConfig.fromJson(Map<String, dynamic> json) => ProxyConfig(
        name: json['name'] as String,
        type: ProxyType.parse(json['type'] as String? ?? 'tcp'),
        localIp: json['localIp'] as String? ?? '127.0.0.1',
        localPort: json['localPort'] as int? ?? 0,
        remotePort: json['remotePort'] as int?,
        customDomains:
            (json['customDomains'] as List?)?.cast<String>() ?? const [],
        subdomain: json['subdomain'] as String?,
        locations: (json['locations'] as List?)?.cast<String>() ?? const [],
        basicAuthUser: json['basicAuthUser'] as String?,
        basicAuthPassword: json['basicAuthPassword'] as String?,
        secretKey: json['secretKey'] as String?,
        serverName: json['serverName'] as String?,
        enabled: json['enabled'] as bool? ?? true,
        extra: _castMap(json['extra'] as Map? ?? {}),
      );

  /// 从 TOML 解析得到的 map(单个 [[proxies]] 表)构造。
  factory ProxyConfig.fromTomlMap(Map<String, dynamic> map) {
    final extra = _castMap(map);
    int? remotePort;
    if (extra.containsKey('remotePort')) {
      remotePort = extra.remove('remotePort') as int?;
    }
    final p = ProxyConfig(
      name: extra.remove('name') as String? ?? 'unnamed',
      type: ProxyType.parse(extra.remove('type') as String? ?? 'tcp'),
      localIp: extra.remove('localIP') as String? ?? '127.0.0.1',
      localPort: extra.remove('localPort') as int? ?? 0,
      remotePort: remotePort,
      extra: extra,
    );
    final domains = extra.remove('customDomains');
    if (domains is List) p.customDomains = domains.cast<String>().toList();
    p.subdomain = extra.remove('subdomain') as String?;
    final locations = extra.remove('locations');
    if (locations is List) p.locations = locations.cast<String>().toList();
    p.secretKey = extra.remove('secretKey') as String?;
    p.serverName = extra.remove('serverName') as String?;
    final basicAuth = extra.remove('basicAuth');
    if (basicAuth is Map) {
      p.basicAuthUser = basicAuth.remove('user') as String?;
      p.basicAuthPassword = basicAuth.remove('password') as String?;
      if (basicAuth.isNotEmpty) extra['basicAuth'] = _castMap(basicAuth);
    }
    return p;
  }

  /// 生成单个 [[proxies]] 表的键值(标量在前,嵌套表在后)。
  Map<String, Object> toTomlMap() => {
        'name': name,
        'type': type.name,
        'localIP': localIp,
        'localPort': localPort,
        if (remotePort != null) 'remotePort': ?remotePort,
        if (customDomains.isNotEmpty) 'customDomains': customDomains,
        if (subdomain != null && subdomain!.isNotEmpty) 'subdomain': ?subdomain,
        if (locations.isNotEmpty) 'locations': locations,
        if (secretKey != null && secretKey!.isNotEmpty) 'secretKey': ?secretKey,
        if (serverName != null && serverName!.isNotEmpty)
          'serverName': ?serverName,
        ...extra,
        if (basicAuthUser != null || basicAuthPassword != null)
          'basicAuth': {
            if (basicAuthUser != null) 'user': ?basicAuthUser,
            if (basicAuthPassword != null) 'password': ?basicAuthPassword,
          },
      };

  ProxyConfig copy() =>
      ProxyConfig.fromJson(jsonDecode(jsonEncode(toJson())) as Map<String, dynamic>);

  static Map<String, Object> _castMap(Map m) =>
      m.map((k, v) => MapEntry(k.toString(), v as Object));
}
