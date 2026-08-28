import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../model/profile.dart';

enum FrpcRunState { stopped, starting, running, stopping }

/// frpc 子进程生命周期:启停、实时日志流、异常退出退避重启、优雅停止。
class FrpcProcessService extends ChangeNotifier {
  FrpcRunState _state = FrpcRunState.stopped;
  FrpcRunState get state => _state;

  int? _exitCode;
  int? get exitCode => _exitCode;

  DateTime? _startedAt;
  DateTime? get startedAt => _startedAt;

  /// 是否异常退出后自动重启(可在设置中关闭)。
  bool autoRestart = true;

  /// 日志落盘目录(可选,由 AppState 注入);null 时仅内存。
  Directory? logDir;

  IOSink? _logSink;
  String? _logSinkKey; // profileId|日期,变化时切换文件
  File? _pidFile; // 运行标记,供下次启动检测孤儿进程

  static const int _maxLogLines = 2000;
  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  Process? _process;
  Timer? _restartTimer;
  int _restartAttempts = 0;
  DateTime? _lastStart;
  String? _runningProfileId;
  String? get runningProfileId => _runningProfileId;

  bool get isRunning => _state == FrpcRunState.running || _state == FrpcRunState.starting;

  /// 启动 frpc。[configPath] 为已写好的 frpc.toml;由调用方保证二进制存在。
  Future<void> start({
    required Profile profile,
    required String frpcPath,
    required String configPath,
  }) async {
    if (isRunning) await stop();
    _state = FrpcRunState.starting;
    _exitCode = null;
    _runningProfileId = profile.id;
    notifyListeners();
    _appendLog('[flux] 启动 frpc: $frpcPath -c $configPath');

    try {
      final process = await Process.start(frpcPath, ['-c', configPath]);
      _process = process;
      _pidFile = File(p.join(p.dirname(configPath), 'frpc.pid'));
      try {
        _pidFile!.writeAsStringSync('${process.pid}');
      } catch (_) {}
      _lastStart = DateTime.now();
      _state = FrpcRunState.running;
      _startedAt = _lastStart;
      notifyListeners();

      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_appendLog, onError: (Object e) => _appendLog('[flux] stdout错误: $e'));
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_appendLog, onError: (Object e) => _appendLog('[flux] stderr错误: $e'));

      unawaited(process.exitCode.then((code) => _onExited(code)));
    } catch (e) {
      _appendLog('[flux] 启动失败: $e');
      _state = FrpcRunState.stopped;
      _runningProfileId = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stop() async {
    final process = _process;
    if (process == null) {
      _state = FrpcRunState.stopped;
      notifyListeners();
      return;
    }
    _state = FrpcRunState.stopping;
    _restartTimer?.cancel();
    notifyListeners();
    _appendLog('[flux] 停止 frpc (pid=${process.pid})...');

    // POSIX 先 SIGTERM 给 frpc 优雅退出机会;Windows TerminateProcess 即硬停。
    process.kill();

    var exited = false;
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (_state == FrpcRunState.stopped) {
        exited = true;
        break;
      }
    }
    if (!exited) {
      _appendLog('[flux] 未在 3s 内退出,SIGKILL 强制结束');
      process.kill(ProcessSignal.sigkill);
      await process.exitCode.catchError((_) => -1);
    }
  }

  void _onExited(int code) {
    final wasStopping = _state == FrpcRunState.stopping;
    _exitCode = code;
    _process = null;
    try {
      _pidFile?.deleteSync();
    } catch (_) {}
    _pidFile = null;
    _closeLogSink();
    _appendLog('[flux] frpc 退出,exitCode=$code${wasStopping ? '(主动停止)' : ''}');

    // 运行稳定 60s 后重置重启计数
    if (_lastStart != null &&
        DateTime.now().difference(_lastStart!).inSeconds > 60) {
      _restartAttempts = 0;
    }

    if (!wasStopping && autoRestart && _restartAttempts < 10) {
      final delay = Duration(
          seconds: (1 << _restartAttempts.clamp(0, 5)).clamp(1, 30));
      _restartAttempts++;
      _state = FrpcRunState.stopped;
      notifyListeners();
      _appendLog('[flux] 异常退出,${delay.inSeconds}s 后自动重启(第 $_restartAttempts 次)');
      _restartTimer = Timer(delay, () {
        if (_pendingRestart != null) _pendingRestart!();
      });
      return;
    }
    _state = FrpcRunState.stopped;
    _runningProfileId = null;
    notifyListeners();
  }

  /// 自动重启回调(由 AppState 注入:重新写配置并 start)。
  void Function()? _pendingRestart;
  set onAutoRestart(void Function()? callback) => _pendingRestart = callback;

  void _appendLog(String line) {
    if (_logController.isClosed) return;
    if (_logs.length >= _maxLogLines) _logs.removeRange(0, _logs.length - _maxLogLines);
    final stamped = '${DateTime.now().toIso8601String().substring(11, 23)} $line';
    _logs.add(stamped);
    _logController.add(stamped);
    _writeLogToDisk(stamped);
  }

  void _writeLogToDisk(String line) {
    final dir = logDir;
    if (dir == null) return;
    try {
      final now = DateTime.now();
      final id = _runningProfileId ?? 'app';
      final key = '$id|${now.year}-${now.month}-${now.day}';
      if (_logSink == null || _logSinkKey != key) {
        unawaited(_logSink?.flush());
        unawaited(_logSink?.close());
        final dayDir = Directory(p.join(dir.path, id));
        dayDir.createSync(recursive: true);
        _logSink = File(p.join(dayDir.path,
                '${now.year}-${_pad2(now.month)}-${_pad2(now.day)}.log'))
            .openWrite(mode: FileMode.append);
        _logSinkKey = key;
      }
      _logSink!.writeln(line);
    } catch (_) {
      // 磁盘写失败不影响内存日志与界面
    }
  }

  void _closeLogSink() {
    unawaited(_logSink?.flush());
    unawaited(_logSink?.close());
    _logSink = null;
    _logSinkKey = null;
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  void clearLogs() => _logs.clear();

  @override
  void dispose() {
    _restartTimer?.cancel();
    _process?.kill();
    _closeLogSink();
    _logController.close();
    super.dispose();
  }
}
