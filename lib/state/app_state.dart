import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/admin/admin_api_service.dart';
import '../core/binary/frpc_binary_service.dart';
import '../core/config/config_service.dart';
import '../core/process/frpc_process_service.dart';
import '../model/profile.dart';
import '../model/proxy_config.dart';

/// 全局状态:Profile/版本/设置管理,frpc 启停编排,状态轮询。
class AppState extends ChangeNotifier {
  AppState();

  late final ConfigService configService;
  late final FrpcProcessService frpc;
  late final FrpcBinaryService binaries;
  late final SharedPreferences _prefs;

  List<Profile> profiles = [];
  String? activeProfileId;
  String? activeVersion; // frpc 版本目录名
  String? get mirror => binaries.mirror;

  bool get ready => _initCompleter.isCompleted;
  final _initCompleter = Completer<void>();
  Future<void> get readyFuture => _initCompleter.future;

  Profile? get activeProfile {
    for (final p in profiles) {
      if (p.id == activeProfileId) return p;
    }
    return profiles.isEmpty ? null : profiles.first;
  }

  AdminApiService? _admin;
  List<ProxyRuntimeStatus> proxyStatuses = const [];
  Timer? _statusTimer;

  Future<void> init() async {
    final support = await getApplicationSupportDirectory();
    _prefs = await SharedPreferences.getInstance();
    configService = ConfigService(support);
    frpc = FrpcProcessService();
    binaries = FrpcBinaryService(
      appSupportDir: support,
      mirror: _prefs.getString('mirror'),
    );
    frpc.autoRestart = _prefs.getBool('autoRestart') ?? true;
    frpc.onAutoRestart = _autoRestart;

    profiles = await configService.loadProfiles();
    activeProfileId = _prefs.getString('activeProfileId');
    if (activeProfileId == null && profiles.isNotEmpty) {
      await setActiveProfile(profiles.first.id);
    }
    activeVersion = _prefs.getString('activeVersion') ??
        (binaries.listInstalled().isNotEmpty ? binaries.listInstalled().first : null);

    _initCompleter.complete();
    notifyListeners();
  }

  // ------------------------------------------------ profile

  Future<void> setActiveProfile(String id) async {
    activeProfileId = id;
    await _prefs.setString('activeProfileId', id);
    notifyListeners();
  }

  Future<Profile> addProfile(String name) async {
    final profile = Profile(id: _id(), name: name, serverAddr: '');
    profiles.add(profile);
    await configService.saveProfile(profile);
    await setActiveProfile(profile.id);
    return profile;
  }

  Future<void> saveActiveProfile() async {
    final profile = activeProfile;
    if (profile != null) await configService.saveProfile(profile);
    notifyListeners();
  }

  Future<void> deleteProfile(String id) async {
    if (frpc.runningProfileId == id) await frpc.stop();
    profiles.removeWhere((p) => p.id == id);
    await configService.deleteProfile(id);
    if (activeProfileId == id && profiles.isNotEmpty) {
      await setActiveProfile(profiles.first.id);
    }
    notifyListeners();
  }

  Future<void> importProfile(String tomlContent, {required String name}) async {
    final profile = configService.fromToml(tomlContent, name: name);
    profiles.add(profile);
    await configService.saveProfile(profile);
    await setActiveProfile(profile.id);
  }

  // ------------------------------------------------ frpc 启停

  /// 选定 frpc 二进制:优先当前版本,回退打包内置。
  String? resolveFrpcPath() {
    if (activeVersion != null && binaries.isInstalled(activeVersion!)) {
      return binaries.binaryPath(activeVersion!);
    }
    return binaries.bundledBinaryPath();
  }

  Future<void> startFrpc() async {
    final profile = activeProfile;
    if (profile == null) throw StateError('没有可用的配置');
    if (profile.serverAddr.isEmpty) {
      throw StateError('请先在"配置"页填写服务器地址');
    }
    final frpcPath = resolveFrpcPath();
    if (frpcPath == null) {
      throw StateError('未找到 frpc,请到"版本"页下载');
    }
    await configService.saveProfile(profile);
    final configFile = configService.writeRuntimeConfig(profile);
    _admin = AdminApiService(profile.adminWebServer!);
    await frpc.start(
      profile: profile,
      frpcPath: frpcPath,
      configPath: configFile.path,
    );
    _startStatusPolling();
  }

  Future<void> stopFrpc() async {
    _stopStatusPolling();
    proxyStatuses = const [];
    await frpc.stop();
    notifyListeners();
  }

  /// 配置变更后热重载:重写运行时配置 → frpc 进程内 reload。
  Future<void> hotReload() async {
    final profile = activeProfile;
    if (profile == null || !frpc.isRunning || _admin == null) return;
    await configService.saveProfile(profile);
    configService.writeRuntimeConfig(profile);
    await _admin!.reload();
  }

  Future<void> _autoRestart() async {
    // 退避重启前重写配置(可能已被用户修改)
    if (frpc.runningProfileId != null && !frpc.isRunning) {
      try {
        await startFrpc();
      } catch (e) {
        debugPrint('自动重启失败: $e');
      }
    }
  }

  // ------------------------------------------------ 状态轮询

  void _startStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final statuses = await _admin?.status();
        if (statuses != null) {
          proxyStatuses = statuses;
          notifyListeners();
        }
      } catch (_) {
        // frpc 尚未起好或已退出,静默跳过
      }
    });
  }

  void _stopStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  // ------------------------------------------------ 设置

  Future<void> setMirror(String? value) async {
    binaries.mirror = value;
    await _prefs.setString('mirror', value ?? '');
    notifyListeners();
  }

  Future<void> setAutoRestart(bool value) async {
    frpc.autoRestart = value;
    await _prefs.setBool('autoRestart', value);
    notifyListeners();
  }

  Future<void> setActiveVersion(String? version) async {
    activeVersion = version;
    await _prefs.setString('activeVersion', version ?? '');
    notifyListeners();
  }

  String _id() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  @override
  void dispose() {
    _stopStatusPolling();
    frpc.dispose();
    super.dispose();
  }
}

/// 便捷扩展:当前 profile 的代理列表操作。
extension ProfileProxies on AppState {
  List<ProxyConfig> get proxies => activeProfile?.proxies ?? const [];

  void addProxy(ProxyConfig proxy) {
    final profile = activeProfile;
    if (profile == null) return;
    profile.proxies.add(proxy);
    saveActiveProfile();
  }

  void removeProxyAt(int index) {
    final profile = activeProfile;
    if (profile == null || index >= profile.proxies.length) return;
    profile.proxies.removeAt(index);
    saveActiveProfile();
  }

  void replaceProxyAt(int index, ProxyConfig proxy) {
    final profile = activeProfile;
    if (profile == null || index >= profile.proxies.length) return;
    profile.proxies[index] = proxy;
    saveActiveProfile();
  }
}
