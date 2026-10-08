# macOS target、权限与验收

2026-10-08：新增 `apps/raft_flutter/macos` 宿主，应用名 `Raft`，Bundle ID `app.raft.raftFlutter`，最低 macOS 12，仅构建 Apple Silicon（ARM64）版本。工具链固定 Flutter 3.47.6 / Dart 3.13.5；本机使用 Xcode 27.0。本文单独记录 macOS 覆盖，Linux / Android 的既有证据不作为 macOS 验收结果。

## 本机构建和打开

Flutter SDK 和依赖由 FVM 管理，项目 `.fvmrc` 固定 3.47.6，`.fvm/flutter_sdk` 指向 FVM 缓存，不修改系统默认 SDK。需要完整 Xcode 与 CocoaPods。在仓库根目录执行：

```sh
fvm install
fvm use 3.47.6
cd apps/raft_flutter
fvm flutter pub get
fvm flutter build macos --release
open -g build/macos/Build/Products/Release/Raft.app
```

Debug / Profile / Release 的项目配置固定 `ARCHS = arm64` 并排除 `x86_64`，CocoaPods targets 使用相同架构限制；不改全局 Flutter 配置。

`open -g` 在后台启动应用。宿主窗口首次显示也保持后台，异步加载不得抢走其他应用的焦点。本机构建使用本地签名；本次不包含 Developer ID 发行、notarization 或商店上架。

## 权限配置

Debug / Profile 与 Release 均启用 App Sandbox，权限位于 `macos/Runner/DebugProfile.entitlements` 和 `Release.entitlements`：

| 配置 | 用途 | 边界 |
| --- | --- | --- |
| `network.client` | HTTP、Socket.IO、附件及指定工作区服务连接 | 用户选择的远端或局域网服务 |
| `network.server` | OAuth 本地回环回调监听 | 保留现有 loopback 登录能力；不代表已配置第三方 OAuth 验收 |
| `files.user-selected.read-write` | 系统文件选择、附件上传与保存 | 用户通过系统面板选择的文件 |
| `cs.allow-jit`、`get-task-allow` | Flutter Debug / Profile 调试 | Release 不启用，并禁用 Xcode 自动注入调试 entitlement |

`Info.plist` 注册 `raft` URL scheme，并提供局域网连接用途说明。没有声明麦克风、摄像头、照片库或全盘访问权限。签名附件与登录凭据仍不得写入源码或构建参数。

会话使用 `flutter_secure_storage` 的 macOS Keychain 后端，设置 `MacOsOptions(usesDataProtectionKeychain: false)`，使用当前应用的传统 Keychain 存储；没有启用跨应用 Keychain sharing。本地构建不要求为此配置共享组或 provisioning profile。

通知初始化不弹出系统授权请求；用户在应用通知设置主动启用后才请求 alert / sound 权限。macOS 接入本地测试通知及系统权限状态，当前 `receivesMessages` 仅对 Android 开启，不能把 macOS 本地测试通知视为服务端 desktop push。

媒体增加 `media_kit_libs_macos_video` 原生依赖，随 macOS bundle 构建；Linux 的 media 下载准备步骤不适用于 macOS。

## 当前覆盖

| 功能 | macOS 实现 / 验收状态 |
| --- | --- |
| Runner、沙盒、原生插件注册 | 本机 Debug、Release 编译通过；FVM 最终 Release 118.0 MB，后台启动到登录界面 |
| 全仓静态检查及 Dart 回归 | FVM 下 `flutter analyze --no-pub` 无问题；通知 9、会话 3、OAuth 2、附件保存 3、登录 UI 4，共 21 项通过 |
| 后台启动及延迟首帧不抢焦点 | Computer Use 后台打开，观察到首次帧与最终登录界面；窗口初始不可见、随后只在现有窗口后显示，禁止窗口状态恢复；未做独立前台 PID 连续采样 |
| 网络、OAuth loopback、局域网 | 权限已配置；真实登录、OAuth 和局域网授权流程待实测 |
| Keychain 会话恢复、退出清理 | 已配置；macOS 实机读写及重启恢复待实测 |
| 文件选择、上传、保存 | 沙盒权限与既有平台适配已接入；系统面板和上传下载链路待实测 |
| `raft` 内容链接 | 已注册；冷启、热启及真实消息上下文跳转待实测 |
| 本地通知及权限拒绝 / 重新启用 | 主动 opt-in、拒绝、撤权恢复、关闭/账户切换与迟到授权竞态回归通过；系统通知显示、点击仍待实测 |
| 服务端桌面推送 | 未接入 |
| 音视频播放 | macOS 媒体运行库已接入；真实媒体播放待实测 |
| 应用内 PDF 预览 | macOS 未实现，使用既有下载回退 |
| 原生分享 | 当前仅 Android 实现 |
| 独立原生工作区多窗口 | 未实现 |
| 中文 / 日文 IME、VoiceOver、键盘、生命周期 | macOS 实机验收待补；Widget Preview 不替代平台验收 |

本机结果：使用 FVM 3.47.6 完成最终 Release 编译、21 项相关回归与全仓静态检查；Computer Use 观察到完整登录页及 `Linux · Android · macOS` 标识。进程路径为 `apps/raft_flutter/build/macos/Build/Products/Release/Raft.app/Contents/MacOS/Raft`。`codesign --verify --deep --strict` 与 plist 检查通过。登录后的真实工作区、Keychain 写入恢复和系统权限面板不在本次启动验收范围内。

媒体插件当前通过 CocoaPods 接入，其尚未支持 Swift Package Manager；构建有上游弃用/宏定义警告，但最终编译通过。此记录不代表 macOS 完整功能轮次通过。

权限配置依据 [Flutter macOS 宿主说明](https://docs.flutter.dev/platform-integration/macos/building)；Keychain 配置依据 [flutter_secure_storage 11.2.0 官方说明](https://pub.dev/packages/flutter_secure_storage)。

## ARM64 构建验证

后续按用户要求将 macOS Debug / Profile / Release 与 CocoaPods targets 固定为 ARM64，并通过 FVM 重新构建 Release（64.5 MB）。逐一检查 bundle 中 25 个 Mach-O 文件，主程序、Dart AOT、Flutter 引擎、SQLite 和媒体运行库均仅含 `arm64`，没有 `x86_64` slice；`codesign --verify --deep --strict` 通过。上文 118.0 MB 为更早构建的历史记录。
