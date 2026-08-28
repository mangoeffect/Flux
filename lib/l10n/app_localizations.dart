import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'Flux — frp 客户端'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get navHome;

  /// No description provided for @navProxies.
  ///
  /// In zh, this message translates to:
  /// **'代理'**
  String get navProxies;

  /// No description provided for @navProfile.
  ///
  /// In zh, this message translates to:
  /// **'配置'**
  String get navProfile;

  /// No description provided for @navVersions.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get navVersions;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @btnStart.
  ///
  /// In zh, this message translates to:
  /// **'启动'**
  String get btnStart;

  /// No description provided for @btnStop.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get btnStop;

  /// No description provided for @btnSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get btnSave;

  /// No description provided for @btnCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get btnCancel;

  /// No description provided for @btnCreate.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get btnCreate;

  /// No description provided for @btnDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get btnDelete;

  /// No description provided for @btnView.
  ///
  /// In zh, this message translates to:
  /// **'查看'**
  String get btnView;

  /// No description provided for @btnCleanup.
  ///
  /// In zh, this message translates to:
  /// **'清理'**
  String get btnCleanup;

  /// No description provided for @btnDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get btnDownload;

  /// No description provided for @menuEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get menuEdit;

  /// No description provided for @menuDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get menuDelete;

  /// No description provided for @requiredField.
  ///
  /// In zh, this message translates to:
  /// **'必填'**
  String get requiredField;

  /// No description provided for @mustBeNumber.
  ///
  /// In zh, this message translates to:
  /// **'数字'**
  String get mustBeNumber;

  /// No description provided for @savedMsg.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get savedMsg;

  /// No description provided for @advancedJson.
  ///
  /// In zh, this message translates to:
  /// **'高级字段(JSON,写入 TOML 原样保留)'**
  String get advancedJson;

  /// No description provided for @invalidJsonErr.
  ///
  /// In zh, this message translates to:
  /// **'高级字段 JSON 无效: {err}'**
  String invalidJsonErr(Object err);

  /// No description provided for @jsonMustBeObject.
  ///
  /// In zh, this message translates to:
  /// **'高级字段必须是 JSON 对象'**
  String get jsonMustBeObject;

  /// No description provided for @statusStopped.
  ///
  /// In zh, this message translates to:
  /// **'已停止'**
  String get statusStopped;

  /// No description provided for @statusStarting.
  ///
  /// In zh, this message translates to:
  /// **'启动中...'**
  String get statusStarting;

  /// No description provided for @statusRunning.
  ///
  /// In zh, this message translates to:
  /// **'运行中'**
  String get statusRunning;

  /// No description provided for @statusStopping.
  ///
  /// In zh, this message translates to:
  /// **'停止中...'**
  String get statusStopping;

  /// No description provided for @uptimeLabel.
  ///
  /// In zh, this message translates to:
  /// **'已运行 {duration}'**
  String uptimeLabel(Object duration);

  /// No description provided for @durHours.
  ///
  /// In zh, this message translates to:
  /// **'{h}时{m}分'**
  String durHours(int h, int m);

  /// No description provided for @durMinutes.
  ///
  /// In zh, this message translates to:
  /// **'{m}分{s}秒'**
  String durMinutes(int m, int s);

  /// No description provided for @frpcVersionUnset.
  ///
  /// In zh, this message translates to:
  /// **'未选择'**
  String get frpcVersionUnset;

  /// No description provided for @noProfile.
  ///
  /// In zh, this message translates to:
  /// **'尚未创建配置'**
  String get noProfile;

  /// No description provided for @profileSummary.
  ///
  /// In zh, this message translates to:
  /// **'{name} · {server}:{port} · {count} 条代理 · frpc {version}'**
  String profileSummary(
    Object name,
    Object server,
    int port,
    int count,
    Object version,
  );

  /// No description provided for @proxyStatusTitle.
  ///
  /// In zh, this message translates to:
  /// **'代理状态'**
  String get proxyStatusTitle;

  /// No description provided for @proxyNameType.
  ///
  /// In zh, this message translates to:
  /// **'{name} ({type})'**
  String proxyNameType(Object name, Object type);

  /// No description provided for @proxyAddrLine.
  ///
  /// In zh, this message translates to:
  /// **'{local} → {remote}'**
  String proxyAddrLine(Object local, Object remote);

  /// No description provided for @logsTitle.
  ///
  /// In zh, this message translates to:
  /// **'日志'**
  String get logsTitle;

  /// No description provided for @clearLogs.
  ///
  /// In zh, this message translates to:
  /// **'清空日志'**
  String get clearLogs;

  /// No description provided for @updateBannerMsg.
  ///
  /// In zh, this message translates to:
  /// **'新版本 {version} 可用'**
  String updateBannerMsg(Object version);

  /// No description provided for @orphanBanner.
  ///
  /// In zh, this message translates to:
  /// **'检测到上次异常退出的 frpc 进程(PID {pids})'**
  String orphanBanner(Object pids);

  /// No description provided for @proxiesTitle.
  ///
  /// In zh, this message translates to:
  /// **'代理'**
  String get proxiesTitle;

  /// No description provided for @btnVerifyConfig.
  ///
  /// In zh, this message translates to:
  /// **'检查配置'**
  String get btnVerifyConfig;

  /// No description provided for @btnHotReload.
  ///
  /// In zh, this message translates to:
  /// **'热重载'**
  String get btnHotReload;

  /// No description provided for @reloadedMsg.
  ///
  /// In zh, this message translates to:
  /// **'已热重载,代理配置生效'**
  String get reloadedMsg;

  /// No description provided for @btnNewProxy.
  ///
  /// In zh, this message translates to:
  /// **'新建代理'**
  String get btnNewProxy;

  /// No description provided for @btnNewVisitor.
  ///
  /// In zh, this message translates to:
  /// **'新建访问端'**
  String get btnNewVisitor;

  /// No description provided for @tabProxies.
  ///
  /// In zh, this message translates to:
  /// **'代理 ({count})'**
  String tabProxies(int count);

  /// No description provided for @tabVisitors.
  ///
  /// In zh, this message translates to:
  /// **'访问端 ({count})'**
  String tabVisitors(int count);

  /// No description provided for @noProxiesHint.
  ///
  /// In zh, this message translates to:
  /// **'还没有代理,点击右上角新建'**
  String get noProxiesHint;

  /// No description provided for @noVisitorsHint.
  ///
  /// In zh, this message translates to:
  /// **'还没有访问端(stcp/xtcp/sudp),点击右上角新建'**
  String get noVisitorsHint;

  /// No description provided for @proxySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'{local} → {tail}'**
  String proxySubtitle(Object local, Object tail);

  /// No description provided for @visitorSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'{bind} → {server} ({type})'**
  String visitorSubtitle(Object bind, Object server, Object type);

  /// No description provided for @verifyPassed.
  ///
  /// In zh, this message translates to:
  /// **'配置校验通过'**
  String get verifyPassed;

  /// No description provided for @verifyFailed.
  ///
  /// In zh, this message translates to:
  /// **'配置校验失败:{err}'**
  String verifyFailed(Object err);

  /// No description provided for @dlgNewProxy.
  ///
  /// In zh, this message translates to:
  /// **'新建代理'**
  String get dlgNewProxy;

  /// No description provided for @dlgEditProxy.
  ///
  /// In zh, this message translates to:
  /// **'编辑代理'**
  String get dlgEditProxy;

  /// No description provided for @fieldName.
  ///
  /// In zh, this message translates to:
  /// **'名称 *'**
  String get fieldName;

  /// No description provided for @fieldNameHint.
  ///
  /// In zh, this message translates to:
  /// **'如 web、ssh'**
  String get fieldNameHint;

  /// No description provided for @localAddr.
  ///
  /// In zh, this message translates to:
  /// **'本地地址'**
  String get localAddr;

  /// No description provided for @localPort.
  ///
  /// In zh, this message translates to:
  /// **'本地端口 *'**
  String get localPort;

  /// No description provided for @remotePort.
  ///
  /// In zh, this message translates to:
  /// **'远程端口(服务器侧)'**
  String get remotePort;

  /// No description provided for @remotePortHint.
  ///
  /// In zh, this message translates to:
  /// **'留空由服务器分配'**
  String get remotePortHint;

  /// No description provided for @customDomains.
  ///
  /// In zh, this message translates to:
  /// **'自定义域名'**
  String get customDomains;

  /// No description provided for @customDomainsHint.
  ///
  /// In zh, this message translates to:
  /// **'多个用英文逗号分隔'**
  String get customDomainsHint;

  /// No description provided for @subdomain.
  ///
  /// In zh, this message translates to:
  /// **'子域名'**
  String get subdomain;

  /// No description provided for @locations.
  ///
  /// In zh, this message translates to:
  /// **'路由 location'**
  String get locations;

  /// No description provided for @locationsHint.
  ///
  /// In zh, this message translates to:
  /// **'如 /api,/static'**
  String get locationsHint;

  /// No description provided for @basicAuthUser.
  ///
  /// In zh, this message translates to:
  /// **'BasicAuth 用户'**
  String get basicAuthUser;

  /// No description provided for @basicAuthPassword.
  ///
  /// In zh, this message translates to:
  /// **'BasicAuth 密码'**
  String get basicAuthPassword;

  /// No description provided for @secretKey.
  ///
  /// In zh, this message translates to:
  /// **'共享密钥 secretKey'**
  String get secretKey;

  /// No description provided for @tlsServerName.
  ///
  /// In zh, this message translates to:
  /// **'TLS SNI serverName'**
  String get tlsServerName;

  /// No description provided for @dlgNewVisitor.
  ///
  /// In zh, this message translates to:
  /// **'新建访问端'**
  String get dlgNewVisitor;

  /// No description provided for @dlgEditVisitor.
  ///
  /// In zh, this message translates to:
  /// **'编辑访问端'**
  String get dlgEditVisitor;

  /// No description provided for @visitorDesc.
  ///
  /// In zh, this message translates to:
  /// **'stcp/xtcp/sudp 的访问端:本地端口收到流量经加密隧道转发到服务端代理。'**
  String get visitorDesc;

  /// No description provided for @visitorServerName.
  ///
  /// In zh, this message translates to:
  /// **'服务端代理名 serverName *'**
  String get visitorServerName;

  /// No description provided for @visitorServerNameHint.
  ///
  /// In zh, this message translates to:
  /// **'要访问的服务端 [[proxies]] 的 name'**
  String get visitorServerNameHint;

  /// No description provided for @bindAddr.
  ///
  /// In zh, this message translates to:
  /// **'本地监听地址'**
  String get bindAddr;

  /// No description provided for @bindPort.
  ///
  /// In zh, this message translates to:
  /// **'本地监听端口 *'**
  String get bindPort;

  /// No description provided for @btnExportToml.
  ///
  /// In zh, this message translates to:
  /// **'导出 TOML'**
  String get btnExportToml;

  /// No description provided for @btnImportToml.
  ///
  /// In zh, this message translates to:
  /// **'导入 frpc.toml'**
  String get btnImportToml;

  /// No description provided for @btnNewProfile.
  ///
  /// In zh, this message translates to:
  /// **'新建配置'**
  String get btnNewProfile;

  /// No description provided for @noProfilesHint.
  ///
  /// In zh, this message translates to:
  /// **'先新建一个配置,或导入现有 frpc.toml'**
  String get noProfilesHint;

  /// No description provided for @serverConnTitle.
  ///
  /// In zh, this message translates to:
  /// **'服务器连接'**
  String get serverConnTitle;

  /// No description provided for @serverAddrLabel.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址 *'**
  String get serverAddrLabel;

  /// No description provided for @serverAddrHint.
  ///
  /// In zh, this message translates to:
  /// **'x.x.x.x 或域名'**
  String get serverAddrHint;

  /// No description provided for @portLabel.
  ///
  /// In zh, this message translates to:
  /// **'端口'**
  String get portLabel;

  /// No description provided for @userLabel.
  ///
  /// In zh, this message translates to:
  /// **'用户名(多用户模式,可空)'**
  String get userLabel;

  /// No description provided for @tokenLabel.
  ///
  /// In zh, this message translates to:
  /// **'Token(可空)'**
  String get tokenLabel;

  /// No description provided for @profileNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'配置名称'**
  String get profileNameLabel;

  /// No description provided for @profileNameHint.
  ///
  /// In zh, this message translates to:
  /// **'如 家里的服务器'**
  String get profileNameHint;

  /// No description provided for @deleteProfileBtn.
  ///
  /// In zh, this message translates to:
  /// **'删除此配置'**
  String get deleteProfileBtn;

  /// No description provided for @deleteProfileTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除配置「{name}」?'**
  String deleteProfileTitle(Object name);

  /// No description provided for @deleteProfileConfirm.
  ///
  /// In zh, this message translates to:
  /// **'将删除该配置及其代理列表,不可恢复。'**
  String get deleteProfileConfirm;

  /// No description provided for @importSuccess.
  ///
  /// In zh, this message translates to:
  /// **'导入成功:{count} 条代理'**
  String importSuccess(int count);

  /// No description provided for @importFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败: {err}'**
  String importFailed(Object err);

  /// No description provided for @exportDone.
  ///
  /// In zh, this message translates to:
  /// **'已导出干净配置(不含 webServer 注入)'**
  String get exportDone;

  /// No description provided for @exportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败: {err}'**
  String exportFailed(Object err);

  /// No description provided for @versionsTitle.
  ///
  /// In zh, this message translates to:
  /// **'frpc 版本'**
  String get versionsTitle;

  /// No description provided for @latestVersion.
  ///
  /// In zh, this message translates to:
  /// **'最新版 v{version}'**
  String latestVersion(Object version);

  /// No description provided for @downloadNewTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载新版本'**
  String get downloadNewTitle;

  /// No description provided for @versionFieldLabel.
  ///
  /// In zh, this message translates to:
  /// **'版本号'**
  String get versionFieldLabel;

  /// No description provided for @versionFieldHint.
  ///
  /// In zh, this message translates to:
  /// **'如 0.71.0,留空用最新版'**
  String get versionFieldHint;

  /// No description provided for @noVersionsHint.
  ///
  /// In zh, this message translates to:
  /// **'尚未安装任何 frpc 版本'**
  String get noVersionsHint;

  /// No description provided for @bundledVersionTitle.
  ///
  /// In zh, this message translates to:
  /// **'打包内置版本'**
  String get bundledVersionTitle;

  /// No description provided for @versionReady.
  ///
  /// In zh, this message translates to:
  /// **'frpc v{version} 已就绪'**
  String versionReady(Object version);

  /// No description provided for @mirrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载镜像'**
  String get mirrorTitle;

  /// No description provided for @mirrorDesc.
  ///
  /// In zh, this message translates to:
  /// **'GitHub Releases 下载加速前缀,留空直连。例如 https://ghfast.top 或其他 ghproxy 类镜像(会拼在 github.com 前)。'**
  String get mirrorDesc;

  /// No description provided for @mirrorHint.
  ///
  /// In zh, this message translates to:
  /// **'https://mirror.example.com'**
  String get mirrorHint;

  /// No description provided for @autoRestartTitle.
  ///
  /// In zh, this message translates to:
  /// **'frpc 异常退出后自动重启'**
  String get autoRestartTitle;

  /// No description provided for @autoRestartDesc.
  ///
  /// In zh, this message translates to:
  /// **'指数退避(1s→30s),运行稳定 60 秒后重置计数'**
  String get autoRestartDesc;

  /// No description provided for @closeToTrayTitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭窗口时最小化到托盘'**
  String get closeToTrayTitle;

  /// No description provided for @closeToTrayDesc.
  ///
  /// In zh, this message translates to:
  /// **'关闭主窗口后台保持 frpc 运行,从托盘菜单退出'**
  String get closeToTrayDesc;

  /// No description provided for @launchAtStartupTitle.
  ///
  /// In zh, this message translates to:
  /// **'开机自启'**
  String get launchAtStartupTitle;

  /// No description provided for @launchAtStartupDesc.
  ///
  /// In zh, this message translates to:
  /// **'登录系统后自动启动 Flux'**
  String get launchAtStartupDesc;

  /// No description provided for @logDirTitle.
  ///
  /// In zh, this message translates to:
  /// **'日志目录'**
  String get logDirTitle;

  /// No description provided for @logDirDesc.
  ///
  /// In zh, this message translates to:
  /// **'frpc 运行日志按天落盘,保留 7 天'**
  String get logDirDesc;

  /// No description provided for @aboutDesc.
  ///
  /// In zh, this message translates to:
  /// **'Flutter 实现的 frp 客户端 · frp 遵循 Apache-2.0'**
  String get aboutDesc;

  /// No description provided for @btnCheckUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get btnCheckUpdate;

  /// No description provided for @upToDate.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get upToDate;

  /// No description provided for @updateChip.
  ///
  /// In zh, this message translates to:
  /// **'新版本 {version}'**
  String updateChip(Object version);

  /// No description provided for @updateCheckFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败: {err}'**
  String updateCheckFailed(Object err);

  /// No description provided for @trayShow.
  ///
  /// In zh, this message translates to:
  /// **'显示主界面'**
  String get trayShow;

  /// No description provided for @trayStart.
  ///
  /// In zh, this message translates to:
  /// **'启动 frpc'**
  String get trayStart;

  /// No description provided for @trayStop.
  ///
  /// In zh, this message translates to:
  /// **'停止 frpc'**
  String get trayStop;

  /// No description provided for @trayQuit.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get trayQuit;

  /// No description provided for @trayTooltipRunning.
  ///
  /// In zh, this message translates to:
  /// **'Flux — 运行中 · {count} 条代理'**
  String trayTooltipRunning(int count);

  /// No description provided for @trayTooltipStopped.
  ///
  /// In zh, this message translates to:
  /// **'Flux — 已停止'**
  String get trayTooltipStopped;

  /// No description provided for @errNoProfile.
  ///
  /// In zh, this message translates to:
  /// **'没有可用的配置'**
  String get errNoProfile;

  /// No description provided for @errNeedServerAddr.
  ///
  /// In zh, this message translates to:
  /// **'请先在\"配置\"页填写服务器地址'**
  String get errNeedServerAddr;

  /// No description provided for @errNoFrpc.
  ///
  /// In zh, this message translates to:
  /// **'未找到 frpc,请到\"版本\"页下载'**
  String get errNoFrpc;

  /// No description provided for @errVerifyFailed.
  ///
  /// In zh, this message translates to:
  /// **'配置校验失败:{err}'**
  String errVerifyFailed(Object err);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
