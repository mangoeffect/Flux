import 'app_localizations.dart';

/// 非 Widget 层(AppState/DesktopShell 等)访问本地化文案的入口。
///
/// 由 [FluxApp] 首次构建时填充;在此之前为 null,调用方以中文回退。
class L10n {
  L10n._();

  static AppLocalizations? of;
}
