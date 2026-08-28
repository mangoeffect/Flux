import 'dart:io';

import 'package:path/path.dart' as p;

/// 开机自启:不引第三方插件(避免 win32 版本冲突),直接操作各平台机制。
/// - Windows:HKCU\...\Run 注册表键(reg 命令)
/// - Linux:~/.config/autostart/flux.desktop(XDG 规范)
/// - macOS:System Events 登录项(osascript)
class StartupService {
  static const _appName = 'Flux';
  static const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

  static bool get supported =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static Future<void> enable() async {
    final exe = Platform.resolvedExecutable;
    if (Platform.isWindows) {
      final r = await Process.run('reg', [
        'add', _runKey, '/v', _appName, '/t', 'REG_SZ', '/d', '"$exe"', '/f',
      ]);
      if (r.exitCode != 0) throw StateError('reg add 失败: ${r.stderr}');
    } else if (Platform.isLinux) {
      final file = File(p.join(_linuxConfigHome(), 'autostart', 'flux.desktop'));
      await file.parent.create(recursive: true);
      await file.writeAsString('''
[Desktop Entry]
Type=Application
Name=$_appName
Exec=$exe
Terminal=false
''');
    } else if (Platform.isMacOS) {
      final r = await Process.run('osascript', [
        '-e',
        'tell application "System Events" to make login item at end '
            'with properties {path:"$exe", hidden:false}',
      ]);
      if (r.exitCode != 0) throw StateError('osascript 失败: ${r.stderr}');
    }
  }

  static Future<void> disable() async {
    // 幂等:条目不存在时静默成功。
    if (Platform.isWindows) {
      await Process.run('reg', ['delete', _runKey, '/v', _appName, '/f']);
    } else if (Platform.isLinux) {
      final file = File(p.join(_linuxConfigHome(), 'autostart', 'flux.desktop'));
      if (await file.exists()) await file.delete();
    } else if (Platform.isMacOS) {
      await Process.run('osascript', [
        '-e',
        'tell application "System Events" to delete login item "$_appName"',
      ]);
    }
  }

  /// 以系统实际状态为准(注册表/文件可能被用户或其他途径改动)。
  static Future<bool> isEnabled() async {
    try {
      if (Platform.isWindows) {
        final r = await Process.run('reg', ['query', _runKey, '/v', _appName]);
        return r.exitCode == 0;
      }
      if (Platform.isLinux) {
        return await File(p.join(_linuxConfigHome(), 'autostart', 'flux.desktop'))
            .exists();
      }
      if (Platform.isMacOS) {
        final r = await Process.run('osascript', [
          '-e',
          'tell application "System Events" '
              'to get the name of every login item',
        ]);
        return r.exitCode == 0 && (r.stdout as String).contains(_appName);
      }
    } catch (_) {
      // 查询失败按"未启用"处理
    }
    return false;
  }

  static String _linuxConfigHome() =>
      Platform.environment['XDG_CONFIG_HOME'] ??
      p.join(Platform.environment['HOME'] ?? '.', '.config');
}
