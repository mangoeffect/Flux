import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../model/proxy_config.dart';
import '../../model/visitor_config.dart';
import '../../state/app_state.dart';

/// 代理(服务端)与访问端(stcp/xtcp/sudp visitors)管理,双 Tab。
class ProxiesPage extends StatefulWidget {
  const ProxiesPage({super.key});

  @override
  State<ProxiesPage> createState() => _ProxiesPageState();
}

class _ProxiesPageState extends State<ProxiesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (mounted && !_tab.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final app = context.watch<AppState>();
    final proxies = app.proxies;
    final visitors = app.visitors;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(l10n.proxiesTitle,
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: Text(l10n.btnVerifyConfig),
                onPressed: () => _verifyConfig(context, app),
              ),
              const SizedBox(width: 8),
              if (app.frpc.isRunning)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(l10n.btnHotReload),
                    onPressed: () async {
                      try {
                        await app.hotReload();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      AppLocalizations.of(context)!.reloadedMsg)));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('$e')));
                        }
                      }
                    },
                  ),
                ),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(_tab.index == 0 ? l10n.btnNewProxy : l10n.btnNewVisitor),
                onPressed: () => _tab.index == 0
                    ? _editProxy(context, null)
                    : _editVisitor(context, null),
              ),
            ],
          ),
          TabBar(
            controller: _tab,
            tabs: [
              Tab(text: l10n.tabProxies(proxies.length)),
              Tab(text: l10n.tabVisitors(visitors.length)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _proxyList(context, app, proxies),
                _visitorList(context, app, visitors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------ 代理(服务端)列表

  Widget _proxyList(
      BuildContext context, AppState app, List<ProxyConfig> proxies) {
    final l10n = AppLocalizations.of(context)!;
    if (proxies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.alt_route, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(l10n.noProxiesHint),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: proxies.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final proxy = proxies[i];
        final tail =
            '${proxy.needsRemotePort && proxy.remotePort != null ? ":${proxy.remotePort}" : ""}'
            '${proxy.needsDomain && proxy.customDomains.isNotEmpty ? proxy.customDomains.join(", ") : ""}'
            '${proxy.needsSecretKey ? " (stcp/xtcp)" : ""}';
        return ListTile(
          leading: _typeBadge(proxy.type),
          title: Text(proxy.name),
          subtitle: Text(
            l10n.proxySubtitle('${proxy.localIp}:${proxy.localPort}', tail),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: proxy.enabled,
                onChanged: (v) {
                  proxy.enabled = v;
                  app.saveActiveProfile();
                },
              ),
              PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'edit') {
                    _editProxy(context, i);
                  } else if (action == 'delete') {
                    app.removeProxyAt(i);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(l10n.menuEdit)),
                  PopupMenuItem(value: 'delete', child: Text(l10n.menuDelete)),
                ],
              ),
            ],
          ),
          onTap: () => _editProxy(context, i),
        );
      },
    );
  }

  // ------------------------------------------------ 访问端列表

  Widget _visitorList(
      BuildContext context, AppState app, List<VisitorConfig> visitors) {
    final l10n = AppLocalizations.of(context)!;
    if (visitors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.vpn_lock_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(l10n.noVisitorsHint),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: visitors.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final v = visitors[i];
        return ListTile(
          leading: _visitorBadge(v.type),
          title: Text(v.name),
          subtitle: Text(
            l10n.visitorSubtitle('${v.bindAddr}:${v.bindPort}', v.serverName, v.type.name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'edit') {
                _editVisitor(context, i);
              } else if (action == 'delete') {
                app.removeVisitorAt(i);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(l10n.menuEdit)),
              PopupMenuItem(value: 'delete', child: Text(l10n.menuDelete)),
            ],
          ),
          onTap: () => _editVisitor(context, i),
        );
      },
    );
  }

  // ------------------------------------------------ 通用

  Widget _typeBadge(ProxyType type) {
    final color = switch (type) {
      ProxyType.tcp => Colors.blue,
      ProxyType.udp => Colors.teal,
      ProxyType.http => Colors.deepOrange,
      ProxyType.https => Colors.green,
      ProxyType.stcp => Colors.purple,
      ProxyType.xtcp => Colors.indigo,
      ProxyType.sudp => Colors.brown,
    };
    return Container(
      width: 56,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(type.name.toUpperCase(),
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _visitorBadge(VisitorType type) {
    final color = switch (type) {
      VisitorType.stcp => Colors.purple,
      VisitorType.xtcp => Colors.indigo,
      VisitorType.sudp => Colors.brown,
    };
    return Container(
      width: 56,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(type.name.toUpperCase(),
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  void _editProxy(BuildContext context, int? index) {
    final app = context.read<AppState>();
    final existing = index == null ? null : app.proxies[index];
    showDialog<void>(
      context: context,
      builder: (_) => _ProxyEditDialog(
        initial: existing?.copy(),
        onSave: (proxy) {
          if (index == null) {
            app.addProxy(proxy);
          } else {
            app.replaceProxyAt(index, proxy);
          }
        },
      ),
    );
  }

  void _editVisitor(BuildContext context, int? index) {
    final app = context.read<AppState>();
    final existing = index == null ? null : app.visitors[index];
    showDialog<void>(
      context: context,
      builder: (_) => _VisitorEditDialog(
        initial: existing?.copy(),
        onSave: (visitor) {
          if (index == null) {
            app.addVisitor(visitor);
          } else {
            app.replaceVisitorAt(index, visitor);
          }
        },
      ),
    );
  }

  Future<void> _verifyConfig(BuildContext context, AppState app) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final err = await app.verifyConfig();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(err == null ? l10n.verifyPassed : l10n.verifyFailed(err))));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _ProxyEditDialog extends StatefulWidget {
  const _ProxyEditDialog({required this.onSave, this.initial});

  final ProxyConfig? initial;
  final void Function(ProxyConfig) onSave;

  @override
  State<_ProxyEditDialog> createState() => _ProxyEditDialogState();
}

class _ProxyEditDialogState extends State<_ProxyEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late ProxyConfig _proxy;
  late final TextEditingController _name;
  late final TextEditingController _localIp;
  late final TextEditingController _localPort;
  late final TextEditingController _remotePort;
  late final TextEditingController _domains;
  late final TextEditingController _subdomain;
  late final TextEditingController _locations;
  late final TextEditingController _basicUser;
  late final TextEditingController _basicPassword;
  late final TextEditingController _secretKey;
  late final TextEditingController _serverName;
  late final TextEditingController _extra;

  @override
  void initState() {
    super.initState();
    _proxy = widget.initial?.copy() ??
        ProxyConfig(name: '', type: ProxyType.tcp, localPort: 8080);
    _name = TextEditingController(text: _proxy.name);
    _localIp = TextEditingController(text: _proxy.localIp);
    _localPort = TextEditingController(text: _proxy.localPort.toString());
    _remotePort =
        TextEditingController(text: _proxy.remotePort?.toString() ?? '');
    _domains = TextEditingController(text: _proxy.customDomains.join(','));
    _subdomain = TextEditingController(text: _proxy.subdomain ?? '');
    _locations = TextEditingController(text: _proxy.locations.join(','));
    _basicUser = TextEditingController(text: _proxy.basicAuthUser ?? '');
    _basicPassword = TextEditingController(text: _proxy.basicAuthPassword ?? '');
    _secretKey = TextEditingController(text: _proxy.secretKey ?? '');
    _serverName = TextEditingController(text: _proxy.serverName ?? '');
    _extra = TextEditingController(
        text: _proxy.extra.isEmpty ? '' : const JsonEncoder.withIndent('  ').convert(_proxy.extra));
  }

  @override
  void dispose() {
    for (final c in [
      _name, _localIp, _localPort, _remotePort, _domains, _subdomain,
      _locations, _basicUser, _basicPassword, _secretKey, _serverName, _extra,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    Object? extra;
    if (_extra.text.trim().isNotEmpty) {
      try {
        extra = jsonDecode(_extra.text);
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.invalidJsonErr('$e'))));
        return;
      }
    }
    if (extra != null && extra is! Map) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.jsonMustBeObject)));
      return;
    }
    _proxy.name = _name.text.trim();
    _proxy.localIp = _localIp.text.trim();
    _proxy.localPort = int.parse(_localPort.text);
    _proxy.remotePort =
        _remotePort.text.isEmpty ? null : int.tryParse(_remotePort.text);
    _proxy.customDomains = _splitList(_domains.text);
    _proxy.subdomain = _subdomain.text.trim().isEmpty ? null : _subdomain.text.trim();
    _proxy.locations = _splitList(_locations.text);
    _proxy.basicAuthUser = _basicUser.text.isEmpty ? null : _basicUser.text;
    _proxy.basicAuthPassword = _basicPassword.text.isEmpty ? null : _basicPassword.text;
    _proxy.secretKey = _secretKey.text.trim().isEmpty ? null : _secretKey.text.trim();
    _proxy.serverName = _serverName.text.trim().isEmpty ? null : _serverName.text.trim();
    _proxy.extra = (extra as Map?)?.cast<String, Object>() ?? {};
    widget.onSave(_proxy);
    Navigator.of(context).pop();
  }

  static List<String> _splitList(String text) => text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(widget.initial == null ? l10n.dlgNewProxy : l10n.dlgEditProxy,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _name,
                      decoration: InputDecoration(
                          labelText: l10n.fieldName, hintText: l10n.fieldNameHint),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l10n.requiredField : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<ProxyType>(
                      value: _proxy.type,
                      items: ProxyType.values
                          .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                          .toList(),
                      onChanged: (t) => setState(() => _proxy.type = t!),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _localIp,
                      decoration: InputDecoration(labelText: l10n.localAddr),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _localPort,
                      decoration: InputDecoration(labelText: l10n.localPort),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) =>
                          v == null || int.tryParse(v) == null ? l10n.mustBeNumber : null,
                    ),
                  ),
                ]),
                if (_proxy.needsRemotePort) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _remotePort,
                    decoration: InputDecoration(
                        labelText: l10n.remotePort, hintText: l10n.remotePortHint),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ],
                if (_proxy.needsDomain) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _domains,
                    decoration: InputDecoration(
                        labelText: l10n.customDomains,
                        hintText: l10n.customDomainsHint),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subdomain,
                    decoration: InputDecoration(labelText: l10n.subdomain),
                  ),
                ],
                if (_proxy.type == ProxyType.http) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locations,
                    decoration: InputDecoration(
                        labelText: l10n.locations, hintText: l10n.locationsHint),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: TextFormField(
                            controller: _basicUser,
                            decoration:
                                InputDecoration(labelText: l10n.basicAuthUser))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextFormField(
                            controller: _basicPassword,
                            decoration: InputDecoration(
                                labelText: l10n.basicAuthPassword))),
                  ]),
                ],
                if (_proxy.needsSecretKey) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _secretKey,
                    decoration: InputDecoration(labelText: l10n.secretKey),
                  ),
                ],
                if (_proxy.type == ProxyType.https) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _serverName,
                    decoration: InputDecoration(labelText: l10n.tlsServerName),
                  ),
                ],
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(l10n.advancedJson),
                  children: [
                    TextFormField(
                      controller: _extra,
                      maxLines: 5,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      decoration: const InputDecoration(
                          hintText: '{"transport": {"useEncryption": true}}'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.btnCancel)),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _save, child: Text(l10n.btnSave)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VisitorEditDialog extends StatefulWidget {
  const _VisitorEditDialog({required this.onSave, this.initial});

  final VisitorConfig? initial;
  final void Function(VisitorConfig) onSave;

  @override
  State<_VisitorEditDialog> createState() => _VisitorEditDialogState();
}

class _VisitorEditDialogState extends State<_VisitorEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late VisitorConfig _visitor;
  late final TextEditingController _name;
  late final TextEditingController _serverName;
  late final TextEditingController _secretKey;
  late final TextEditingController _bindAddr;
  late final TextEditingController _bindPort;
  late final TextEditingController _extra;

  @override
  void initState() {
    super.initState();
    _visitor = widget.initial?.copy() ?? VisitorConfig(name: '', bindPort: 7000);
    _name = TextEditingController(text: _visitor.name);
    _serverName = TextEditingController(text: _visitor.serverName);
    _secretKey = TextEditingController(text: _visitor.secretKey);
    _bindAddr = TextEditingController(text: _visitor.bindAddr);
    _bindPort = TextEditingController(text: _visitor.bindPort.toString());
    _extra = TextEditingController(
        text: _visitor.extra.isEmpty ? '' : const JsonEncoder.withIndent('  ').convert(_visitor.extra));
  }

  @override
  void dispose() {
    for (final c in [_name, _serverName, _secretKey, _bindAddr, _bindPort, _extra]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    Object? extra;
    if (_extra.text.trim().isNotEmpty) {
      try {
        extra = jsonDecode(_extra.text);
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.invalidJsonErr('$e'))));
        return;
      }
    }
    if (extra != null && extra is! Map) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.jsonMustBeObject)));
      return;
    }
    _visitor.name = _name.text.trim();
    _visitor.serverName = _serverName.text.trim();
    _visitor.secretKey = _secretKey.text.trim();
    _visitor.bindAddr = _bindAddr.text.trim();
    _visitor.bindPort = int.parse(_bindPort.text);
    _visitor.extra = (extra as Map?)?.cast<String, Object>() ?? {};
    widget.onSave(_visitor);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                    widget.initial == null
                        ? l10n.dlgNewVisitor
                        : l10n.dlgEditVisitor,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(l10n.visitorDesc,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _name,
                      decoration: InputDecoration(
                          labelText: l10n.fieldName, hintText: l10n.fieldNameHint),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l10n.requiredField : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<VisitorType>(
                      value: _visitor.type,
                      items: VisitorType.values
                          .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                          .toList(),
                      onChanged: (t) => setState(() => _visitor.type = t!),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _serverName,
                  decoration: InputDecoration(
                      labelText: l10n.visitorServerName,
                      hintText: l10n.visitorServerNameHint),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? l10n.requiredField : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _secretKey,
                  decoration: InputDecoration(labelText: l10n.secretKey),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _bindAddr,
                      decoration: InputDecoration(labelText: l10n.bindAddr),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _bindPort,
                      decoration: InputDecoration(labelText: l10n.bindPort),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) =>
                          v == null || int.tryParse(v) == null ? l10n.mustBeNumber : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(l10n.advancedJson),
                  children: [
                    TextFormField(
                      controller: _extra,
                      maxLines: 5,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      decoration: const InputDecoration(
                          hintText: '{"keepTunnelOpen": true}'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.btnCancel)),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _save, child: Text(l10n.btnSave)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
