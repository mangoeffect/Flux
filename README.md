# Flux

基于 Flutter 的 frp 跨平台 GUI 客户端(Windows / macOS / Linux / Android,iOS 规划中)。

可视化编辑 frpc 配置、管理多条隧道代理、启停/热重载、实时日志、系统托盘(桌面)与前台服务保活(Android)。

## 功能

- **可视化配置**:表单编辑 frpc TOML(tcp/udp/http/https/stcp/xtcp/sudp),支持导入现有 `frpc.toml`
- **多 Profile**:管理多套服务器/代理组合,一键切换
- **frpc 进程管理**:启停、实时日志、崩溃自动重启、优雅退出
- **Admin API**:自动注入本地 webServer 配置,代理状态实时展示、热重载不中断连接
- **frpc 版本管理**:打包内置稳定版,可从 GitHub Releases(支持镜像)下载其他版本
- **桌面体验**:系统托盘、关闭最小化到托盘、开机自启
- **Android**:前台服务保活、开机自启、电池优化白名单引导

## 架构

```
lib/
├── ui/          界面(首页/代理编辑器/Profile/版本管理/设置)
├── core/        纯 Dart 核心服务(全平台共享)
│   ├── config/    TOML 生成与解析(ConfigService)
│   ├── process/   frpc 子进程生命周期(FrpcProcessService)
│   ├── admin/     frpc Admin API 客户端(AdminApiService)
│   └── binary/    frpc 二进制获取与版本管理(FrpcBinaryService)
├── model/       领域模型(Profile/ProxyConfig)
└── platform/    平台集成(托盘/自启/前台服务/通道)
```

- 桌面与 Android:frpc 以**外部二进制子进程**运行(版本解耦、崩溃隔离),叠加 **Admin API** 做状态与热重载
- iOS(规划):frp 以 **gomobile 库**进程内运行(平台禁止子进程)

## 开发

依赖:Flutter stable(当前 3.47.x)。

```bash
flutter pub get
flutter test                   # 单元测试 + 端到端验收(需 .e2e/ 下有 frp 二进制,缺失时自动跳过)
flutter run -d windows         # 或 macos/linux
flutter build windows
```

frpc 二进制获取:应用内"版本"页可直接从 GitHub Releases 下载(支持镜像加速,见设置页)。
离线/打包场景可用脚本:

```bash
scripts/fetch_frpc.sh windows amd64   # → third_party/frpc/windows-amd64/frpc.exe,打包时复制到应用可执行文件旁
```

端到端验收测试依赖真实 frp 二进制:

```bash
mkdir -p .e2e && cd .e2e
curl -sLO https://github.com/fatedier/frp/releases/download/v0.71.0/frp_0.71.0_windows_amd64.zip && unzip -o frp_0.71.0_windows_amd64.zip
```

## 路线

- [x] M0 脚手架与领域模型、调研沉淀([docs/research.md](docs/research.md))
- [x] M1 桌面 MVP(Windows):可视化配置编辑、TOML 生成/导入、frpc 进程管理(日志流/退避重启)、Admin API 状态与热重载、frpc 版本管理
- [x] M2 桌面完善:托盘(菜单/双态图标/tooltip 随运行状态)/关闭最小化到托盘/单实例/开机自启、自定义图标、CI 三平台打包
- [x] M2.5 桌面精修:visitor(stcp/xtcp/sudp)可视化编辑、frpc verify 启动前校验、配置导出、日志按天落盘、窗口状态记忆、检查更新、孤儿 frpc 进程检测清理、token 系统凭据库存储、中英双语(zh/en)
- [ ] M3 Android:NDK 构建 libfrpc.so/jniLibs 打包/specialUse 前台服务/开机自启
- [ ] M4 iOS:gomobile 库内运行(前台+自动重连形态)

调研详情见 [docs/research.md](docs/research.md)。

## 打包与发布

**发版流程**:改 `pubspec.yaml` 的 `version` → 提交 → 打同号 tag(如 `v1.1.0`)并推送 → Actions 自动打包出 Release,应用内"检查更新"即可感知新版本。

```bash
git tag v1.1.0 && git push origin v1.1.0
```

推 tag 后 GitHub Actions 产出(`.github/workflows/release.yml`,**包内已内置 frpc**,首启无需联网下载;内置版本由 workflow 的 `FRPC_VERSION` 变量控制):

| 产物 | 平台 |
|---|---|
| `flux-windows-x64.zip` | Windows 10+ x64 |
| `flux-macos-arm64.dmg` / `flux-macos-x64.dmg` | macOS 13+(Apple Silicon / Intel) |
| `flux-linux-x86_64.AppImage` / `flux-linux-amd64.deb` | Linux x64 |
| `flux-linux-arm64.AppImage` / `flux-linux-arm64.deb` | Linux arm64 |

修改图标设计后重新生成应用/托盘图标(运行态彩色/停止态灰):

```bash
dart run tool/gen_icons.dart && dart run flutter_launcher_icons
```

### 签名与公证(可选)

目前产物未签名:Windows 首次运行会弹 SmartScreen(点"仍要运行"),macOS 需右键打开或 `xattr -cr Flux.app`。拿到证书后在仓库 secrets 配置并取消 release.yml 中对应注释块即可自动签名:

- **Windows**:代码签名证书 pfx 转 Base64 存 `WINDOWS_CERT_PFX_B64` + `WINDOWS_CERT_PASSWORD`,workflow 中已预留 signtool 步骤
- **macOS**:需要 Apple Developer 账号,配置 `APPLE_DEV_ID`/`APPLE_ID`/`APPLE_PASSWORD`/`APPLE_TEAM_ID`,workflow 中已预留 codesign + notarytool 公证步骤

### 平台说明

- **Linux 托盘**:依赖 ayatana appindicator(deb 已声明 `libayatana-appindicator3-1` 依赖);GNOME 需安装 AppIndicator 扩展才会显示托盘,KDE/X11 无需额外配置。token 安全存储需要 keyring 服务(gnome-keyring/KWallet),无 keyring 时自动回退明文 JSON
- **macOS**:应用关闭了 App Sandbox —— frpc 需以子进程运行,且单实例需要本地回环监听;仅 dmg 分发,不支持上架 Mac App Store
- **Windows arm64**:Flutter 暂不支持交叉构建,暂不提供
- **多 Profile 同时运行**:暂不支持(单 frpc 实例),规划为独立里程碑

### i18n

界面跟随系统语言(中文/英文)。文案在 `lib/l10n/app_*.arb`,改后 `flutter gen-l10n` 重新生成。

## License

Apache-2.0(与 frp 一致)
