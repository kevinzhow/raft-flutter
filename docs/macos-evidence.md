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

会话使用 `flutter_secure_storage`。未配置 provisioning profile 的构建默认保留传统 Keychain 后端。使用 Apple Development / Distribution 身份和有效 macOS profile 签名的构建可通过 `--dart-define=RAFT_MACOS_DATA_PROTECTION_KEYCHAIN=true` 启用 Data Protection Keychain；主应用签名的 `com.apple.application-identifier`、team identifier 必须由嵌入的 profile 授权。使用应用自己的默认 access group，不启用跨应用共享或生物识别。账户、证书选择、team 和 profile 配置只存于本机被忽略的 `.local/macos-signing/`，不得提交。

启用后优先读取现代 Keychain，仅当该 origin 的条目不存在时迁移传统条目；解析、写入及精确读回验证全部成功后才移除旧副本。权限错误继续上报，不能当成没有登录资料。迁移与退出登录串行执行，退出会清除两套后端对应 origin 的条目。已有 ad-hoc 签名创建的传统条目可能需要一次系统授权；新建现代条目及同一 team / app identifier 的后续更新不需要这个旧 ACL 授权。

Personal Team 的开发 profile 有效期通常为 7 天。后续本地构建须用 Xcode 自动续签并核验实际嵌入 profile、签名身份、ARM64 架构及 Release entitlement；不能仅添加 Dart 开关或在签名失败后退回 ad-hoc 安装。Release 继续禁用 `CODE_SIGN_INJECT_BASE_ENTITLEMENTS`，不能额外启用 `get-task-allow` / JIT。当前本机验证包括：用合成数据创建钥匙串条目、重新编译签名后读回、清理；查询显式禁止认证 UI，四步均返回成功。本机用户随后完成真实旧会话迁移，并确认再次启动不再弹出钥匙串授权。

已配置签名的本机更新使用 `python3 .local/macos-signing/build.py --install`：FVM 生成 Release 配置，Xcode 自动续签，核验后备份并替换关闭的 App；App 仍运行时停止安装。脚本不启动窗口，安装后的启动继续使用 Computer Use 后台操作。不得用普通 ad-hoc 构建覆盖已经迁移到现代 Keychain 的签名版，否则该构建无法读取迁移后的会话。

通知初始化不弹出系统授权请求；用户在应用通知设置点击“发一条测试通知”后才请求 alert / sound 权限。macOS 是否投递由系统通知权限控制，不使用移动端本地 opt-in。Darwin 插件 initialize 的 false 表示授权结果，不代表原生通知不支持。当前服务端 Socket 只投递 mobile，macOS 在应用仍运行、窗口在后台且授权时复用现有长连接驱动的已接受 unread inbox 数据，不能视为服务端 desktop push 或退出后推送。

媒体原先随 macOS bundle 构建 `media_kit_libs_macos_video`（libmpv）；现改用系统播放器（`video_player` / AVPlayer），bundle 不再包含 libmpv，见 [media-playback](media-playback.md)，该变更尚待在 Mac 上验证。Linux 的 media 下载准备步骤不适用于 macOS。

## 初始覆盖（2026-10-08；后续状态见文末）

| 功能 | macOS 实现 / 验收状态 |
| --- | --- |
| Runner、沙盒、原生插件注册 | 本机 Debug、Release 编译通过；FVM 最终 Release 118.0 MB，后台启动到登录界面 |
| 全仓静态检查及 Dart 回归 | FVM 下 `flutter analyze --no-pub` 无问题；通知 9、会话 3、OAuth 2、附件保存 3、登录 UI 4，共 21 项通过 |
| 后台启动及延迟首帧不抢焦点 | Computer Use 后台打开，观察到首次帧与最终登录界面；窗口初始不可见、随后只在现有窗口后显示，禁止窗口状态恢复；未做独立前台 PID 连续采样 |
| 网络、OAuth loopback、局域网 | 权限已配置；真实登录、OAuth 和局域网授权流程待实测 |
| Keychain 会话恢复、退出清理 | 已配置；macOS 实机读写及重启恢复待实测 |
| 文件选择、上传、保存 | 沙盒权限与既有平台适配已接入；系统面板和上传下载链路待实测 |
| `raft` 内容链接 | 已注册；冷启、热启及真实消息上下文跳转待实测 |
| 本地通知及权限拒绝 / 重新启用 | OS 权限、延迟授权初始化、测试按钮、撤权/恢复及账号隔离回归通过；系统通知横幅、点击仍待实测 |
| 服务端桌面推送 | 未接入 |
| 音视频播放 | macOS 媒体运行库已接入；真实媒体播放待实测 |
| 应用内 PDF 预览 | macOS 未实现，使用既有下载回退 |
| 原生分享 | 当前仅 Android 实现 |
| 独立原生工作区多窗口 | 未实现 |
| 中文 / 日文 IME、VoiceOver、键盘、生命周期 | macOS 实机验收待补；Widget Preview 不替代平台验收 |

本机结果：使用 FVM 3.47.6 完成最终 Release 编译、21 项相关回归与全仓静态检查；Computer Use 观察到完整登录页及 `Linux · Android · macOS` 标识。进程路径为 `apps/raft_flutter/build/macos/Build/Products/Release/Raft.app/Contents/MacOS/Raft`。`codesign --verify --deep --strict` 与 plist 检查通过。登录后的真实工作区、Keychain 写入恢复和系统权限面板不在本次启动验收范围内。

媒体插件当前通过 CocoaPods 接入，其尚未支持 Swift Package Manager；构建有上游弃用/宏定义警告，但最终编译通过。此记录不代表 macOS 完整功能轮次通过。

权限配置依据 [Flutter macOS 宿主说明](https://docs.flutter.dev/platform-integration/macos/building)；Keychain 配置依据 [flutter_secure_storage 11.2.0 官方说明](https://pub.dev/packages/flutter_secure_storage)。

## 品牌图标（2026-10-11）

macOS AppIcon 已替换 Flutter 默认图标，使用 Android 前景与设计系统相同的 Raft 标记：品牌黄 `#FFD440` 圆角底、黑色标记、纸色 `#FFFAEF` 镂空填充。1024px 画布保留外部透明边距，提供 16–1024px 七套 PNG，映射现有 1x/2x 资源槽。`tool/gen-macos-icon` 从现有品牌矢量生成这些资源，无新增 Flutter 包或运行时图像加载。

使用 FVM Flutter 3.47.6 更新 Release 配置，再通过 Xcode 指定 `ARCHS=arm64`、`ONLY_ACTIVE_ARCH=YES` 构建成功。主程序及 Dart App.framework 为 arm64；bundle 引用已生成的 `AppIcon.icns`，签名校验通过。未启动或置前应用；Dock/Finder 图标刷新及实际窗口展示未验收。

## macOS 通知能力修复（2026-10-11）

固定 flutter_local_notifications 22.3.1 的 Darwin initialize 返回授权结果；所有启动权限请求关闭时返回 false，原实现误判为 unavailable。现在将成功调用与 OS 权限分开，并保持启动不弹窗。macOS 使用桌面设置卡片及系统权限，不受陈旧移动端偏好影响；同类初始化修复也覆盖 iOS。

新增 DesktopInboxNotifications：直接消费 SourceActivityUnreadStore 已接受的收件箱窗口，该数据由现有长连接消息/线程事件合并刷新，通知模块没有第二个连接、收件箱请求或周期轮询。该 store 从 WorkspaceView 私有所有权提升为 WorkspaceController 的唯一惰性数据所有者，Activity 页面、未读标记和系统通知共享同一个实例；各消费者借用同一生命周期，最后一个消费者离开才释放，Workspace 退出仍统一清理。仅当前已授权账号/服务器的后台窗口工作，进入后台建立时间基线，不补发前台及旧未读消息。新候选才读取独立 notification-settings 的 OS push mode/静音规则，已通知窗口不重复取规则；投递前核对当前已接受窗口，保留 Done、线程关注及个人提及判断。已投递 ID 有界保存，账号、服务器、角色、生命周期、权限代次或 OS 撤权使迟到请求失效。真正的 App 前后台独立于工作区遮挡状态，Android 和 macOS 消息提醒都只在后台发送，最终 OS 队列发送前再次检查；测试通知可由前台主动发送。不修改已读游标、不注册实验设备协议、不声称应用退出后接收远程推送。

本轮 78 项针对性 Dart/Widget 检查通过，覆盖延迟授权初始化、设置 UI、共享长连接收件箱窗口、前后台、去重、取消、通知规则、通知点击导航、既有 Activity 协议与 section swipe 回归；静态分析无问题，设计系统审计通过。Computer Use 原生连接失败，实际系统授权面板、横幅和点击尚未补验；不把模拟插件检查算作 macOS 原生验收。

安装记录：FVM ARM64 Release 编译成功，主程序、App.framework 及 24 个嵌入框架可执行文件均为 arm64。增量构建后 App.framework 的旧资源签名失效，重新签署该框架与外层 bundle（保留原 identifier、entitlements、flags、runtime）后 `codesign --verify --deep --strict` 通过。仅替换 `/Users/kevinzhow/Applications/Raft.app` 应用包并 `open -g` 后台启动；旧包保留于忽略的本地安装备份，未更改 Keychain / 用户数据。Android ARM64 Release versionCode 8021 通过安装脚本预检及保留数据更新，targetSdk 37。

## ARM64 构建验证

后续按用户要求将 macOS Debug / Profile / Release 与 CocoaPods targets 固定为 ARM64，并通过 FVM 重新构建 Release（64.5 MB）。逐一检查 bundle 中 25 个 Mach-O 文件，主程序、Dart AOT、Flutter 引擎、SQLite 和媒体运行库均仅含 `arm64`，没有 `x86_64` slice；`codesign --verify --deep --strict` 通过。上文 118.0 MB 为更早构建的历史记录。

## Local-use checkpoint (2026-10-12)

本机 macOS 客户端已用于真实工作区，状态不再是“只启动到登录页”。此前用户完成真实旧会话的 Data Protection Keychain 迁移，并确认再次启动不再重复弹出旧钥匙串授权。2026-10-11 用户试用了 Mac 性能优化版本，认可体验提升并批准合入；这不等于全平台功能或完整 120fps 验收。上面的初始覆盖表保留其历史范围，不能据此否定后续已有验证。

2026-10-12 本轮只读检查确认：

| 项目 | 实际结果 |
| --- | --- |
| 已安装原生 App | `~/Applications/Raft.app`，运行进程来自该包；与 Chrome PWA 区分 |
| 应用身份 | `app.raft.raftFlutter`，0.1.0 (6047)，最低 macOS 12 |
| 主程序架构 | `arm64` |
| 包签名 | `codesign --verify --deep --strict` 通过；包内含 provisioning profile |
| Release 权限 | App Sandbox、网络客户端/服务器、用户选择文件读写；无 JIT / get-task-allow |
| 本地更新流程 | 忽略目录内的签名更新脚本存在；本轮未执行构建、替换、重启或 UI 操作 |

版本号与当前进程用于辨认已安装的 App，不据此推断其源码等于仓库最新提交，也不据此证明 profile 当前仍具备续签条件。签名身份、team、profile、账号或凭据不进入公开文档。

[Activity 原生 profile 对比](activity-preview-performance.md) 使用独立测试包及合成缓存：修正前 C 方案的热缓存首帧 raster 中位数从 233.105ms 降到 13.582ms；后续同条目双击修正没有重跑这组原生对比。它证明特定等待的移除，不认证正式 App 的网络延迟或稳定 120fps。

仍需原生验收：通知权限/横幅/点击，OAuth 与局域网权限，系统文件面板与上传下载，冷启/热启内容链接，真实媒体播放，中文/日文 IME、VoiceOver 和完整生命周期。已有源代码、模拟插件回归或其他平台的通过结果不能代替这些检查。正式退出登录与钥匙串清理也不由会话迁移/重开确认推导为通过。
