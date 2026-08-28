import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../model/proxy_config.dart';
import '../../state/app_state.dart';

class ProxiesPage extends StatelessWidget {
  const ProxiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final proxies = app.proxies;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('代理', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 8),
              Text('${proxies.length} 条', style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              if (app.frpc.isRunning)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('热重载'),
                    onPressed: () async {
                      try {
                        await app.hotReload();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已热重载,代理配置生效')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')));
                        }
                      }
                    },
                  ),
                ),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('新建代理'),
                onPressed: () => _editProxy(context, null),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: proxies.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.alt_route,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text('还没有代理,点击右上角新建'),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: proxies.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final proxy = proxies[i];
                      return ListTile(
                        leading: _typeBadge(proxy.type),
                        title: Text(proxy.name),
                        subtitle: Text(
                          '${proxy.localIp}:${proxy.localPort} → '
                          '${proxy.needsRemotePort && proxy.remotePort != null ? ":${proxy.remotePort}" : ""}'
                          '${proxy.needsDomain && proxy.customDomains.isNotEmpty ? proxy.customDomains.join(", ") : ""}'
                          '${proxy.needsSecretKey ? " (stcp/xtcp)" : ""}',
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
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('编辑')),
                                PopupMenuItem(value: 'delete', child: Text('删除')),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _editProxy(context, i),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

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
    if (!_formKey.currentState!.validate()) return;
    Object? extra;
    if (_extra.text.trim().isNotEmpty) {
      try {
        extra = jsonDecode(_extra.text);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('高级字段 JSON 无效: $e')));
        return;
      }
    }
    if (extra != null && extra is! Map) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('高级字段必须是 JSON 对象')));
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
                Text(widget.initial == null ? '新建代理' : '编辑代理',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                          labelText: '名称 *', hintText: '如 web、ssh'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? '必填' : null,
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
                      decoration: const InputDecoration(labelText: '本地地址'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _localPort,
                      decoration: const InputDecoration(labelText: '本地端口 *'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) =>
                          v == null || int.tryParse(v) == null ? '数字' : null,
                    ),
                  ),
                ]),
                if (_proxy.needsRemotePort) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _remotePort,
                    decoration: const InputDecoration(
                        labelText: '远程端口(服务器侧)', hintText: '留空由服务器分配'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ],
                if (_proxy.needsDomain) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _domains,
                    decoration: const InputDecoration(
                        labelText: '自定义域名', hintText: '多个用英文逗号分隔'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subdomain,
                    decoration: const InputDecoration(labelText: '子域名'),
                  ),
                ],
                if (_proxy.type == ProxyType.http) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locations,
                    decoration: const InputDecoration(
                        labelText: '路由 location', hintText: '如 /api,/static'),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: TextFormField(
                            controller: _basicUser,
                            decoration: const InputDecoration(labelText: 'BasicAuth 用户'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextFormField(
                            controller: _basicPassword,
                            decoration: const InputDecoration(labelText: 'BasicAuth 密码'))),
                  ]),
                ],
                if (_proxy.needsSecretKey) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _secretKey,
                    decoration: const InputDecoration(labelText: '共享密钥 secretKey'),
                  ),
                ],
                if (_proxy.type == ProxyType.https) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _serverName,
                    decoration: const InputDecoration(labelText: 'TLS SNI serverName'),
                  ),
                ],
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('高级字段(JSON,写入 TOML 原样保留)'),
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
                      child: const Text('取消')),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _save, child: const Text('保存')),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
