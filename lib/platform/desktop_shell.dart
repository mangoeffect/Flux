import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_holder.dart';
import '../state/app_state.dart';

/// 桌面外壳:托盘图标/菜单、关闭到托盘、退出清理。
/// 单实例与窗口初始尺寸在 main() 中完成,这里接管后续交互。
class DesktopShell with WindowListener, TrayListener {
  DesktopShell(this._app);

  final AppState _app;
  bool _quitting = false;
  String? _lastTrayKey; // 避免状态未变时反复重建托盘菜单
  Timer? _winStateDebounce;
  AppLocalizations? _l10n;

  static const _showKey = 'show';
  static const _toggleKey = 'toggle';
  static const _quitKey = 'quit';

  /// 注册窗口/托盘监听并挂上托盘。
  /// 失败不阻塞主界面。
  Future<void> start() async {
    windowManager.addListener(this);
    trayManager.addListener(this);
    await windowManager.setPreventClose(true);
    try {
      await _app.readyFuture;
      // 等首帧(FluxApp 填充 L10n.of)再取文案
      await WidgetsBinding.instance.endOfFrame;
      _l10n = L10n.of ??
          await AppLocalizations.delegate
              .load(WidgetsBinding.instance.platformDispatcher.locale);
      _app.addListener(_onStateChanged);
      _app.frpc.addListener(_onStateChanged);
      await _refreshTray();
    } catch (e) {
      // 托盘失败不致命,主界面仍可用
      stderr.writeln('[flux] 托盘初始化失败: $e');
    }
  }

  // ------------------------------------------------ 托盘

  Future<void> _refreshTray() async {
    final running = _app.frpc.isRunning;
    final l10n = _l10n;
    await trayManager.setIcon(Platform.isWindows
        ? (running ? 'assets/tray/icon_running.ico' : 'assets/tray/icon_stopped.ico')
        : (running ? 'assets/tray/icon_running.png' : 'assets/tray/icon_stopped.png'));
    await trayManager.setToolTip(running
        ? (l10n?.trayTooltipRunning(_app.proxies.length) ?? 'Flux — 运行中')
        : (l10n?.trayTooltipStopped ?? 'Flux — 已停止'));
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: _showKey, label: l10n?.trayShow ?? '显示主界面'),
      MenuItem.separator(),
      MenuItem(
          key: _toggleKey,
          label: running
              ? (l10n?.trayStop ?? '停止 frpc')
              : (l10n?.trayStart ?? '启动 frpc')),
      MenuItem.separator(),
      MenuItem(key: _quitKey, label: l10n?.trayQuit ?? '退出'),
    ]));
  }

  void _onStateChanged() {
    final key = '${_app.frpc.isRunning}:${_app.proxies.length}';
    if (key == _lastTrayKey) return;
    _lastTrayKey = key;
    _refreshTray();
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _toggleFrpc() async {
    try {
      if (_app.frpc.isRunning) {
        await _app.stopFrpc();
      } else {
        await _app.startFrpc();
      }
    } catch (_) {
      // 启动失败原因已写入 frpc 日志,主界面可见
    }
  }

  /// 退出:优雅停止 frpc → 撤托盘 → 销毁窗口。
  Future<void> quit() async {
    if (_quitting) return;
    _quitting = true;
    try {
      await _app.stopFrpc();
    } catch (_) {}
    await trayManager.destroy();
    await windowManager.destroy();
  }

  // ------------------------------------------------ WindowListener

  @override
  void onWindowClose() {
    if (_app.closeToTray) {
      windowManager.hide(); // frpc 继续运行
    } else {
      quit();
    }
  }

  /// 窗口移动/缩放后(防抖 500ms)持久化几何状态。
  @override
  void onWindowMove() => _saveWindowStateDebounced();

  @override
  void onWindowResize() => _saveWindowStateDebounced();

  void _saveWindowStateDebounced() {
    _winStateDebounce?.cancel();
    _winStateDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final maximized = await windowManager.isMaximized();
        await _app.setWindowMaximized(maximized);
        // 最大化时只记标志,矩形保留上次的常规尺寸
        if (!maximized) {
          final pos = await windowManager.getPosition();
          final size = await windowManager.getSize();
          await _app.setWindowRect(
              pos.dx, pos.dy, size.width, size.height);
        }
      } catch (_) {}
    });
  }

  // ------------------------------------------------ TrayListener

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _showKey:
        _showWindow();
      case _toggleKey:
        _toggleFrpc();
      case _quitKey:
        quit();
    }
  }

  @override
  void onTrayIconMouseDown() {
    // macOS 点按图标即弹出菜单,交给菜单处理;Windows/Linux 单击恢复窗口。
    if (!Platform.isMacOS) _showWindow();
  }
}
