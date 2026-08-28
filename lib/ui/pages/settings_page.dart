import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final mirrorCtrl = TextEditingController(text: app.mirror ?? '');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('设置', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('下载镜像',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    'GitHub Releases 下载加速前缀,留空直连。'
                    '例如 https://ghfast.top 或其他 ghproxy 类镜像(会拼在 github.com 前)。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: mirrorCtrl,
                        decoration: const InputDecoration(
                            hintText: 'https://mirror.example.com'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () async {
                        final v = mirrorCtrl.text.trim();
                        await app.setMirror(v.isEmpty ? null : v);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已保存')));
                        }
                      },
                      child: const Text('保存'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          Card(
            child: SwitchListTile(
              title: const Text('frpc 异常退出后自动重启'),
              subtitle: const Text('指数退避(1s→30s),运行稳定 60 秒后重置计数'),
              value: app.frpc.autoRestart,
              onChanged: app.setAutoRestart,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Flux'),
              subtitle: const Text('Flutter 实现的 frp 客户端 · frp 遵循 Apache-2.0'),
            ),
          ),
        ],
      ),
    );
  }
}
