@Timeout(Duration(minutes: 3))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flux/model/profile.dart';
import 'package:flux/model/proxy_config.dart';
import 'package:flux/model/visitor_config.dart';

import 'e2e_helpers.dart';

/// 多协议端到端验收:tcp 已由 e2e_frpc_test.dart 覆盖,
/// 这里用真实 frps + frpc 逐协议验证 udp/http/https/stcp/sudp/xtcp。
/// 端口整体错开另一 e2e 文件(17999/16999/16998/18888),两文件可并发运行。
void main() {
  final frpsBin = e2eBinary('frps');
  final frpcBin = e2eBinary('frpc');
  final binariesReady = frpsBin != null && frpcBin != null;
  final skipReason = binariesReady ? false : '未下载 frp 二进制(.e2e/)';

  const frpsPort = 18099;
  const vhostHttpPort = 18080;
  const vhostHttpsPort = 18443; // 仅注册验证,不做 TLS 穿透
  const tcpEchoPort = 19011;
  const udpEchoPort = 19001; // udp 代理背后
  const udpEchoPort2 = 19021; // sudp 代理背后
  const httpLocalPort = 19081;
  const stcpVisitorPort = 19012;
  const xtcpVisitorPort = 19013;
  const sudpVisitorPort = 19022;

  final workDir = Directory.systemTemp.createTempSync('flux_e2e_proto_');
  Process? frps;
  final frpsLogs = <String>[];
  final cleaners = <Future<void> Function()>[];

  setUpAll(() async {
    if (!binariesReady) return;
    final config = File('${workDir.path}${Platform.pathSeparator}frps.toml')
      ..writeAsStringSync('''
bindAddr = "127.0.0.1"
bindPort = $frpsPort
vhostHTTPPort = $vhostHttpPort
vhostHTTPSPort = $vhostHttpsPort
auth.token = "e2e-token"
''');
    frps = await Process.start(frpsBin.path, ['-c', config.path]);
    frps!.stdout.transform(systemEncoding.decoder).transform(const LineSplitter()).listen(frpsLogs.add);
    frps!.stderr.transform(systemEncoding.decoder).transform(const LineSplitter()).listen(frpsLogs.add);
    await waitForPort('127.0.0.1', frpsPort);

    // TCP echo(19011)
    final tcpEcho = await ServerSocket.bind('127.0.0.1', tcpEchoPort);
    tcpEcho.listen((socket) => socket.listen((data) => socket.add(data),
        onDone: () => socket.destroy()));
    cleaners.add(tcpEcho.close);

    // UDP echo(19001 / 19021)
    Future<void> udpEcho(int port) async {
      final sock = await RawDatagramSocket.bind('127.0.0.1', port);
      sock.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = sock.receive();
          if (dg != null) sock.send(dg.data, dg.address, dg.port);
        }
      });
      cleaners.add(() async => sock.close());
    }

    await udpEcho(udpEchoPort);
    await udpEcho(udpEchoPort2);

    // HTTP 服务(19081),固定 marker 响应
    final httpServer = await HttpServer.bind('127.0.0.1', httpLocalPort);
    httpServer.listen((req) async {
      req.response.write('flux-e2e-http-marker');
      await req.response.close();
    });
    cleaners.add(httpServer.close);
  });

  tearDownAll(() async {
    for (final c in cleaners) {
      try {
        await c();
      } catch (_) {}
    }
    frps?.kill();
    try {
      await workDir.delete(recursive: true);
    } catch (_) {}
  });

  Profile buildProfile({
    List<ProxyConfig> proxies = const [],
    List<VisitorConfig> visitors = const [],
  }) =>
      Profile(
        id: 'e2e-proto',
        name: 'e2e-proto',
        serverAddr: '127.0.0.1',
        serverPort: frpsPort,
        token: 'e2e-token',
        proxies: proxies,
        visitors: [for (final v in visitors) v.toMap()],
      );

  /// 发送 UDP 数据报并等待内容一致的回包(事件驱动,超时返回 null)。
  /// frp 的 UDP 代理首包可能因按需建 workConn 而丢失,故周期性重发。
  /// 注意:RawDatagramSocket 必须以事件驱动方式收包,纯轮询 receive() 收不到。
  Future<Datagram?> sendAndWaitReply(
      RawDatagramSocket sock, List<int> data, InternetAddress addr, int port,
      {Duration timeout = const Duration(seconds: 10)}) async {
    final done = Completer<Datagram?>();
    late final StreamSubscription<RawSocketEvent> sub;
    sub = sock.listen((event) {
      if (event != RawSocketEvent.read || done.isCompleted) return;
      final dg = sock.receive();
      if (dg != null && List<int>.from(dg.data).join(',') == data.join(',')) {
        done.complete(dg);
      }
    });
    final resend = Timer.periodic(
        const Duration(milliseconds: 500), (_) => sock.send(data, addr, port));
    sock.send(data, addr, port);
    final dg = await done.future.timeout(timeout, onTimeout: () => null);
    resend.cancel();
    await sub.cancel();
    return dg;
  }

  test('udp 代理:数据报穿透', skip: skipReason, () async {
    final inst = await startFrpc(
      buildProfile(proxies: [
        ProxyConfig(
            name: 'e2e-udp',
            type: ProxyType.udp,
            localPort: udpEchoPort,
            remotePort: 19002),
      ]),
      frpcPath: frpcBin!.path,
    );
    addTearDown(inst.dispose);

    await waitForProxies(inst.admin,
        until: (s) => s.any((e) => e.name == 'e2e-udp' && e.isRunning));

    final sock = await RawDatagramSocket.bind('127.0.0.1', 0);
    addTearDown(sock.close);
    final dg = await sendAndWaitReply(
        sock, utf8.encode('ping-udp'), InternetAddress.loopbackIPv4, 19002);
    expect(dg, isNotNull,
        reason: 'UDP 数据报应穿透返回\n--frpc--\n${inst.frpc.logs.join('\n')}\n--frps--\n${frpsLogs.join('\n')}');
    expect(utf8.decode(dg!.data), 'ping-udp');
  });

  test('http 代理:vhost 路由穿透', skip: skipReason, () async {
    final inst = await startFrpc(
      buildProfile(proxies: [
        ProxyConfig(
            name: 'e2e-http',
            type: ProxyType.http,
            localPort: httpLocalPort,
            customDomains: ['e2e.test.local']),
      ]),
      frpcPath: frpcBin!.path,
    );
    addTearDown(inst.dispose);

    await waitForProxies(inst.admin,
        until: (s) => s.any((e) => e.name == 'e2e-http' && e.isRunning));

    // frps vhostHTTPPort 按 Host 头路由(customDomains 精确匹配)
    final sock = await Socket.connect('127.0.0.1', vhostHttpPort,
        timeout: const Duration(seconds: 10));
    sock.add(utf8.encode('GET / HTTP/1.1\r\n'
        'Host: e2e.test.local\r\n'
        'Connection: close\r\n\r\n'));
    final body = await utf8.decoder
        .bind(sock)
        .join()
        .timeout(const Duration(seconds: 10), onTimeout: () => '');
    expect(body, contains('200'),
        reason: '应返回 200\n--frpc--\n${inst.frpc.logs.join('\n')}\n--frps--\n${frpsLogs.join('\n')}');
    expect(body, contains('flux-e2e-http-marker'),
        reason: '响应体应来自本地 HTTP 服务');
  });

  test('https 代理:注册为 running', skip: skipReason, () async {
    // frps 的 https vhost 仅按 SNI 路由转发 TLS 流,本地需真证书才能断言内容;
    // 这里验证配置生成与代理注册正确,数据穿透由用户侧证书环境覆盖。
    final inst = await startFrpc(
      buildProfile(proxies: [
        ProxyConfig(
            name: 'e2e-https',
            type: ProxyType.https,
            localPort: httpLocalPort,
            customDomains: ['securee2e.test.local']),
      ]),
      frpcPath: frpcBin!.path,
    );
    addTearDown(inst.dispose);

    final statuses = await waitForProxies(inst.admin,
        until: (s) => s.any((e) => e.name == 'e2e-https' && e.isRunning));
    expect(statuses.any((e) => e.name == 'e2e-https' && e.isRunning), isTrue,
        reason: 'https 代理应注册为 running\n--frpc--\n${inst.frpc.logs.join('\n')}\n--frps--\n${frpsLogs.join('\n')}');
  });

  test('stcp 代理 + stcp 访问端:TCP 穿透', skip: skipReason, () async {
    final inst = await startFrpc(
      buildProfile(
        proxies: [
          ProxyConfig(
              name: 'e2e-stcp',
              type: ProxyType.stcp,
              localPort: tcpEchoPort,
              secretKey: 'sk-e2e'),
        ],
        visitors: [
          VisitorConfig(
              name: 'e2e-stcp-v',
              type: VisitorType.stcp,
              serverName: 'e2e-stcp',
              secretKey: 'sk-e2e',
              bindPort: stcpVisitorPort),
        ],
      ),
      frpcPath: frpcBin!.path,
    );
    addTearDown(inst.dispose);

    await waitForProxies(inst.admin,
        until: (s) => s.any((e) => e.name == 'e2e-stcp' && e.isRunning));

    // 访问端 bindPort → 经 frps → stcp 代理 → 本地 echo
    final client = await Socket.connect('127.0.0.1', stcpVisitorPort,
        timeout: const Duration(seconds: 10));
    client.add(utf8.encode('hello-stcp'));
    final echoed = await client.first
        .timeout(const Duration(seconds: 10))
        .onError((_, _) => Uint8List(0));
    await client.close();
    expect(String.fromCharCodes(echoed), 'hello-stcp',
        reason: '数据应经 stcp 隧道 echo 回来\n--frpc--\n${inst.frpc.logs.join('\n')}\n--frps--\n${frpsLogs.join('\n')}');
  });

  test('sudp 代理 + sudp 访问端:UDP 穿透', skip: skipReason, () async {
    final inst = await startFrpc(
      buildProfile(
        proxies: [
          ProxyConfig(
              name: 'e2e-sudp',
              type: ProxyType.sudp,
              localPort: udpEchoPort2,
              secretKey: 'sk-sudp'),
        ],
        visitors: [
          VisitorConfig(
              name: 'e2e-sudp-v',
              type: VisitorType.sudp,
              serverName: 'e2e-sudp',
              secretKey: 'sk-sudp',
              bindPort: sudpVisitorPort),
        ],
      ),
      frpcPath: frpcBin!.path,
    );
    addTearDown(inst.dispose);

    await waitForProxies(inst.admin,
        until: (s) => s.any((e) => e.name == 'e2e-sudp' && e.isRunning));

    final sock = await RawDatagramSocket.bind('127.0.0.1', 0);
    addTearDown(sock.close);
    final dg = await sendAndWaitReply(
        sock, utf8.encode('ping-sudp'), InternetAddress.loopbackIPv4,
        sudpVisitorPort);
    expect(dg, isNotNull,
        reason: 'UDP 数据报应经 sudp 隧道返回\n--frpc--\n${inst.frpc.logs.join('\n')}\n--frps--\n${frpsLogs.join('\n')}');
    expect(utf8.decode(dg!.data), 'ping-sudp');
  });

  test('xtcp 代理 + xtcp 访问端:启动级验证', skip: skipReason, () async {
    // xtcp 依赖 NAT 打洞,单机回环环境不可靠,这里只验证双方都能注册/启动。
    final inst = await startFrpc(
      buildProfile(
        proxies: [
          ProxyConfig(
              name: 'e2e-xtcp',
              type: ProxyType.xtcp,
              localPort: tcpEchoPort,
              secretKey: 'sk-xtcp'),
        ],
        visitors: [
          VisitorConfig(
              name: 'e2e-xtcp-v',
              type: VisitorType.xtcp,
              serverName: 'e2e-xtcp',
              secretKey: 'sk-xtcp',
              bindPort: xtcpVisitorPort),
        ],
      ),
      frpcPath: frpcBin!.path,
    );
    addTearDown(inst.dispose);

    final statuses = await waitForProxies(inst.admin,
        until: (s) => s.any((e) => e.name == 'e2e-xtcp' && e.isRunning));
    expect(statuses.any((e) => e.name == 'e2e-xtcp' && e.isRunning), isTrue,
        reason: 'xtcp 代理应注册为 running\n--frpc--\n${inst.frpc.logs.join('\n')}\n--frps--\n${frpsLogs.join('\n')}');

    var visitorOk = false;
    for (var i = 0; i < 20; i++) {
      if (inst.frpc.logs.any((l) => l.contains('start visitor success'))) {
        visitorOk = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    expect(visitorOk, isTrue,
        reason: 'frpc 日志应出现访问端启动成功\n--frpc--\n${inst.frpc.logs.join('\n')}');
  });
}
