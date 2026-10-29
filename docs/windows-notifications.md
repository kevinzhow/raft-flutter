# Windows 通知

Windows 复用 DesktopInboxNotifications，消费 WorkspaceController 已接受的 Activity/unread 窗口，与 macOS 使用相同的通知规则、后台条件、去重和账户／服务器／角色／权限 fence。不会另开连接或重复消费移动端 notification:push。首次恢复的历史窗口只建立基线，退出、切换账户和授权撤销清理该身份下的系统通知。系统设置拥有通知开关，应用不保存第二份桌面 opt-in。

Windows 宿主通过系统 Windows.UI.Notifications.ToastNotificationManager／ToastNotifier 投递，使用 `<toast activationType='protocol'>` 和当前用户的 `raft-notification://open?payload=…` 协议。身份为 `app.raft.raft_flutter`，通过 SetCurrentProcessExplicitAppUserModelID 与 HKCU 的 AppUserModelId DisplayName／IconUri 登记，不借用其他应用身份，也不创建 COM 激活器。按微软的桌面 Toast 契约，初始化时确保当前用户开始菜单的 `Raft.lnk` 携带同一 AUMID，位置与安装包一致；匹配的快捷方式不重写，移动便携 bundle 后更新目标路径。隔离 lab 使用单独的 `Raft notification lab.lnk`。完整 bundle 包含 `raft.ico` 和品牌 PNG `notification_icon.png`；通知通过 appLogoOverride 引用图标。每次运行刷新当前用户的协议命令及图标路径，不需要管理员或 Windows App Runtime。

Dart 的 NativeNotificationService／NativeContentCoordinator 继续拥有投递规则、权限、账户 fence 和点击授权。宿主只处理系统投递、设置查询和窗口恢复。暖点击按完整 exe 路径找到既有 Flutter 窗口，通过有界 WM_COPYDATA 转交 URI；冷点击经命令参数启动，初始化回调后再处理目标。宿主兼容 SDK 的 `----ms-protocol:` 参数前缀；Dart 与宿主均兼容 Windows 给空路径补 `/` 的格式。进入内容前仍重新检查 origin、principal、server membership 和消息可访问性。解析限制单个 payload、4096 字符目标和 16384 字符 URI，并拒绝额外路径、端口、用户信息和 fragment；原生早到点击暂存最多 8 条。协议注册不包含账号或消息正文，通知本身包含目标 payload。

未打包应用首次查询 Setting 可能返回 ERROR_NOT_FOUND。宿主仅针对这一错误执行与 [CommunityToolkit 初始化](https://github.com/CommunityToolkit/WindowsCommunityToolkit/blob/main/Microsoft.Toolkit.Uwp.Notifications/Toasts/Compat/ToastNotificationManagerCompat.cs) 相同的登记：禁止横幅、只含产品名称、15 秒过期并立即从历史移除，然后重新查询实际设置。其他查询失败按禁止投递处理。请勿打扰仍由系统控制，Enabled 不表示系统一定显示横幅。

## 历史验证记录（2026-10-12）

以下保留旧 WinRT／COM 与 Windows App SDK 方案的原始结果，不表示当前系统 Toast 实现已经完成设备验收。旧运行库前提、管理员登记脚本和 COM 探针已不适用于当前构建；新版本的验证证据随对应 PR 交付。

| 场景 | 当时证据 | 结果／边界 |
| --- | --- | --- |
| 身份与图标、OS 开关变化、无桌面私有 opt-in | Windows service/widget tests | 通过；原生查询也返回 allowed |
| 后台新收件箱候选、前台抑制、规则、去重、权限／账户切换 | Windows 变体及 coordinator tests | 通过；没有向线上工作区发送验收消息 |
| 暖回调及启动 payload 授权、拒绝越权导航 | service/coordinator/navigation tests | 通过；fixture 的冷 payload 不证明系统冷启动 |
| 系统接口接受及历史存储 | 独立 notification lab；真实指针点击发送按钮；WinRT GetHistory(appId) | 通过：posted=true、active=1、error=null；不证明横幅或通知中心可见 |
| 运行中 COM 通知回调 | Windows INotificationActivationCallback 协议探针 | 通过：taps=1；不是通知中心真实点击验收 |
| 设置入口 | lab 真实指针操作 | 通过：打开系统 > 通知；只读取，没有改变 OS 开关 |
| 横幅与通知中心可见、真实点击 | 用户确认 Windows 右下角通知中心没有测试通知；旧截图曾与目标窗口文字不一致 | 失败反馈待定位；撤回以请勿打扰解释的结论，不修改用户的系统偏好 |
| 完全退出后的 COM 冷启动 | 显式 CLSCTX_LOCAL_SERVER 探针，C# 与原生 C++ 均复现 | 失败：REGDB_E_CLASSNOTREG (0x80040154)；注册路径存在，原因尚未确认 |
| 完全退出后接收新远程消息 | 无 Windows 常驻服务／远程推送通道 | 未实现；当前投递依赖正在运行的客户端 |
| Windows release 主应用 | 本机 x64 编译和会话恢复；实际设置页面、测试按钮 | 通过：恢复原有工作区，页面报告测试通知交给系统；不替代完整功能验收 |

75 项定向测试及 `tool/flutter analyze --no-pub` 通过。设计系统审计仍有本次修改之前的 497 项报告和 14 个 baseline 增长对；本次通知页面使用既有 raft_ui 组件，没有增加这些计数。不由此宣称设计系统全量通过。

首次权限失败的原始 receipt 保留于忽略的 `.local/windows-notification-first-failure.json`，后续权限失败和 cold-first-failure 也保留。成功发送及暖 COM receipt 为 `.local/windows-notification-warm-receipt.json`；包含的只是合成通知测试计数。没有将私有日志或本地会话写入文档。

下表保留首次旧 WinRT／COM 方案的失败证据；2026-10-12 协议方案的最新状态见文末，不将历史失败覆盖成通过。

## 独立原生复验

```powershell
Set-Location apps/raft_flutter
python ../../tool/flutter build windows --debug --target tool/windows_notification_lab.dart --no-pub
```

将整个 Debug 目录复制到一个新的、被忽略的本地测试目录后运行其中的 `raft_flutter.exe`。测试身份 `app.raft.raft_flutter.notificationlab`、GUID `c7f8c268-2e7c-5079-9305-1a7294c70d9d` 和开始菜单目录均与产品隔离；lab 不创建会话、工作区或网络连接。点击 Send test notification 后读取制品旁的 `notification-lab-receipt.json`。`active` 是该 lab 身份的 WinRT 历史数量；未打包应用的插件 getActiveNotifications 固定返回空，不能用于这个判定。

仓库根目录的 `tool/windows-notification-activate.ps1` 仅向 lab 的 COM GUID 投递合成 payload。先在 lab 运行时验证暖回调，再完全关闭 lab 验证冷启动；它不会自动重试或启动替代进程掩盖失败。该协议探针不能替代通知中心的真实指针点击。完成测试后重新用默认 main.dart 构建主应用，勿分发 lab 制品。

## 主应用显示失败复查（2026-10-11）

用户确认点击测试通知后，Windows 右下角通知中心仍为空。只读复查发现产品身份下 WinRT 历史保留 9 条通知，其中 7 条为合成测试，测试通知 SuppressPopup 均为 false。系统通知数据库同身份保留 9 条未过期记录，横幅、toast 和 toast 存储标志允许；系统投递日志记载当前桌面会话收到通知。以上仅证明通知进入系统存储，不证明桌面可见。

当前用户的 AppUserModelId 显示名、图标、CustomActivator 及 COM LocalServer32 路径存在；读取 Windows 设置发送者列表时未找到 Raft。桌面身份解析或显示环节仍需核对，不能仅凭这一现象认定注册缺失或 Windows 故障。此前设置截图出现与窗口文字不一致，且用户确认请勿打扰关闭，因此撤回“请勿打扰是确定原因”的判断。没有清理通知数据库、重启系统服务或更改系统通知开关。

## 基于 shell 的注册与发送对照调研（2026-10-11）

此次通过 shell、原生 API 和源码对照执行；未操作系统设置界面。对照当前插件 3.1.1、本地宿主、微软桌面通知示例与 CommunityToolkit 的登记实现。

| 假设 | 验证方式 | 当前结论 |
| --- | --- | --- |
| 发到了错误的 Windows 用户／登录／桌面会话，或发送进程有管理员身份 | 原生 token、ProcessIdToSessionId、WTSGetActiveConsoleSessionId 查询；RegOpenUserClassesRoot 按实际进程 token 读取 | Explorer、ShellExperienceHost、产品和 shell 的用户与登录会话相同，均非管理员、非 restricted token、无注册表虚拟化或 UIAccess；实际用户类根均能读取产品身份与 COM 键。产品与 shell 为 medium integrity。没有通过模拟用户或改变权限验证 |
| 快捷方式的 AUMID、ToastActivatorCLSID 或目标路径写错 | IPersistFile 重新加载，用 IPropertyStore 和 IShellLink.GetPath 读回实际 .lnk | 产品和 lab 的身份、GUID 均与预期一致，目标路径可读回且文件存在 |
| 只在 PowerShell 里能看到注册表，原生合并视图读不到 | 64 位原生 RegOpenKeyExW 查询 HKCR | 产品和 lab 的 AppUserModelId、64 位 LocalServer32 均存在；不能据此证明 COM 激活成功 |
| 桌面应用目录能够解析 Raft 身份 | 原生 SHCreateItemFromParsingName(shell:AppsFolder\AUMID)；Get-StartApps | 产品和 lab 均返回 ERROR_FILE_NOT_FOUND (0x80070002)，Get-StartApps 无对应条目；同一原生接口查询 Microsoft Store 成功。这是异常线索，现代登记机制不一定依赖 AppsFolder，不能单独认定它是显示失败根因 |
| 仅缺少快捷方式的 Shell 刷新通知 | 仅对产品自身 .lnk 发 SHCNE_CREATE，再查上述接口 | 未修复；未将这一假设写入产品代码 |
| Flutter／插件生成的 XML 导致通知发送失败 | 使用已有独立 lab 身份，由原生 CLI 分别发送最小 ToastGeneric XML 和插件同格式 XML，监听 Failed/Dismissed 10 秒 | 两者 Show 正常返回，历史分别从 1→2、2→3；未收到 Failed/Dismissed。用户确认两条均不在 Windows 通知中心，显示故障在绕过 Flutter 后仍复现 |
| 冷 COM 激活已经修好 | 64 位原生显式 CLSCTX_LOCAL_SERVER 探针 | 仍即时返回 0x80040154，lab 进程未启动；该错误目前不能直接解释通知中心显示失败 |
| 冷 COM 失败仅由 Flutter 宿主造成 | 独立原生 IClassFactory/IUnknown 程序，新建仅本次使用的用户级 CLSID；不同进程、STA、指定 32/64 位、明确 ServerExecutable 对照 | 均返回 0x80040154，独立服务进程未启动。系统自带 ShellWindows 的 local-server 激活成功。说明独立用户级登记也有识别异常，尚未证明与通知显示故障同源；测试后验证命令值并移除仅本次新建的两个注册键 |
| 普通 shell 可以捕获更底层 COM 激活轨迹 | 对单独命名的临时追踪会话启动 COMRuntime Activations ETW | Access denied；会话未启动，没有提升权限、启用系统日志或修改安全设置 |

原生 Shell 状态查询返回 QUNS_ACCEPTS_NOTIFICATIONS，只说明该旧接口的用户活动状态；它不是 Windows 11 请勿打扰状态的可靠替代。未用它覆盖用户对请勿打扰的确认。TWinUI / AppModel 的现有启用日志中，未发现这次 Raft 投递对应的错误；日志缺失不能证明系统显示正常。

### 调研来源与适用范围

- [微软桌面通知示例](https://github.com/microsoft/Windows-classic-samples/blob/main/Samples/DesktopToasts/CPP/DesktopToastsSample.cpp)：旧 WinRT 桌面应用的快捷方式、AUMID、COM 处理器合同。
- [CommunityToolkit 登记实现](https://github.com/CommunityToolkit/WindowsCommunityToolkit/blob/main/Microsoft.Toolkit.Uwp.Notifications/Toasts/Compat/ToastNotificationManagerCompat.cs)：未打包应用的注册表身份、处理器登记与首次通知登记。
- [ToastNotification.Failed](https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.toastnotification.failed)：Show 后仍可能异步失败，Failed.ErrorCode 用于检查失败原因；当前 Flutter 插件没有订阅此事件。
- [微软通知故障排查](https://github.com/MicrosoftDocs/windows-dev-docs/blob/docs/hub/apps/develop/notifications/push-notifications/troubleshoot-notifications.md)：区分未收到与收到未显示的日志入口。这里只采用客户端显示诊断部分，不把 WNS 推送要求套用于本地通知。
- [Get-StartApps](https://learn.microsoft.com/en-us/powershell/module/startlayout/get-startapps)：当前用户安装应用的名称与 AUMID；不是通知成功判定 API。
- [RegOpenUserClassesRoot](https://learn.microsoft.com/en-us/windows/win32/api/winreg/nf-winreg-regopenuserclassesroot)：按指定用户 token 读取合并类根；读到键不证明 COM 服务采用了登记。
- [LocalServer32](https://learn.microsoft.com/en-us/windows/win32/com/localserver32)、[IShellWindows](https://learn.microsoft.com/en-us/windows/win32/api/exdisp/nn-exdisp-ishellwindows)：本地 COM 服务启动路径合同与此次系统处理器对照的 CLSID。

本轮旧方案诊断确认存在实际显示故障：通知进入系统存储，主应用与绕过 Flutter 的两条原生测试均未在通知中心出现。应用身份登记未被桌面正确采用是待验证的推断，不能据此宣布 Windows 缺陷或修改产品注册方案。桌面身份解析异常与独立用户级冷 COM 失败是否同源仍需更底层轨迹；普通 shell 的追踪权限不足。不能以重启服务、清通知数据库、借用其他应用 AUMID 或强开系统偏好掩盖原因。所有探针及原始回执位于忽略的 .local；截至本节旧方案诊断时尚未修改产品发送或注册代码，后续 SDK 协议方案与结果见下文。

## 官方 Windows App SDK 独立对照（2026-10-12，日本时间）

根据用户要求，编译并运行独立 C++/WinRT 控制程序，采用微软 [Console 通知示例](https://learn.microsoft.com/en-us/windows/apps/develop/notifications/app-notifications/app-notifications-console) 的 NotificationInvoked → Register → AppNotificationBuilder → Show 流程，并按 [未打包应用 bootstrap 教程](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/tutorial-unpackaged-deployment) 显式加载本机现有 runtime。没有复用产品／旧 lab 的 AUMID、CLSID、快捷方式或手写身份登记。程序没有登录、工作区、网络消息或 Flutter。

使用官方 NuGet 包 Microsoft.WindowsAppSDK 1.7.250310001，包 SHA-256 为 `A4FDCB81CE3C0F78C0EE801B5DB433FA316E91BE2659F9491706AB91DFE8A985`；只提取编译所需元数据、bootstrap header/lib/dll，没有安装或升级系统 runtime。本机已有 1.7 x64 runtime。独立程序 SHA-256 为 `E0C15A577EF50C553132CFEA61CDEA53400EF732C4C010C34EAA219B26962137`。

SDK 自行创建身份 `{1BA5D2F6-13E1-48EB-9E70-2895401BE904}`、COM GUID `{54E17267-870F-4812-A878-83AA97DB9909}` 和本地 PNG 图标；发送者显示名为 `Official_sdk_control`。通知标题为 `Raft Microsoft SDK test`。初次运行注册成功，Setting=Enabled，Show 返回 notificationId=2515。原始回执、源码和构建日志均在忽略的 `.local/windows-app-sdk-control`。

初次发送用户未注意，按用户要求再次发送，Show 返回 notificationId=2519。用户明确确认第二次发送在横幅和 Windows 通知中心均不可见。此时默认激活方案显示验收失败，尚未接入产品；不能把 API 成功当成显示成功，也不能据此单独宣布所有 Windows 通知均已损坏。

随后只读检查未找到禁用 toast／通知中心的用户或系统策略，ToastEnabled=1，相关 RPC/DCOM/WPN 服务运行，ShellExperienceHost 包 Status=Ok、进程响应，最近日志无对应桌面组件崩溃。WPN 日志记录两次 SDK 通知交给桌面会话。SDK 身份没有独立 Notifications\\Settings 项，但这一项缺失也不是根因证明。独立 COM 控制程序改到本地 C 盘运行仍返回 0x80040154，排除该冷 COM 故障只与 D 盘位置有关；仅本次新建的控制注册键已验证并移除。通知可见性与冷 COM 故障仍不等价。

下一层诊断脚本为 `tool/windows-notification-trace.ps1`：明确要求管理员，采集范围仅通知／桌面／COM 的临时 ETW 会话，默认 20 秒，循环文件上限 16 MiB，仅写入新建的仓库 .local 目录，finally 结束自己创建的会话。不改变注册表、系统偏好、服务或已有追踪会话。通知示例仍从普通用户进程发送。用户明确授权管理员采集后，三次有界追踪已执行并正常停止。原始 ETL 可能含其他应用的事件，仅供本地诊断，不提交或发布。

## 显示侧定位与协议对照（2026-10-12）

追踪加入当前 ShellExperienceHost 注册的 NotificationController、NotificationCenter、ToastCenter 等 TraceLogging provider。默认 foreground 通知 XML 解析成功，但 `AgnosticActivator_InvokeCanActivate` 返回 canActivate=0；NotificationController.dll 10.0.26100.8875 在 notificationactivatorfactory.cpp:43 返回 `0x80070032`（请求不受支持）。随后通知 lifetime 记录 wasToastDisplayed=0、dispatchedToControllersAfterParsing=0。传输层“已投递”和历史记录均不能覆盖此显示侧失败。已确认 Windows 在本机拒绝默认激活路径；尚未证实造成拒绝的底层注册或系统原因，不将其归因为请勿打扰。

同一追踪内，隔离 lab 的 protocol 通知 ID2530 返回 canActivate=1，进入显示控制器，NotificationCenter 记录该条 NotificationItemImpression；用户确认看到推送。主应用旧 foreground 对照 ID2531 仍在相同位置失败。

进一步将独立官方 SDK 对照改为原始 AppNotification XML，activationType=protocol、目标 ms-settings:notifications，SDK 仍自行登记独立身份。ID2532 的「Raft Microsoft SDK protocol test」由用户明确确认出现在 Windows 通知中心。该成功对照满足“官方 SDK 能显示后接入”的用户要求，产品现使用 SDK + Raft 自身协议。协议激活为[微软 Toast XML schema](https://learn.microsoft.com/en-us/uwp/schemas/tiles/toastschema/element-toast) 的公开合同。

| 最新场景 | 证据与状态 |
| --- | --- |
| 独立官方 SDK protocol 通知中心显示 | 用户确认通过；默认 SDK foreground 的失败保留 |
| 主应用 SDK／协议构建与显示 | Windows x64 Release 编译运行通过；用户确认设置按钮发送的通知出现在通知中心 |
| URI 编码、冷启动参数顺序、拒绝歧义／过长／其他身份链接 | 定向测试通过；不等同于通知中心真实点击 |
| 原规则、系统权限、前台抑制、账户切换、授权导航 | 最终 65 项相关测试通过；静态检查通过 |
| 暖协议参数及复用窗口 | shell 发起 Windows 协议，兼容 SDK 前缀与补斜杠后只保留既有 PID；不代替实际通知点击／前台焦点验收 |
| 实际点击与图标 | 初次点击提示获取协议应用的失败保留；机器级协议登记后，用户确认「Raft 图标与点击测试」显示黄色 Raft 图标、点击返回 Raft 正常。此次重发通过原生 shell 使用产品身份与同格式 XML；设置按钮发送已在此前确认显示 |
| 退出后真实点击 | 尚未验收；fixture 或 shell 的参数传递不计作真实通知点击 |
| 完全退出后收到新远程消息 | 仍未实现常驻远程推送；已存在通知的点击启动为独立能力 |

构建通过 CMake 获取上文固定 NuGet 包并校验 SHA-256，生成的 C++/WinRT 投影留在 build 目录。当前验证目标为 x64；制品为 framework-dependent，运行需要 Windows App Runtime 1.7 x64（本机已经安装，包括通知 singleton 依赖）。bootstrap DLL 随 bundle 分发，不等同于携带完整 runtime；本次没有安装或升级系统 runtime，也未验收全新机器部署。

主应用可使用 `raft_flutter.exe --windows-notification-test` 发送与设置按钮相同的合成测试通知；不发送工作区消息。启动阶段恢复账户可能清除此诊断通知，实际显示验收应优先使用设置中的测试按钮。隔离 lab 可用 `--send-test` 发送，`raft-notification-lab://open?payload=raft-notification-test` 复验协议暖／冷传递。旧 `tool/windows-notification-activate.ps1` 是历史 COM 探针，不是新协议方案的验收工具。拉取前设计系统审计报告既有 497 项／14 个 baseline 增长对；合并后的结果见下文，不宣称全量通过。

### 本机协议点击对照

用户确认主应用通知已显示，但点击提示获取打开 raft-notification 的应用。ShellExecute 能解析当前用户协议；Windows.System.Launcher.QueryUriSupportAsync 返回 NotSupported（3），对照 ms-settings 返回 Available（0）。单独 SHChangeNotify、当前用户 RegisteredApplications／Capabilities 登记，以及官方 ActivationRegistrationManager.RegisterForProtocolActivation 均未改变该结果；不能以 shell 能启动推断通知点击能启动。

`tool/windows-notification-register.ps1` 为独立管理员安装步骤，仅登记 HKLM 的 raft-notification 协议，核对完整 Release bundle 的 exe 名称、预期 SHA-256 与现有键的 RaftOwner 后才写入。不会自动从应用启动、不改通知偏好、UserChoice 或 COM，不覆盖其他程序拥有的同名键。用户单独授权后登记成功，退出码为 0；同一 Windows.System.Launcher 查询由 NotSupported（3）变为 Available（0），LaunchUriAsync 返回 true，继续复用既有 Raft 进程。随后重发带图标的产品身份通知，用户明确确认图标和点击返回均正常。此结果是本机对照，不表示所有 Windows 都必须进行机器级登记；移动 bundle 后需重新核对并登记。

### 提交与拉取后的验证

Windows 实现提交 `be2921e` 后拉取 `origin/cindy/integration` 的 `a418fa1`，合并为 `cdaca77`。保留最新 README 的简介结构，Windows 构建、运行库与登记步骤补充至开发和部署指南。合并未改变 Windows 通知宿主、通知服务和内容协调器；用户的实际图标／暖点击确认发生在拉取前，不计作新版完整功能验收。

合并后 65 项通知相关测试重新通过，全工程 `tool/flutter analyze --no-pub` 无问题，Windows x64 Release 重编译通过（97 秒）。设计系统审计为 483 项（widget 221、style 262），13 个 baseline 增长对仍导致 `--check` 失败，增长对均不在此次通知修改的文件中，未修改审计基线。另以全新 CMake 配置确认 bootstrap DLL 安装至对应 runner bundle，避免首次配置时误用系统默认安装目录；SDK 许可与第三方说明随 bundle 保留。

### Windows 工程检查补充（2026-10-12）

更新主线前的整批检查发现，上述 13 个增长对实际来自 Windows CRLF 换行使 `ds-allow` 注释未被识别。审计改用 LineSplitter 后，原有注释 fixture 与 baseline 门槛测试均通过；未放宽规则或修改基线。工程检查入口现支持 Windows 的 Python 脚本启动，要求 Python 3.11+，并向子进程传递 UTF-8 环境。Android 安装器的跨进程锁仍仅支持 macOS/Linux，对应原生锁测试在 Windows 明确跳过；性能保护用例使用假设备及模拟负载，不接触真实设备。

Python 3.12 复验运行 122 项 host 测试，仍有 3 项错误、1 项跳过：上游 CSS 文件的本地换行导致来源散列不一致，以及两项 parity builder 缺少本机 raft-source 参照 fixture。Dart 全量检查另有附件缓存、桌面拖放、截图与原生分享用例失败。整批检查不记为通过，原始日志保留在忽略的 `.local/`；本次主线更新不扩大 Windows 实际验收范围。
