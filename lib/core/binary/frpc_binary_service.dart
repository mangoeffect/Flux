import 'dart:io';

import 'package:archive/archive.dart' as arch;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// frpc 二进制的版本管理:下载(GitHub Releases,支持镜像)、tar.gz 解压、按版本存放。
class FrpcBinaryService extends ChangeNotifier {
  FrpcBinaryService({required this.appSupportDir, String? mirror})
      : _mirror = mirror; // ignore: prefer_initializing_formals

  static const githubBase = 'https://github.com';
  static const apiBase = 'https://api.github.com/repos/fatedier/frp/releases/latest';

  final Directory appSupportDir;
  String? _mirror;
  String? get mirror => _mirror;

  set mirror(String? value) {
    _mirror = (value == null || value.isEmpty) ? null : value;
    notifyListeners();
  }

  Directory get versionsDir => Directory(p.join(appSupportDir.path, 'frpc'));

  String get _exeName => Platform.isWindows ? 'frpc.exe' : 'frpc';

  /// 已安装版本目录名列表(语义化倒序)。
  List<String> listInstalled() {
    if (!versionsDir.existsSync()) return const [];
    final versions = versionsDir
        .listSync()
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .where((name) =>
            File(p.join(versionsDir.path, name, _exeName)).existsSync())
        .toList();
    versions.sort((a, b) => b.compareTo(a)); // 简单倒序,新版本号在前
    return versions;
  }

  String binaryPath(String version) =>
      p.join(versionsDir.path, version, _exeName);

  bool isInstalled(String version) =>
      File(binaryPath(version)).existsSync();

  /// 打包内置的 frpc(位于可执行文件旁,见 scripts/fetch_frpc.sh + 打包流程)。
  String? bundledBinaryPath() {
    final beside = File(p.join(p.dirname(Platform.resolvedExecutable), _exeName));
    return beside.existsSync() ? beside.path : null;
  }

  /// 查询 frp 最新版本号(不带 v 前缀)。
  Future<String> fetchLatestVersion() async {
    final dio = Dio();
    final resp = await dio.get<String>(apiBase);
    if (resp.statusCode != 200) {
      throw StateError('查询 frp 最新版本失败: HTTP ${resp.statusCode}');
    }
    final tag = RegExp(r'"tag_name":\s*"v([^"]+)"')
            .firstMatch(resp.data ?? '')?.group(1) ??
        (throw StateError('无法解析 frp 版本号'));
    return tag;
  }

  /// Windows 发行包是 zip,其余平台是 tar.gz。
  bool get _isZip => Platform.isWindows;

  String _downloadUrl(String version) {
    final os = Platform.isWindows
        ? 'windows'
        : Platform.isMacOS
            ? 'darwin'
            : 'linux';
    final arch = switch (Platform.version) {
      _ when _isArm64() => 'arm64',
      _ => 'amd64',
    };
    final ext = _isZip ? 'zip' : 'tar.gz';
    final file = 'frp_${version}_${os}_$arch.$ext';
    final base = mirror ?? githubBase;
    return '$base/fatedier/frp/releases/download/v$version/$file';
  }

  bool _isArm64() {
    if (Platform.isMacOS || Platform.isLinux) {
      return Platform.environment.containsKey('FLUX_FORCE_ARM64')
          ? false
          : _hostIsArm();
    }
    return false;
  }

  bool _hostIsArm() {
    try {
      final cpu = File('/proc/cpuinfo');
      if (cpu.existsSync()) {
        return cpu.readAsStringSync().contains('aarch64');
      }
    } catch (_) {}
    // macOS: sysctl 由 Process 查询成本高,环境探测留待构建时处理
    return Platform.environment['FLUX_ARM'] == '1';
  }

  /// 下载并安装指定版本。onProgress 收到 0~1 进度。
  Future<void> download(String version,
      {void Function(double progress)? onProgress}) async {
    final url = _downloadUrl(version);
    final dio = Dio();
    final tmpDir = Directory(p.join(appSupportDir.path, '.tmp-frpc'));
    await tmpDir.create(recursive: true);
    final archivePath = p.join(tmpDir.path, _isZip ? 'frpc.zip' : 'frpc.tar.gz');

    try {
      await dio.download(
        url,
        archivePath,
        onReceiveProgress: (count, total) {
          if (total > 0) onProgress?.call(count / total);
        },
      );
    } catch (e) {
      throw StateError('下载失败($url): $e');
    }

    try {
      final bytes = await File(archivePath).readAsBytes();
      final archive =
          _isZip ? arch.ZipDecoder().decodeBytes(bytes) : arch.TarDecoder()
              .decodeBytes(arch.GZipDecoder().decodeBytes(bytes));
      arch.ArchiveFile? frpcFile;
      for (final f in archive.files) {
        final base = p.basename(f.name);
        if (base == 'frpc' || base == 'frpc.exe') {
          frpcFile = f;
        }
      }
      if (frpcFile == null) {
        throw StateError('压缩包中未找到 frpc 二进制');
      }
      final destDir = Directory(p.join(versionsDir.path, version));
      await destDir.create(recursive: true);
      final dest = File(p.join(destDir.path, _exeName));
      await dest.writeAsBytes(frpcFile.content as List<int>);
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', dest.path]);
      }
    } finally {
      await Directory(tmpDir.path).delete(recursive: true);
    }
    notifyListeners();
  }

  Future<void> remove(String version) async {
    final dir = Directory(p.join(versionsDir.path, version));
    if (dir.existsSync()) await dir.delete(recursive: true);
    notifyListeners();
  }
}
