import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/process/frpc_process_service.dart';
import '../../state/app_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _logScroll = ScrollController();
  StreamSubscription<String>? _logSub;
  Timer? _uptimeTimer;

  @override
  void initState() {
    super.initState();
    // 日志到达后滚动到底部(延迟等帧渲染完)
    final app = context.read<AppState>();
    _logSub = app.frpc.logStream.listen((_) => _scrollToBottom());
    _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _logSub?.cancel();
    _uptimeTimer?.cancel();
    _logScroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_logScroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.animateTo(
          _logScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final frpc = app.frpc;
    final profile = app.activeProfile;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _statusCard(context, app, frpc, profile),
          const SizedBox(height: 12),
          if (frpc.isRunning && app.proxyStatuses.isNotEmpty)
            _proxyStatusTable(context, app),
          if (frpc.isRunning && app.proxyStatuses.isNotEmpty)
            const SizedBox(height: 12),
          Expanded(child: _logConsole(context, frpc)),
        ],
      ),
    );
  }

  Widget _statusCard(BuildContext context, AppState app,
      FrpcProcessService frpc, profile) {
      final running = frpc.state == FrpcRunState.running;
      final color = switch (frpc.state) {
        FrpcRunState.running => Colors.green,
        FrpcRunState.starting || FrpcRunState.stopping => Colors.orange,
        FrpcRunState.stopped => Colors.grey,
      };
      String uptime = '';
      if (running && frpc.startedAt != null) {
        final d = DateTime.now().difference(frpc.startedAt!);
        uptime = d.inHours > 0
            ? '${d.inHours}时${d.inMinutes % 60}分'
            : '${d.inMinutes}分${d.inSeconds % 60}秒';
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.circle, color: color, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    switch (frpc.state) {
                      FrpcRunState.stopped => '已停止',
                      FrpcRunState.starting => '启动中...',
                      FrpcRunState.running => '运行中',
                      FrpcRunState.stopping => '停止中...',
                    },
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (uptime.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text('已运行 $uptime',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  FilledButton.icon(
                    onPressed: () => _toggle(app),
                    icon: Icon(running ? Icons.stop : Icons.play_arrow),
                    label: Text(running ? '停止' : '启动'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                profile == null
                    ? '尚未创建配置'
                    : '${profile.name} · ${profile.serverAddr}:${profile.serverPort} · '
                        '${profile.enabledProxies.length} 条代理 · frpc ${app.activeVersion ?? "未选择"}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
  }

  Future<void> _toggle(AppState app) async {
    try {
      if (app.frpc.isRunning) {
        await app.stopFrpc();
      } else {
        await app.startFrpc();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Widget _proxyStatusTable(BuildContext context, AppState app) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('代理状态', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...app.proxyStatuses.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        s.isRunning ? Icons.check_circle : Icons.error_outline,
                        size: 16,
                        color: s.isRunning ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text('${s.name} (${s.type})'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s.isRunning
                              ? '${s.localAddr} → ${s.remoteAddr}'
                              : (s.err.isEmpty ? s.status : s.err),
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _logConsole(BuildContext context, FrpcProcessService frpc) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Text('日志', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: '清空日志',
                  onPressed: () {
                    frpc.clearLogs();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Container(
              color: const Color(0xFF1E1E1E),
              padding: const EdgeInsets.all(8),
              child: ListView.builder(
                controller: _logScroll,
                itemCount: frpc.logs.length,
                itemBuilder: (_, i) => Text(
                  frpc.logs[i],
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFFD4D4D4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
