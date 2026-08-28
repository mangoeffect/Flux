import 'package:dio/dio.dart';

/// Flux 自身更新检查(GitHub Releases),仅提示,不做自动更新。
class UpdateService {
  UpdateService({this.repo = 'mangoeffect/Flux'});

  final String repo;

  /// 最新 Release 的 tag(如 v1.1.0);查询失败抛异常。
  Future<String> latestTag() async {
    final resp = await Dio().get<String>(
      'https://api.github.com/repos/$repo/releases/latest',
      options: Options(headers: {'Accept': 'application/vnd.github+json'}),
    );
    if (resp.statusCode != 200) {
      throw StateError('查询更新失败: HTTP ${resp.statusCode}');
    }
    final tag = RegExp(r'"tag_name":\s*"v?([^"]+)"')
            .firstMatch(resp.data ?? '')?.group(1) ??
        (throw StateError('无法解析最新版本号'));
    return 'v$tag';
  }
}

/// 语义化版本比较:a 是否比 b 新(如 1.2.0 > 1.1.9)。
bool isNewerVersion(String a, String b) {
  int seg(String s) {
    final m = RegExp(r'^\d+').firstMatch(s.trim());
    return int.tryParse(m?.group(0) ?? '0') ?? 0;
  }

  final pa = a.split('.').map(seg).toList();
  final pb = b.split('.').map(seg).toList();
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}
