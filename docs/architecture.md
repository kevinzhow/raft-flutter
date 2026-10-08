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
- raft_sync 的纯 reducer 已通过 TS/Dart 等价向量；消息、read-state 与恢复流程通过 WorkspaceController/MessageLedger 接线。source-enabled thread-replies 的最新三条、epoch rebaseline 与 accepted unread refresh 已接入；notification-prefs 使用真实条件开关并保留 legacy 路径。工程和平台结果按下方源码检查点记录，Activity TypeSpec experimental cutover 不由纯 reducer 或旧平台基线替代。
- Drift 缓存按账户与工作区隔离，保存真实离线消息、草稿与 read frontier；撤权立即清 UI 并串行清缓存。签名附件地址及凭据不进入缓存。
- 管理页面使用现网挂载路径与能力校验：providers、MCP、Apps、Slack、analytics、billing、setup、agents 和 Computers。未配置的第三方 OAuth、计费和 Slack provisioning 不产生模拟成功状态。
- go_router 尚未作为路由权威接线；本地 URI 与通知由 NativeContentCoordinator 校验服务器成员资格并获取真实消息上下文。Android 原生 share/通知 bridge 和 Linux 单实例 URI 使用平台 facade。Android 周期后台收件箱兜底已有独立冷进程、去重和系统点击证据；iOS 仅源码接入。FCM/APNs 注册、Linux 服务端消息推送及独立桌面多窗口不属于当前已验证能力。

## 当前共享组件与领域边界

共享侧栏规则区分 raft-ui 通用组件与实际产品覆写。产品分组标题、计数、折叠与排序使用共享 recipe；Search/Activity 与 Saved 使用各自实际挂载角色，Saved 的总数来自真实 GET 元数据，与未读数分离。48 像素触摸范围属于原生适配，不能计为原版 24 像素动作布局相同。

系统提醒中心分为无网络的 raft_ui 展示组件、纯提醒投影、作用域数据 store 与挂载 Bell 适配。它独立于消息 Activity 和 OS 通知。适配读取现有 Computers、agents、server、channels 与 Feedback 未读数据，不创造提醒列表或已读 API；本地只持久化有界的提醒指纹。账号、server、权限和请求版本变化会撤销旧结果与弹层，暂时读取失败保留已接受的未读数。

Feedback 页面读取已挂载列表与详情接口；详情 GET 本身推进服务端阅读游标。列表、详情和回复只保存在当前账号作用域内存，晚到结果不能恢复旧未读数或跨作用域内容。本次页面提供阅读，不提供创建、评论或关闭操作；实际后端未配置时显示错误，不生成空列表成功状态。

会话组件按实际挂载来源区分频道图标与 DM 头像。频道使用 ChannelKindIcon 的 14px 图标、18px 槽位、2px 线宽和联合频道 GitBranch；通用组件的 12/14px 与 1.5px 线宽不是这个页面的规则。频道标题为 14/20、常规 500，仅真实未读增加粗体。频道与 DM 的响亮未读徽标共享 accent 规则；DM 徽标修正不表示其头像与行布局已对齐。当前尺寸合同绑定 39 项规则、101 个所选文件内的公开类及 462 个产品与验证输入，只验证来源和散列，不验证完整 CSS、算式或像素相等。

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
| 最终共享规则与完整原生复验 `3ac80c8f` | 709 Dart、33 host、分析器通过 | 通过；12:13:48 run，56 检查点 | 通过；12:20:19 run，66 检查点；两平台实际退出登录与会话清除通过 |

以上时间均为 2026-10-08 UTC；完整源码哈希分别为 `6ab79f33a7f39f98523dadd38dfc1430fd2d7f8e75d10736d0c80050bd1c5701`、`0ea636e658e0d8042b6342e9e50d9ba504cc87492f1e51ad2e9b1a4f99b7baed`、`518ad5e4ca0686df5eb7805fcbde752a4d774fab9bd627a4dbae44e9f36947e3`、`1b8906fa579960daa933c0c18dc18cda7ecc3d648834e83967e2269840040d95`、`348911c8c934e37a7d5dcc39d5a8812115400a4e6aae9866c6a6de5fccbca916`、`e1ac2c23eff8c980e405b01ed92beaed54dd9e69e953aeb9429d5860fe216c5d`、`2b85d1b4a9ee271ab23eb582add5c8277d1e22821d6a37ddf645a3833413e9a6`、`d6cf1b57d689b28d4c2d88adb524ce727771ffd4aab79e88f217c822981d2a12`、`4df9efd8a0374ecaa877fe925c22377ec0ba273835d122a410546de93f96f032`、`ad337eade5901c79658179a06863646ea5f7d3b1a76398eb51878151c9e20b87`、`7f39a5f4f8b4d4265da6fb00a128dcb880e05f432b2803a11399b7bbdae64b40`、`1ca110f694349b8a540d073a810f8e77fdfdce34ce336c28b4f23f1082229877`、`3ac80c8fe00d6dd9cf1e5f58407a8c526cfccec9a28790fa3bbce5aa35a416d6`。6ab 基线归档于 `.local/functional-baseline-6ab`，0ea Linux 归档于 `.local/functional-phase4-0ea636e658e0`。源码和 runId 决定证据适用范围；旧通过不能计为当前修改通过。

Search、Account、Appearance 和移动四项导航已有后续实现与定向回归。依据用户要求继续完善共享尺寸、响应式与布局约束；后续 348、e1ac、2b85、d6cf、4df9 与 ad337 已分别冻结并实际运行 Android，均未完成通过两平台流程。最终 3ac 已完成同源码 Linux 56 与 Android 66 个原生功能检查点；新安装包构建、实际安装验证与交付仍待完成。

视觉验收未完成。旧 `0e049d15` 的 30 组实际失败配对保留为历史；`518ad5e4`、`348911c8`、`e1ac2c23`、`2b85d1b4` 与 `d6cf1b57` 的三主题 Android Home 结构对照也均未通过。e1ac 背景色与按钮居中已有实测改进，2b85 已显示共享分组计数、折叠与排序操作；触摸适配后的布局、导航分组间距及原版提醒中心仍未完整验收。ad337 的三主题 Home 与真实系统通知弹窗已发布为六张原始截图；实际打开、320×288 尺寸及关闭操作通过，但没有判定像素通过。固定清单为 523 项，另有三组移动诊断。移动诊断使用原 Web 和原生各自真实的 412×915 图，不裁剪或缩放，但公开参考数据与原生工作区数据、安全区不同，不能充当同数据逐像素验收。原生根页面操作通过不代表字体、布局、颜色或全部状态与 Web 一致。

## 共享设计系统与布局约束

raft_ui 的颜色映射已有生成来源；部分尺寸与布局约束仍分散在手写 recipes 和产品组合中。原版规范同时来自 raft-ui 组件 recipe、foundation.css 与 Web 的响应式覆写，不能只提取主题颜色或单组数值。当前完善工作从共享规则入手：记录源版本和方向性间距，区分绘制尺寸与触摸范围，表达容器约束、窄屏换行、断点和安全区。页面应使用这些共享规则；实际失败用例验证规则，不能靠页面局部坐标掩盖差异。

历史 75 项 SDK 主题交互证明相应浏览器交互，不证明当前源码的逐像素对齐，也不能替代原生系统输入、无障碍或完整平台流程。

共享尺寸来源及尚未绑定的布局规则见 [尺寸合同](design-dimensions.md)；详细源文件、行号、摘录与 SHA 在同名 JSON 中。该审计快照不代表像素或原生验收通过。
