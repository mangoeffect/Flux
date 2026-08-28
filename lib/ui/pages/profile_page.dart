import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';

/// Profile 管理 + 当前 Profile 的服务器连接信息表单 + 导入 frpc.toml。
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController _name;
  late final TextEditingController _addr;
  late final TextEditingController _port;
  late final TextEditingController _user;
  late final TextEditingController _token;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _addr = TextEditingController();
    _port = TextEditingController(text: '7000');
    _user = TextEditingController();
    _token = TextEditingController();
    _syncFromProfile();
  }

  void _syncFromProfile() {
    final p = context.read<AppState>().activeProfile;
    _name.text = p?.name ?? '';
    _addr.text = p?.serverAddr ?? '';
    _port.text = (p?.serverPort ?? 7000).toString();
    _user.text = p?.user ?? '';
    _token.text = p?.token ?? '';
  }

  @override
  void dispose() {
    for (final c in [_name, _addr, _port, _user, _token]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final app = context.read<AppState>();
    final p = app.activeProfile;
    if (p == null) return;
    p.name = _name.text.trim().isEmpty ? p.name : _name.text.trim();
    p.serverAddr = _addr.text.trim();
    p.serverPort = int.tryParse(_port.text) ?? 7000;
    p.user = _user.text.isEmpty ? null : _user.text;
    p.token = _token.text.isEmpty ? null : _token.text;
    app.saveActiveProfile();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已保存')));
  }

  Future<void> _import() async {
    final app = context.read<AppState>();
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['toml'],
    );
    if (files.isEmpty) return;
    final file = files.single;
    final path = file.path;
    if (path == null || path.isEmpty) return;
    try {
      final content = await File(path).readAsString();
      final name = file.name.replaceFirst(RegExp(r'\.toml$'), '');
      await app.importProfile(content, name: name);
      if (mounted) {
        setState(_syncFromProfile);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('导入成功:${app.activeProfile?.proxies.length ?? 0} 条代理')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.activeProfile?.id != _lastProfileId) {
      _lastProfileId = app.activeProfile?.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(_syncFromProfile);
      });
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('配置', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: const Text('导入 frpc.toml'),
                onPressed: _import,
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('新建配置'),
                onPressed: () => _addProfileDialog(context, app),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (app.profiles.isEmpty)
            const Expanded(
                child: Center(child: Text('先新建一个配置,或导入现有 frpc.toml'))),
          if (app.profiles.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              children: [
                for (final p in app.profiles)
                  ChoiceChip(
                    label: Text(p.name),
                    selected: p.id == app.activeProfileId,
                    onSelected: (_) => app.setActiveProfile(p.id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('服务器连接',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _addr,
                          decoration: const InputDecoration(
                              labelText: '服务器地址 *', hintText: 'x.x.x.x 或域名'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _port,
                          decoration: const InputDecoration(labelText: '端口'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _user,
                          decoration: const InputDecoration(
                              labelText: '用户名(多用户模式,可空)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _token,
                          decoration: const InputDecoration(labelText: 'Token(可空)'),
                          obscureText: true,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: '配置名称'),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      FilledButton(onPressed: _save, child: const Text('保存')),
                      const Spacer(),
                      if (app.profiles.length > 1)
                        TextButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('删除此配置'),
                          style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error),
                          onPressed: () => _confirmDelete(context, app),
                        ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _lastProfileId;

  void _addProfileDialog(BuildContext context, AppState app) {
    final nameCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新建配置'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '配置名称', hintText: '如 家里的服务器'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消')),
          FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await app.addProfile(nameCtrl.text.trim());
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (mounted) setState(_syncFromProfile);
              },
              child: const Text('创建')),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState app) {
    final p = app.activeProfile!;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('删除配置「${p.name}」?'),
        content: const Text('将删除该配置及其代理列表,不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await app.deleteProfile(p.id);
              if (mounted) setState(_syncFromProfile);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
