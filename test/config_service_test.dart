import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core/config/config_service.dart';
import 'package:flux/model/profile.dart';
import 'package:flux/model/proxy_config.dart';
import 'package:flux/model/visitor_config.dart';
import 'package:toml/toml.dart';

const sampleToml = '''
serverAddr = "frps.example.com"
serverPort = 7000
user = "alice"
loginFailExit = false

auth.method = "token"
auth.token = "secret-token"

transport.tlsEnable = true

[webServer]
addr = "127.0.0.1"
port = 7400
user = "admin"
password = "admin123"

[[proxies]]
name = "ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = 6000
transport.useEncryption = true

[[proxies]]
name = "web"
type = "http"
localPort = 8080
subdomain = "mydev"
customDomains = ["a.example.com", "b.example.com"]

[proxies.basicAuth]
user = "u1"
password = "p1"

[[visitors]]
name = "ssh-v"
type = "stcp"
serverName = "ssh"
secretKey = "abc"
bindAddr = "127.0.0.1"
bindPort = 6000
''';

void main() {
  final service = ConfigService(Directory.systemTemp);

  test('Profile 生成合法 TOML 且含注入的 webServer', () {
    final profile = Profile(
      id: 't1',
      name: 'test',
      serverAddr: '1.2.3.4',
      token: 'tk',
      proxies: [
        ProxyConfig(name: 'ssh', type: ProxyType.tcp, localPort: 22, remotePort: 6000),
        ProxyConfig(
          name: 'off',
          type: ProxyType.tcp,
          localPort: 80,
          enabled: false,
        ),
        ProxyConfig(
          name: 'web',
          type: ProxyType.http,
          localPort: 8080,
          subdomain: 'dev',
          basicAuthUser: 'u',
          basicAuthPassword: 'p',
          extra: {'transport': {'useCompression': true}},
        ),
      ],
    );
    final tomlText = service.profileToToml(profile);
    // 生成的文本必须能被标准 TOML 解析器重新解析
    final map = TomlDocument.parse(tomlText).toMap();

    expect(map['serverAddr'], '1.2.3.4');
    expect(map['auth'], {'method': 'token', 'token': 'tk'});
    expect(map['webServer']['addr'], '127.0.0.1');
    expect(map['webServer']['port'], isA<int>());
    expect((map['webServer']['password'] as String).length, greaterThanOrEqualTo(8));
    final proxies = map['proxies'] as List;
    expect(proxies.length, 2, reason: '禁用的代理不应生成');
    expect(proxies.first['remotePort'], 6000);
    final web = proxies.last as Map;
    expect(web['basicAuth'], {'user': 'u', 'password': 'p'});
    expect(web['transport'], {'useCompression': true});

    // adminWebServer 已生成并持久化在 profile 上
    expect(profile.adminWebServer, isNotNull);
    expect(profile.adminWebServer!.port, map['webServer']['port']);
  });

  test('导入官方风格 frpc.toml:常用字段解析、高级字段保留', () {
    final profile = service.fromToml(sampleToml, name: 'imported');
    expect(profile.serverAddr, 'frps.example.com');
    expect(profile.serverPort, 7000);
    expect(profile.user, 'alice');
    expect(profile.token, 'secret-token');
    expect(profile.loginFailExit, false);
    expect(profile.extraClient['transport'], {'tlsEnable': true});

    expect(profile.proxies.length, 2);
    final ssh = profile.proxies[0];
    expect(ssh.name, 'ssh');
    expect(ssh.type, ProxyType.tcp);
    expect(ssh.localPort, 22);
    expect(ssh.remotePort, 6000);
    expect(ssh.extra['transport'], {'useEncryption': true});

    final web = profile.proxies[1];
    expect(web.customDomains, ['a.example.com', 'b.example.com']);
    expect(web.subdomain, 'mydev');
    expect(web.basicAuthUser, 'u1');

    expect(profile.visitors.length, 1);
    expect(profile.visitors.first['name'], 'ssh-v');

    // 原 webServer 复用为注入配置
    expect(profile.adminWebServer?.port, 7400);
    expect(profile.adminWebServer?.password, 'admin123');
  });

  test('导入 → 生成 往返:字段不丢失', () {
    final imported = service.fromToml(sampleToml, name: 'rt');
    final regenerated = service.profileToToml(imported);
    final map = TomlDocument.parse(regenerated).toMap();

    expect(map['serverAddr'], 'frps.example.com');
    expect(map['auth'], {'method': 'token', 'token': 'secret-token'});
    expect(map['transport'], {'tlsEnable': true});
    expect(map['user'], 'alice');
    final proxies = map['proxies'] as List;
    expect(proxies.length, 2);
    expect((proxies[0] as Map)['transport'], {'useEncryption': true});
    expect((proxies[1] as Map)['basicAuth'], {'user': 'u1', 'password': 'p1'});
    final visitors = map['visitors'] as List;
    expect(visitors.length, 1);
    // webServer 端口保持导入值(复用)
    expect((map['webServer'] as Map)['port'], 7400);
  });

  test('ProxyConfig JSON 序列化往返', () {
    final p = ProxyConfig(
      name: 'x',
      type: ProxyType.stcp,
      localPort: 1,
      secretKey: 'k',
      extra: {'a': 1, 'nested': {'b': true}},
    );
    final restored = ProxyConfig.fromJson(
        Map<String, dynamic>.from(p.toJson() as Map));
    expect(restored.type, ProxyType.stcp);
    expect(restored.secretKey, 'k');
    expect(restored.extra['nested'], {'b': true});
  });

  test('VisitorConfig 编辑往返:typed → TOML → 解析一致,未知字段保留', () {
    final profile = Profile(id: 'v1', name: 'v', serverAddr: '1.2.3.4');
    profile.visitors.add(VisitorConfig(
      name: 'visit-ssh',
      type: VisitorType.stcp,
      serverName: 'ssh',
      secretKey: 'sk',
      bindPort: 6000,
      extra: {'keepTunnelOpen': true},
    ).toMap());

    final tomlText = service.profileToToml(profile);
    final back = service.fromToml(tomlText, name: 'back');
    expect(back.visitors.length, 1);
    final v = VisitorConfig.fromMap(back.visitors.single);
    expect(v.name, 'visit-ssh');
    expect(v.type, VisitorType.stcp);
    expect(v.serverName, 'ssh');
    expect(v.secretKey, 'sk');
    expect(v.bindPort, 6000);
    expect(v.extra['keepTunnelOpen'], true);
  });

  test('exportToml 不注入 webServer', () {
    final profile = Profile(id: 'e1', name: 'e', serverAddr: '1.2.3.4');
    final exported = service.exportToml(profile);
    final map = TomlDocument.parse(exported).toMap();
    expect(map.containsKey('webServer'), isFalse);
    // 导出文件可再次导入
    final back = service.fromToml(exported, name: 'back');
    expect(back.serverAddr, '1.2.3.4');
  });

  Map<String, dynamic> proxyTomlOf(ProxyConfig p) {
    final tomlText = service.profileToToml(Profile(
        id: 'p', name: 'p', serverAddr: '1.2.3.4', proxies: [p]));
    final proxies = TomlDocument.parse(tomlText).toMap()['proxies'] as List;
    return proxies.single as Map<String, dynamic>;
  }

  test('七种代理类型 TOML 字段生成:必需字段在,无关字段不出现', () {
    // tcp/udp:必须带 remotePort,不带 secretKey
    final tcp = proxyTomlOf(ProxyConfig(
        name: 'p', type: ProxyType.tcp, localPort: 80, remotePort: 8080));
    expect(tcp['remotePort'], 8080);
    expect(tcp.containsKey('secretKey'), isFalse);
    expect(proxyTomlOf(ProxyConfig(
            name: 'p', type: ProxyType.udp, localPort: 53, remotePort: 8053))[
        'remotePort'], 8053);

    // http/https:域名路由字段透传,不接受 remotePort
    final http = proxyTomlOf(ProxyConfig(
        name: 'p',
        type: ProxyType.http,
        localPort: 80,
        subdomain: 'dev',
        customDomains: ['a.example.com'],
        locations: ['/api']));
    expect(http['subdomain'], 'dev');
    expect(http['customDomains'], ['a.example.com']);
    expect(http['locations'], ['/api']);
    expect(http.containsKey('remotePort'), isFalse);
    final https = proxyTomlOf(ProxyConfig(
        name: 'p',
        type: ProxyType.https,
        localPort: 443,
        customDomains: ['s.example.com']));
    expect(https['customDomains'], ['s.example.com']);

    // stcp/xtcp/sudp:secret 型代理,带 secretKey,不带 remotePort(frp 0.71 拒绝)
    final stcp = proxyTomlOf(ProxyConfig(
        name: 'p', type: ProxyType.stcp, localPort: 22, secretKey: 'sk'));
    expect(stcp['secretKey'], 'sk');
    expect(stcp.containsKey('remotePort'), isFalse);
    final xtcp = proxyTomlOf(ProxyConfig(
        name: 'p', type: ProxyType.xtcp, localPort: 22, secretKey: 'sk'));
    expect(xtcp['secretKey'], 'sk');
    expect(xtcp.containsKey('remotePort'), isFalse);
    final sudp = proxyTomlOf(ProxyConfig(
        name: 'p', type: ProxyType.sudp, localPort: 53, secretKey: 'sk'));
    expect(sudp['secretKey'], 'sk');
    expect(sudp.containsKey('remotePort'), isFalse);
  });

  test('三种访问端 TOML 输出:serverName/secretKey/bindAddr/bindPort', () {
    for (final vtype in [VisitorType.stcp, VisitorType.xtcp, VisitorType.sudp]) {
      final profile = Profile(id: 'v', name: 'v', serverAddr: '1.2.3.4');
      profile.visitors.add(VisitorConfig(
        name: 'v-${vtype.name}',
        type: vtype,
        serverName: 'svc',
        secretKey: 'sk',
        bindAddr: '127.0.0.1',
        bindPort: 6100,
      ).toMap());

      final map = TomlDocument.parse(service.profileToToml(profile)).toMap();
      final visitors = map['visitors'] as List;
      expect(visitors.length, 1, reason: 'visitor 类型 ${vtype.name}');
      final v = visitors.single as Map;
      expect(v['name'], 'v-${vtype.name}');
      expect(v['type'], vtype.name);
      expect(v['serverName'], 'svc');
      expect(v['secretKey'], 'sk');
      expect(v['bindAddr'], '127.0.0.1');
      expect(v['bindPort'], 6100);
    }
  });
}
