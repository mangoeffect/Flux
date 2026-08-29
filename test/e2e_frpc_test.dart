@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core/admin/admin_api_service.dart';
import 'package:flux/core/config/config_service.dart';
import 'package:flux/core/process/frpc_process_service.dart';
import 'package:flux/model/profile.dart';
import 'package:flux/model/proxy_config.dart';

import 'e2e_helpers.dart';

/// 端到端验收:真实拉起 frps + frpc(取自 .e2e/ 目录,未下载则跳过),
/// 验证 配置生成 → 进程管理 → Admin API 状态 → 数据穿透 → 热重载 → 停止。
void main() {
  final frpsBin = e2eBinary('frps');
  final frpcBin = e2eBinary('frpc');
  final binariesReady = frpsBin != null && frpcBin != null;

  test('frpc 全链路:启动→状态→数据穿透→热重载→停止', skip: binariesReady ? false : '未下载 frp 二进制(.e2e/)', () async {
    final workDir = await Directory.systemTemp.createTemp('flux_e2e_');
    addTearDown(() async {
      try {
        await workDir.delete(recursive: true);
      } catch (_) {}
    });

    // 本地 frps:127.0.0.1:17999,token 认证
    final frpsConfig = File('${workDir.path}${Platform.pathSeparator}frps.toml')
      ..writeAsStringSync('bindAddr = "127.0.0.1"\nbindPort = 17999\nauth.token = "e2e-token"\n');
    final frps = await Process.start(frpsBin!.path, ['-c', frpsConfig.path]);
    addTearDown(() => frps.kill());
    final frpsLogs = <String>[];
    frps.stdout.transform(systemEncoding.decoder).transform(const LineSplitter()).listen(frpsLogs.add);
    frps.stderr.transform(systemEncoding.decoder).transform(const LineSplitter()).listen(frpsLogs.add);

    // 等 frps 监听端口就绪(Windows 下进程/杀软可能拖慢启动)
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        final s = await Socket.connect('127.0.0.1', 17999,
            timeout: const Duration(seconds: 2));
        s.destroy();
        break;
      } catch (_) {}
    }

    // 本地被代理服务:TCP echo
    final echoServer = await ServerSocket.bind('127.0.0.1', 18888);
    addTearDown(() => echoServer.close());
    echoServer.listen((socket) => socket.listen(
          (data) => socket.add(data),
          onDone: () => socket.destroy(),
        ));

    // 用真实模型+服务构造 frpc 配置(含 webServer 注入)
    final configService = ConfigService(workDir);
    final profile = Profile(
      id: 'e2e',
      name: 'e2e',
      serverAddr: '127.0.0.1',
      serverPort: 17999,
      token: 'e2e-token',
      proxies: [
        ProxyConfig(
          name: 'e2e-tcp',
          type: ProxyType.tcp,
          localPort: 18888,
          remotePort: 16999,
        ),
      ],
    );
    final configFile = configService.writeRuntimeConfig(profile);
    expect(profile.adminWebServer, isNotNull, reason: '生成时自动注入 webServer');

    final frpc = FrpcProcessService();
    addTearDown(() => frpc.dispose());
    await frpc.start(
        profile: profile, frpcPath: frpcBin!.path, configPath: configFile.path);

    // Admin API:轮询直到代理 running
    final admin = AdminApiService(profile.adminWebServer!);
    List<ProxyRuntimeStatus> statuses = const [];
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        statuses = await admin.status();
        if (statuses.any((s) => s.name == 'e2e-tcp' && s.isRunning)) break;
      } catch (_) {}
    }
    expect(statuses.any((s) => s.name == 'e2e-tcp' && s.isRunning), isTrue,
        reason: 'Admin API 应报告代理运行中,日志:\n${frpc.logs.join('\n')}');
    final statusLine = statuses.firstWhere((s) => s.name == 'e2e-tcp');
    expect(statusLine.localAddr, contains('18888'));
    expect(statusLine.remoteAddr, contains('16999'));

    // 数据穿透:连 frps 暴露的 16999 → 经隧道 → 18888 echo 回来
    final client = await Socket.connect('127.0.0.1', 16999,
        timeout: const Duration(seconds: 10));
    client.add('hello-flux'.codeUnits);
    final echoed = await client.first
        .timeout(const Duration(seconds: 10))
        .onError((_, _) => Uint8List(0));
    await client.close();
    expect(String.fromCharCodes(echoed), 'hello-flux',
        reason: '数据应穿过 frpc 隧道被 echo 回来,日志:\n${frpc.logs.join('\n')}');

    // 热重载:新增代理 → 重写配置 → reload → 新代理出现且旧代理不断
    profile.proxies.add(ProxyConfig(
      name: 'e2e-tcp2',
      type: ProxyType.tcp,
      localPort: 18888,
      remotePort: 16998,
    ));
    configService.writeRuntimeConfig(profile);
    await admin.reload();
    List<ProxyRuntimeStatus> statusesAfter = const [];
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        statusesAfter = await admin.status();
        if (statusesAfter.where((s) => s.isRunning).length >= 2) break;
      } catch (_) {}
    }
    expect(
      statusesAfter.where((s) => s.isRunning).map((s) => s.name),
      containsAll(['e2e-tcp', 'e2e-tcp2']),
      reason: '热重载后新旧代理都应运行\n--frpc--\n${frpc.logs.join('\n')}\n--frps--\n${frpsLogs.join('\n')}',
    );

    // 停止
    await frpc.stop();
    expect(frpc.state, FrpcRunState.stopped);
    expect(frpc.logs.any((l) => l.contains('exitCode=')), isTrue);
  });
}
