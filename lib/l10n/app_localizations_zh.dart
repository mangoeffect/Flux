// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Flux — frp 客户端';

  @override
  String get navHome => '首页';

  @override
  String get navProxies => '代理';

  @override
  String get navProfile => '配置';

  @override
  String get navVersions => '版本';

  @override
  String get navSettings => '设置';

  @override
  String get btnStart => '启动';

  @override
  String get btnStop => '停止';

  @override
  String get btnSave => '保存';

  @override
  String get btnCancel => '取消';

  @override
  String get btnCreate => '创建';

  @override
  String get btnDelete => '删除';

  @override
  String get btnView => '查看';

  @override
  String get btnCleanup => '清理';

  @override
  String get btnDownload => '下载';

  @override
  String get menuEdit => '编辑';

  @override
  String get menuDelete => '删除';

  @override
  String get requiredField => '必填';

  @override
  String get mustBeNumber => '数字';

  @override
  String get savedMsg => '已保存';

  @override
  String get advancedJson => '高级字段(JSON,写入 TOML 原样保留)';

  @override
  String invalidJsonErr(Object err) {
    return '高级字段 JSON 无效: $err';
  }

  @override
  String get jsonMustBeObject => '高级字段必须是 JSON 对象';

  @override
  String get statusStopped => '已停止';

  @override
  String get statusStarting => '启动中...';

  @override
  String get statusRunning => '运行中';

  @override
  String get statusStopping => '停止中...';

  @override
  String uptimeLabel(Object duration) {
    return '已运行 $duration';
  }

  @override
  String durHours(int h, int m) {
    return '$h时$m分';
  }

  @override
  String durMinutes(int m, int s) {
    return '$m分$s秒';
  }

  @override
  String get frpcVersionUnset => '未选择';

  @override
  String get noProfile => '尚未创建配置';

  @override
  String profileSummary(
    Object name,
    Object server,
    int port,
    int count,
    Object version,
  ) {
    return '$name · $server:$port · $count 条代理 · frpc $version';
  }

  @override
  String get proxyStatusTitle => '代理状态';

  @override
  String proxyNameType(Object name, Object type) {
    return '$name ($type)';
  }

  @override
  String proxyAddrLine(Object local, Object remote) {
    return '$local → $remote';
  }

  @override
  String get logsTitle => '日志';

  @override
  String get clearLogs => '清空日志';

  @override
  String updateBannerMsg(Object version) {
    return '新版本 $version 可用';
  }

  @override
  String orphanBanner(Object pids) {
    return '检测到上次异常退出的 frpc 进程(PID $pids)';
  }

  @override
  String get proxiesTitle => '代理';

  @override
  String get btnVerifyConfig => '检查配置';

  @override
  String get btnHotReload => '热重载';

  @override
  String get reloadedMsg => '已热重载,代理配置生效';

  @override
  String get btnNewProxy => '新建代理';

  @override
  String get btnNewVisitor => '新建访问端';

  @override
  String tabProxies(int count) {
    return '代理 ($count)';
  }

  @override
  String tabVisitors(int count) {
    return '访问端 ($count)';
  }

  @override
  String get noProxiesHint => '还没有代理,点击右上角新建';

  @override
  String get noVisitorsHint => '还没有访问端(stcp/xtcp/sudp),点击右上角新建';

  @override
  String proxySubtitle(Object local, Object tail) {
    return '$local → $tail';
  }

  @override
  String visitorSubtitle(Object bind, Object server, Object type) {
    return '$bind → $server ($type)';
  }

  @override
  String get verifyPassed => '配置校验通过';

  @override
  String verifyFailed(Object err) {
    return '配置校验失败:$err';
  }

  @override
  String get dlgNewProxy => '新建代理';

  @override
  String get dlgEditProxy => '编辑代理';

  @override
  String get fieldName => '名称 *';

  @override
  String get fieldNameHint => '如 web、ssh';

  @override
  String get localAddr => '本地地址';

  @override
  String get localPort => '本地端口 *';

  @override
  String get remotePort => '远程端口(服务器侧)';

  @override
  String get remotePortHint => '留空由服务器分配';

  @override
  String get customDomains => '自定义域名';

  @override
  String get customDomainsHint => '多个用英文逗号分隔';

  @override
  String get subdomain => '子域名';

  @override
  String get locations => '路由 location';

  @override
  String get locationsHint => '如 /api,/static';

  @override
  String get basicAuthUser => 'BasicAuth 用户';

  @override
  String get basicAuthPassword => 'BasicAuth 密码';

  @override
  String get secretKey => '共享密钥 secretKey';

  @override
  String get tlsServerName => 'TLS SNI serverName';

  @override
  String get dlgNewVisitor => '新建访问端';

  @override
  String get dlgEditVisitor => '编辑访问端';

  @override
  String get visitorDesc => 'stcp/xtcp/sudp 的访问端:本地端口收到流量经加密隧道转发到服务端代理。';

  @override
  String get visitorServerName => '服务端代理名 serverName *';

  @override
  String get visitorServerNameHint => '要访问的服务端 [[proxies]] 的 name';

  @override
  String get bindAddr => '本地监听地址';

  @override
  String get bindPort => '本地监听端口 *';

  @override
  String get btnExportToml => '导出 TOML';

  @override
  String get btnImportToml => '导入 frpc.toml';

  @override
  String get btnNewProfile => '新建配置';

  @override
  String get noProfilesHint => '先新建一个配置,或导入现有 frpc.toml';

  @override
  String get serverConnTitle => '服务器连接';

  @override
  String get serverAddrLabel => '服务器地址 *';

  @override
  String get serverAddrHint => 'x.x.x.x 或域名';

  @override
  String get portLabel => '端口';

  @override
  String get userLabel => '用户名(多用户模式,可空)';

  @override
  String get tokenLabel => 'Token(可空)';

  @override
  String get profileNameLabel => '配置名称';

  @override
  String get profileNameHint => '如 家里的服务器';

  @override
  String get deleteProfileBtn => '删除此配置';

  @override
  String deleteProfileTitle(Object name) {
    return '删除配置「$name」?';
  }

  @override
  String get deleteProfileConfirm => '将删除该配置及其代理列表,不可恢复。';

  @override
  String importSuccess(int count) {
    return '导入成功:$count 条代理';
  }

  @override
  String importFailed(Object err) {
    return '导入失败: $err';
  }

  @override
  String get exportDone => '已导出干净配置(不含 webServer 注入)';

  @override
  String exportFailed(Object err) {
    return '导出失败: $err';
  }

  @override
  String get versionsTitle => 'frpc 版本';

  @override
  String latestVersion(Object version) {
    return '最新版 v$version';
  }

  @override
  String get downloadNewTitle => '下载新版本';

  @override
  String get versionFieldLabel => '版本号';

  @override
  String get versionFieldHint => '如 0.71.0,留空用最新版';

  @override
  String get noVersionsHint => '尚未安装任何 frpc 版本';

  @override
  String get bundledVersionTitle => '打包内置版本';

  @override
  String versionReady(Object version) {
    return 'frpc v$version 已就绪';
  }

  @override
  String get mirrorTitle => '下载镜像';

  @override
  String get mirrorDesc =>
      'GitHub Releases 下载加速前缀,留空直连。例如 https://ghfast.top 或其他 ghproxy 类镜像(会拼在 github.com 前)。';

  @override
  String get mirrorHint => 'https://mirror.example.com';

  @override
  String get autoRestartTitle => 'frpc 异常退出后自动重启';

  @override
  String get autoRestartDesc => '指数退避(1s→30s),运行稳定 60 秒后重置计数';

  @override
  String get closeToTrayTitle => '关闭窗口时最小化到托盘';

  @override
  String get closeToTrayDesc => '关闭主窗口后台保持 frpc 运行,从托盘菜单退出';

  @override
  String get launchAtStartupTitle => '开机自启';

  @override
  String get launchAtStartupDesc => '登录系统后自动启动 Flux';

  @override
  String get logDirTitle => '日志目录';

  @override
  String get logDirDesc => 'frpc 运行日志按天落盘,保留 7 天';

  @override
  String get aboutDesc => 'Flutter 实现的 frp 客户端 · frp 遵循 Apache-2.0';

  @override
  String get btnCheckUpdate => '检查更新';

  @override
  String get upToDate => '已是最新版本';

  @override
  String updateChip(Object version) {
    return '新版本 $version';
  }

  @override
  String updateCheckFailed(Object err) {
    return '检查更新失败: $err';
  }

  @override
  String get trayShow => '显示主界面';

  @override
  String get trayStart => '启动 frpc';

  @override
  String get trayStop => '停止 frpc';

  @override
  String get trayQuit => '退出';

  @override
  String trayTooltipRunning(int count) {
    return 'Flux — 运行中 · $count 条代理';
  }

  @override
  String get trayTooltipStopped => 'Flux — 已停止';

  @override
  String get errNoProfile => '没有可用的配置';

  @override
  String get errNeedServerAddr => '请先在\"配置\"页填写服务器地址';

  @override
  String get errNoFrpc => '未找到 frpc,请到\"版本\"页下载';

  @override
  String errVerifyFailed(Object err) {
    return '配置校验失败:$err';
  }
}
