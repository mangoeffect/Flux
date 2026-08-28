import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final app = context.watch<AppState>();
    final mirrorCtrl = TextEditingController(text: app.mirror ?? '');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.navSettings, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.mirrorTitle,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    l10n.mirrorDesc,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: mirrorCtrl,
                        decoration: InputDecoration(
                            hintText: l10n.mirrorHint),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () async {
                        final v = mirrorCtrl.text.trim();
                        await app.setMirror(v.isEmpty ? null : v);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.savedMsg)));
                        }
                      },
                      child: Text(l10n.btnSave),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(l10n.closeToTrayTitle),
                  subtitle: Text(l10n.closeToTrayDesc),
                  value: app.closeToTray,
                  onChanged: app.setCloseToTray,
                ),
                SwitchListTile(
                  title: Text(l10n.launchAtStartupTitle),
                  subtitle: Text(l10n.launchAtStartupDesc),
                  value: app.launchAtStartup,
                  onChanged: app.setLaunchAtStartup,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.folder_open),
                  title: Text(l10n.logDirTitle),
                  subtitle: Text(l10n.logDirDesc),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () => app.openLogDir(),
                ),
              ],
            ),
          ),
          Card(
            child: SwitchListTile(
              title: Text(l10n.autoRestartTitle),
              subtitle: Text(l10n.autoRestartDesc),
              value: app.frpc.autoRestart,
              onChanged: app.setAutoRestart,
            ),
          ),
          _AboutCard(l10n: l10n, app: app),
        ],
      ),
    );
  }
}

class _AboutCard extends StatefulWidget {
  const _AboutCard({required this.l10n, required this.app});

  final AppLocalizations l10n;
  final AppState app;

  @override
  State<_AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<_AboutCard> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = 'v${info.version}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final app = widget.app;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Flux'),
            subtitle: Text('$_version · ${l10n.aboutDesc}'),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (app.updateAvailable != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(Icons.system_update_alt,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary),
                    label: Text(l10n.updateChip(app.updateAvailable!)),
                    onPressed: app.openReleasesPage,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: OutlinedButton(
                  onPressed: () async {
                    try {
                      await app.checkForUpdate(silent: false);
                      if (!context.mounted) return;
                      final msg = app.updateAvailable == null
                          ? l10n.upToDate
                          : l10n.updateBannerMsg(app.updateAvailable!);
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(msg)));
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text(l10n.updateCheckFailed('$e'))));
                      }
                    }
                  },
                  child: Text(l10n.btnCheckUpdate),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
