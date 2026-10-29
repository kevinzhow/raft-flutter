# Raft Flutter 工程约定

- 本仓库为独立 Flutter 客户端；Web参照版本记录于 docs/source-reference.json。实现前阅读 docs/architecture.md 和当前用户指令。
- 合入与 PR：每个分支开 PR 指向 cindy/integration。PR 描述写清改了什么、怎么验证的（命令与结果、设备、哪些没验证）和 `tool/prepare-handoff` 输出的全量检查结果行；验证证据只放 PR 描述，不进 docs/（docs/README.md 是索引，新文档必须登记，见 tool/tests/test_docs_index.py）。仓库是公开的：PR 里不放私有 URL、服务器名、token、用户数据；真实 workspace 的截图/录屏留在 Raft。线性合入：rebase 到 origin/cindy/integration，跑全量检查，fast-forward 推送到 cindy/integration（GitHub 自动标记 PR 已合并）。外部贡献者（fork）的 PR：先请对方开「允许维护者修改」，变基与修复推回其 PR 分支再 fast-forward；对方没开时，修复请对方在 PR 内改或另开 PR 叠在其后，其 PR 用 GitHub「Rebase and merge」合入（基线与检查时一致），不要只合入我们这边的副本而关闭原 PR。`tool/prepare-handoff --pr --pr-body <文件>` 可在检查通过后推分支并创建/更新 PR。
- 设备/原生/播放器问题要在模拟器或真机复现并验证（widget 测试不算）；新增回归测试先在旧代码上跑红；结论只写测到的范围。
- 对没 @ 你的请求先读话题，看有没有人认领；打 tag、发布、推共享分支前先在话题里认领。
- raft_ui 只拥有设计tokens与交互组件，不依赖API/数据库/原生系统服务。每个新组件同时提供 SDK Widget Preview 和适用的主题、状态、键盘、语义验收。
- 客户端协议、同步reducer、持久化、平台服务与业务页面分离。Flutter chat UI 的 model/controller 是展示适配，不是Raft消息或同步权威。
- 公共 source mirror 的 experimental/未挂载合同不能当现网接口。以已挂载服务端路径与 Web 当前启用行为验证。
- 测试使用命名隔离本地环境，Web与Flutter共用fixture。保护其他服务/dirty files；不提交登录资料、token、私有URL或本地seed输出。
- Android 真机更新统一使用 `python3 tool/android-install --device <serial> --apk <arm64.apk> [--launch]`；先用 `--check-only` 验证制品。禁止用 `fvm flutter run/drive/test/install` 隐式安装正式 App，禁止卸载、清数据、降级或安装失败后的卸载重试。脚本核对实际 APK 的身份/架构/版本/签名与安装前后数据目录；任何失败立即停止。
- 首次安装只在用户明确要求时追加 `--first-install`，同样先做 `--check-only`；该模式必须确认设备上不存在此包（含其他用户与保留数据），禁止用作更新失败后的自动兜底。
- Android profile 测试只通过 `tool/performance/lab.py`，只接受预编译且实际包名为 `app.raft.raft_flutter.linkperf` 的 APK，并强制 `--keep-app-running`。只改 `applicationId` 不足以隔离：Flutter drive 的 source 包名可能取 namespace，结束时自动卸载。测试前后检查正式 App 仍在，不得把“找不到包”当成正常状态继续安装。
- Linux profile 问题检测：`python3 tool/performance/lab.py detect --out .local/performance/detect-<新名称> --scenarios all`（自动使用独立 Weston GPU 会话；单场景如 `--scenarios keyboard`，异常归因单独加 `--details`；以 detection.md 的 ISSUE / REVIEW / NOT_RUN 为准，退出码只表示采集是否成功）。
- 视觉对齐扩展套件（tool/parity-ext）的新增 / 修复流程见 docs/parity-ext-quickstart.md。
- 状态对齐：每个页面/面板的 loading / empty / error / partial 状态登记在 docs/state-parity.json（有无 Web 对应、有无 parity case、差距大小）。`test/state_parity_guard_test.dart` 要求每个已登记状态要么有 parity case id，要么写明 intentional / NA 理由；新增页面或面板时同时登记。只盯默认（有数据）状态的 case 会漏掉加载 / 空 / 错误的差异，而且这些状态的 case 必须先确认 Web 侧真的渲染出该状态（React host 不得用预置 store 数据盖住它）。
- 空闲 CPU：禁止 `scheduleTask`/`Priority.idle` 与零延迟自重排的 Timer（被拒绝的 idle 任务会经 `Timer.run` 热循环，见 docs/idle-cpu.md）；延后工作用 `RaftIdleTimer`，仅屏幕可见才有意义的轮询用 `RaftForegroundPeriodic`；常驻动画必须用 State vsync 并随 TickerMode/减弱动效停止。`avoid_unreviewed_idle_work` lint（tool/raft_lints，由 tool/raft-lints 运行）扫描并要求在用法处写 `// ignore: raft_lints/avoid_unreviewed_idle_work -- 理由`。
- 提示可解决：凡用户可见的提示 / banner / 通知 / 重试 / 回填 / 同步 / “加载更多”入口，都要有端到端 widget 测试证明：执行其动作后状况被解决、提示不再出现（含重开 / 重启后），且在不该出现时不会显示。
- 本地持久化变更必须带升级测试：从上一个发布版的磁盘数据 / 格式起步，证明没有多余提示、没有数据丢失。
- 按功能矩阵报告实际覆盖；Widget Preview 不能替代Linux/Android平台无障碍、输入法、生命周期或通知测试。

- 原生流程遇到等待超时、点击未生效或未命中时，先用实际可见控件和真实指针输入复现，区分产品丢事件/延迟反馈与测试尚未完成布局，再决定修改产品或测试；保留初次失败。等待条件不能掩盖已经显示的控件丢点击。

## 验收材料的保存与链接

- 不为截图、录屏或验收报告创建、长期保留独立的 evidence／素材远端分支；正常开发分支完成合入后按既有流程清理。
- 需要更新或稳定链接的报告使用 Raft Artifact，一次性交付使用附件，并保持原有可见范围。真实 workspace 和私有材料留在有权限的 Raft 对话；公开 PR 只放可公开的验证摘要和链接。
- 必须纳入 Git 的测试夹具或素材随正常源码提交，引用固定到完整 commit SHA，不使用分支 URL 托管长期材料。

## 产品体验原则（2026-10-10，Kevin 确认）

- 体验与 Web 一致，实现可以灵活：用户看到的行为对齐 Web；技术方案按 Flutter 最佳实践选择。滚动、打开、resize 的流畅度是硬门槛，优先于像素级一致。
- 对齐数据生命周期，不只对齐界面：移植任何功能时，同时对齐 Web 的加载时机、清空条件和事件更新方式。服务器级数据（Agent、成员等）只在账号 / 服务器 / 角色 / 权限变化时清空，不随频道切换清空；频道级缓存（消息窗口、任务列表、消息串）离开后保留；刷新保留旧数据并原地替换；实时事件按单条增量更新，不清空重拉。安全隔离放在 Web 对应的层级上，不擅自下沉到频道级。
- 首帧即最终：一行内容显示后，作者、头像、徽章、标签和布局不再变化；只允许真正异步的内容（如链接预览）和真实的实时更新改变它。不使用占位头像 / 昵称；必须占位时，占位与最终内容尺寸一致。优先使用消息自带字段完成首帧。
- 再次访问即时呈现：访问过的频道、消息串、动态 / 已保存 / 搜索 / 任务页再次打开时直接显示缓存，后台静默刷新，不出现加载态或整页刷新。
- tooltip 只补充看不到的信息（纯图标按钮、被截断的文字、头像状态等），不重复已可见的文字；列表滚动不得触发 tooltip；tooltip 与 hover card 只在指针静止时出现，任何滚动（滚轮、触控板、滚动条、键盘）立即关闭已打开的；应用 UI 一律用 RaftTooltip，不用原生 Tooltip 或 Material 的 tooltip: 参数。
- 验收必须覆盖：切换频道、打开消息串、收到实时事件时，已显示的行逐帧不变（widget 测试）；性能改动用 tool/performance 的 profile 基准对比前后数据。
- 用户打开内容就是要看：先想办法直接呈现（本地渲染、分段加载、交给系统应用打开），失败提示只是最后兜底，且要说明具体原因并给出能完成任务的动作。
- 布局看宽度，交互看输入方式（2026-10-20）：展开的折叠屏和平板和桌面窗口一样宽，仍是手指操作；窄桌面窗口和手机一样窄，仍是鼠标。列数、侧栏并排还是覆盖用宽度（`RaftAdaptiveWorkspace.compactOf`、`raftBreakpointWidth`）；手势（下滑关闭、左右滑切 tab、下拉刷新、长按菜单）、hover 栏 / 卡片 / tooltip、Enter 发送、触控目标尺寸、自动弹键盘、快捷键提示一律读 `RaftInteraction.of(context)`（按平台解析；测试用 `RaftInteractionScope` 或 `ThemeData.platform` 覆盖），不得用宽度或 `shortestSide` 判断。新增交互测试要在折叠屏尺寸（856x944、944x856，Android）和窄桌面窗口（390x844，Linux）各证明一次。
- 文字缩放（follow Apple Dynamic Type，Kevin 确认）：内容文字（消息、文档、列表、输入框、对话框）跟随系统字号、不设上限（iOS body 17pt 到 53pt，约 3.1x；Android 到 2x）；越大的样式涨得越少。只读 `MediaQuery.textScalerOf(context).scale(fontSize)`，禁止 `textScaleFactor`（`avoid_text_scale_factor` lint）；线性平台缩放器（iOS、桌面）由 raft_ui 的 `RaftTextScaling`（app 根 builder 里装一次）统一映射到 Apple 曲线，不在组件里各自处理。固定 chrome（底部 tab、频道 Chat/Tasks/Files tab、顶栏图标按钮、徽标/计数）用 `RaftChrome` 限制在 1.35x，字号大到被限制时长按弹出 Large Content Viewer（`RaftLargeContentViewer`，松手触发该项）。布局重排而不是裁切：文字所在盒子的高度是最小值（`RaftScaled.grows`），名称/时间折行，并排行改上下排；行高不写 px（`avoid_fixed_height_text`、`avoid_pixel_text_height`）。回归由 `text_scale_audit_test`（packages/raft_ui/test，1.0x/1.3x/2.0x/3.1x，基线只许下降）把关；1.0x 必须与现状逐像素一致。

## 设计系统对齐（2026-10-26，Kevin 确认）

- 以 Web 为准：Raft 外观的验收基准是 Web 当前版本（raft-ui 版本见 packages/web/package.json），不是我们自己之前的 Flutter 版本。凡改样式、配方、token、组件，PR 必须附受影响真实界面的「Web | Flutter」明暗并排对比（tool/parity-ext 截 Web 默认主题），并列出剩余差异。
- 改在组件层，不改在页面层：每个 PR 写明属于哪个设计系统家族（Button、DropdownMenu、Dialog……）。页面上单独覆盖样式、在页面里自拼浮层或菜单的改动不收；差异先修组件，所有用到它的界面一起变。
- 一个家族只有一个实现：新代码只用该家族的规范组件；直接用 Material/Cupertino 控件（`ds-audit` 的 `bypass.*`）或已列为待淘汰的重复组件，计数只许下降，增长即检查失败。
- 设计系统随 Web 升级：`tool/upstream_sync.py status` 报出 raft-ui 版本漂移时，先用 `tool/recipes/run` 重新生成配方，再做功能对齐；旧外观（Elegant、Brutal）读冻结配方，`tool/theme-suite --look all` 证明不变。

## 并行开发与模型分工（2026-10-10，Kevin 确认；18:26Z 更新）

- 启动 subagent 时显式指定模型，不默认继承。
- 默认一律用 Sonnet 5.5：调研、视觉对齐、页面移植、底层绘制、功能开发都用 Sonnet。
- 只有 Kevin 明确要求时才用 Opus 5.5。
- subagent 只跑与改动相关的测试、`tool/flutter analyze`、设计系统审计和 `tool/raft-lints --changed`（每轮编辑后跑，几秒出结果），不跑全量检查。
- 每个 clone 首次使用时运行一次 `tool/install-git-hooks`：提交前自动 lint 暂存的 lib 文件，pull / rebase / 切分支后自动按 pubspec.lock 重跑 `pub get`。
- 用户也会出错：发现明显错误或前后决策冲突时，直接、毫不留情地指出并给出证据，再提建议；你是同事，不是奴仆（Kevin，2026-10-18）。
- 多个有依赖关系的 PR 用 `gh stack`（官方扩展 `github/gh-stack`）管理：`gh stack init <分支…>`、`add`、`submit`、`sync`；合入仍是 rebase 后 fast-forward，不产生合并提交。
- 申请全量检查前先跑 `tool/preflight`（约 1 分钟：结构/设计系统审计、守卫测试、改动文件的 analyze/lint/format、受影响测试、测试预算（改动的测试文件及其分片文件的 case 数，规则同全量检查的 tool/test_budget.py）、跨平台路径扫描），把它输出的 `preflight:` 汇总行贴进 PR；`tool/prepare-handoff` 会先跑它，失败即停。preflight 没全部通过（结构审计超上限也算）的 PR 不送全量检查：先改到通过，要放宽上限须先由负责人同意；改了 capability 或宿主侧行为时，先本地重新生成 capability-parity 文档。
- 全量检查每个分支一次：负责人审核后用 `tool/prepare-handoff`（rebase + `tool/check-project`），通过后 fast-forward 推送到 cindy/integration。例外：小的机械性 PR（如同一迁移的多个批次）可以叠成一串只跑一次全量检查，通过后按顺序逐个 fast-forward；失败时按失败位置只打回对应的那个。
- `tool/check-project` 只在失败项全是 Dart 测试文件（不超过 6 个）时，单独重跑这些文件最多 3 次（`RAFT_CHECK_RETRIES=0` 关闭）；重跑通过的算 flaky，列在最终 JSON 的 `flaky` 里，运行可通过。同一棵树（`git rev-parse HEAD^{tree}`）在干净工作区通过后会被记录，`tool/check-project --reuse` 对相同的干净树直接复用，不重跑。
