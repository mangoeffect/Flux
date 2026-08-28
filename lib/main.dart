import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/profile_page.dart';
import 'ui/pages/proxies_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/pages/versions_page.dart';

void main() {
  runApp(const FluxApp());
}

class FluxApp extends StatelessWidget {
  const FluxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
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
