# frp 跨平台 GUI 客户端调研报告

> 调研日期:2026-08-28。本报告是 Flux 立项前的技术调研沉淀,支撑 [实施计划](../README.md) 中的架构决策。

## 一、frp 官方现状

- frp 当前 **v0.71.0**(2026-08-14),约 109k stars,Apache-2.0,活跃维护。
- 配置格式:自 v0.52.0 起 **TOML/YAML/JSON 为一等公民,INI 已废弃**。本项目只支持 TOML。
- **官方明确不做 GUI**(issue #3308/#5382 等均 not planned),但为管理端提供了官方能力:
  - **Admin API**:frpc 配置 `webServer.addr/port/user/password` 后暴露 HTTP API 与 Web UI,
    支持 `/api/status`(代理状态)、`/api/config`(读/写配置)、`frpc reload` 热重载(仅代理生效)。
  - **v0.68.0 起 Store CRUD API**(`/api/store/proxies*` 等):运行时动态增删改代理并按 `store.path` 持久化。
- frp 可作为 **Go 库** import(PR #4569 已为库模式重构),但**无 API 稳定性承诺**,升级需回归测试。

## 二、现有开源项目格局(2026-08)

| 项目 | Stars | 技术栈 | frpc 集成 | 备注 |
|---|---|---|---|---|
| [frpc-desktop](https://github.com/luckjiawei/frpc-desktop) | ~6.9k | Electron+Vue3 | 运行时下载管理 frpc 二进制 | 最流行;安装包 86–219MB;无托盘 |
| [frpmgr](https://github.com/koho/frpmgr) | ~2.0k | Go 原生(Win32) | **Go 库进程内嵌入** | 仅 Windows;安装包 6.7MB;服务级自启+热重载 |
| [FrpGUI](https://github.com/f-shake/FrpGUI) | ~88 | Avalonia+.NET | 外部进程 | 唯一同时管 frps/frpc;无许可证 |
| [MoonProxy Desktop](https://github.com/MoonProxyHQ/moonproxy-desktop) | ~58 | **Tauri v2**+Vue3 | **sidecar 内置 frpc**+自更新 | 2026 新项目;托盘/定时调度;无 Linux |
| [AceDroidX/frp-Android](https://github.com/AceDroidX/frp-Android) | ~621 | Kotlin | **NDK 编译 libfrpc.so 子进程** | Android 最成熟参照;jniLibs+前台服务 |
| [frp-panel](https://github.com/VaalaCat/frp-panel) | ~1.8k | Go+Web | Master/Client 架构 | 多节点集中管理面板,非桌面单机工具 |

**生态空白**:跨平台 + 托盘 + 移动端 + frpc 版本管理的组合无项目全部做到;**Flutter + 移动端**的 frp 客户端目前为空白。

## 三、frpc 集成方式三大流派

| 流派 | 适用平台 | 优点 | 缺点 |
|---|---|---|---|
| (a) 外部子进程 | 桌面/Android | 版本解耦、崩溃隔离、可复用官方二进制 | 需自研进程守护/优雅退出;分发第二份二进制 |
| (b) Go 库进程内嵌入 | 仅 Go 后端 | 单二进制、配置结构化读写 | 绑定 frp 内部 API;iOS 需 gomobile |
| (c) Admin API | 任意(HTTP) | 官方支持的状态/热重载/动态代理通道 | 需开本地端口(须绑 127.0.0.1+token) |

**本项目采用 (a)+(c) 组合**(桌面/Android 子进程 + Admin API 管理),iOS 后期用 (b)(gomobile)。

## 四、平台约束与验证结论

### 桌面(Windows/macOS/Linux)
- Flutter 桌面 stable;插件:`tray_manager`(托盘,Linux 需 ayatana,GNOME 需扩展)、
  `window_manager`(单实例/关闭到托盘)、`launch_at_startup`。
- frpc 二进制:`dart:io Process.start` 拉起,stdout 管道做日志。
- Linux 自动更新生态弱,MVP 只做"检查更新"提示。

### Android(已有三个成熟先例)
- **运行方式**:`CGO_ENABLED=1 GOOS=android` + NDK 工具链编译 frp → 产物命名 `libfrpc.so` 放
  `jniLibs/<abi>/`,AGP 安装到 `nativeLibraryDir`(Android 10+ 唯一可 exec 位置);
  必须设置 `useLegacyPackaging true`(否则 .so 留在 APK 内无法 execve)。
- **DNS 坑**:Android 无 `/etc/resolv.conf`,纯 Go 解析器(CGO_ENABLED=0)域名解析会失败;
  对策是 CGO 编译,或在生成配置中默认注入 `dnsServer`。
- **16KB 页对齐**:Play 要求 2025-11-01 起新 App 支持;NDK r27+ + CGO 编译天然满足。
- **后台保活**:前台服务是唯一正解;Android 15 起 `dataSync` 类型有 6h/天限制且不能开机自启,
  应选 **`specialUse`**(需 Play 审核话术)。首发走 GitHub/APK 直发规避审核变量。
  另需 `RECEIVE_BOOT_COMPLETED` + 电池优化白名单引导;建议默认 `loginFailExit = false`。
- frp 官方 Release 只有 `android_arm64`(且 CGO 状态存疑),**需自建 NDK 构建管线**。
- `dart:io Process.start` 在 Android 上真实可用(约束只在二进制放置位置)。

### iOS(平台限制,预期需收敛)
- **禁 fork/exec**(App Store 指南 2.5.2),frpc 只能以 **gomobile bind framework 静态链接**进 App
  (先例:duanhai/Frpc-iOS 等,均小型/停滞,库 API 封装需自建)。
- **退后台 ~30s 即挂起断连**;背景模式无一适合隧道客户端,滥用触 2.5.4 拒审;
  Network Extension 需 entitlement 且 TN3120 反对非 VPN 用途,国区另有牌照问题。
- **结论**:iOS 产品形态只能是"前台使用 + 自动重连",突出 stcp/xtcp visitor 访问端场景;
  不做后台常驻承诺。放在最后一个里程碑。

## 五、GUI 技术栈对比结论(为何选 Flutter)

| 维度 | Flutter | Tauri 2 | Electron | Avalonia | Wails v3 |
|---|---|---|---|---|---|
| 桌面体积 | 20–30MB | 3–10MB | 50–200MB | 25–80MB | ~15MB |
| 移动端 | **stable(最成熟)** | stable(较新) | 无 | stable | 规划中 |
| 托盘 | 插件(Linux 部分) | 内置 | 最成熟 | 内置 | v3 内置 |
| 后端语言 | Dart | Rust | Node | C# | Go |

选 Flutter 的决定性因素:**唯一同时具备成熟桌面+移动端能力的 UI 框架**,契合"桌面+移动"的目标;
代价是桌面工具型能力(托盘等)依赖插件且 Linux 托盘为部分支持——已评估为可接受。

## 六、对本项目架构的直接结论

1. 核心服务层(ConfigService/FrpcProcessService/AdminApiService/FrpcBinaryService)纯 Dart,
   桌面与 Android 共享同一套子进程管理代码。
2. frpc 版本管理:桌面从 GitHub Releases 下载(带镜像)+ 打包内置一个稳定版本;
   Android 打包内置(平台限制不能动态下载数据目录可执行文件)。
3. Admin API 注入:启动时自动写 `[webServer]`(127.0.0.1+随机端口+随机 token)。
4. 运行时后端抽象:`SubprocessBackend`(桌面+Android)/ `LibraryBackend`(iOS,gomobile)。

## 参考链接

- frp:<https://github.com/fatedier/frp> · Admin UI 文档:<https://gofrp.org/en/docs/features/common/ui/>
- Android 打包可执行文件最佳实践:<https://www.viliussutkus89.com/posts/distributing-android-cli-programs-in-apks/>
- Android 16KB 页大小要求:<https://developer.android.com/guide/practices/page-sizes>
- 前台服务类型(dataSync 限制/specialUse):<https://developer.android.com/develop/background-work/services/fg-service-types>
- iOS 后台限制:<https://developer.apple.com/app-store/review/guidelines/>(2.5.2/2.5.4)、TN3120
- 桌面框架对比(2026):<https://devmil.de/2026/06/30/2026-06-30-Desktop-framework-comparison/>
