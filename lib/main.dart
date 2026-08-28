import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'platform/desktop_shell.dart';
import 'state/app_state.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/profile_page.dart';
import 'ui/pages/proxies_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/pages/versions_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final app = AppState()..init();
  final desktop =
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  DesktopShell? shell;

  if (desktop) {
    // 单实例:非首实例时插件会激活已运行实例,直接退出本次启动。
    // 注意:Windows 上从 main 返回不会结束进程,必须显式 exit。
    if (!await FlutterSingleInstance().isFirstInstance()) exit(0);
    await windowManager.ensureInitialized();
    shell = DesktopShell(app);
    windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1280, 720),
        minimumSize: Size(1000, 680),
        title: 'Flux — frp 客户端',
        center: true,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  runApp(FluxApp(app: app));
  if (desktop) shell!.start();
}

class FluxApp extends StatelessWidget {
  const FluxApp({super.key, required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: app,
      child: MaterialApp(
        title: 'Flux — frp 客户端',
        debugShowCheckedModeBanner: false,
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

  static const _destinations = [
    NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('首页')),
    NavigationRailDestination(icon: Icon(Icons.alt_route_outlined), selectedIcon: Icon(Icons.alt_route), label: Text('代理')),
    NavigationRailDestination(icon: Icon(Icons.dns_outlined), selectedIcon: Icon(Icons.dns), label: Text('配置')),
    NavigationRailDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download), label: Text('版本')),
    NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('设置')),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(),
      const ProxiesPage(),
      const ProfilePage(),
      const VersionsPage(),
      const SettingsPage(),
    ];
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.selected,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircleAvatar(child: Icon(Icons.bolt)),
            ),
            destinations: _destinations,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: pages[_index]),
        ],
      ),
    );
  }
}
