# 移动导航验收

## 当前修改：侧栏位置可选左 / 右（2026-10-14）

“设置 > 外观 > 导航栏” 选择手机布局侧栏在左还是右，设备本地偏好 `raft.railSide`，值 `start`（默认）/ `end`，按起始 / 结束边解释，RTL 下自动镜像，选项文字写的是屏幕上实际看到的一侧（左侧 / 右侧，Left / Right）。只影响手机布局的侧栏（`RaftWindowClass` 选中侧栏时）；≥ 768 的桌面布局不变，仍在左侧。

- 该行只在当前窗口能显示侧栏时出现（宽或矮的窗口、任一侧）；普通竖屏手机和桌面布局没有这一行，因此不改变这些尺寸下的设置页。
- `RaftRailSideScope` 向下提供偏好；折叠铰链规则按侧栏所在的那一边判断（铰链落在该侧 72 dp 条带内则保留底栏）。
- 侧栏在窗口右边缘时：延伸到右侧系统 inset 之下；侧栏弹出的菜单（工作区菜单、通知中心）朝内容一侧展开；分隔线在内容一侧；内容区（含滚动条）在侧栏左侧，互不重叠。
- Android 系统返回手势：侧栏在右边缘时，通过 `app.raft/gesture-exclusion`（`View.setSystemGestureExclusionRects`，API 29+）排除侧栏按钮区，只覆盖侧栏项目区到窗口边缘、最高 200 dp（系统上限，取项目区最上方的一段，约 4 个条目），页面被盖住（侧栏不可见）时清除；左边缘返回手势不受影响。侧栏在左边缘时不做排除。
- 切换侧栏位置只改布局槽位，当前页、滚动位置、草稿保留。

## 当前修改：宽 / 矮窗口用左侧导航栏替代底部标签栏（2026-10-14）

手机布局（宽度小于 768）的根导航分两种位置，由 `RaftWindowClass.phoneNavigationFor`（`packages/raft_ui/lib/src/viewport_breakpoints.dart`，阈值都在这个类里）决定，只看窗口宽高，不看设备型号：

- 宽度 ≥ 600 dp，或 宽度 ≥ 360 dp 且 高/宽 < 1.75（宽折叠内屏竖屏约 440×707、任何横屏手机）：左侧栏（起始边，RTL 自动在右侧），复用桌面 `RaftWorkspaceRail` 与 `workspaceRail()`：同样的条目、顺序、徽标 / 注意点、工作区菜单、通知铃、帮助、设置。
- 其余（390×844、430×932 等普通竖屏手机）：底部标签栏，行为不变。≥ 768 仍是桌面布局。

这只替换导航外壳。`RaftAdaptiveWorkspace.compactOf`（768）仍决定路由、弹窗和页面栈，页面栈、`WorkspaceNavigation`、返回行为不变；侧栏条目走与底栏同一条手机导航路径（`selectMobileTab`；搜索是首页列表的推入页）。栏只出现在底栏会出现的根页面上，推入的频道 / 详情页仍是全宽。

- 侧栏模式下底栏自定义不适用（与桌面一致）：设置里的 “Bottom bar” 与仅手机的 “Computers” 快捷行隐藏；Activity、Computers 是侧栏的根页面。
- 内容区在 `_MobileKeyboardLayout` 里让出侧栏；内容与侧栏各占固定的 `LayoutId` 槽，切换位置不重建页面栈，滚动位置、草稿、当前页保留。侧栏延伸到起始边的系统 inset（刘海 / 侧导航栏）下，按钮自身避让；键盘只缩内容区。
- 底部悬浮胶囊的避让（Elegant）、首页列表的胶囊预留在侧栏模式下取消；实时活动条改为贴内容区底部。
- 触摸目标 ≥ 48 dp（侧栏按钮在手机上使用满宽，不套桌面的内边距）。
- 折叠屏：只读取 `MediaQuery.displayFeatures`。铰链 / 半开折叠若落在侧栏条带（起始边 72 dp）内则保留底栏；中间的竖直铰链不影响侧栏（始终在起始侧）。尚无桌面姿态（tabletop）或跨铰链布局。

## 当前修正：移除页面快照（2026-10-11）

移动端每条 MaterialPage 现在持有真实页面子树和固定的页面位置。删除手工截图、进入动画的图片替身与零透明度 live 页面，同时设置 `allowSnapshotting:false`；继续使用 Flutter 平台过渡及 Android 拉伸。历史数据不按页面复制：路由借用工作区的消息 ledger、草稿、上传、实体目录和缓存，操作转发到唯一工作区权威，不建立额外长连接。被覆盖的页面沿用已构建 widget，普通工作区通知不重建隐藏目录。

搜索参数修改仍替换同一历史条目；顶部/系统返回消费一次页面历史。Tab 根切换、减少动态效果、冷详情语义返回以及根附件预览对预测返回的隔离继续保留。设置页的移动详情由 URL 控制，避免先把原目录改成详情；管理页不再另建隐藏聊天窗口。工作区 PageStorageBucket 按权限/账号/服务器隔离，宽窄宿主切换保留它；根预览覆盖期间保留原宿主，防止 resize 卸载附件入口导致预览退出。

验收为定向 Widget 与启用 Impeller 的 host 引擎测试，覆盖计算机拉伸返回、任务、频道/私信设置、附件、撤权、草稿/乐观发送以及滚动与搜索历史。三主题和 Android/iOS/Linux/macOS 的 Widget 平台变体不代表这些平台的原生验收；尚无此次改造的手机手势验收或 profile 前后比较。以下为历史检查点，旧快照设计已不再使用。

## 当前修正：附件预览的 Android 预测返回（2026-10-11）

普通系统返回和顶部按钮未复现多退一级；使用 `flutter/backgesture` 的 start/update/commit 事件，在真实 RaftAppRouter → WorkspaceView → 附件预览上稳定复现：本应保留 `/s/demo/channel/c1`，实际退到了 `/s/demo`。Android 将预测返回广播给路由观察者；根 Navigator 的预览和嵌套 Navigator 的消息页各自仍是所在栈的 current route，因而同时提交返回。

`MobileWorkspacePages` 现在订阅父 ModalRoute 的 current 状态；父页面被根预览覆盖时，将嵌套 MaterialPage 的 `canPop` 设为 false，阻止其接收预测手势。预览关闭后自动恢复原返回行为。没有增加定时器、消息复制或导航缓存。

| 项目 | 本次证据 |
| --- | --- |
| 三主题 × 频道/私信的真实消息页 | 6 项定向 Widget 回归通过；顶部返回、普通系统返回、预测手势取消/提交保留消息页及历史索引，手势只由一个 Navigator 接收；关闭预览后的独立手势返回上级一次 |
| 既有附件入口、移动页面与私信设置 | 连同上述回归共 22 项通过，覆盖移动/桌面图片、文档、HTML 入口及撤权 |
| 静态分析 | 修改相关 2 个 Dart 文件通过 |
| 实机手势、全量检查 | 后台 Computer Use native pipe unavailable，未计为本机交互通过；本次遵循用户指令不跑全量测试 |

首次失败与修正后日志保留于忽略的 `.local/attachment-predictive-*.log`。这是 Flutter 手势协议回归证据，不代替 Android 原生无障碍/生命周期验收。

FVM ARM64 Release 构建及安全覆盖安装通过：targetSdk 37、versionCode 6011（build number 4011 + ABI 偏移 2000），APK SHA-256 `58840c7190c75e6b2b93415973df83ff0d866e3dab9fd6a902ac263a5c2424be`。`tool/android-install` 预检和安装后哈希、首次安装时间、CE/DE 数据目录 inode 验证通过，未卸载、清数据或启动 App。

## 当前修改：私信设置与附件预览（2026-10-11）

移动私信设置现在复用 `channelPage=settings:<dmId>`，展示联系人名称和原有偏好，无频道元数据编辑或自动键盘。移动附件图片、文档、PDF、音视频及 HTML 预览改用临时 MaterialPageRoute，共用 Web 手机面板页头（盒状返回按钮）和平台返回动画；预览保留原有权限检查、下载、缩放与媒体清理。附件评论的移动入口采用同样的平台页面过渡。

| 项目 | 本次实际证据 |
| --- | --- |
| 私信设置、图片/文档预览、加载/错误，三套主题 | 独立 Preview 组件 15 项 Widget 检查通过，覆盖 390×844 与 320×568、页头几何、语义、返回、Escape 和操作回执 |
| 实际私信设置入口 | 三主题 3 项通过，进入动画、无输入框及系统返回恢复原私信 |
| 实际图片/文档/HTML 附件入口 | 移动/桌面 6 项通过，连续两次进出与权限撤销；音视频/PDF 共用页面壳，本次未验原生解码 |
| SDK Widget Preview | 生成并成功编译包含以上五组的新预览；后台浏览器 unavailable，未计为浏览器人工交互通过；Widget 渲染图仅存忽略的 `.local/` |
| 静态分析 | 修改相关 11 个文件通过 |
| 全量检查、手机实机交互 | 本次按用户要求不跑全量测试；安装后由用户验收 |

FVM 仅 ARM64 Android Release 编译及安全覆盖安装通过：targetSdk 37、versionCode 6010（build number 4010 + ABI 偏移 2000），APK SHA-256 `191060122037e986278cddb76d8e531960fda7803acc52c71ae5d9eee2b8852d`。重新预检通过，安装后实际 APK 哈希、首次安装时间及 CE/DE 数据目录 inode 核对一致；未卸载或清数据。构建、预检及安装收据仅存 `.local/`。

## 前次修改：任务与频道管理页面（2026-10-11）

依据手机已安装的官方 Android `build.raft.app` 1.13.0 APK 静态核对：普通手机任务进入 `compose_thread`，大屏桌面模式先尝试 adaptive detail；新版频道设置进入 `compose_channel_settings`，成员进入 `compose_thread_members`。频道设置先展示信息，编辑是按需弹窗；私聊设置仍是弹窗。官方新版设置有偏好开关，Flutter 本次直接采用已确认的页面体验，不增加兼容开关。

- `WorkspaceNavigation` 仍是唯一导航权威；`MobileWorkspacePages` 将现代/legacy 任务及客户端 `channelPage` 槽投影为独立 `MaterialPage`。任务 controller、底层消息窗口与列表不因呈现切换重复创建。
- 三类页面使用 Web 手机面板页头（Brutal 62px / Elegant 56px，盒状返回按钮，触控区 48px）；仅标签根页保留 `RaftMobilePageHeader` 的 56px 几何；使用 Flutter 平台页面过渡；桌面任务 modal / docked 及桌面、DM 设置维持原行为。
- 设置页没有编辑输入框或 autofocus；显式编辑后留在设置页。`#all` 不可重命名、归档和权限限制仍生效。成员添加视图的系统返回先回到成员列表，不被隐藏工作区重复消费。
- 冷任务和管理链接补入底层目的地；历史帧仍最多八页、倍率最多 2，仅供过渡、不持久化。隐藏工作区排除焦点/语义并停止 ticker。权限收缩撤销管理页与根 Navigator 上的编辑弹窗。

| 项目 | 本次实际证据 |
| --- | --- |
| 三主题、Task 根列表/频道 Tasks、现代/legacy 任务 | Widget 72 次顶部返回/系统返回通过，列表与任务宿主 State 保持同一实例，owner 释放正常 |
| 三主题 × Android/iOS 的设置→成员→添加成员→返回、显式编辑及撤权 | Widget 通过，验证平台进入动画、无自动键盘、编辑后页面保留及编辑弹窗撤销 |
| 三主题任务页面的导航几何、返回语义、Tab/Enter | Widget 通过；SDK Preview 提供现代与 legacy 页面 |
| 设置/成员 SDK Preview | 提供三主题、加载与错误状态；不作为原生验收证据 |
| Android 实机交互、iOS 原生手势、Linux/Windows/macOS | 本次未验收；后台 Computer Use 返回 native pipe startup failed，未使用其他 UI 自动化绕过 |

定向任务回归 102 项通过；host 检查 94 项通过。首轮全工程失败中的旧页头、Tab 返回后立即点击及桌面拖放问题，在未修改的 HEAD `7620cc0` 隔离 worktree 中复现 20 项失败（该组 88 项通过）。基线日志、首轮失败及修正后的任务回归日志保留于忽略的 `.local/`，不作为全工程通过证明。

最终 `python3 tool/check-project` 对未变化的源码执行：Flutter 3,442 项通过、3 项跳过、20 项失败；失败集合与 HEAD 对照完全相同，没有新增失败；host 94 项及全工程静态分析通过。`sourceChanged=false`，但因原有失败，完整工程检查结果仍为未通过。

FVM ARM64 Android Release 构建通过（`--target-platform android-arm64 --split-per-abi --build-number 4009`）。包名 `app.raft.raft_flutter`、targetSdk 37、实际 versionCode 6009，SHA-256 `b98b6d609e05f76c5b1bd78f66bf8923276778914299b4d026001a3b151651af`。`tool/android-install --check-only` 验证签名、版本及 ARM64 条件通过；本次只读预检，没有安装、启动、卸载或清数据，不能计为手机实机验收。构建日志与收据只保留在忽略的 `.local/`。

随后依据用户安装指令重新预检并通过 `tool/android-install` 覆盖更新到 6009；安装后 APK 哈希与产物一致，首次安装时间及 CE/DE 数据目录 inode 保持不变。未卸载、清数据或启动 App；本次安装不计为实机交互验收。

以下为旧版本检查点，不能计为本次源码的原生通过。

## 历史验收：统一移动页头（2026-10-10）

2026-10-10；基于 `80769ee` 的当前工作区修改。Flutter 3.47.6 由 FVM 管理。

## 实现

- 移动导航栏统一为 56 逻辑像素高度，返回和右侧操作槽 48 像素，返回图标中心距左侧 32 像素；标题支持截断与标题语义。频道、讨论串、搜索、设置、资源及独立页面共用布局。
- 工作区层级页面使用平台 MaterialPage 路由，保留既有导航历史和唯一活动 controller。历史页面仅暂存绘制帧供动画使用，最多八页、帧像素倍率上限 2；不写入磁盘或同步数据。
- Tab 根页面和减少动态效果直接切换；桌面分栏继续直接切换。转发编辑器使用平台全屏模态路由。

## 覆盖

| 项目 | 实际结果 |
| --- | --- |
| Android 17 / API 37，Moto XT2603-1，ARM64 Release | 已安装、后台 Computer Use 实机操作 |
| 频道进入讨论串、顶部返回 | 通过；返回按钮位置一致，频道滚动位置保留 |
| 频道进入搜索、Android 系统返回 | 通过；返回原频道，出现平台过渡 |
| 设置列表进入外观详情、边缘返回手势 | 通过；显示上一页预览并返回设置列表 |
| 恢复频道后返回主页 | 通过；顶部返回及冷恢复后的 Android 系统返回均已实机复验，不停留在空白页 |
| 根 Tab 切换 | 通过；无层级返回按钮 |
| 三套主题的导航高度、返回位置、键盘 Tab/Enter | Widget 检查通过 |
| 历史投影、查询/任务不新增页面、唯一活动状态、一次返回跳过同页定位记录 | Widget 检查通过；共七项定向检查 |
| 静态分析 | 修改相关 app / raft_ui 与定向测试通过 |
| iOS 原生侧滑、Linux/Windows/macOS 实机 | 本次未验收 |
| 通知冷启动链接、撤权过程、IME 与全部业务详情 | 本次未验收 |

三主题 Widget Preview 是组件展示，不能代替平台无障碍或生命周期验收。Android 原始录屏和截图只存于忽略的本地验收目录，不提交工作区聊天内容。

## Task 白屏根因与修正（2026-10-10）

手机旧 Release 在 Task 列表点击任务即可复现整页白屏。之前的任务查询投影测试只覆盖频道，没有覆盖 Tab 根页面，不能支持“任务不新增页面”的完整结论。

1. 页面身份忽略 `task` / `legacyTask`，但根页面判定使用原始 URI 的 `mobileRootTab`，其有弹层时返回 null。`/tasks?task=c:t` 因而仍拥有 `/tasks` 的页面身份，却被当作冷详情补入 `/tasks` 根页面，产生两个相同 MaterialPage key 和帧 GlobalKey。Navigator 的页面匹配及子树所有权约束被破坏。
2. 频道上打开任务时，旧 PopScope 允许 Android 系统返回弹出频道 MaterialPage，而业务返回仅清除 task 槽。业务历史仍保留频道，Navigator 却已弹出频道。下一次更新重新创建仍在退出动画中的同 key 页面；单独撤销 PopScope 修正后，真实 WorkspaceView 回归测试稳定报 `Multiple widgets used the same GlobalKey`。
3. 全工程既有“返回元数据请求未完成就切回频道”场景进一步复现：已离开历史栈但仍在退出动画中的页面，其帧 GlobalKey 被重新进入的同业务页面复用。路由实例不能等同于业务页面身份。现在仅为新进入的呈现分配实例 ID，仍在栈内的页面保留实例；退出中的旧页面回调也不会误删后来重开的页面。

修正统一从去除任务槽后的底层 location 计算页面身份和根页面分类；任务呈现继续由 WorkspaceTaskHost 独立持有。任务打开时 PopScope 先消费任务返回，底层平台页面留在栈中。无需清缓存、重建工作区、延迟重试或改动任务 API。

新增十二个真实 WorkspaceView 回归场景：三主题 × Task 根列表/频道 Tasks × modern/legacy，每个交替顶部关闭和系统返回六轮（共 72 次进出），断言页面仍可见、列表与 task host State 保持同一实例、任务 owner 正常释放且无框架异常。另覆盖四个 Tab 根页面的任务打开、返回及冷链接投影。与既有任务 URI、入口及移动页面检查合计 47 项通过。首次失败日志和实机白屏截图保留在忽略的 `.local/android/` 中。

追加退出动画期间立即重入的逐帧回归（四轮、每轮 24 帧），验证始终只有一个 live State、当前页面可见且没有 key 冲突；与十二项任务进出及既有移动导航检查合计 31 项通过，其中包含首次全工程失败的返回元数据场景。

宽窄布局切换现在只启停平台页面呈现，保留同一个活动子树，避免重新创建任务 owner、编辑器和自适应工作区 State。真实 legacy 面板的宽度切换、权限撤销、关后晚到结果及重新打开场景均通过；收窄到 320px 时任务编号使用单行截断，避免元数据换行造成 1px 溢出。

最终定向回归 81 项、host 检查 81 项、全工程静态分析通过。`tool/check-project` 首轮已执行并保留失败：除本次已修正的 key 复用/宽窄切换问题，仍有旧频道/线程导航高度、控件 key、返回后立即断言，以及桌面文件拖放失败；期间源码更新导致该轮 sourceChanged，因此不计为最终全工程通过。

Android 17 Moto 实机安装 ARM64 Release（targetSdk 37、versionCode 4001，ABI 分包偏移 2000、Flutter build number 2001）。APK SHA-256 `f14115f3206a68d7e0f67ed9c27b4f77362b54d364effea53a40f2799030f043`。保留原数据目录和登录状态，未卸载或清数据。后台 Computer Use 六轮任务进出通过：同任务重复打开、另一任务、顶部返回、系统返回、边缘手势、切换设置 Tab 后重入，以及频道内任务的系统返回；随后频道返回 Home、切回 Task 根列表均正常。实机只验证当前主题；三主题与 legacy 任务由上述 Widget 回归覆盖。App 留在 Task 列表；私有截图/录屏只存本地忽略目录。


## 列表返回后的滚动恢复（2026-10-11）

主页频道列表原先只有普通 Key，没有 PageStorageKey；进入频道时列表卸载，返回后新 ScrollPosition 从 0 开始。平台路由各自拥有的 PageStorageBucket 还会随出栈或 Tab 根页面切换销毁，所以仅给列表加 Key 不足以覆盖重复进入与 Tab 切换。

MobileWorkspacePages 现在在唯一 live 子树内提供随工作区状态存活的 Flutter PageStorageBucket，位于平台 route 的默认 bucket 下方；宽窄切换沿用它。宿主现有 authority key 包含 controller、账号 generation、用户、服务器、角色与频道权限修订，变化后销毁该 bucket。仅保存临时 UI 位置，不落盘，也不保留额外业务页面。

主页与桌面频道侧栏、成员与电脑目录、移动 Fleet 列表、设置目录及各详情、搜索主页及各查询结果、独立 Billing / Applications / Administration、通用管理页各自有独立 PageStorageKey。任务看板各状态列也分别保存纵向位置；Activity、Saved、Tasks 的现有数据窗口和显式滚动 snapshot 继续负责原有恢复，消息窗口继续使用现有 viewport owner。

定向 Widget 检查共 75 项通过。新增三主题真实 WorkspaceView 场景覆盖主页反复进入频道后的系统/顶部返回、Home/Settings Tab 切换、成员进入 Agent 后系统返回、设置目录进入详情后返回，以及搜索结果进入消息后返回。另验证各页位置不互相覆盖、宽窄切换保留位置、authority 更换清空位置；既有 Activity/Saved/Tasks/channel Tasks snapshot 与附件返回检查通过。修复前 Home 的三主题回归均失败，约 2000 的 offset 归零，原始日志保存在忽略的 .local/ 中。

上述为组件及实际路由的 Widget 证据；本次没有跑全量测试，不据此声明 Android 手势、生命周期、无障碍或其他平台实机验收通过。
