import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';

/// Profile 管理 + 当前 Profile 的服务器连接信息表单 + 导入/导出 frpc.toml。
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
    final l10n = AppLocalizations.of(context)!;
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
        .showSnackBar(SnackBar(content: Text(l10n.savedMsg)));
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context)!;
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
            content: Text(l10n.importSuccess(
                app.activeProfile?.proxies.length ?? 0))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.importFailed('$e'))));
      }
    }
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context)!;
    final app = context.read<AppState>();
    final p = app.activeProfile;
    if (p == null) return;
    try {
      // saveFile 由插件直接写文件(bytes 必传)
      final uri = await FilePicker.saveFile(
        dialogTitle: 'frpc.toml',
        fileName: '${p.name}.toml',
        bytes: utf8.encode(app.configService.exportToml(p)),
        type: FileType.custom,
        allowedExtensions: ['toml'],
      );
      if (uri == null || !mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.exportDone)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.exportFailed('$e'))));
      }
    }
  }

  Future<void> _verifyConfig() async {
    final l10n = AppLocalizations.of(context)!;
    final app = context.read<AppState>();
    try {
      final err = await app.verifyConfig();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err == null ? l10n.verifyPassed : l10n.verifyFailed(err))));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  String? _lastProfileId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              Text(l10n.navProfile, style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: Text(l10n.btnVerifyConfig),
                onPressed: _verifyConfig,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: Text(l10n.btnExportToml),
                onPressed: _export,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: Text(l10n.btnImportToml),
                onPressed: _import,
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.btnNewProfile),
                onPressed: () => _addProfileDialog(context, app),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (app.profiles.isEmpty)
            Expanded(child: Center(child: Text(l10n.noProfilesHint))),
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
                    Text(l10n.serverConnTitle,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _addr,
                          decoration: InputDecoration(
                              labelText: l10n.serverAddrLabel,
                              hintText: l10n.serverAddrHint),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _port,
                          decoration: InputDecoration(labelText: l10n.portLabel),
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
                          decoration: InputDecoration(labelText: l10n.userLabel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _token,
                          decoration: InputDecoration(labelText: l10n.tokenLabel),
                          obscureText: true,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _name,
                      decoration: InputDecoration(labelText: l10n.profileNameLabel),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      FilledButton(onPressed: _save, child: Text(l10n.btnSave)),
                      const Spacer(),
                      if (app.profiles.length > 1)
                        TextButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(l10n.deleteProfileBtn),
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

  void _addProfileDialog(BuildContext context, AppState app) {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.btnNewProfile),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
              labelText: l10n.profileNameLabel, hintText: l10n.profileNameHint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.btnCancel)),
          FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await app.addProfile(nameCtrl.text.trim());
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (mounted) setState(_syncFromProfile);
              },
              child: Text(l10n.btnCreate)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState app) {
    final l10n = AppLocalizations.of(context)!;
    final p = app.activeProfile!;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteProfileTitle(p.name)),
        content: Text(l10n.deleteProfileConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.btnCancel)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await app.deleteProfile(p.id);
              if (mounted) setState(_syncFromProfile);
            },
            child: Text(l10n.btnDelete),
          ),
        ],
      ),
    );
  }
}
