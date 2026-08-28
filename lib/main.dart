import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'platform/desktop_shell.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n_holder.dart';
import 'state/app_state.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/profile_page.dart';
import 'ui/pages/proxies_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/pages/versions_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final desktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  if (desktop) {
    // 单实例:非首实例时插件会激活已运行实例,直接退出本次启动。
    // 注意:Windows 上从 main 返回不会结束进程,必须显式 exit。
    if (!await FlutterSingleInstance().isFirstInstance()) exit(0);
    await windowManager.ensureInitialized();
  }

  final app = AppState();
  await app.init();

  if (desktop) {
    final shell = DesktopShell(app);
    // 窗口几何:有存档则恢复位置与尺寸,否则默认尺寸居中
    windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: app.windowSize ?? const Size(1280, 720),
        minimumSize: const Size(1000, 680),
        title: 'Flux — frp 客户端',
        center: app.windowPosition == null,
      ),
      () async {
        final pos = app.windowPosition;
        if (pos != null) await windowManager.setPosition(pos);
        await windowManager.show();
        await windowManager.focus();
        if (app.windowMaximized) await windowManager.maximize();
      },
    );
    runApp(FluxApp(app: app));
    shell.start();
  } else {
    runApp(FluxApp(app: app));
  }
}

class FluxApp extends StatelessWidget {
  const FluxApp({super.key, required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    // 供非 Widget 层(AppState/DesktopShell)使用的全局实例
    final l10n = AppLocalizations.of(context);
    L10n.of = l10n;
    return ChangeNotifierProvider.value(
      value: app,
      child: MaterialApp(
        onGenerateTitle: (context) =>
            AppLocalizations.of(context)?.appTitle ?? 'Flux — frp 客户端',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF3F51B5),
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF3F51B5),
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        home: const AppShell(),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = context.read<AppState>().lastPageIndex;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(),
      const ProxiesPage(),
      const ProfilePage(),
      const VersionsPage(),
      const SettingsPage(),
    ];
    final l10n = AppLocalizations.of(context)!;
    final destinations = [
      NavigationRailDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: Text(l10n.navHome)),
      NavigationRailDestination(icon: const Icon(Icons.alt_route_outlined), selectedIcon: const Icon(Icons.alt_route), label: Text(l10n.navProxies)),
      NavigationRailDestination(icon: const Icon(Icons.dns_outlined), selectedIcon: const Icon(Icons.dns), label: Text(l10n.navProfile)),
      NavigationRailDestination(icon: const Icon(Icons.download_outlined), selectedIcon: const Icon(Icons.download), label: Text(l10n.navVersions)),
      NavigationRailDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: Text(l10n.navSettings)),
    ];
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) {
              setState(() => _index = i);
              context.read<AppState>().setLastPageIndex(i);
            },
            labelType: NavigationRailLabelType.selected,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircleAvatar(child: Icon(Icons.bolt)),
            ),
            destinations: destinations,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: pages[_index]),
        ],
      ),
    );
  }
}
