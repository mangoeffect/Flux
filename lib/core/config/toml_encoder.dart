/// 手写 TOML 编码器:控制字段顺序与分组(顶层标量 → [webServer] → [[proxies]] → [[visitors]]),
/// 嵌套 Map 展平为点号键,保证 frpc 可读且 diff 友好。
library;

String encodeToml(Map<String, Object?> doc) {
  final buf = StringBuffer();
  for (final entry in _flatten(doc)) {
    buf.writeln('${_key(entry.$1)} = ${_value(entry.$2)}');
  }
  return buf.toString();
}

/// 将嵌套 Map 展平为 (dottedKey, scalarOrInlineValue) 序列;List 不再递归,按内联值输出。
Iterable<(String, Object)> _flatten(Map<Object?, Object?> map, [String prefix = '']) sync* {
  for (final e in map.entries) {
    if (e.value == null) continue;
    final key = prefix.isEmpty ? '${e.key}' : '$prefix.${e.key}';
    if (e.value is Map) {
      yield* _flatten(e.value as Map, key);
    } else {
      yield (key, e.value as Object);
    }
  }
}

bool _isBareKey(String k) =>
    k.isNotEmpty &&
    k.runes.every((r) =>
        (r >= 0x41 && r <= 0x5A) ||
        (r >= 0x61 && r <= 0x7A) ||
        (r >= 0x30 && r <= 0x39) ||
        r == 0x5F ||
        r == 0x2D);

/// 点号键按段处理:仅对非裸键的段加引号(如 a."b-c".d)。
String _key(String dotted) => dotted
    .split('.')
    .map((seg) => _isBareKey(seg) ? seg : '"${_escapeString(seg)}"')
    .join('.');

String _value(Object v) {
  if (v is String) return '"${_escapeString(v)}"';
  if (v is bool) return v.toString();
  if (v is int) return v.toString();
  if (v is double) {
    if (v.isFinite) return v.toString();
    throw ArgumentError('TOML 不支持浮点特殊值: $v');
  }
  if (v is DateTime) return v.toUtc().toIso8601String();
  if (v is List) return '[${v.map((e) => _value(e as Object)).join(', ')}]';
  if (v is Map) {
    final inner = <String>[];
    for (final e in v.entries) {
      if (e.value == null) continue;
      inner.add('${_key(e.key.toString())} = ${_value(e.value as Object)}');
    }
    return '{ ${inner.join(', ')} }';
  }
  throw ArgumentError('无法编码为 TOML 的值: ${v.runtimeType}');
}

String _escapeString(String s) => s
    .replaceAll(r'\', r'\\')
    .replaceAll('"', r'\"')
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\r')
    .replaceAll('\t', r'\t');
