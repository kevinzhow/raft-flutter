# 原生分享与接收

源码基准 26f77ef。Web SelectShareLightbox 的原始行为是选择消息、预览 PNG，再通过支持文件的系统分享或下载导出。原生截图选择与预览 UI 由对应界面模块实现；本平台模块提供私有 PNG bytes lease、Android 系统分享及 Linux/Android 原生保存接口。

Android 消息链接使用源码 `/s/:slug/{channel,dm}/:id?msg=:id&thread=:channelId:parentId` 形状。分享前重新读取服务器成员资格、频道和消息上下文。可配置 RAFT_FRONTEND_ORIGIN，它只对同次编译明确绑定的 RAFT_ORIGIN 生效；切换其他 coordinator 不继承这个别名。Linux 保留复制链接和保存文件，未声称有通用原生分享面板。

附件分享重新取签名地址，再下载到 app 私有 cache/raft-share；FileProvider 只暴露这一目录，每次只授予目标文件的读取权限。签名地址不进入持久缓存或分享正文。导出在作用域变化、宿主关闭、失败或最长 15 分钟后删除，重启清理过期目录。系统 chooser 返回只表示关闭，不证明收件人已经发送内容。

ACTION_SEND/MULTIPLE 是原生接收入口；Flutter 当前的确认弹窗只覆盖既有原生路径，尚未对齐用户提供的实际 Android Raft 分享目标选择流程（见下方差异核对）。接收只接受 content URI，最多 10 个文件、单文件最大 50 MB；文本有长度上限。当前已登录账户、已加入频道和服务器必须通过 fresh authority 检查。用户明确预览并选择添加后，文件才读取、暂存到现有 composer，文本追加现有草稿；不会自动发送。取消和账户/服务器/频道切换使 review 失效。源码内容链接选择打开后仍须重新验证消息上下文。OAuth、含认证参数或签名资源的分享文本不进入草稿。

## 证据边界

- 独立 Android app.raft.attachment_probe 使用生产 MainActivity/NativeSharingBridge（仅 package 改名），实际系统 chooser 将 37 bytes 文件交给另一个独立 app.raft.share_receiver。接收 app 通过授予的 ContentResolver 权限读到 SHA256 `921f61ecb862b1e0eecc02d97c20a3b004cd8ea7a2cf99553377930f75b3322d`，再通过真实 ACTION_SEND 把 grant 交回 probe，probe 读取相同 bytes。源码形状的无凭证 URL 也通过真实 chooser 到达同一个隔离 receiver。真实 BACK 关闭 chooser。
- 原始截图和 UI XML 断言在 agent workspace reports/sharing-platform；主应用及真实服务器未作为这个 OS probe 的发送方。主应用完整分享 UI 的验收由整体 native 测试另行执行。
- 新针对性测试覆盖 content grant 与数量限制、路径清理、迟到文件读取失效、接收器替换所有权、实际 HTTP 下载与临时文件清理、PNG lease/save 取消、API 绑定的 frontend origin、草稿追加及取消、review 权限拒绝与作用域关闭。
- 独立 probe 和 receiver 已 force-stop；自身的 proof 导出已清理，未删除主应用账户数据或更改其他设备。


主 Linux 运行已在 2026-10-07 UTC 的当前检查点覆盖 PNG review/forwarded content；主测试仍在执行且该编译早于最终任务/发送修补，因此这里不将其记作新版本完整 Linux/Android 分享验收。独立 OS chooser 只证明授予接收者的文件与 URL，不证明任何外部服务已发送，也不包含公开上传。

## Android 接收修复（2026-10-11）

接收事件使用 pub 的 `receive_intent 0.2.8`，文件字节使用 `uri_content 4.0.1` 的流式接口；移除本项目自写的 incoming MethodChannel 事件传输与文件字节读取。现有向外分享、私有文件 lease 和确认弹窗保持原有职责。Android 宿主只补齐插件未投影的 ClipData URI、监听建立前的事件暂存和消费后的 Activity intent 清理；文件名称、大小与 MIME 查询在后台线程完成。

选择前检查了实际发布源码。`receive_sharing_intent 1.9.0` 与 `share_handler_android 0.0.11` 会在接收回调中同步解析路径，部分 provider 文件还会同步复制到缓存。当前方案保留 content grant，确认后才通过插件按 256 KiB 分块读取；使用 BytesBuilder 合并一次，而非重复拼接整个文件。声明大小与实际累计大小都受 50 MiB 限制，越界、撤权和 dispose 会取消流。上传接口仍需要完整 bytes；此改动不宣称流式 HTTP 上传或零内存复制，也不宣称任意云 provider 的打开操作都不会阻塞。

连续到达的分享按顺序确认；更换频道、权限或账号会作废旧 receiver 的排队任务。确认后返回频道主输入框，附件沿用既有上传、移除与重试机制，文字追加现有草稿并通过显式 revision 更新已挂载的编辑器，不重建或抢占输入框。普通编辑持久化不增加 revision。取消不读取文件，也不发送消息。

验证：应用平台/确认流程 11 项定向测试、设计系统输入框/焦点/附件输入 22 项定向测试通过；应用及 raft_ui 静态分析无问题；FVM 构建 Android 37、ARM64 release APK。旧独立 OS probe 不代表此插件版本已经完成真机分享、URI grant 或冷启动验收。该轮仅构建，没有安装或改动手机应用数据。

包与发布源码入口：[receive_intent](https://pub.dev/packages/receive_intent)、[uri_content](https://pub.dev/packages/uri_content)、[receive_sharing_intent](https://pub.dev/packages/receive_sharing_intent)、[share_handler](https://pub.dev/packages/share_handler)。

## 跨任务分享导致会话恢复失败（2026-10-11）

在安装版本 4003 的 Android 真机上读取 Activity 状态，确认同一个应用同时存在两个 MainActivity，分别属于不同的任务。分享进入的新页面先显示启动等待，随后出现 `Could not restore the session`；此页仍显示默认 origin，因为恢复过程在读取偏好和安全会话之前就失败了。

主 Activity 的 `singleTop` 加空 `taskAffinity` 允许来自其他任务的分享创建第二个 Flutter engine。第一 UI engine 持有进程级 NativeSessionOwner，第二个在 restore 的 acquire 等待 30 秒后超时，catch 统一显示登录表单。该错误路径没有读取或清除已保存的会话。

修复为 `singleTask`，恢复应用默认 task affinity；外部 SEND/MULTIPLE、OAuth 与通知入口复用同一个主 Activity，通过现有 onNewIntent / 插件传入业务逻辑。会话所有权规则见 session-ownership.md（2026-10-12 起前台不再等待后台）。宿主回归约束同时检查启动模式、affinity、分享/链接/launcher 入口和 Flutter 自动深链关闭状态。

Android 启动模式依据：[Tasks and the back stack](https://developer.android.com/guide/components/activities/tasks-and-back-stack)。原始 Activity 状态和截图只保存在忽略的 `.local/android-share-spinner`，不纳入仓库。

该修复的验证：20 项后台会话/分享/确认定向检查、12 项 Android 入口/安装宿主检查通过。ARM64 release APK versionCode 4005、target 37，实际 APK 的 launchMode 枚举为 singleTask。先 preflight，随后用 tool/android-install 覆盖更新真机；脚本确认首次安装时间及 CE/DE 数据目录 inode 一致，并核对已安装 APK SHA 与制品一致。没有主动启动或操作手机 UI；修复后的真实跨应用分享复验仍待用户重新触发。安装回执仅位于忽略的 `.local/android-installs`。

## 实际 Android Raft 分享流程差异（2026-10-11）

用户提供三张截图作为体验合同：首先显示服务器、搜索和 DM/频道目标列表；选中目标后显示已选目标 chip 与“继续”；点击继续进入目标的普通对话，文件作为可移除附件留在输入框，用户继续编辑并自行发送。用户随后明确更正：截图来自 Android Raft 客户端，而不是安装到 Chrome 的 Web App；下方 Web 调研保留为独立链路的核对，不再将截图入口缺失视为待确认 Web 安装来源。

Flutter 既有 incoming_share_review 使用当前已加入会话和“添加分享内容”确认弹窗，不提供服务器/目标选择。前两轮修改修复了插件接收、草稿同步与 Activity 会话复用，并保留这一旧确认 UI；不能记为已对齐实际 Web 分享体验。插件负责系统事件/文件读取，目标选择与草稿交接属于产品业务。

公开快照 26f77ef 的 public/site.webmanifest 没有 share_target 字段；这个文件不能用于解释 Android Raft 客户端的分享入口。对齐应以实际截图的目标选择、继续和进入普通编辑器为准，同时继续使用已验证的 API 与账户/服务器权限隔离。

## Web 源码调研（2026-10-11）

本轮只调研并补充证据，没有修改产品流程、编译或安装。通过 GitHub API 核对 main 与全部三个公开 tag，并下载完整快照检索源码内容。main / v1.21.2-source.1 指向 `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`（2026-10-06）；另两份为 v1.21.0-source.1 `5f775a9ec3d01cc4951522a7ab313d2ec7e2ae4d`、v1.13.0-source.1 `05f7d8fd77d2535f993d5d90b85118438bc18216`。tag 名称与 packages/web/package.json 的 1.17.5 不是同一版本字段，不能据此推断截图版本。

公开源码中没有找到外部文件分享接收入口（share_target、launchQueue、分享 POST/文件交接处理）。不仅检查 manifest，也检查了 App 路由、构建时 manifest 修改、service worker、附件入口和转发组件；另两份完整公开快照也没有找到对应入口。README 明确这是私有开发仓库的发行镜像。上述结果只证明公开源码的覆盖边界，不否定用户实际 Chrome App 的三步流程。

| 链路 | 已核对的实际代码行为 | 对齐含义 |
| --- | --- | --- |
| 已有消息转发 | ChatPanel 从已选 Raft Message 打开 ForwardComposerDialog；目标取当前服务器频道/DM，按活动时间排序，搜索走 /messages/forward/targets/search。窄屏单选直接进入独立“添加说明”页面，多选最多 10 个目标；最终 POST /messages/forward 携带 sourceMessageIds、destinationChannelIds、note 与 requestId。 | 这是已有消息的快照转发；不支持把外部图片伪装为消息 ID。其移动 UI 没有截图中的服务器 chips、底部继续和进入普通对话的交接。 |
| 普通附件草稿 | MessageInput 的 picker、paste、drop 都调用 addFiles。先创建 File 引用和图片 object URL，显示 validating 预览；每次选择读取服务端 upload-capabilities 的 maxBytes，连同现有附件限制为最多 10 个，拒绝空文件/超限。验证后沿用正常上传、进度、移除与重试。 | 外部分享进入目标对话后应复用这一业务行为；读取资源、上传附件与发送消息是不同阶段，添加附件不自动发送。原生当前的固定 50 MiB 读取保护不能替代服务端上限校验。 |
| 草稿与发送 | 普通输入框保留按 user/channel 隔离的内存附件草稿，组件卸载中断的上传可重试；账户变化清空旧预览。文字另由 messageStore 持久化。handleSubmit 检查 validating/uploading/error 后才向普通消息链路提交 attachmentIds。 | 不应为分享新建第二套编辑器、上传器或消息发送逻辑；Web 的附件内存草稿不等于杀进程后持久恢复。 |
| 实现前 Flutter 接收 | WorkspaceView 只有存在已加入的当前频道时才注册 receiver；reviewIncomingShare 锁定该频道并显示确认弹窗，随后直接 attachUpload。 | 需把待处理分享的目标选择放到能访问服务器列表的宿主，用户明确选择后导航到对应普通 composer，并沿用现有附件选择校验；不能默认投递启动时的频道。调研时尚未实现，现已按下节替换。 |

已验证上述服务器路径在 app.ts 挂载，受 requireAuth / requireVerified / requireServer 保护；attachments/upload 还检查频道访问、发言、归档及只读限制。源码合同不是任意跨服务器转发许可。

额外只读检查了源码公开声明的生产前端 `app.raft.build`：其当前 site.webmanifest 同样没有 share_target，sw.js 未发现外部分享处理。初次 JS 请求返回 HTTP 403，使用普通浏览器 User-Agent / Referer 后读到 index-hVMwuquo.js 与 4,077,057 bytes 的 app-shell-BSa9aQZF.js。主前端包含相同的 forward-mobile-target-page / forward-mobile-note-page / forward-mobile-preview-actions、消息转发和附件能力路径，未找到 share_target、launchQueue、shareTarget、shareFiles 或分享 formData 接收。此为公开制品静态核对，没有运行登录后交互；用户随后更正截图来自 Android 客户端，因此这份 Web 制品不代表截图入口。下载资源与 SHA 记录只保存在 /tmp 调研目录。

## Android Raft 安装包调研（2026-10-11）

用户更正来源后，通过只读 ADB 确认手机另有 `build.raft.app`，versionName 1.13.0 / versionCode 11300008 / targetSdk 36，包入口支持 SEND 与 SEND_MULTIPLE、MIME */*。只提取已安装 base.apk 做静态分析，没有启动、安装、卸载、清数据或读取账户存储。APK SHA-256 为 `89ea95a3d2dbaf02eedda89408f1240726a19738ebe86541624afb9c52e7acf9`。该安装包包含 Android/Kotlin 客户端代码，不是前述 Web PWA。资料留在 /tmp/raft-android-share-research-20261011，不提交 APK、反编译代码或设备截图。

已追到与用户截图一致的外部分享业务链路：

1. MainActivity → AndroidExternalShareAdmissionOwner → AndroidExternalShareInbox：读取 SEND/MULTIPLE、EXTRA_STREAM/ClipData 和文本。接收任务在 Dispatchers.IO 中执行，按 64 KiB buffer 把授权 content URI 复制到 noBackupFilesDir 私有 inbox，并写入 envelope / pending token。默认入站保护为 9 个文件、单文件 25 MiB、累计 100 MiB、envelope 24 小时 TTL；声明大小与实际读取大小分别校验。这是该版本的本地接收保护，不代表服务端套餐限额。
2. ExternalShareLaunchCoordinator：路由只携带 opaque externalShareToken；等待已认证的 account/server/servers authority 再派发 Load，按 token 去重。分享正文、附件路径和登录 token 不作为页面参数传递。
3. ExternalShareStore → ExternalSharePickerAdapter → SlockForwardTargetPicker：复用目标选择 UI，而非消息转发提交逻辑。支持账户有权访问的服务器切换、搜索、目录分页（每页 40）、目标 chip 移除和 Continue；外部分享强制恰好一个目标。切服务器清空旧搜索/目标/选择并取消旧请求，session/render generation 拦截旧行点击。目标目录和搜索由目标 repository 组合频道与成员数据；不能推定等同 Web 的 /messages/forward/targets/search。
4. Continue → resolveComposerHandoff：解析选中目标的真实对话并保存交接草稿；ReadyForComposer 交给应用宿主。需要加入频道的目标有单独确认约束，普通已加入频道/已有 DM 不增加旧 Flutter 那种“添加到当前频道”弹窗。
5. SettingsHomePage 的 openExternalShareComposer → SharedThreadComposerDraftPersistSlice.stageExternalShareDraft：按目标会话的普通 composer key 将附件作为带本地文件引用的 queued 项加入持久草稿，保留已有文字/附件并做去重，再选择服务器、打开普通对话。该交接方法明确记录 upload=0 send=0；用户在普通输入框继续编辑，交接本身不上传或发送。成功才 HandoffCompleted，失败走 HandoffFailed；取消走 cancelAndDiscard。

关键区别：实现前 Flutter 在确认后读取完整 bytes 并立即 attachUpload；原版 Android 先完成受限后台文件暂存，目标选择后只交接本地 queued 草稿。对齐需要覆盖选择入口、草稿追加、上传时机与文件生命周期，不只替换弹窗外观。可继续使用 pub 插件接收系统事件，但插件不承担目标选择或业务草稿权威。

证据为已安装 APK 的可读反编译方法与用户截图；jadx 全量输出存在部分复杂方法还原失败，未将其视作原始 Kotlin 源码，也未执行原版 UI 流程或认定真机验收通过。以上是实现前的只读调研证据；后续 Flutter 实现与验证见下节。

源码入口（均固定为本次核对 commit）：[发行镜像说明](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/README.md#L33)、[消息转发入口](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/message/ChatPanel.tsx#L1158)、[移动转发页面](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/message/ForwardComposerMobile.tsx)、[目标规则与搜索](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/message/forwardComposerModel.tsx)、[普通输入框](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/message/MessageInput.tsx#L1575)、[附件草稿行为用例](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/messageInputDraftAttachments.behavior.test.tsx#L326)、[上传能力与路由挂载](https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/server/src/app.ts#L515)。本轮阅读了用例但没有执行 Web 测试，不计作行为测试通过。


## Flutter Android incoming share handoff（2026-10-11）

本次将接收入口从当前频道移到应用根层。receive_intent 负责系统 Intent 事件与初始 Intent，NativeSharingBridge 仅做平台适配：后台线程查询 provider 元数据、以 64 KiB 固定缓冲复制到 noBackupFilesDir 私有 inbox。Dart inbox 串行写入原子 envelope，最多 9 个文件、单个 25 MiB、合计 100 MiB；未交接记录 24 小时过期。普通发送前仍重新读取服务端 upload-capabilities；暂存上限不是服务器上传额度。

选择页先选服务器，再搜索并单选一个频道 / DM / 成员 / Agent。目录读取显式指定 X-Server-Id，不改变当前工作区；切换服务器清空选择及查询、请求序号拒绝旧结果。公开未加入频道经确认后加入；新 DM 只在 Continue 时解析。Continue 重新验证服务器成员资格与目标频道，再导航到普通 composer，追加文字与 queued 本地附件。此时不调用附件上传、消息发送或消息转发接口。

普通草稿缓存只记录不透明文件引用与安全元数据；文件按 origin / principal 绑定，恢复时校验路径、文件长度和账户。交接 token 防止恢复重放追加同一份文字。普通发送从文件流上传，401 刷新重试重新打开流；发送失败保留草稿，成功、移除、取消、退出与频道 / 服务器撤权清理文件。切换频道 / 服务器与关闭 App 保留未发送草稿。没有卸载或清数据。

| 场景 | 当前验证 |
| --- | --- |
| 根层登录恢复后收件、跨服务器单选、普通 composer 编辑、取消 / 移除 | widget 回归用例（最终工程结果另行记录） |
| 暂存流背压、空 / 超限 / 取消清理、冷恢复、账户隔离、路径约束、撤权清理 | inbox 单元用例 |
| 草稿追加去重、文件引用恢复、失败发送保留、成功释放、持久化失败回滚 | controller 单元用例 |
| multipart 401 重试重新打开文件 | client transport 用例 |
| Android provider、Chrome / Photos / Files 真实分享与系统生命周期、性能基准 | 本次尚未真机执行，不能由 widget / 编译通过推断 |
| iOS / Linux / Windows 外部分享收件 | 本次未新增入口；共享草稿模型不等于这些平台已验收 |


最终验证：产品 / 验证输入 SHA-256 `ade05a14695bb65e1d06916b97f5c9c7f49e0cd5ec0e8c63e09a95521e2c943c`。`tool/check-project` 的 94 项 host 检查与全工程静态分析通过；Dart 全量 3291 通过、3 跳过、18 失败，因此整轮工程状态仍为失败。18 项失败全部在未修改的 HEAD `06521dc40ed48cb49454473a180e702f8ab8f8c9` 副本复现，涉及既有桌面文件夹拖放、Activity 导航定位、频道 / 消息串 / 面板栏测试；本次分享用例全部通过。保留首次失败与基线复验，不将它们记为已修复。

三主题 10000 个目标的惰性列表用例验证首屏构建少于 30 行，且远端行未构建；它只证明构建数量，不替代手机帧耗时基准。已提供三主题 SDK Widget Preview 入口 `features/incoming_share_previews.dart`。

最终 ARM64 release：Flutter build-number 4006，分 ABI 后实际 versionCode **6006**，target SDK **37**，仅 `arm64-v8a`。APK SHA-256 `aef7eeb0e85e818b3b587fe0a82e0eb7cbe6bf1f76f4c1b88f16f2505c3e2962`。用户要求安装后，重新执行 `tool/android-install --check-only` 通过真实制品身份 / 架构 / 版本 / 签名检查，再用同一脚本覆盖更新。安装结果 verified，版本从 4005 更新至 6006；首次安装时间及 CE / DE 数据目录 inode 均保持一致。没有主动启动 App 或操作手机 UI。安装回执保存在忽略的 `.local/android-installs/20261010T182203207084Z.json`；工程与基线详细结果保存在忽略的 `.local/incoming-share-validation.json` 及相邻日志中。本次 Android 真实 provider 分享、冷启动 / 后台生命周期与性能尚待验收。

### 目标选择页对齐 Web 手机转发页（cindy/share-forward）

选择页不再是独立样式：它与消息转发共用 Web `ForwardComposerMobile` 的同一组 raft_ui 页面组件，只在分享模式下替换内容。第一页标题为“选择目标”，副标题说明分享的内容（文件数 / 文字）；服务器 chips 位于搜索框上方（仅多个服务器时出现）；单选行无复选框、无箭头、无底部选择条；点击一行进入第二页“添加分享内容”，显示分享预览（文字片段、文件名与大小）和全宽“继续”。交接、暂存上限、加入频道确认、成员资格重验证和“不上传、不发送”均未改动。差异与测量见 docs/parity.md “Phone forward page and incoming share”。

## 分享等待状态（2026-10-12，cindy/share-progress）

Kevin 反馈：选好目标点“继续”后界面像卡住，没有任何反馈。在隔离模拟器（`app.raft.raft_flutter.linkperf`，真实 receive_intent + NativeSharingBridge，固定的假 API 可调延迟，真实 SEND/SEND_MULTIPLE + ClipData + 读授权）上逐步计时，等待有三个来源：

1. 继续之后依次串行等待：`GET /servers`、`GET /channels/:id`、`selectChannel` 的消息页（含 `X-Server-Id` 切换时的整个工作区加载），每步一个往返；单个小图在 800 ms 往返下共 3.4 s，跨服务器 5.2 s。
2. 源文件复制（接收到分享时已经在后台开始）：模拟器的本机存储 47 MB 约 0.5 s，所以只有云端 / 慢 provider 才会让继续等复制；模拟 1 MB/s 的 provider，两个文件共 10 s。
3. 没有反馈：`RaftControl.busy` 只禁用点击，不画任何东西；“准备中”条按完成文件数计，一个大文件复制期间一直是“0 of N”。

改动：继续时复制、成员资格读取、目标频道行读取并行；只等会话草稿恢复，不再等消息页网络；文件引用与工作区切换并行；取消（返回或系统返回）会终止尚未生效的交接。复制由 Kotlin 每 ~100 ms 回报字节；超限用 provider 声明的大小在复制前拒绝；失败原因（过大、不可读、授权被撤销、空文件）留在页面上标出文件，不再关闭页面后弹一个通用提示。继续在复制未完成时变为进度块（条 + 字节 + 取消 + 转圈按钮）；“添加分享内容”的每个文件卡片显示等待 / 字节进度 / 红色失败原因（方案 B）。`incomingShareWaitStyle` 一个常量切换为方案 A（只有继续按钮显示进度）。方案 C（立即进入输入框，附件显示暂存进度）未实现。

模拟器计时（继续点击到交接完成，单位 ms，往返 120 / 800）：小图 607 -> 243 / 3415 -> 1083；4 张照片（26 MB）590 -> 248 / 3493 -> 1068；20 MB 视频 618 -> 314 / 3457 -> 1024；跨服务器小图 912 -> 567 / 5195 -> 2698。Android 路由收起动画另需约 0.45–0.5 s。模拟器不能证明真机复制速度和 Photos / Drive 的 provider 行为；方案 C 与真机验收未做。

### 即时交接（2026-10-12，Kevin 12:26Z 要求，取代上文“继续前重新读取 fresh authority”）

“继续”之后不再等待任何网络请求：手机已缓存服务器、频道和成员资格，验证放到导航之后。Android 与 iPhone 走同一个 `IncomingSharePicker` 和同一个 `onContinue`（iOS 的 Share Extension 已先把文件发布到共享 inbox，应用收到的是带 token 的暂存分享，所以只剩本机步骤）。

继续时只等待本机操作：复制（慢 provider 时才有等待，带进度和取消）、账户认领、`chooseServer(cacheOnly: true)`（跨服务器时画出该服务器的设备缓存工作区，缓存缺失则直接继续，不等频道/消息页网络）、会话草稿恢复、本地文件引用、草稿和暂存附件写入。选择页自己的目录/成员资格重新验证不再阻塞继续。

导航之后在后台（`verifySharedDestination`）：重读成员资格与目标频道行；公开未加入频道先立即显示“加入频道”确认框（不预先请求），确认后以已加入的本地行打开并在后台 `POST /channels/:id/join`；全新的 DM 以本地行 `pending-dm:...` 打开乐观输入框，后台 `POST /channels/dm` 后把草稿、暂存文件和选中项迁到真实 DM。验证期间该会话的 Send 关闭（控制器 `send` 也拒绝），不发送任何消息。

结果：通过则恢复 Send；服务器明确拒绝（403/404、非成员、已归档/只读、新 DM 无法创建）时保留草稿和暂存文件，在输入框上方显示持久提示并保持 Send 关闭；暂时性失败（离线）则恢复 Send，因为每次发送本来就由服务器裁决；加入失败则换回原来的“加入”行并提示。控制器自身的撤权清理（消息页 403、频道列表缺失）对仍在“验证”或“被拒”状态的分享会话不再丢弃草稿和文件；整个服务器被撤销（`revokeServer`）仍会清理，因为此时已无输入框可展示。

测试：`instant_entry_test.dart` 的新用例在 API 全部挂起、虚拟时间不前进时断言输入框到达（Android warm/cold、iOS 已暂存、跨服务器、新 DM、公开频道加入），并覆盖服务器拒绝、失去服务器、DM 创建失败、加入失败；注入一次 `await c.servers()` 的变异会使这些用例失败。`incoming_share_progress_test.dart` 断言选择页在目录读取永不返回时仍立即交接。

模拟器计时（`app.raft.raft_flutter.linkperf`，真实 receive_intent / provider / ClipData，假 API 往返 120 / 800 ms；从指针按下到草稿与附件已暂存、页面开始退出，单位 ms；含约 60 ms 的测试点击按住；之后 Android 路由动画另需约 0.5 s）：

| 分享 | 上一版（并行读取） 120 / 800 | 即时交接 120 / 800 |
|---|---|---|
| 小图 | 243 / 1083 | 144 / 186 |
| 4 张照片 26 MB | 248 / 1068 | 109 / 142 |
| 20 MB 视频 | 314 / 1024 | 83 / 118 |
| 6 个文件 47 MB | 340 / 992 | 139 / 150 |
| 目标在另一服务器（该服务器无设备缓存） | 567 / 2698 | 138 / 205 |
| 新 DM（乐观输入框） | - | 80 / 85 |
| 公开频道（确认框之后） | - | 126 / 77 |

与往返延迟无关（后台验证在 120 ms 下约 0.25 s 完成，800 ms 下约 1 s，不阻塞）。原始版本为 607 / 3415（小图）和 912 / 5195（跨服务器）。慢 provider（1 MB/s 两个文件）仍受复制本身限制（约 9.6 s），有进度和取消。仅模拟器；真机与 iPhone 未实测。

