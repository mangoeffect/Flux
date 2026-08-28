import 'dart:async';
import 'dart:io';
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/admin/admin_api_service.dart';
import '../core/binary/frpc_binary_service.dart';
import '../core/config/config_service.dart';
import '../core/process/frpc_process_service.dart';
import '../core/update/update_service.dart';
import '../model/profile.dart';
import '../model/proxy_config.dart';
import '../model/visitor_config.dart';
import '../l10n/l10n_holder.dart';
import '../platform/startup_service.dart';

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

  /// 关闭窗口时最小化到托盘(而非退出)。
  bool closeToTray = true;
  /// 随系统登录自启。
  bool launchAtStartup = false;

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

  /// 检查更新得到的新版本 tag;null 表示无更新或尚未检查。
  String? updateAvailable;

  /// 上次异常退出残留的 frpc 进程 PID(应用崩溃遗留),首页横幅提示清理。
  List<int> orphanPids = [];

  Future<void> init() async {
    final support = await getApplicationSupportDirectory();
    _prefs = await SharedPreferences.getInstance();
    configService = ConfigService(support);
    // 日志落盘:appSupport/logs/<profileId>/<yyyy-MM-dd>.log
    final logsDir = Directory(p.join(support.path, 'logs'));
    _cleanOldLogs(logsDir);
    frpc = FrpcProcessService()..logDir = logsDir;
    binaries = FrpcBinaryService(
      appSupportDir: support,
      mirror: _prefs.getString('mirror'),
    );
    frpc.autoRestart = _prefs.getBool('autoRestart') ?? true;
    frpc.onAutoRestart = _autoRestart;
    // frpc 状态变化(starting/running/退出码等)转发给全局监听者(托盘/UI)
    frpc.addListener(notifyListeners);

    closeToTray = _prefs.getBool('closeToTray') ?? true;
    // 自启以系统实际状态为准,本地偏好仅作查询失败时的回退
    launchAtStartup = _prefs.getBool('launchAtStartup') ?? false;
    if (StartupService.supported) {
      try {
        launchAtStartup = await StartupService.isEnabled();
      } catch (_) {}
    }

    profiles = await configService.loadProfiles();
    activeProfileId = _prefs.getString('activeProfileId');
    if (activeProfileId == null && profiles.isNotEmpty) {
      await setActiveProfile(profiles.first.id);
    }
    activeVersion = _prefs.getString('activeVersion') ??
        (binaries.listInstalled().isNotEmpty ? binaries.listInstalled().first : null);

    _initCompleter.complete();
    notifyListeners();

    _detectOrphanFrpc();
    unawaited(checkForUpdate());
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

  /// frpc verify:通过返回 null,否则返回错误文本(供 UI 弹提示)。
  Future<String?> verifyConfig() {
    final profile = activeProfile;
    if (profile == null) throw StateError(L10n.of?.errNoProfile ?? '没有可用的配置');
    final frpcPath = resolveFrpcPath();
    if (frpcPath == null) {
      throw StateError(L10n.of?.errNoFrpc ?? '未找到 frpc,请到"版本"页下载');
    }
    return _verifyFile(frpcPath, configService.writeRuntimeConfig(profile));
  }

  Future<String?> _verifyFile(String frpcPath, File configFile) async {
    final r = await Process.run(frpcPath, ['verify', '-c', configFile.path]);
    if (r.exitCode == 0) return null;
    final out = ('${r.stdout}${r.stderr}').trim();
    return out.isEmpty ? 'frpc verify 退出码 ${r.exitCode}' : out;
  }

  String? resolveFrpcPath() {
    if (activeVersion != null && binaries.isInstalled(activeVersion!)) {
      return binaries.binaryPath(activeVersion!);
    }
    return binaries.bundledBinaryPath();
  }

  Future<void> startFrpc() async {
    final profile = activeProfile;
    if (profile == null) throw StateError(L10n.of?.errNoProfile ?? '没有可用的配置');
    if (profile.serverAddr.isEmpty) {
      throw StateError(L10n.of?.errNeedServerAddr ?? '请先在"配置"页填写服务器地址');
    }
    final frpcPath = resolveFrpcPath();
    if (frpcPath == null) {
      throw StateError(L10n.of?.errNoFrpc ?? '未找到 frpc,请到"版本"页下载');
    }
    await configService.saveProfile(profile);
    final configFile = configService.writeRuntimeConfig(profile);
    // 启动前语法校验,避免配置错误导致的"起进程秒退→自动重启"循环
    final verifyErr = await _verifyFile(frpcPath, configFile);
    if (verifyErr != null) {
      throw StateError(L10n.of?.errVerifyFailed(verifyErr) ?? '配置校验失败:$verifyErr');
    }
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

  // ------------------------------------------------ 更新检查

  static const releasesUrl = 'https://github.com/mangoeffect/Flux/releases/latest';

  /// 检查更新。手动触发(silent=false)时失败抛出、无更新也通知,供 UI 反馈。
  Future<void> checkForUpdate({bool silent = true}) async {
    try {
      final tag = await UpdateService().latestTag();
      final latest = tag.replaceFirst('v', '');
      final current = await PackageInfo.fromPlatform();
      final hasNew = isNewerVersion(latest, current.version);
      final changed = hasNew != (updateAvailable != null);
      updateAvailable = hasNew ? tag : null;
      if (!silent || changed) notifyListeners();
    } catch (_) {
      if (!silent) rethrow;
    }
  }

  Future<void> openReleasesPage() async {
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', releasesUrl]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [releasesUrl]);
    } else {
      await Process.run('xdg-open', [releasesUrl]);
    }
  }

  // ------------------------------------------------ 孤儿 frpc 进程

  /// 扫描 runtime/*/frpc.pid:进程仍在则记为孤儿,已死则清理 pid 文件。
  void _detectOrphanFrpc() {
    final runtimeDir =
        Directory(p.join(configService.appSupportDir.path, 'runtime'));
    if (!runtimeDir.existsSync()) return;
    for (final d in runtimeDir.listSync().whereType<Directory>()) {
      final f = File(p.join(d.path, 'frpc.pid'));
      if (!f.existsSync()) continue;
      final pid = int.tryParse(f.readAsStringSync().trim());
      if (pid == null) {
        try {
          f.deleteSync();
        } catch (_) {}
        continue;
      }
      if (_isFrpcAlive(pid)) {
        orphanPids.add(pid);
      } else {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
    if (orphanPids.isNotEmpty) notifyListeners();
  }

  /// 校验 PID 存活且确实是 frpc(防 PID 复用误杀)。
  bool _isFrpcAlive(int pid) {
    try {
      if (Platform.isWindows) {
        final r = Process.runSync(
            'tasklist', ['/FI', 'PID eq $pid', '/FO', 'CSV', '/NH']);
        final out = (r.stdout as String);
        return out.contains('frpc') && out.contains('$pid');
      }
      final comm = File('/proc/$pid/comm');
      return comm.existsSync() && comm.readAsStringSync().startsWith('frpc');
    } catch (_) {
      return false;
    }
  }

  Future<void> cleanupOrphans() async {
    for (final pid in List.of(orphanPids)) {
      try {
        if (Platform.isWindows) {
          Process.runSync('taskkill', ['/PID', '$pid', '/F', '/T']);
        } else {
          Process.runSync('kill', ['-9', '$pid']);
        }
      } catch (_) {}
    }
    orphanPids = [];
    final runtimeDir =
        Directory(p.join(configService.appSupportDir.path, 'runtime'));
    if (runtimeDir.existsSync()) {
      for (final d in runtimeDir.listSync().whereType<Directory>()) {
        final f = File(p.join(d.path, 'frpc.pid'));
        if (f.existsSync()) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    }
    notifyListeners();
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

  Future<void> setCloseToTray(bool value) async {
    closeToTray = value;
    await _prefs.setBool('closeToTray', value);
    notifyListeners();
  }

  Future<void> setLaunchAtStartup(bool value) async {
    launchAtStartup = value;
    await _prefs.setBool('launchAtStartup', value);
    if (StartupService.supported) {
      try {
        value ? await StartupService.enable() : await StartupService.disable();
      } catch (e) {
        debugPrint('设置开机自启失败: $e');
      }
    }
    notifyListeners();
  }

  Future<void> setActiveVersion(String? version) async {
    activeVersion = version;
    await _prefs.setString('activeVersion', version ?? '');
    notifyListeners();
  }

  // ------------------------------------------------ 窗口状态记忆

  Offset? get windowPosition => _prefs.containsKey('winX')
      ? Offset(_prefs.getDouble('winX')!, _prefs.getDouble('winY')!)
      : null;

  Size? get windowSize => _prefs.containsKey('winW')
      ? Size(_prefs.getDouble('winW')!, _prefs.getDouble('winH')!)
      : null;

  bool get windowMaximized => _prefs.getBool('winMaximized') ?? false;

  Future<void> setWindowRect(double x, double y, double w, double h) async {
    await _prefs.setDouble('winX', x);
    await _prefs.setDouble('winY', y);
    await _prefs.setDouble('winW', w);
    await _prefs.setDouble('winH', h);
  }

  Future<void> setWindowMaximized(bool value) =>
      _prefs.setBool('winMaximized', value);

  int get lastPageIndex => (_prefs.getInt('lastPageIndex') ?? 0).clamp(0, 4);

  Future<void> setLastPageIndex(int i) =>
      _prefs.setInt('lastPageIndex', i.clamp(0, 4));

  // ------------------------------------------------ 日志目录

  Future<void> openLogDir() async {
    final dir = Directory(p.join(configService.appSupportDir.path, 'logs'));
    await dir.create(recursive: true);
    if (Platform.isWindows) {
      await Process.run('explorer', [dir.path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [dir.path]);
    } else {
      await Process.run('xdg-open', [dir.path]);
    }
  }

  /// 删除 7 天前的落盘日志(按文件名日期,回退按修改时间)。
  void _cleanOldLogs(Directory logsDir) {
    if (!logsDir.existsSync()) return;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    for (final profileDir in logsDir.listSync().whereType<Directory>()) {
      for (final f in profileDir.listSync().whereType<File>()) {
        final day = DateTime.tryParse(p.basenameWithoutExtension(f.path));
        final stale = (day ?? f.lastModifiedSync()).isBefore(cutoff);
        if (stale) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    }
  }

  String _id() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  @override
  void dispose() {
    _stopStatusPolling();
    frpc.dispose();
    super.dispose();
  }
}

/// 便捷扩展:当前 profile 的代理/访问端列表操作。
extension ProfileProxies on AppState {
  List<ProxyConfig> get proxies => activeProfile?.proxies ?? const [];

  List<VisitorConfig> get visitors =>
      (activeProfile?.visitors ?? const []).map(VisitorConfig.fromMap).toList();

  void addProxy(ProxyConfig proxy) {
    final profile = activeProfile;
    if (profile == null) return;
    profile.proxies.add(proxy);
    saveActiveProfile();
  }

  void addVisitor(VisitorConfig visitor) {
    final profile = activeProfile;
    if (profile == null) return;
    profile.visitors.add(visitor.toMap());
    saveActiveProfile();
  }

  void removeProxyAt(int index) {
    final profile = activeProfile;
    if (profile == null || index >= profile.proxies.length) return;
    profile.proxies.removeAt(index);
    saveActiveProfile();
  }

  void removeVisitorAt(int index) {
    final profile = activeProfile;
    if (profile == null || index >= profile.visitors.length) return;
    profile.visitors.removeAt(index);
    saveActiveProfile();
  }

  void replaceProxyAt(int index, ProxyConfig proxy) {
    final profile = activeProfile;
    if (profile == null || index >= profile.proxies.length) return;
    profile.proxies[index] = proxy;
    saveActiveProfile();
  }

  void replaceVisitorAt(int index, VisitorConfig visitor) {
    final profile = activeProfile;
    if (profile == null || index >= profile.visitors.length) return;
    profile.visitors[index] = visitor.toMap();
    saveActiveProfile();
  }
}
