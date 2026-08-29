// e2e 测试共享辅助:frp 二进制定位(跨平台)、端口/代理就绪轮询、frpc 实例起停。
import 'dart:io';

import 'package:flux/core/admin/admin_api_service.dart';
import 'package:flux/core/config/config_service.dart';
import 'package:flux/core/process/frpc_process_service.dart';
import 'package:flux/model/profile.dart';

const String kFrpVersion = '0.71.0';

final String _exeSuffix = Platform.isWindows ? '.exe' : '';

/// 定位仓库 `.e2e/` 下唯一的 `frp_<版本>_<os>_<arch>` 目录;不存在返回 null(测试 skip)。
Directory? findE2eFrpDir() {
  final root = Directory('.e2e');
  if (!root.existsSync()) return null;
  for (final e in root.listSync()) {
    if (e is Directory &&
        e.uri.pathSegments.any((s) => s.startsWith('frp_$kFrpVersion'))) {
      return e;
    }
  }
  return null;
}

/// .e2e/ 下的 frpc/frps 二进制;缺失返回 null。
File? e2eBinary(String name) {
  final dir = findE2eFrpDir();
  if (dir == null) return null;
  final f = File('${dir.path}${Platform.pathSeparator}$name$_exeSuffix');
  return f.existsSync() ? f : null;
}

/// 轮询直到 TCP 端口可连接,超时抛 StateError。
Future<void> waitForPort(String host, int port,
    {int tries = 40,
    Duration interval = const Duration(milliseconds: 500)}) async {
  for (var i = 0; i < tries; i++) {
    await Future<void>.delayed(interval);
    try {
      final s =
          await Socket.connect(host, port, timeout: const Duration(seconds: 2));
      s.destroy();
      return;
    } catch (_) {}
  }
  throw StateError('端口未就绪 $host:$port');
}

/// 轮询 Admin API 直到条件满足,返回最后一次状态(供断言给出详细信息)。
Future<List<ProxyRuntimeStatus>> waitForProxies(
  AdminApiService admin, {
  bool Function(List<ProxyRuntimeStatus> statuses)? until,
  int tries = 40,
}) async {
  List<ProxyRuntimeStatus> statuses = const [];
  for (var i = 0; i < tries; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    try {
      statuses = await admin.status();
      if (until == null || until(statuses)) break;
    } catch (_) {}
  }
  return statuses;
}

/// 一个已启动的 frpc 实例及其上下文。
class FrpcInstance {
  FrpcInstance._(this.frpc, this.admin, this.workDir);

  final FrpcProcessService frpc;
  final AdminApiService admin;
  final Directory workDir;

  /// 停止 frpc 并清理临时目录。
  Future<void> dispose() async {
    try {
      await frpc.stop();
    } catch (_) {}
    try {
      await workDir.delete(recursive: true);
    } catch (_) {}
  }
}

/// 在临时目录生成注入 webServer 的 runtime 配置并启动 frpc。
/// 调用方负责 addTearDown(inst.dispose)。
Future<FrpcInstance> startFrpc(Profile profile,
    {required String frpcPath}) async {
  final workDir = await Directory.systemTemp.createTemp('flux_e2e_');
  final configFile = ConfigService(workDir).writeRuntimeConfig(profile);
  assert(profile.adminWebServer != null, 'writeRuntimeConfig 应注入 webServer');
  final frpc = FrpcProcessService();
  await frpc.start(
      profile: profile, frpcPath: frpcPath, configPath: configFile.path);
  return FrpcInstance._(frpc, AdminApiService(profile.adminWebServer!), workDir);
}
