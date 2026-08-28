import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// token 安全存储:Windows Credential Manager / macOS Keychain / Linux libsecret。
///
/// 不可用时(如 Linux 无 keyring 服务)自动降级为明文 JSON,
/// 调用方通过返回值判断是否走了安全存储。
class TokenStore {
  TokenStore._();

  static final TokenStore instance = TokenStore._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _available = true;

  /// 凭据库是否可用(首次读写失败后置 false,降级明文)。
  bool get available => _available;

  Future<String?> read(String profileId) async {
    if (!_available) return null;
    try {
      return await _storage.read(key: 'flux-token-$profileId');
    } catch (_) {
      _available = false;
      return null;
    }
  }

  /// 写入(空值删除);返回是否成功写入安全存储。
  Future<bool> write(String profileId, String? token) async {
    if (!_available) return false;
    try {
      if (token == null || token.isEmpty) {
        await _storage.delete(key: 'flux-token-$profileId');
      } else {
        await _storage.write(key: 'flux-token-$profileId', value: token);
      }
      return true;
    } catch (_) {
      _available = false;
      return false;
    }
  }

  Future<void> delete(String profileId) async {
    try {
      await _storage.delete(key: 'flux-token-$profileId');
    } catch (_) {}
  }
}
