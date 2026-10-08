# Raft Flutter 客户端架构

2026-10-08 更新：下文记录来源约束与目标架构。当前已实现原生聊天、管理、集成与平台服务，扩展原生验收仍在进行；实际完成边界以 feature-parity.csv 与各 evidence 文档为准。下方“拆分”和“推进”保留设计目标，并不表示所有目标已有实测证据。

## 当前证据

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
- raft_sync 的纯 reducer 已通过 TS/Dart 等价向量；当前消息、read-state 与恢复流程通过 WorkspaceController/MessageLedger 接线。source-enabled thread-replies 的最新三条、epoch rebaseline 与 accepted unread refresh 已接入；notification-prefs 使用真实条件开关，保留 legacy 路径。19 项新增 reply/preferences/controller 回归均已通过；最终工程检查 353 Dart、29 host 与全仓 analyze 通过，较早 b20 源码 Linux 整轮通过；新增 mobile thread/main 状态复用修复后的当前源码整轮，Android完整主运行已通过、同哈希Linux正在验证。Activity TypeSpec experimental cutover 不由纯 reducer 证明替代。
- Drift 缓存按账户与工作区隔离，保存真实离线消息、草稿与 read frontier；撤权立即清 UI 并串行清缓存。签名附件地址及凭据不进入缓存。
- 管理页面使用现网挂载路径与能力校验：providers、MCP、Apps、Slack、analytics、billing、setup、agents 和 Computers。未配置的第三方 OAuth、计费和 Slack provisioning 不产生模拟成功状态。
- go_router 尚未作为路由权威接线；本地 URI 与通知由 NativeContentCoordinator 校验服务器成员资格并获取真实消息上下文。Android 原生 share/通知 bridge 和 Linux 单实例 URI 使用平台 facade。后台 FCM、Linux 服务端消息推送及桌面多窗口不属于当前已验证能力。

## 视觉实现与验收缺口

设计tokens及75项SDK主题交互已有具体证据，逐组件像素级一致性尚未完成。原生默认Material控件与Web产品组件的呈现需审查和修正，并建立同版本/数据/主题/尺寸的截图和差异验收。功能测试、主题可切换与原生整轮通过不能替代该项；架构中的golden与同源视觉比对是待完成目标，不是当前完成声明。当前6ab源码Android整轮已完成，Linux同源码仍在运行。

功能基线6ab现已通过两平台完整主应用验收：Android `2026-10-08T03:02:43.361866Z` /54检查点、Linux `2026-10-08T03:11:25.507223Z` /53检查点，归档于 `.local/functional-baseline-6ab`。用户已授权新的页面/组件像素级对齐；该视觉修正工作正在进行，新版源码需重新工程/原生验收，最终安装包暂未发行。这些功能基线记录不证明像素等价。
