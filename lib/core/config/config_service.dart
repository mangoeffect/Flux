import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:toml/toml.dart';

import '../../model/profile.dart';
import '../../model/proxy_config.dart';
import '../security/token_store.dart';
import 'toml_encoder.dart';

/// frpc TOML 的生成与导入、Profile 的 JSON 持久化。
class ConfigService {
  ConfigService(this.appSupportDir);

  final Directory appSupportDir;

  Directory get _profilesDir =>
      Directory(p.join(appSupportDir.path, 'profiles'));

  // ------------------------------------------------ TOML 生成

  /// Profile → frpc.toml 文本。
  ///
  /// [injectAdmin] 为 true(运行时)恒定注入 [webServer](127.0.0.1 + 随机
  /// 端口/口令,持久化在 Profile 中),供 AdminApiService 做状态查询与热
  /// 重载;导出时传 false 生成干净配置。禁用的代理不生成。
  String profileToToml(Profile profile, {bool injectAdmin = true}) {
    WebServerConfig? admin;
    if (injectAdmin) admin = profile.adminWebServer ??= _newWebServer();
    final hasToken = profile.token != null && profile.token!.isNotEmpty;

    // auth 表:token + extraClient 中保留的其他 auth.* 字段合并,避免重复定义
    final extras = _normalizeExtras(profile.extraClient);
    final authExtras = extras.remove('auth');
    final auth = <String, Object?>{
      if (hasToken) 'method': 'token',
      if (hasToken) 'token': profile.token,
      if (authExtras is Map) ...authExtras.cast<String, Object>(),
    };

    final doc = <String, Object?>{
      'serverAddr': profile.serverAddr,
      'serverPort': profile.serverPort,
      if (profile.user != null && profile.user!.isNotEmpty)
        'user': profile.user,
      'loginFailExit': profile.loginFailExit,
      if (profile.dnsServer.isNotEmpty) 'dnsServer': profile.dnsServer,
      ...extras,
      if (auth.isNotEmpty) 'auth': auth,
      if (admin != null)
        'webServer': {
          'addr': '127.0.0.1',
          'port': admin.port,
          'user': admin.user,
          'password': admin.password,
        },
    };

    final buf = StringBuffer(encodeToml(doc));
    for (final proxy in profile.enabledProxies) {
      buf.writeln();
      buf.writeln('[[proxies]]');
      buf.write(encodeToml(_normalizeExtras(proxy.toTomlMap())));
    }
    for (final visitor in profile.visitors) {
      buf.writeln();
      buf.writeln('[[visitors]]');
      buf.write(encodeToml(_normalizeExtras(visitor)));
    }
    return buf.toString();
  }

  /// 写入指定 profile 的运行时配置文件,返回文件路径。
  File writeRuntimeConfig(Profile profile) {
    final dir = Directory(p.join(appSupportDir.path, 'runtime', profile.id));
    dir.createSync(recursive: true);
    final file = File(p.join(dir.path, 'frpc.toml'));
    file.writeAsStringSync(profileToToml(profile));
    return file;
  }

  /// 导出干净 TOML(不注入 admin webServer),可直接给 frpc 使用或再导入。
  String exportToml(Profile profile) =>
      profileToToml(profile, injectAdmin: false);

  // ------------------------------------------------ TOML 导入

  /// 解析 frpc.toml → 新 Profile;未知字段原样保留。
  Profile fromToml(String content, {required String name}) {
    final map = TomlDocument.parse(content).toMap();
    final client = _castMap(map);

    // webServer 属于注入配置,单独取出复用。
    WebServerConfig? admin;
    final ws = client.remove('webServer');
    if (ws is Map && ws['port'] != null) {
      admin = WebServerConfig(
        port: ws['port'] as int,
        user: ws['user']?.toString() ?? 'admin',
        password: ws['password']?.toString() ?? '',
      );
    }

    // auth 表拆出 token,其余保留。
    final auth = client.remove('auth');
    String? token;
    if (auth is Map) {
      token = auth.remove('token')?.toString();
      if (auth.isNotEmpty) client['auth'] = _castMap(auth);
    }

    final proxies = (client.remove('proxies') as List? ?? [])
        .whereType<Map>()
        .map((m) => ProxyConfig.fromTomlMap(_castMap(m)))
        .toList();

    final visitors = (client.remove('visitors') as List? ?? [])
        .whereType<Map>()
        .map(_castMap)
        .toList();

    return Profile(
      id: _newId(),
      name: name,
      serverAddr: client.remove('serverAddr')?.toString() ?? '',
      serverPort: client.remove('serverPort') as int? ?? 7000,
      user: client.remove('user')?.toString(),
      token: token,
      loginFailExit: client.remove('loginFailExit') as bool? ?? false,
      dnsServer: (client.remove('dnsServer') as List?)?.cast<String>() ?? const [],
      proxies: proxies,
      extraClient: client,
      visitors: visitors,
      adminWebServer: admin,
    );
  }

  // ------------------------------------------------ Profile 持久化(JSON)

  Future<List<Profile>> loadProfiles() async {
    if (!_profilesDir.existsSync()) return [];
    final files = _profilesDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final profiles = <Profile>[];
    for (final f in files) {
      try {
        final profile = profileFromJson(await f.readAsString());
        // token 在系统凭据库中,读回内存
        if (profile.tokenSecured && profile.token == null) {
          profile.token = await TokenStore.instance.read(profile.id);
        } else if (profile.token != null && profile.token!.isNotEmpty) {
          // 旧版明文:立即迁移到凭据库并重写 JSON
          await saveProfile(profile);
        }
        profiles.add(profile);
      } catch (_) {
        // 单个损坏文件跳过,不阻塞启动
      }
    }
    return profiles;
  }

  Future<void> saveProfile(Profile profile) async {
    // token 优先写入系统凭据库;不可用时降级明文 JSON
    profile.tokenSecured =
        await TokenStore.instance.write(profile.id, profile.token);
    await _profilesDir.create(recursive: true);
    final file = File(p.join(_profilesDir.path, '${profile.id}.json'));
    await file.writeAsString(profileToJson(profile));
  }

  Future<void> deleteProfile(String id) async {
    await TokenStore.instance.delete(id);
    final file = File(p.join(_profilesDir.path, '$id.json'));
    if (await file.exists()) await file.delete();
    final runtime = Directory(p.join(appSupportDir.path, 'runtime', id));
    if (await runtime.exists()) await runtime.delete(recursive: true);
  }

  String profileToJson(Profile profile) =>
      const JsonEncoder.withIndent('  ').convert(profile.toJson());

  Profile profileFromJson(String json) =>
      Profile.fromJson(Map<String, dynamic>.from(jsonDecode(json) as Map));

  // ------------------------------------------------ utils

  /// 展平点号键(如 "auth.token")为嵌套结构,交给 encoder 统一处理。
  Map<String, Object> _normalizeExtras(Map<String, Object> extra) {
    final out = <String, Object>{};
    for (final e in extra.entries) {
      final parts = e.key.split('.');
      Map<String, Object> cur = out;
      for (var i = 0; i < parts.length - 1; i++) {
        cur = cur.putIfAbsent(parts[i], () => <String, Object>{})
            as Map<String, Object>;
      }
      cur[parts.last] = e.value;
    }
    return out;
  }

  WebServerConfig _newWebServer() {
    final rng = DateTime.now().microsecondsSinceEpoch;
    return WebServerConfig(
      port: 20000 + rng % 20000,
      user: 'flux',
      password: _randomToken(),
    );
  }

  static String _randomToken() {
    final seed = DateTime.now().microsecondsSinceEpoch ^ pid.hashCode;
    return (seed.toRadixString(36) + DateTime.now().millisecond.toRadixString(36))
        .padRight(16, 'x');
  }

  static String _newId() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36);

  static Map<String, Object> _castMap(Map m) =>
      m.map((k, v) => MapEntry(k.toString(), v as Object));
}
