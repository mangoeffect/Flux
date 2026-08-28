import 'dart:convert';

import 'package:dio/dio.dart';

import '../../model/profile.dart';

/// 单条代理的运行状态(来自 frpc Admin API /api/status)。
class ProxyRuntimeStatus {
  ProxyRuntimeStatus({
    required this.name,
    required this.type,
    required this.status,
    required this.err,
    required this.localAddr,
    required this.remoteAddr,
  });

  final String name;
  final String type;
  final String status; // running / new / closed / start error ...
  final String err;
  final String localAddr;
  final String remoteAddr;

  bool get isRunning => status == 'running';

  factory ProxyRuntimeStatus.fromMap(Map<String, dynamic> m) =>
      ProxyRuntimeStatus(
        name: m['name']?.toString() ?? '',
        type: m['type']?.toString() ?? '',
        status: m['status']?.toString() ?? '',
        err: m['err']?.toString() ?? '',
        localAddr: m['local_addr']?.toString() ?? '',
        remoteAddr: m['remote_addr']?.toString() ?? '',
      );
}

/// frpc Admin API 客户端(需在生成配置时注入 [webServer])。
class AdminApiService {
  AdminApiService(this.config);

  final WebServerConfig config;

  late final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://127.0.0.1:${config.port}',
    connectTimeout: const Duration(seconds: 3),
    receiveTimeout: const Duration(seconds: 5),
    // 本地回环 + 随机口令,仅本机访问
    validateStatus: (_) => true,
  ))..options.headers['Authorization'] = _basicAuth();

  String _basicAuth() =>
      'Basic ${base64Encode(utf8.encode('${config.user}:${config.password}'))}';

  /// GET /api/status → 全部代理运行状态。
  Future<List<ProxyRuntimeStatus>> status() async {
    final resp = await _dio.get<String>('/api/status');
    if (resp.statusCode != 200 || resp.data == null) {
      throw DioException(
        requestOptions: resp.requestOptions,
        message: 'Admin API 状态查询失败: HTTP ${resp.statusCode}',
      );
    }
    final Map<String, dynamic> body =
        jsonDecode(resp.data!) as Map<String, dynamic>;
    final result = <ProxyRuntimeStatus>[];
    for (final group in body.values) {
      if (group is List) {
        for (final item in group) {
          if (item is Map) {
            result.add(
                ProxyRuntimeStatus.fromMap(item.cast<String, dynamic>()));
          }
        }
      }
    }
    return result;
  }

  /// 热重载(仅代理配置生效,全局参数改动需重启进程)。
  Future<void> reload() async {
    // frp 各版本对 /api/reload 的 method 注册略有差异,先 GET 后 POST 兜底
    final get = await _dio.get<String>('/api/reload');
    if (get.statusCode == 200 || get.statusCode == 204) return;
    final post = await _dio.post<String>('/api/reload');
    if (post.statusCode != 200 && post.statusCode != 204) {
      throw DioException(
        requestOptions: post.requestOptions,
        message: '热重载失败: HTTP ${post.statusCode} ${post.data}',
      );
    }
  }

  Future<String> getConfig() async {
    final resp = await _dio.get<String>('/api/config');
    if (resp.statusCode != 200) {
      throw DioException(
        requestOptions: resp.requestOptions,
        message: '读取运行配置失败: HTTP ${resp.statusCode}',
      );
    }
    return resp.data ?? '';
  }
}
