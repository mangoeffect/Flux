// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Flux — frp Client';

  @override
  String get navHome => 'Home';

  @override
  String get navProxies => 'Proxies';

  @override
  String get navProfile => 'Profile';

  @override
  String get navVersions => 'Versions';

  @override
  String get navSettings => 'Settings';

  @override
  String get btnStart => 'Start';

  @override
  String get btnStop => 'Stop';

  @override
  String get btnSave => 'Save';

  @override
  String get btnCancel => 'Cancel';

  @override
  String get btnCreate => 'Create';

  @override
  String get btnDelete => 'Delete';

  @override
  String get btnView => 'View';

  @override
  String get btnCleanup => 'Clean up';

  @override
  String get btnDownload => 'Download';

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuDelete => 'Delete';

  @override
  String get requiredField => 'Required';

  @override
  String get mustBeNumber => 'Number';

  @override
  String get savedMsg => 'Saved';

  @override
  String get advancedJson => 'Advanced fields (JSON, kept as-is in TOML)';

  @override
  String invalidJsonErr(Object err) {
    return 'Invalid advanced JSON: $err';
  }

  @override
  String get jsonMustBeObject => 'Advanced fields must be a JSON object';

  @override
  String get statusStopped => 'Stopped';

  @override
  String get statusStarting => 'Starting...';

  @override
  String get statusRunning => 'Running';

  @override
  String get statusStopping => 'Stopping...';

  @override
  String uptimeLabel(Object duration) {
    return 'Up $duration';
  }

  @override
  String durHours(int h, int m) {
    return '${h}h ${m}m';
  }

  @override
  String durMinutes(int m, int s) {
    return '${m}m ${s}s';
  }

  @override
  String get frpcVersionUnset => 'not selected';

  @override
  String get noProfile => 'No profile created yet';

  @override
  String profileSummary(
    Object name,
    Object server,
    int port,
    int count,
    Object version,
  ) {
    return '$name · $server:$port · $count proxies · frpc $version';
  }

  @override
  String get proxyStatusTitle => 'Proxy Status';

  @override
  String proxyNameType(Object name, Object type) {
    return '$name ($type)';
  }

  @override
  String proxyAddrLine(Object local, Object remote) {
    return '$local → $remote';
  }

  @override
  String get logsTitle => 'Logs';

  @override
  String get clearLogs => 'Clear logs';

  @override
  String updateBannerMsg(Object version) {
    return 'New version $version available';
  }

  @override
  String orphanBanner(Object pids) {
    return 'Found leftover frpc process from last crash (PID $pids)';
  }

  @override
  String get proxiesTitle => 'Proxies';

  @override
  String get btnVerifyConfig => 'Verify config';

  @override
  String get btnHotReload => 'Hot reload';

  @override
  String get reloadedMsg => 'Reloaded, proxies updated';

  @override
  String get btnNewProxy => 'New proxy';

  @override
  String get btnNewVisitor => 'New visitor';

  @override
  String tabProxies(int count) {
    return 'Proxies ($count)';
  }

  @override
  String tabVisitors(int count) {
    return 'Visitors ($count)';
  }

  @override
  String get noProxiesHint => 'No proxies yet — create one at top right';

  @override
  String get noVisitorsHint =>
      'No visitors yet (stcp/xtcp/sudp) — create one at top right';

  @override
  String proxySubtitle(Object local, Object tail) {
    return '$local → $tail';
  }

  @override
  String visitorSubtitle(Object bind, Object server, Object type) {
    return '$bind → $server ($type)';
  }

  @override
  String get verifyPassed => 'Config verified';

  @override
  String verifyFailed(Object err) {
    return 'Config check failed: $err';
  }

  @override
  String get dlgNewProxy => 'New proxy';

  @override
  String get dlgEditProxy => 'Edit proxy';

  @override
  String get fieldName => 'Name *';

  @override
  String get fieldNameHint => 'e.g. web, ssh';

  @override
  String get localAddr => 'Local address';

  @override
  String get localPort => 'Local port *';

  @override
  String get remotePort => 'Remote port (server side)';

  @override
  String get remotePortHint => 'Leave empty to assign on server';

  @override
  String get customDomains => 'Custom domains';

  @override
  String get customDomainsHint => 'Separate with commas';

  @override
  String get subdomain => 'Subdomain';

  @override
  String get locations => 'HTTP locations';

  @override
  String get locationsHint => 'e.g. /api,/static';

  @override
  String get basicAuthUser => 'BasicAuth user';

  @override
  String get basicAuthPassword => 'BasicAuth password';

  @override
  String get secretKey => 'Shared secretKey';

  @override
  String get tlsServerName => 'TLS SNI serverName';

  @override
  String get dlgNewVisitor => 'New visitor';

  @override
  String get dlgEditVisitor => 'Edit visitor';

  @override
  String get visitorDesc =>
      'stcp/xtcp/sudp visitor: traffic on the local port is forwarded to the server-side proxy through an encrypted tunnel.';

  @override
  String get visitorServerName => 'Server proxy name (serverName) *';

  @override
  String get visitorServerNameHint =>
      'The name of the server-side [[proxies]] entry';

  @override
  String get bindAddr => 'Local bind address';

  @override
  String get bindPort => 'Local bind port *';

  @override
  String get btnExportToml => 'Export TOML';

  @override
  String get btnImportToml => 'Import frpc.toml';

  @override
  String get btnNewProfile => 'New profile';

  @override
  String get noProfilesHint =>
      'Create a profile or import an existing frpc.toml';

  @override
  String get serverConnTitle => 'Server Connection';

  @override
  String get serverAddrLabel => 'Server address *';

  @override
  String get serverAddrHint => 'x.x.x.x or domain';

  @override
  String get portLabel => 'Port';

  @override
  String get userLabel => 'User (multi-user mode, optional)';

  @override
  String get tokenLabel => 'Token (optional)';

  @override
  String get profileNameLabel => 'Profile name';

  @override
  String get profileNameHint => 'e.g. Home server';

  @override
  String get deleteProfileBtn => 'Delete this profile';

  @override
  String deleteProfileTitle(Object name) {
    return 'Delete profile \"$name\"?';
  }

  @override
  String get deleteProfileConfirm =>
      'This deletes the profile and its proxies. This cannot be undone.';

  @override
  String importSuccess(int count) {
    return 'Imported: $count proxies';
  }

  @override
  String importFailed(Object err) {
    return 'Import failed: $err';
  }

  @override
  String get exportDone => 'Exported clean config (without injected webServer)';

  @override
  String exportFailed(Object err) {
    return 'Export failed: $err';
  }

  @override
  String get versionsTitle => 'frpc Versions';

  @override
  String latestVersion(Object version) {
    return 'Latest v$version';
  }

  @override
  String get downloadNewTitle => 'Download a version';

  @override
  String get versionFieldLabel => 'Version';

  @override
  String get versionFieldHint => 'e.g. 0.71.0, empty for latest';

  @override
  String get noVersionsHint => 'No frpc version installed yet';

  @override
  String get bundledVersionTitle => 'Bundled version';

  @override
  String versionReady(Object version) {
    return 'frpc v$version ready';
  }

  @override
  String get mirrorTitle => 'Download mirror';

  @override
  String get mirrorDesc =>
      'Prefix for GitHub Releases download acceleration, empty for direct. e.g. https://ghfast.top or other ghproxy-style mirrors (prepended to github.com).';

  @override
  String get mirrorHint => 'https://mirror.example.com';

  @override
  String get autoRestartTitle => 'Auto restart frpc after crash';

  @override
  String get autoRestartDesc =>
      'Exponential backoff (1s→30s), counter resets after 60s stable';

  @override
  String get closeToTrayTitle => 'Minimize to tray on close';

  @override
  String get closeToTrayDesc =>
      'Closing the window keeps frpc running in background; quit from the tray menu';

  @override
  String get launchAtStartupTitle => 'Launch at startup';

  @override
  String get launchAtStartupDesc => 'Start Flux automatically after login';

  @override
  String get logDirTitle => 'Log directory';

  @override
  String get logDirDesc => 'frpc logs written daily, kept for 7 days';

  @override
  String get aboutDesc => 'Flutter frp client · frp is Apache-2.0 licensed';

  @override
  String get btnCheckUpdate => 'Check for updates';

  @override
  String get upToDate => 'You are up to date';

  @override
  String updateChip(Object version) {
    return 'New $version';
  }

  @override
  String updateCheckFailed(Object err) {
    return 'Update check failed: $err';
  }

  @override
  String get trayShow => 'Show main window';

  @override
  String get trayStart => 'Start frpc';

  @override
  String get trayStop => 'Stop frpc';

  @override
  String get trayQuit => 'Quit';

  @override
  String trayTooltipRunning(int count) {
    return 'Flux — Running · $count proxies';
  }

  @override
  String get trayTooltipStopped => 'Flux — Stopped';

  @override
  String get errNoProfile => 'No profile available';

  @override
  String get errNeedServerAddr =>
      'Set the server address on the Profile page first';

  @override
  String get errNoFrpc => 'frpc not found — download it on the Versions page';

  @override
  String errVerifyFailed(Object err) {
    return 'Config check failed: $err';
  }
}
