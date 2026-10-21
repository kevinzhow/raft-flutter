# Raft Flutter 客户端架构

2026-10-08 更新：下文记录来源约束与目标架构。当前已实现原生聊天、管理、集成与平台服务，扩展原生验收仍在进行；实际完成边界以 feature-parity.csv 与各 evidence 文档为准。下方“拆分”和“推进”保留设计目标，并不表示所有目标已有实测证据。

## 当前证据

> 以下“当前证据”是 2026-10-08 的历史快照（26f77ef、Web 1.17.5、raft-ui 0.5.27）。客户端正在对齐 Web v1.21.12（raft-ui 0.5.52）；当前固定的上游版本以 `docs/upstream-sync.md` 为准。

- raft-source main 快照 26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6；Web 1.17.5，使用 raft-ui 0.5.27、Socket.IO 4.8.3、Zustand、React Markdown、Mermaid、FlexLayout。
- 真正的基础设计系统在独立 npm 包 raft-ui，不只在 Web CSS。下载并检查了版本匹配的包，包元数据标记 MIT，包含 foundation.css、fonts.css、React 组件声明和行为。产品 Web 还覆写部分 tokens；ui-inventory 导入真实产品组件，但例子包含历史硬编码，不能把全部例子自动视为最新规范。
- appTheme.ts 将 family 与 mode 分离。Brutal 仅 light；Elegant light/dark；偏好 mode + lightThemeId + darkThemeId，默认 system、白天 brutal、夜间 elegant。Flutter 要照搬解析/兼容规则，而非额外发明 Brutal Dark。
- API 认证需要人类客户端会话、刷新去重、X-Server-Id、generation 切换清理。raft-sdk 是 TS 库，不可直接导入 Dart；agent API 也不能充当全量 human API。
- sync-core 是纯状态机，存在 epoch、watermark、gap repair、幂等和 domain adapter；需 Dart 行为移植。Activity TypeSpec packet/部分 OpenAPI pilot 明确 experimental 或未挂载，不能当现网已实现全量协议。
- 现有桌面 bridge 包含窗口与服务器绑定；移动 bridge 区分实际会话和 onboarding generation。Flutter 平台适配要保留这些行为，不依赖 React DOM。
- 公共仓库是发行快照镜像，不收 PR。客户端宜放独立仓库或获得官方开发仓库授权后集成，不能预设向镜像提交。

## 拆分

1. contracts：全功能清单按用户场景、平台、角色/能力、现有 Web 行为、API/events、测试、进度列出；取已挂载协议，生成可生成的 Dart 模型，对空缺保留审计过的手写适配。建立主题/token、消息/同步、权限三套共享 fixture。
2. raft_ui：分 primitive tokens、semantic tokens、组件 recipes；导出 Web 对应主题的 computed values 与源版本摘要，OKLCH/alpha/shadow/font metrics 转换经验证，生成 Dart ThemeExtension。基础控件到产品组合组件分层；包含 hover/focus/pressed/disabled/loading/error、键盘和语义。组件展示 app/golden 对照。无网络/领域依赖。
3. raft_client：纯 Dart human auth/HTTP/socket，安全存储接口、refresh single-flight、server/account 隔离、typed errors、分页/上传、日志脱敏。未来可独立 SDK，不放 UI 状态。模型和通信分开。
4. raft_sync：移植已启用的 snapshot/difference/event reducer、seq/epoch/去重/补偿、撤权清理、read state；共用 TS/Dart fixtures。Repository + Drift 落库并投影给 Riverpod。缓存离线读；离线写只按服务端幂等合同支持，失败发送显式重试。不能把 Riverpod 或数据库当同步算法。
5. app/features：登录入驻、server/channel/DM、消息/thread、搜索/saved、Activity/read、tasks、agents/computers、settings/admin/integrations；每 feature 垂直实现 model/repository/controller/view，领域 reducer 尽量纯 Dart。共享实体和权限，避免页面独立重复 stores。
6. raft_platform + adaptive shell：Linux 侧栏/消息/线程多栏、调整栏宽/键盘/右键/拖拽/多窗口、通知和 URI；Android 单栏栈、sheet、返回、IME/分享/后台恢复/推送。宽度和输入决定布局，OS 控制系统服务。各宿主按 interface/capability 提供能力。Linux Wayland/X11、keyring缺失、通知激活；Android冷启/deeplink/token续期/后台推送都是实机验收。
7. qa/tooling：主题/组件 golden、跨语言 sync vectors、角色与撤权、Web/Flutter相同任务回放、长消息和数万条历史、长时间掉线、多服务器、多窗口、Android生命周期、Linux窗口/发行打包。按协议、行为、视觉、平台四种证据定义完成。

## 库选择与职责

- flutter_riverpod：依赖注入和订阅投影；业务同步状态不写进 Widget。
- dio：HTTP、取消、拦截器和上传进度；应用负责刷新/重试幂等政策。
- socket_io_client：兼容现有 Socket.IO 4.x；单实例与认证/重连需集成验证。
- drift + sqlite：消息缓存、索引、事务、迁移；保留 Web 存储后端接口。
- go_router：频道/线程/消息/通知链接统一路由，回退与布局状态分离。
- flutter_secure_storage：Android Keystore 与 Linux Secret Service；Linux keyring 不存在必须有明确恢复行为。
- flutter_markdown_plus + 定制AST节点：普通 GFM、代码/引用与 mentions。它不支持 inline HTML，Mermaid、任务引用/action cards、附件、流式块需单独协议 renderer。
- 编辑器第一步 TextField/SelectionArea + mention/附件；super_editor 候选先测中文日文 IME、selection、Markdown双向保真、Linux键盘，不能选了就宣称等价。
- window_manager、flutter_local_notifications 等经平台 facade。后台 Android remote push 还需生产推送链路与服务端支持，local notifications 不代替。
- Flutter 自带 Sliver、Shortcuts/Actions/Focus/Semantics 作为基础；倒序聊天列表历史 prepend、可变高度、图片晚加载、anchor 必须实测，必要时再选专项库。

## 推进与验收

P0 设计与功能盘点/协议确认；P1 UI 展示站和 theme fixtures，同时客户端auth/socket尖峰和两平台壳；P2 真实登录→频道/DM→历史→发送→thread→断网重连→未读→通知定位的完整切片；P3 其余功能逐项对齐，包括平台高级能力；P4 按全功能清单封版和发行。

UI、纯Dart协议/同步、平台适配在 P0 合同后可并行，feature任务按独立领域分组。先验证实时会话、中文日文输入、主题三大风险，避免大量静态页完成后才发现基础不兼容。

不承诺项目日历时长或库是绝对最好；这是基于当前源码和官方库能力的选择，落地需要工程尖峰。

## 来源

- https://github.com/botiverse/raft-source
- https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/theme/appTheme.ts
- https://github.com/botiverse/raft-source/tree/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/sync-core
- https://registry.npmjs.org/raft-ui/0.5.27
- https://pub.dev/packages/flutter_riverpod
- https://pub.dev/packages/dio
- https://pub.dev/packages/socket_io_client
- https://pub.dev/packages/drift
- https://pub.dev/packages/go_router
- https://pub.dev/packages/flutter_secure_storage
- https://pub.dev/packages/flutter_markdown_plus
- https://pub.dev/packages/super_editor
- https://pub.dev/packages/window_manager
- https://pub.dev/packages/flutter_local_notifications

## 讨论修订：flutter_chat_ui

用户补充 flutter_chat_ui 后，检查了当前 2.12.0 发布源码及官方定制/架构文档，将其列为聊天列表首选候选。使用 ChatAnimatedList 的分页/消息更新，通过 chatMessageBuilder、customMessageBuilder、composerBuilder 实现 Raft 展示与编辑；ChatController 通过 adapter 消费自己的 domain projections，不取代 Raft API/sync/Drift 权威。复杂消息模型以领域对象保存，展示映射不丢字段。

主题 tokens 映射 ChatTheme，完整 borders/shadows/layout 用 Raft 自定义 builders。频道/线程需独立 controller 和滚动状态；搜索/通知跳转到未加载消息需要 API 上下文加载，不是只调用 scrollToMessage 就够。验证连续历史 prepend、变高图片/Markdown/流式内容、选区/右键、平台 IME、切频道恢复，以及全量 setMessages vs 增量 operations 对滚动影响后才锁定依赖。

来源：https://pub.dev/packages/flutter_chat_ui 、https://flyer.chat/docs/flutter/getting-started/customisation/ 、https://flyer.chat/docs/flutter/getting-started/architecture/ 。客户端现已采用 flutter_chat_ui 2.12.0，通过独立 Raft model/ledger 与 ChatView adapter 接入。Linux 和 Android 已验证中文日文消息、thread、搜索上下文跳转和断线回放；变高富文本、更多平台流程与长历史性能按覆盖矩阵单独记录。

## 当前实现对应关系

- raft_ui 提供独立 tokens、主题、导航、表单、消息、附件与原生 Mermaid 组件，SDK Widget Preview 覆盖三种实际主题。API 与原生系统服务位于 app/platform 或 feature 层。
- raft_client 提供人类认证、刷新去重、Socket.IO、账户/工作区 generation fence、上传重试与安全错误。main 对跨客户端登录尝试的安全存储提交另加串行栅栏。
- raft_sync 的纯 reducer 已通过 TS/Dart 等价向量；消息、read-state 与恢复流程通过 WorkspaceController/MessageLedger 接线。source-enabled thread-replies 的最新三条、epoch rebaseline 与 accepted unread refresh 已接入；notification-prefs 使用真实条件开关并保留 legacy 路径。工程和平台结果按下方源码检查点记录，Activity TypeSpec experimental cutover 不由纯 reducer 或旧平台基线替代。
- Drift 缓存按账户与工作区隔离，保存真实离线消息、草稿与 read frontier；撤权立即清 UI 并串行清缓存。签名附件地址及凭据不进入缓存。
- 冷启动缓存优先：会话带有上次确认的账号记录时，先用本机服务器目录、频道列表、未读、上次选择的消息窗口（及访问过的消息串窗口）绘制首帧，再在后台依次校验 /auth/me、/servers、频道列表与当前页，原地替换。缓存不设过期时间，始终后台重验；它不是授权：窗口只在保存时相同的角色与频道权限下采用，新事实撤销频道 / 服务器成员身份或改变角色时立即从界面和磁盘移除。未经重验的磁盘窗口不发送已读回执。每个服务器的消息 / 消息串窗口按最近写入保留（默认 120 个，每个最多 500 行）；登出、会话被拒或账号变化清空该账号数据。服务器级实体目录（Agent 含已删除墓碑、成员、电脑）同样按 (origin, 账号, 服务器) 每类一条记录落盘并记录保存时的角色：选择服务器时先于网络绘制（Agent 状态徽章、模型、成员角色、电脑列表首帧即有），标记为重验中并由本次读取原地替换；只在角色相同且该角色可查看此类时采用，角色 / 权限变化、401/403、服务器撤销与账号清空时删除。已接受的读取与实时补丁去抖写回；登出先停止写入再清空。消息翻译（Web translationStore 只在内存，按消息 ID 保存，仅对请求时的目标语言与原文有效）额外落盘（schema v2 的 message_translations 表，按 (origin, 账号, 服务器, 消息 ID) 一行，带频道 ID）：只保存稳定结果（已翻译，以及只取决于内容的跳过原因），等待中、失败、配额 / 服务端跳过不保存；连同服务器翻译开关（记录保存时角色，角色不同不采用并删除）在选择服务器时先于频道首帧恢复，因此重启后缓存的翻译首帧即显示、不再请求，开关本会话仍重验一次。原文被编辑或目标语言 / 模式变化时旧条目不匹配，按 Web 规则重新请求。写入去抖批量进行；每个服务器按最近使用保留（默认 2000 条，再次显示的恢复条目视为使用）；频道 / 服务器撤销与账号清空时删除，登出先停止写入再清空。
- 管理页面使用现网挂载路径与能力校验：providers、MCP、Apps、Slack、analytics、billing、setup、agents 和 Computers。未配置的第三方 OAuth、计费和 Slack provisioning 不产生模拟成功状态。
- go_router 尚未作为路由权威接线；本地 URI 与通知由 NativeContentCoordinator 校验服务器成员资格并获取真实消息上下文。Android 原生 share/通知 bridge 和 Linux 单实例 URI 使用平台 facade。Android 周期后台收件箱兜底（WorkManager）已于 2026-10-13 按业主决定移除，Android 后台通知只依赖在线 socket；其历史证据保留但不再适用。iOS 仅源码接入。FCM/APNs 注册、Linux 服务端消息推送及独立桌面多窗口不属于当前已验证能力。

### 前台启动与后台会话交接

前台先只读本机已确认的账号与工作区缓存，不等待后台通知 worker 或 `/auth/me`。原生启动画面只保留到本地页面就绪；没有账号记录、服务器目录或频道缓存时，立即交给相应的首次加载界面，不用网络等待延长启动画面。正常恢复的第一个应用帧直接是缓存页面，网络重验原地更新。

凭据所有权见 [session-ownership.md](session-ownership.md)：前台（UI engine）是所有者，后台 worker 是访客。前台 `claim()` 同步、永不等待、永不失败，直接替换活跃访客或已死亡 isolate 留下的注册；HTTP、缓存读取和 Socket.IO 连接都不等待后台。只有凭据旋转会在访客确认停止（上限 1 秒）后，重读最新完整凭据并沿用其已持久化的刷新重试绑定。访客被抢占时立即关闭网络、屏蔽后续凭据写入；其写入按读取时的记录做比较后写入，绝不覆盖前台已改变的会话。交接发现会话被删除或变成另一账号时，退休旧客户端与旧账号缓存，不覆盖另一账号的会话。退出登录立即使旧请求失效，将凭据清理排在后续登录写入之前，并用后台最后保存的凭据撤销旧会话。

定向覆盖由 `cached_restore_test`、`session_test`、`session_persistence_test`、`background_inbox_test` 和 `restart_cache_first_frame_test` 提供：包含 Android 布局下后台访客存在时的首帧与全部启动网络读取、缓存页面交互、凭据轮换/刷新重试、撤权、退出与重新登录并发、连接启动以及等待中的 owner 释放。这些组件和逻辑回归不替代 Android/iOS 真机冷启动、系统后台调度或启动耗时采集。

## 当前共享组件与领域边界

共享侧栏规则区分 raft-ui 通用组件与实际产品覆写。产品分组标题、计数、折叠与排序使用共享 recipe；Search/Activity 与 Saved 使用各自实际挂载角色，Saved 的总数来自真实 GET 元数据，与未读数分离。48 像素触摸范围属于原生适配，不能计为原版 24 像素动作布局相同。

系统提醒中心分为无网络的 raft_ui 展示组件、纯提醒投影、作用域数据 store 与挂载 Bell 适配。它独立于消息 Activity 和 OS 通知。适配读取现有 Computers、agents、server、channels 与 Feedback 未读数据，不创造提醒列表或已读 API；本地只持久化有界的提醒指纹。账号、server、权限和请求版本变化会撤销旧结果与弹层，暂时读取失败保留已接受的未读数。

Feedback 页面读取已挂载列表与详情接口；详情 GET 本身推进服务端阅读游标。列表、详情和回复只保存在当前账号作用域内存，晚到结果不能恢复旧未读数或跨作用域内容。本次页面提供阅读，不提供创建、评论或关闭操作；实际后端未配置时显示错误，不生成空列表成功状态。

会话组件按实际挂载来源区分频道图标与 DM 头像。频道使用 ChannelKindIcon 的 14px 图标、18px 槽位、2px 线宽和联合频道 GitBranch；通用组件的 12/14px 与 1.5px 线宽不是这个页面的规则。频道标题为 14/20、常规 500，仅真实未读增加粗体。频道与 DM 的响亮未读徽标共享 accent 规则；DM 徽标修正不表示其头像与行布局已对齐。当前尺寸合同绑定 39 项规则、101 个所选文件内的公开类及 463 个产品与验证输入，只验证来源和散列，不验证完整 CSS、算式或像素相等。

长内容的共享组件从首次布局限制折叠视口，同时保留自然内容测量。测量回调、延迟富文本、列表回收与初始定位必须配合验证；原版以消息及其视口内偏移保持阅读位置，展开内容属于阅读操作。针对性回归与修改前后的聊天列表测试不替代下方同源码完整原生流程，最终 3ac 工程及两平台原生功能断言已通过，逐像素验收仍未完成。

## 已验证的源码与当前边界

| 源码检查点 | 工程检查 | Linux 完整主应用 | Android 完整主应用 |
| --- | --- | --- | --- |
| 历史 `6ab79f33` | 353 Dart、29 host、分析器通过 | 通过；53 检查点，03:11:25 run | 通过；54 检查点，03:02:43 run |
| 历史 `0ea636e6` | 不由旧平台结果推断新版工程状态 | 通过；53 检查点，07:53:47 run | 失败；08:00:19 run，8 检查点后旧移动导航定位失效 |
| 移动导航 `518ad5e4` | 533 Dart、29 host、分析器通过 | 未运行 | 失败；08:56:29 run，44 检查点后 Mermaid 窄屏工具栏溢出及退出选择定位歧义 |
| 后续修正 `1b8906fa` | 541 Dart、29 host、分析器通过 | 未运行 | 未运行 |
| 共享布局 `348911c8` | 548 Dart、29 host、分析器通过 | 未运行 | 已开始后中断；09:28:15 run，Home/详情/历史通过，Search 全局等待停滞 |
| 历史修正 `e1ac2c23` | 549 Dart、29 host、分析器通过 | 未运行 | 失败；09:41:21 run，三主题 Home 与 Search 目标可见通过，随后显示源码后的复制点击失败 |
| 分组基础 `2b85d1b4` | 562 Dart、29 host、分析器通过 | 未运行 | 失败；10:01:22 run，分组组件挂载后，Search 部分遮挡的消息被接受，真实操作点击失败 |
| 可见范围修正 `d6cf1b57` | 563 Dart、33 host、分析器通过 | 未运行 | 失败；10:13:43 run，Search/Save 真实点击与 Copy 精确剪贴板通过；Expand 原本可点击，辅助滚动后移出命中区域 |
| 富文本点击辅助修正 `4df9efd8` | 563 Dart、33 host、分析器通过 | 未运行 | 失败；10:24:11 run，25 个检查点后切回聊天时 pumpAndSettle 超时；运行时采样确认持续重排 |
| 新导航、通知、Feedback 与初始布局 `ad337ead` | 696 Dart、33 host、分析器通过 | 未运行 | 失败；11:36:09 run，60 个检查点通过后，侧栏标题测试仍按旧大小写定位；保留此失败后修正测试 |
| 侧栏定位与独立复验 `7f39a5f4` | 696 Dart、33 host、分析器通过 | 未运行 | 独立侧栏实际操作、API 结果与恢复设置通过；完整流程未开始，此通过不替代整轮验收 |
| 共享会话规则与桌面铃铛复验 `1ca110f6` | 709 Dart、33 host、分析器通过 | 未运行 | 通过；12:06:34 run，66 个完整流程检查点与实际退出登录通过，原始证据已归档 |
| 共享规则与完整原生复验 `3ac80c8f` | 709 Dart、33 host、分析器通过 | 通过；12:13:48 run，56 检查点 | 通过；12:20:19 run，66 检查点；两平台实际退出登录与会话清除通过 |
| 发布配置显式化 `1844d4af` | 709 Dart、33 host、分析器通过 | 已开始后因补齐会话备份策略而中断；无整轮通过 | 未运行 |
| 最终备份策略 `14fd1064` | 709 Dart、33 host、分析器通过；实际 APK 发布构建预检通过 | 通过；12:44:12 run，56 检查点，实际退出及会话清除 | 失败；12:50:22 run，首轮 53 检查点后 HTTP 响应解析异常；12:55:15 同源第二轮 42 检查点后 PDF 真实点击未命中 |
| 最终附件命中辅助与完整复验 `b98e0a30` | 709 Dart、33 host、分析器通过 | 通过；13:10:10 run，56 检查点，实际退出及会话清除 | 通过；13:04:28 run，66 检查点，真实 PDF 点击与原生解码、管理操作、退出清空会话通过 |

以上时间均为 2026-10-08 UTC；完整源码哈希分别为 `6ab79f33a7f39f98523dadd38dfc1430fd2d7f8e75d10736d0c80050bd1c5701`、`0ea636e658e0d8042b6342e9e50d9ba504cc87492f1e51ad2e9b1a4f99b7baed`、`518ad5e4ca0686df5eb7805fcbde752a4d774fab9bd627a4dbae44e9f36947e3`、`1b8906fa579960daa933c0c18dc18cda7ecc3d648834e83967e2269840040d95`、`348911c8c934e37a7d5dcc39d5a8812115400a4e6aae9866c6a6de5fccbca916`、`e1ac2c23eff8c980e405b01ed92beaed54dd9e69e953aeb9429d5860fe216c5d`、`2b85d1b4a9ee271ab23eb582add5c8277d1e22821d6a37ddf645a3833413e9a6`、`d6cf1b57d689b28d4c2d88adb524ce727771ffd4aab79e88f217c822981d2a12`、`4df9efd8a0374ecaa877fe925c22377ec0ba273835d122a410546de93f96f032`、`ad337eade5901c79658179a06863646ea5f7d3b1a76398eb51878151c9e20b87`、`7f39a5f4f8b4d4265da6fb00a128dcb880e05f432b2803a11399b7bbdae64b40`、`1ca110f694349b8a540d073a810f8e77fdfdce34ce336c28b4f23f1082229877`、`3ac80c8fe00d6dd9cf1e5f58407a8c526cfccec9a28790fa3bbce5aa35a416d6`、`1844d4afe53cb45c150cca1e608adc313e83104f577520435d83500bbe79d884`、`14fd1064f16f726a7835c33e9a22b2239407fb422ab80b698777215bc4f7b72e`、`b98e0a301b74980654be7a5268f2ada2202541b2c2ba026b9a8b3f575a7fc079`。6ab 基线归档于 `.local/functional-baseline-6ab`，0ea Linux 归档于 `.local/functional-phase4-0ea636e658e0`。源码和 runId 决定证据适用范围；旧通过不能计为当前修改通过。

Search、Account、Appearance 和移动四项导航已有后续实现与定向回归。依据用户要求继续完善共享尺寸、响应式与布局约束；后续 348、e1ac、2b85、d6cf、4df9 与 ad337 已分别冻结并实际运行 Android，均未完成通过两平台流程。3ac 已完成同源码 Linux 56 与 Android 66 个原生功能检查点，证据已保留。发布构建随后要求明确三个 loopback 域名的 includeSubdomains=false；该默认值显式化形成 1844 源码，709 Dart、33 host 与全工程分析器已通过；Linux 复验开始后因还需明确会话备份策略而中断，Android 尚未运行。最终会话备份策略已冻结为 14fd 源码，配置为排除云端与设备转移备份中的本地状态；实际 APK 发布构建预检及 709 Dart、33 host、全工程分析器已通过；当前 Linux 56 个完整检查点已通过，Android 首轮在 53 个检查点后出现 HTTP 响应解析异常，已记录失败；同源码第二轮又在 42 个检查点后 PDF 真实点击未命中；随后仅修正附件测试的滚动定位与命中就绪辅助；b98 工程检查及同源码 Linux 56、Android 66 个完整检查点已通过；最终 APK／Linux 包构建、实际安装／移目录基本交互、媒体解码及发布报告浏览器下载 SHA 校验已通过。

视觉验收未完成。旧 `0e049d15` 的 30 组实际失败配对保留为历史；`518ad5e4`、`348911c8`、`e1ac2c23`、`2b85d1b4` 与 `d6cf1b57` 的三主题 Android Home 结构对照也均未通过。e1ac 背景色与按钮居中已有实测改进，2b85 已显示共享分组计数、折叠与排序操作；触摸适配后的布局、导航分组间距及原版提醒中心仍未完整验收。ad337 的三主题 Home 与真实系统通知弹窗已发布为六张原始截图；实际打开、320×288 尺寸及关闭操作通过，但没有判定像素通过。固定清单为 523 项，另有三组移动诊断。移动诊断使用原 Web 和原生各自真实的 412×915 图，不裁剪或缩放，但公开参考数据与原生工作区数据、安全区不同，不能充当同数据逐像素验收。原生根页面操作通过不代表字体、布局、颜色或全部状态与 Web 一致。

## 共享设计系统与布局约束

raft_ui 的颜色映射已有生成来源；部分尺寸与布局约束仍分散在手写 recipes 和产品组合中。原版规范同时来自 raft-ui 组件 recipe、foundation.css 与 Web 的响应式覆写，不能只提取主题颜色或单组数值。当前完善工作从共享规则入手：记录源版本和方向性间距，区分绘制尺寸与触摸范围，表达容器约束、窄屏换行、断点和安全区。页面应使用这些共享规则；实际失败用例验证规则，不能靠页面局部坐标掩盖差异。

历史 75 项 SDK 主题交互证明相应浏览器交互，不证明当前源码的逐像素对齐，也不能替代原生系统输入、无障碍或完整平台流程。

共享尺寸来源及尚未绑定的布局规则见 [尺寸合同](design-dimensions.md)；详细源文件、行号、摘录与 SHA 在同名 JSON 中。该审计快照不代表像素或原生验收通过。

当前完整输入为 b98：仅附件测试使用支持的 Scrollable.ensureVisible 将真实标题居中，并等待有限时间内真实命中检查通过，再执行原有真实点击；PDF、音频、视频断言未改。工程与同源码 Linux／Android 整轮、最终制品运行与下载校验均已通过；这不证明 Search 自动定位或已解决此前 HTTP 异常。

## Final released artifact scope

The delivered b98 APK and Linux archive match the manifest bound to product commit `032f9f0442cf972c3e566c57ee9a19e8f361e2f3`. The real browser downloaded both archives and confirmed their sizes and SHA-256 against the independently reviewed manifest; all 221 report images decoded. See [released artifact evidence](release-evidence.md) for exact hashes and probe boundaries.

The released APK smoke used an owned 16KiB Android emulator and synthetic input without authentication. Linux basic GUI/CJK interaction used a relocated archive, the build host’s isolated GTK/X11 session and an initialized empty SecretService keyring. Its live text readback passed, while the separately attempted AT-SPI Component.GetExtents method still timed out; screenshot-measured pointer input does not certify that coordinate method. Bundled libmpv PCM decoding passed separately. These checks do not establish store signing, physical devices, authenticated release workflows, Wayland or arbitrary Linux distributions. Pixel-level parity remains unaccepted, and the earlier HTTP parser failure has no confirmed cause.

## 移动导航呈现（2026-10-10）

窄屏工作区由 `MobileWorkspacePages` 将既有 `WorkspaceNavigation` 历史投影为平台 `MaterialPage`，不建立第二份业务导航权威。历史页面保留实际 widget 子树及借用的呈现 controller，共享工作区已接受的数据；不再保存路由截图，并明确关闭路由快照。账号、服务器或权限范围变化会撤销旧页面。Tab 根页面与减少动态效果直接切换，层级页面采用 Flutter 平台默认进入、返回和返回手势。宽屏继续直接投影分栏内容。

移动任务槽现在拥有独立 MaterialPage，桌面继续使用 modal / docked 呈现。频道设置与成员通过客户端 `channelPage=settings:<channelId>|members:<channelId>` 槽投影为页面；底层频道、消息串与任务 URI 合同仍保留。冷链接先补入底层目的地，系统返回与顶部返回消费同一份业务历史；页面身份与进入实例分离，退出动画中的旧实例不会与快速重入的新实例共享帧 key。宽窄切换保留活动子树和任务 owner；呈现实例只由既有业务历史派生，不维护额外业务位置。隐藏的工作区保留草稿与列表状态，排除焦点、语义并暂停动画。

移动频道设置与桌面复用 `ChannelOverflowMenu` 对应的成员区、内联名称/描述表单、偏好与管理操作，以及同一份权限和命令逻辑；移动端仍由路由槽承载，使用与 Web 手机面板一致的页头（盒状返回按钮，Brutal 62px / Elegant 56px），打开时不自动聚焦。未保存编辑在退出或转到成员页前由同一 guard 处理，窄屏提示按钮自动换行。私聊设置共享新版偏好内容，显示对方名称，不提供频道元数据或成员区。成员添加视图先消费自己的返回，再返回频道设置。账户、服务器、角色或频道权限收缩时撤销管理页。桌面仍使用右侧 drawer。

2026-10-11 此次对齐通过 50 项设置适配/路由测试与 13 项组件/预览检查；包含 Android/iOS 路由变体、三种主题、保存、未保存返回、成员页往返和失权退出。组件测试中的系统返回模拟不等同于原生返回手势验收。

移动附件预览是持有附件元数据及权限绑定的临时 `MaterialPageRoute`，不改变底层频道业务位置；图片、文档、PDF、音视频与 HTML 共用页面页头及原有预览资源生命周期。图片缩放 controller 在退出动画完成后释放；权限撤销仍立即移除私有预览。桌面预览继续使用 DialogRoute。

`RaftMobilePageHeader` 仅用于标签根页（56 逻辑像素、48 像素操作槽）；面板/详情页（2026-10-11 起，业主选 B）使用 Web 的 `panelHeader` 配方与盒状返回按钮，触控区由 `RaftTouchTargetExpander` 扩展到 48px，系统安全区由宿主提供。Android 实机及组件检查的覆盖边界见 [mobile-navigation.md](mobile-navigation.md)，不能据此推断 iOS、Linux、Windows 的平台验收通过。

### macOS 通知平台补充（2026-10-11）

NativeContentCoordinator 为 macOS 绑定 DesktopInboxNotifications，直接消费 WorkspaceController 唯一 SourceActivityUnreadStore 已接受的窗口，与 Activity 页面和未读标记共享长连接驱动的现有收件箱刷新，不创建第二连接、收件箱请求或周期轮询。OS 权限是桌面开关；只在后台消费新候选，读取独立 notification-settings 通知规则，核对当前已接受窗口，并维护账号/角色/权限代次/生命周期 fence。仅持久化时间基线和有界 message ID，不持久化通知正文。应用完全退出后的远程推送与 macOS 系统横幅/点击实机验收仍未覆盖。

### Windows 通知平台补充（2026-10-11）

Windows 使用同一 DesktopInboxNotifications 权威与生命周期。WindowsNotifications／原生宿主提供稳定身份、官方 Windows App SDK 投递、ToastNotifier.Setting 及窗口恢复；业务授权与导航仍在 NativeContentCoordinator。系统权限在每次投递时重新读取，桌面不保存私有 opt-in。ETW 确认本机在显示前拒绝默认 foreground 激活（0x80070032），官方 SDK 的 protocol 对照已由用户确认在通知中心显示。因此产品使用 raft-notification 协议：暖点击转交同 exe 的现有窗口，冷点击经参数启动后等待回调初始化，仍保留全部账户／授权检查。主应用设置按钮发送已确认显示；本机另经用户授权登记机器级 Raft 协议后，用户确认品牌图标和暖点击返回正常。冷点击仍待实测，不以接口接受、历史、fixture 或旧 COM 探针代替。当前 x64 bundle 需要 Windows App Runtime 1.7。具体矩阵、独立身份和边界见 [Windows 通知](windows-notifications.md)。

## 附件磁盘缓存的清理（2026-10-14）

`AttachmentDiskCache` 的 `attachments` 命名空间（按账号 / 服务器 / 频道）除 1 GiB 的 LRU 外还有四项清理，全部只在启动或访问时做，没有定时器（见 `docs/idle-cpu.md`）：

- 闲置过期：条目 30 天没被打开就删除。访问时惰性检查（过期按未命中处理并删除，正在被预览持有的文件不算过期），启动建索引后再整体扫一遍；打开条目会重新计时。`public` 命名空间不适用（它按服务器声明的有效期）。时钟可注入（测试）。
- 预览文档（`preview` JSON、`html` 静态页）通过 `readPreview` / `writePreview` 读写，条目头里带客户端预览格式版本（`attachmentPreviewFormatVersion`）和写入时间：版本不同、缺头、或写入超过 14 天都按未命中处理并删除；14 天从写入算起，打开不续期。
- 孤儿账号：启动时 `runStartupCacheHygiene` 用 `SecureSessionStore.readAll()`（钥匙串里 `raft.session.<base64url(origin)>` 的全部会话）取得 `(origin, cachedUser.id)`，删除 `raft-attachments/v2/` 下不属于任何已保存会话的账号目录（目录名即 `hash(jsonEncode([origin, principal]))`）。读取失败、或任一会话没有 `cachedUser.id` 时什么都不删。
- 临时 staging 清扫：启动时删除超过 1 小时的 `raft-previews/*`、`raft-share/*`、`raft-attachment-*`、`raft-export-*`、`raft-gallery-*`（按文件夹或其中文件的最新修改时间），只按这些名字匹配，**不碰 `raft-incoming`**（收到的分享是用户数据）。桌面平台的 staging 位于 `<应用缓存>/staging/`（Linux 的 `/tmp` 常是内存盘），并顺带清理旧版本留在系统临时目录里的同名目录；Android / iOS 的临时目录本来就是缓存目录，且原生桥（FileProvider、`ShareInboxWriter.exportFile`、`NativePdfPreviewBridge`）按 `cacheDir/raft-share`、`raft-previews` 放行，所以保持在缓存目录顶层。
- 设置 > 存储 的“清除缓存”只经过 `CacheClear`（`lib/data/cache_clear.dart`，按注册顺序依次运行的具名 hook，后加的层自行注册，设置页不认识任何一层；某个 hook 抛错只记录，其余照常运行，对话框保持打开并提示重试）。当前的 hook：`disk`（两个命名空间，打开中的预览文件被固定，不删；头像内存层由 `public` 清除监听一并忘掉，包括重验证用的校验头和时间）、`staging`（`clearStaging`：与启动清扫同一份位置和名字匹配，但窗口为 5 分钟，并跳过仍被 `SharedFileLease` 持有的文件夹；永远不碰 `raft-incoming`）、`image-cache`（框架 `ImageCache`）、`workspace-memory`（每个 `WorkspaceController` 注册：没有 widget 持有的已解码附件图片、已解析的签名 URL（进行中的请求不动）、空闲的视频静帧（`PlayerSessions.trimStills`，正在播放或被查看器持有的不动））。登录、草稿、设置、`workspace.sqlite`、用户另存的文件和收到的分享都不在其中。
- 索引总量在 OS 于运行期间删除文件时保持一致：读取、`contains` / `containsFile`、打开发现文件已不在时，从索引和总量中扣除，下一次访问即恢复正确。

## 头像与图标图片缓存（2026-10-14）

头像 / 图标（用户、Agent、服务器、应用）走独立于附件的缓存，目标是和 Web 一样“加载过一次就即时出现”：`RaftSizedImage.avatar`（`RaftAvatarContent` 与 `RaftAvatar(imageUrl:)` 都用它）→ 已解码位图 → 编码字节 → 磁盘 → 网络。

- 缓存键是 `raftStableImageKey(url)`：忽略签名 / 过期类 query（`X-Amz-*`、`Signature`、`Expires`、`token` 等），请求仍使用原始 URL；显示尺寸不进入网络键，20 / 36 / 64 dp 共用一次下载。
- 已解码位图由 `RaftHotImages`（最多 384 个、估算 24 MB 的 LRU）持有，框架 `ImageCache` 的 LRU（预算见下节“内存预算”）被附件图片冲掉后重新挂载仍同步命中；解码尺寸取 12 px 的倍数（高于 144 取 48 的倍数），常见的 1x / 2x / 3x 尺寸保持精确。
- 编码字节：内存 8 MB LRU，加磁盘：放进 Settings > 存储 显示并清理的附件磁盘缓存（`AttachmentDiskCache`）的 `public` 命名空间。同一个根目录和索引、同一份 1 GB 预算、同一个大小统计与“清除缓存”（清除时内存中的已解码头像和字节也一并忘掉，下次挂载只重新请求一次）；`attachments` 命名空间（按账号 / 服务器 / 频道，退出登录即清）行为不变。`public` 条目以稳定键的哈希为名、所有账号共用、退出登录不清（公开图片），有自己的上限（`min(64 MiB, 预算 / 8)`）和 LRU，附件超预算时不会被淘汰。条目头部（`RIV1` 标记、8 字节到期时间、`ETag` 与 `Last-Modified`）之后是图片字节：到期时间取服务器 `Cache-Control` 的有效期，上限 14 天，没给就 1 小时；`no-store` 不落盘，`no-cache` 或已过期但带 `ETag` / `Last-Modified` 的条目作为“过期条目”保留 30 天，没有校验头的过期条目当作未命中并删除（旧格式条目照常读取）。`/api/avatars/**`、`/api/external-avatars/**` 与 `/api/integration-logos/**` 在服务器侧是无需鉴权的公开路由（URL 即能力，`/api/avatars` 为 `immutable` 一年；`external-avatars` 为 `no-cache`）。
- 过期条目走条件重验证（stale-while-revalidate，`RaftImageBytes`）：外部头像（`/api/external-avatars/:id.webp`，服务器为 `public, no-cache, must-revalidate` + 强 `ETag`，同一 URL 的内容可能变）与已过期的条目先立即显示存着的字节，再发一次 `If-None-Match` / `If-Modified-Since`。304：不传输正文、不重新解码，已解码位图和内存字节原样保留，只续期（`touch`）；200 且字节不同：换掉内存和磁盘条目、放掉旧的已解码位图，屏幕上的头像预解码新图后无缝替换（解码键带 `revision`，`RaftSizedImage` 监听变更）；200 但字节相同只更新 `ETag`；网络错误 / 错误响应保留存着的图片，不记失败。每个稳定键每个进程最多每 10 分钟重验证一次（整份下载也算一次验证），一屏很多行不会各发一个 304；已解码位图命中时（不经过字节层）由 `resolveStreamForKey` 触发同一检查。请求经 `fetchAvatarImage`（`SystemProxy`，无凭据），`/api/avatars/**` 为 `immutable` 一年，不会重验证。
- 请求按稳定键合并，失败会被记住：4xx 10 分钟、网络错误 / 5xx 1 分钟，没有 Gravatar 的用户不会在每次挂载时重新请求。请求经 `SystemProxy`（`fetchAvatarImage`），不带任何凭据。
- 内存压力（Android 把应用退到后台也会报一次）只把头像缓存收缩到小底线（最近 64 个已解码头像 / 4 MB，内存字节 1 MB，`trimAvatarImages`）；“后台 30 秒”的清理不动它们：它们有上限，且让应用切回时头像即时呈现。
- 视频封面等非头像图片仍用 `RaftSizedImage.network`，走框架 `ImageCache`。

## 内存预算（2026-10-14）

所有可重建的内存层集中在 `apps/raft_flutter/lib/platform/memory_budgets.dart` 的 `RaftMemoryBudgets`（Android / iOS 为 phone，其余为 desktop）。附件图片另按设备总内存分档，区分闲置缓存目标与查看图片时的临时额度；其他层保持按设备类别取值。里面没有唯一副本：被释放的位图、静帧、验证结果都会在需要时重新解码或读取。`RaftMemoryRelease` 在应用隐藏 30 秒和系统内存压力时回收无人使用的缓存；`RaftMemoryRelease.install()` 同时设置框架 `ImageCache` 的上限。`RaftMemoryRelease.snapshot()` 列出各层当前用量。

| 层 | 持有者 | phone | desktop |
|---|---|---|---|
| 框架 `ImageCache`（已解码的 `Image` provider：尺寸化图片、头像重新挂载、封面、表情） | `PaintingBinding` | 200 张 / 64 MiB | 500 张 / 128 MiB |
| 附件图片，已解码（低档闲置目标 / 临时总额度） | `AttachmentImageRepository` | 64 张 / 64 / 192 MiB | 64 张 / 96 / 384 MiB |
| 附件图片，已编码（解码来源） | `AttachmentImageRepository` | 32 MiB | 64 MiB |
| 头像位图，已解码 | `RaftHotImages` | 384 个 / 24 MiB | 同 phone |
| 头像编码字节 | `RaftImageBytes` | 8 MiB | 同 phone |
| 视频静帧 | `PlayerSessions` | 24 张 / 16 MiB | 同 phone |
| 视频 / 音频播放器 | `PlayerSessions` | 最多 2 个存活（原生 demuxer 每个 32 或 64 MiB + 8 MiB 回看） | 同 phone |
| HDR 判定、已准备集合、续播位置 | `PlayerSessions` | 各 256 条 LRU | 同 phone |
| 签名附件 URL | `AttachmentUrlCache` | 256 条、4 分钟 | 同 phone |

- 附件图片的位图与 `ImageCache` 条目共享同一个 `ui.Image`；附件仓库单独拥有其生命周期，不要求与框架 LRU 使用相同上限。用户查看原图时可以临时超过闲置目标，优先清理闲置图片和邻图预加载；只有临时总额度的剩余空间不够时才降采样。解码与入账串行，网络传输保持并发；空闲位图在新位图分配前释放，已释放的大图不会留在超额缓存中。
- 启动时读取设备总内存：Android `ActivityManager.MemoryInfo`（低内存设备标记强制低档），Apple `ProcessInfo.physicalMemory`，Windows `GlobalMemoryStatusEx`，Linux `/proc/meminfo`。这不是可用内存保证；读取失败或超过 500 ms 使用低档。

| 类别与总内存 | 闲置目标 | 临时总额度 |
|---|---:|---:|
| phone ≤3 GiB 或未知 | 64 MiB | 192 MiB |
| phone >3–6 GiB | 128 MiB | 384 MiB |
| phone >6 GiB | 256 MiB | 768 MiB |
| desktop ≤8 GiB 或未知 | 96 MiB | 384 MiB |
| desktop >8–16 GiB | 192 MiB | 768 MiB |
| desktop >16 GiB | 256 MiB | 1024 MiB |

关闭预览会释放其大位图。系统内存告警保留当前图片、清理闲置项并停止该查看器的邻图预加载；后续 30 秒新解码最多使用本档的闲置目标，仍须扣除其他在用图片。没有后台轮询或自动重新下载。原始下载字节不因预览降采样而改变。
- `PlayerSessions` 注册了内存 trimmer：隐藏 30 秒或内存压力时释放没有在播放、没有全屏播放页持有的静帧（卡片自己持有一份拷贝，不受影响；正在播放或被查看器持有的会话不动，播放器本身不动）。静帧按数量（24）和估算字节（16 MiB）双重限制，最旧的先释放。`hdrVerdicts` / `prepared` / `resumeAt` 是有界 LRU（`BoundedLruMap` / `BoundedLruSet`）；被挤出的附件下次建卡片时重新判定 / 重新准备。
- 守卫：`test/image_cache_ban_guard_test.dart` 禁止应用代码使用 `cross_cache` 和 flutter_chat_ui 自带的头像 / 图片构建（它们走一份没有上限、设置页看不到也清不掉的磁盘目录和绕过预算的位图）。图片只走 `RaftSizedImage`、`RaftAvatarContent` 和 `AttachmentImageRepository`。

## 稳定规则（原审计文档的结论）

- **登出策略。** 会话只在服务器明确判定凭据无效时结束：`/auth/refresh`，或刷新成功后的 `/auth/me`，返回带服务器 JSON 错误体的 401。无 JSON 体的 401、任何 403、400/404/408/429/5xx、超时、连接错误、无法解析的 200 一律保留会话与凭据，显示非破坏性状态并退避重试；启动恢复失败（不是“没有已存凭据”）显示恢复页，不显示登录表单。实现在 `packages/raft_client/lib/src/session_policy.dart`，由 `logout_policy_test.dart` 固定。
- **Android 边到边。** 背景绘制到系统栏下方，页面自己拥有底部内容边界：滚动页用 `raftScrollPadding`，底部栏用 `RaftBottomInsetSurface`，锚定菜单和弹层按所属 overlay 的 metrics 放置并限高；不加通用 SafeArea，嵌套滚动不重复加。回归在 `edge_to_edge_audit_test.dart`。
- **保留但不活动的页面。** 用回调内部守卫排除输入、焦点和语义，不要传 `null` 回调：`null` 会套用控件的禁用透明度（0.6），页面滑动时表现为颜色闪变。
