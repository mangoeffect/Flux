import 'dart:convert';

enum VisitorType { stcp, xtcp, sudp }

/// stcp/xtcp/sudp 访问端([[visitors]])的类型化视图。
///
/// 持久化仍走 [Profile.visitors] 的原始 Map(未知字段原样保留不丢),
/// 本类只做 UI 编辑与 TOML 生成前的结构化。
class VisitorConfig {
  VisitorConfig({
    required this.name,
    this.type = VisitorType.stcp,
    this.serverName = '',
    this.secretKey = '',
    this.bindAddr = '127.0.0.1',
    this.bindPort = 0,
    Map<String, Object>? extra,
  }) : extra = extra ?? {};

  String name;
  VisitorType type;

  /// 要访问的服务端代理名(服务端 [[proxies]] 的 name)。
  String serverName;
  String secretKey;
  String bindAddr;
  int bindPort;

  /// 未知字段原样保留。
  Map<String, Object> extra;

  Map<String, Object> toMap() => {
        'name': name,
        'type': type.name,
        'serverName': serverName,
        'secretKey': secretKey,
        'bindAddr': bindAddr,
        'bindPort': bindPort,
        ...extra,
      };

  factory VisitorConfig.fromMap(Map<String, Object> map) {
    const known = {
      'name', 'type', 'serverName', 'secretKey', 'bindAddr', 'bindPort'
    };
    final extra = {...map}..removeWhere((k, v) => known.contains(k));
    return VisitorConfig(
      name: map['name'] as String? ?? '',
      type: VisitorType.values
          .where((t) => t.name == map['type'])
          .firstOrNull ?? VisitorType.stcp,
      serverName: map['serverName'] as String? ?? '',
      secretKey: map['secretKey'] as String? ?? '',
      bindAddr: map['bindAddr'] as String? ?? '127.0.0.1',
      bindPort: map['bindPort'] as int? ?? 0,
      extra: extra,
    );
  }

  VisitorConfig copy() => VisitorConfig.fromMap(
      jsonDecode(jsonEncode(toMap())) as Map<String, Object>);
}
