import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';

class VersionsPage extends StatefulWidget {
  const VersionsPage({super.key});

  @override
  State<VersionsPage> createState() => _VersionsPageState();
}

class _VersionsPageState extends State<VersionsPage> {
  double? _downloading; // null=空闲,0~1=进度
  String? _downloadingVersion;
  String? _error;
  String? _latestHint;

  Future<void> _download(AppState app, String version) async {
    setState(() {
      _downloading = 0;
      _downloadingVersion = version;
      _error = null;
    });
    try {
      await app.binaries.download(version, onProgress: (p) {
        if (mounted) setState(() => _downloading = p);
      });
      await app.setActiveVersion(version);
      if (mounted) {
        setState(() => _downloading = null);
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.versionReady(version))));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = null;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final app = context.watch<AppState>();
    final installed = app.binaries.listInstalled();
    final bundled = app.binaries.bundledBinaryPath();
    final controller = TextEditingController(text: _downloadingVersion ?? '');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(l10n.versionsTitle,
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              FutureBuilder<String>(
                future: app.binaries.fetchLatestVersion(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  final latest = snap.data!;
                  _latestHint = latest;
                  return Text(l10n.latestVersion(latest),
                      style: Theme.of(context).textTheme.bodySmall);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.downloadNewTitle,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: l10n.versionFieldLabel,
                          hintText: l10n.versionFieldHint,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      icon: _downloading == null
                          ? const Icon(Icons.download, size: 18)
                          : const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                      label: Text(l10n.btnDownload),
                      onPressed: _downloading == null
                          ? () async {
                              var ver = controller.text.trim();
                              ver = ver.startsWith('v') ? ver.substring(1) : ver;
                              if (ver.isEmpty) {
                                ver = _latestHint ??
                                    await app.binaries.fetchLatestVersion();
                              }
                              await _download(app, ver);
                            }
                          : null,
                    ),
                  ]),
                  if (_downloading != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(value: _downloading),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: installed.isEmpty && bundled == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.system_update,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(l10n.noVersionsHint),
                        ],
                      ),
                    )
                  : ListView(
                      children: [
                        for (final version in installed)
                          ListTile(
                            leading: const Icon(Icons.terminal),
                            title: Text('v$version'),
                            subtitle: Text(app.binaries.binaryPath(version)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RadioGroup<String>(
                                  groupValue: app.activeVersion,
                                  onChanged: (v) => app.setActiveVersion(v!),
                                  child: Radio<String>(value: version),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  onPressed: () async {
                                    await app.binaries.remove(version);
                                    if (app.activeVersion == version) {
                                      final rest = app.binaries.listInstalled();
                                      await app.setActiveVersion(
                                          rest.isEmpty ? null : rest.first);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        if (bundled != null)
                          ListTile(
                            leading: const Icon(Icons.inventory_2_outlined),
                            title: Text(l10n.bundledVersionTitle),
                            subtitle: Text(bundled),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
