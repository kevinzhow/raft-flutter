# Source 导航行为合同

本合同用于行为移植与可执行验收，按实际挂载代码确定目标。Source 固定为 `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`（Web 1.17.5）；Flutter 比较对象为只读检查的整合提交 `9bcf512c92858155ab22bf7ebff100901c8c34b5`。本次只提交合同，没有修改产品、Source fixture 或视觉基线，也没有运行原生、API、Source 测试或新增 Dart 行为测试。下表是后续纯模型及真实页面测试的具体输入与断言，不表示已通过。

## 一份位置及其投影

Source 用 React Router 的 location 表达当前表面，结构为 `pathname + search + hash + history state/key/index`。路径决定服务器及 rail；查询表达所选内容、消息定位和可并存的面板；视口决定展示方式。URL 的实体 ID 不等同于已经取得权限的数据对象。App 挂载一个 NavigationDepthTracker，并把 `/s/:serverSlug/*` 交给 ServerResolver；MainLayout 再挂载页面路由和 URL/store 双向投影。

依据：[App.tsx:1164–1185][S1]、[MainLayout.tsx:1423–1516][S2]、[useSidebarTab.ts:7–41][S3]。Source 自身仍有 store 和异步适配，不能把“单 location”解释成所有领域数据也必须放入路由。

| `/s/<slug>` 后的路径 | 身份或表面 | rail / 移动所属 tab |
| --- | --- | --- |
| 空或 `/` | 服务器 Home；移动频道列表 | chat / chat |
| `/channel/<channelId>`、`/dm/<dmId>` | 频道与私信；两种 route kind 必须保留 | chat / chat |
| `/agent/<agentId>`、`/human/<userId>` | 成员详情 | members / members |
| `/members`、`/members/graph` | 成员根页、关系图详情 | members / members |
| `/computers`、`/computer/<machineId>` | 电脑列表、详情 | computers / settings |
| `/settings`、`/settings/<tab>/*` | 设置列表及子页 | settings / settings |
| `/release-notes` | 设置下的发行说明 | settings / settings |
| `/search` | 搜索页或 Electron 搜索浮层 | search / chat |
| `/activity` | Activity 列表及内容选择 | activity / chat |
| `/tasks` | 任务根页 | tasks / tasks |
| `/saved` | 收藏详情页 | chat / chat |
| `/machine/<id>` | 旧路径，REPLACE 为 `/computer/<id>` | computers / settings |
| `/inbox`、`/threads` | 旧路径，REPLACE 为 `/activity` | activity / chat |
| `/workspace` | 旧工作区 demo 路径的重定向 | 单独的工作区能力分支 |

挂载清单：[MainLayout.tsx:2439–2463][S4]；rail 映射：[useSidebarTab.ts:25–41][S3]；旧路径：[useRailLegacyRedirect.ts:16–64][S5]、[MainLayout.tsx:726–728][S6]。成员/电脑根页不应误重定向到频道；guest 会被替换到服务器根页。桌面 DefaultRoute 在有首个频道且没有 suppression state 时 REPLACE 到首个频道，移动 Home 不自动跳频道。这是入口规则，不能用它授权每次 resize 任意改写当前详情位置。[MainLayout.tsx:914–996][S7]

## 查询、面板与解析边界

| 键 | 含义与实际解析规则 |
| --- | --- |
| `msg` | 消息定位 ID。带 thread 时，等于 parentMessageId 表示父消息，不传入回复列表的 focusedMessageId；不等于父消息时是回复定位。 |
| `open` | Search/Activity 的内容槽：`channel|dm|thread|agent|human|machine:<id>`；按第一个冒号拆，kind 受限、ID 非空。无值、未知 kind、无冒号或空侧返回 null。仅 channel/dm/thread 消费 `msg`。 |
| `thread` | `<parentChannelId>:<parentMessageId>`；第一个冒号必须在非首位置，两侧非空。与 `open=thread:<threadChannelId>` 同时存在时，直接使用已知 threadChannelId。 |
| `task` | `<parentChannelId>:<parentMessageId>` 独立任务浮层；可与另一个 thread 身份并存。旧 `task=1` 才绑定 `thread` 的 anchor。移除 task 只关任务浮层，保留下层 thread。 |
| `legacyTask` | `<channelId>:<taskId>`；异步加载任务期间保留 URL 身份，完成时仍须匹配当前 query 才可打开。 |
| `profile` | `agent:<id>`、`human:<id>`；或 `external:<channelId>:<messageId>`，external 必须恰好两个非空 ID 部分，来源是消息的冻结作者事实。 |
| `agentTab` | Agent 详情分页；显式 tab intent 写入该键。同一 Agent 的普通 URL 同步保留明确分页；显式 reopen 的 ordered-first intent 按实际顺序选择，并清理旧 intent。未知分页由详情页降级，不能因此拒绝整个位置。 |
| `chatTab` | `chat|tasks|files`，频道内分页；默认 chat 不必写入。 |
| `q`、`channelId`、`defer=1` | 搜索文字、预选频道和等待文字后再搜索；构造时使用 URLSearchParams 编码。 |
| `presentation=page` | Electron Search 浮层进入完整结果页的显式例外；普通 Web 仍是完整页。它是 URL 标记，不能只存在会被其他 query writer 丢弃的 state 中。 |
| `filter=attention` | Computers 的关注筛选入口。 |
| `sidebarTab`、旧 `tab=machines|messages` | 旧 rail 指示，入场时 REPLACE 清理；根页上的 members/computers intent 折入路径。保留其他 query 和 hash。 |

依据：[searchContentStore.ts:63–83][S8]、[rightPanelUrlSync.ts:258–425][S9]及[427–550][S10]、[useAppNavigate.ts:403–464][S11]及[493–547][S12]、[searchOverlayLocation.ts:77–175][S13]、[useRailLegacyRedirect.ts:29–64][S5]。

解析模型必须区分原始 URI 与已解析的有效槽。Source 对 `thread=bad` 这样的非空但不合法值没有调用 open；只有键被移除的 else 分支关闭现有 thread。不要把“无效槽”擅自实现成“立即清除所有现存领域数据”。URLSearchParams.get 取首次同名键；模型若改用只保留最后一个值的 Map，需专门证明与来源一致。所有 ID 的大小写、内容和 kind 原样保留，不把 DM 当 channel。

`open` 仅在 Search/Activity 上投影；离开这两类路由或键被移除即清槽，两页之间的新入口也不会沿用上一页槽。内容槽变更在当前 pathname 上 REPLACE `open`/`msg`，读取 live URL 合并，以免覆盖同一 tick 已写入的 thread。右侧 thread/profile/task 可以并存；task 是独立覆盖槽，不能替换 thread。普通侧面板保留挂载，profile 关闭恢复同一个 thread 实例。[MainLayout.tsx:1306–1335][S14]、[1519–1619][S15]

一般导航记录和 route memory 包含 hash。旧 rail 重定向明确保留 hash；旧 `#settings` / `#channel/<id>` 等另有一次性迁移。右面板同步接口只传 pathname/search，不能据此宣称每一个 writer 都保留 hash。[useAppNavigate.ts:111–127][S16]、[useTabRouteMemory.ts:151–172][S17]、[MainLayout.tsx:1929–1944][S18]

## PUSH、REPLACE、Back 与记忆

1. `useAppNavigate.to*` 页面入口默认 PUSH；同一次用户表面迁移只能有一个 owner 写历史。移动 Activity thread 点击不先 openThread 再跳路由，否则会产生两个 PUSH。目标 URL 自带 thread anchor，目标投影再加载数据。
2. 右面板自动同步：首次增加 thread/profile/legacyTask/task 且未移除其他面板时 PUSH；普通 retarget、关闭、显式 replace 模式 REPLACE。`open` 内容槽选择是 REPLACE。不要笼统声明“任何详情都 PUSH”。
3. Back 先执行 beforeNavigate 的同步 teardown，再查实际观察到的前一历史 entry。只有已知、属于安全服务器 scope 的 entry 才 POP(-1)。否则字符串 semantic parent 用 REPLACE，callback fallback 直接执行关闭。显式服务器 fallback 决定 scope；未带服务器的 fallback 使用当前位置/服务器确定 scope。冷启动/重新加载不能假定浏览器此前 entry 属于本应用；未知索引空隙保持 unknown。
4. 浏览器多步 Back/Forward 依据实际 idx 记录，不假定每个 POP 只减少一层。Forward 不丢历史记录；从较早位置 PUSH 才丢其后的分支。同步 store 导航在 Router render 前登记；后续 commit 必须幂等，不能重复增加 entry。同 key 但 idx 变化仍是真 POP。
5. 任务 sheet 的 Back 先关任务槽，再消费打开时的 PUSH；检查 idx 已回到来源，不能只比 URL，因为关闭时的 REPLACE 与原入口可以拥有相同字符串。View in channel 桌面 PUSH、移动 REPLACE，均同步关 thread 并拒绝旧 query effect。
6. 桌面 rail 记忆按 server+mode 保存完整位置，并校验其归属。Search/Activity 入口总是新 landing，不恢复旧 query；Search 不写 chat memory。保存最后 server surface 和每 rail mode memory 是不同用途。
7. 移动每次点击 tab，无论 active/inactive，都 PUSH 到根页并丢目标 tab 的子页记忆。`mobileNavStore` 顶部旧注释的“inactive 恢复 top”已经被实际 `useMobileNav.selectTab` 覆盖；不能照旧注释实现。store 仍做临时 hydration/归属记录，换 server 清空；它不驱动 Back fallback。

依据：[useAppNavigate.ts:50–109][S19]、[192–315][S20]、[363–400][S21]；[rightPanelUrlSync.ts:139–208][S22]、[509–549][S10]；[MainLayout.tsx:1153–1159][S23]；[useSidebarTab.ts:55–84][S3]、[useTabRouteMemory.ts:12–36及101–172][S17]；[useMobileNav.ts:30–109][S24]、[mobileNavStore.ts:120–183][S25]。

## 响应式展示与可见性

| 判断 | Source 行为 |
| --- | --- |
| viewport `<768` / `>=768` | 一般移动/rail 布局边界；移动根页 inline 侧栏，详情覆盖 tab bar；rail 可见时任务浮层居中，窄屏全屏。 |
| viewport `>=1024` | workspace grid 必须同时满足能力开关、用户偏好与 hydration；宽度不足不能由 URL 绕过。经典 Activity 未开新 inbox 时，1024 才允许点击打开 master/detail；新 inbox 已开时使用 768。 |
| viewport `>=1280` **或 landscape**，并且 thread 内容容器 `>=680` | 普通 Channel+Thread 才同排。680 是扣除 rail/sidebar 后的命名容器实际可用宽度，不是 viewport；不满足则 thread 覆盖主频道、显示 Back，隐藏 Close。 |
| viewport `>=1024` 且容器 `>=680`，profile 从 thread 打开 | 折叠 channel，显示 Thread+Profile；保留 thread 挂载。profile 来源为 channel 时有不同折叠目标。 |
| Search/Activity 已有内容槽 | `>=768` 才组装真实 master/detail；没有槽时列表独占内容区，Tasks 不挂 conversation sidebar。 |
| 宽/紧凑 master 宽度 | 当前代码宽模式默认560、min400/max720；紧凑默认/min320、max480，独立持久化。MainLayout 老注释中的480/360及240/180–320与当前代码冲突，以代码为准。 |

依据：[MainLayout.tsx:1691–1715][S26]、[1287–1335][S14]、[1954–2008][S27]、[2170–2173][S28]；[ThreadsInbox.tsx:572–574][S29]；[workspaceGridDemoConfig.ts:12–25][S30]；[index.css:857–979][S31]；[MainLayout.tsx:1772–1796][S32]、[masterDetailPanelSizing.ts:1–24][S33]。

移动 tab 根页为 `/s/<slug>`、`/tasks`、`/members`、`/settings`。频道/DM、成员详情/graph、Search、Activity、Saved、Computers、电脑详情、设置子页与 release-notes 隐藏 tab；已有 thread 或内容槽也隐藏。guest 没 Members tab，host-shell embed 从第一帧就不渲染全局 tab。这里 Source 用负向详情列表判定并在剩余路径返回 true；纯模型应测试已挂载路由，不把注释的“仅根页”误当成未知路由已验证行为。[MainLayout.tsx:227–330][S34]

Electron Search 与普通宽屏 Web 要分开：Electron 普通 `/search` 是浮层，其背景依次取同 server 的显式 backgroundLocation、searchFrom、上次非 search 位置、server home；拒绝跨 server 或 search 背景。`presentation=page` 才显示完整页。普通 Web 忽略这些背景 state。浮层期间停止内容槽同步，保留背景现有 picked entity/thread；server home 背景禁止自动首频道重定向。[searchOverlayLocation.ts:15–175][S13]、[MainLayout.tsx:1533–1539][S15]

## Activity 行激活与通知点击

Activity 单击、双击、移动点击有实际不同合同，不能合并成一个选择 helper 的消息优先级：

| 操作 | 结果与定位 |
| --- | --- |
| 可 master/detail 的桌面单击 | 延迟220ms，留在 Activity 内容槽；channel/DM 取 unread 时 firstUnread 或 last，已读取 last；thread 取 unread 时 firstUnread 或 latest，否则 latest。thread 内容槽直接占详情列，不另外增加同一个 thread 的右侧副本。 |
| 桌面双击 | 取消单击 timer，PUSH 完整 channel/DM route。channel/DM 取 firstUnread 或 last；thread 优先 firstMention，再 unread firstUnread/latest，再 latest，并携带 parent 的 route kind 与 thread anchor。 |
| 移动/不够宽立即点击 | 不等 timer，PUSH canonical route；channel/DM 优先 firstMention，再 unread firstUnread/last，再 last；thread 取 unread firstUnread/latest 或 latest，保持 Source 与双击的区别。 |
| mention_action | 取该 action 自身的 messageId；桌面双击区分 channelType=dm，不能被 additive firstMentionMessageId 覆盖。当前单击路径直接构造 channel 内容槽/route，这是实际 Source 的分支，后续如修正需另行审查。 |
| workspace 注入 onOpenItem | 委托工作区自己的 panel/slot 入口，不执行上述经典布局 timer/route 分支。 |

依据：[ThreadsInbox.tsx:1018–1175][S35]；实际 Source 用例：[inboxDoubleClickNavigation.behavior.test.tsx:255–634][T1]。桌面 thread 单击通过 thread store 新增 anchor 后可能 PUSH，再由内容槽同步 REPLACE 同一 entry；移动/双击不预先打开 store，只写一次 canonical PUSH。关闭 Activity thread 时既去掉 thread，也清内容槽。[MainLayout.tsx:795–910][S36]

OS/PWA 通知也从 URI 进入同一 router：ServiceWorker 点击关闭系统通知，匹配已有目标 client 时 postMessage+focus，否则 openWindow；bridge 只接受正确 message type 与同 origin URL，然后 navigate(path+query+hash)。冷启动 thread permalink 的 Back 应依次 semantic REPLACE 到父频道，再 Home。系统铃铛 NotificationCenter 则是独立系统提醒：动作调用自己的 onClick（设置/电脑等），不能把它的每一行当 Activity 消息。[sw.js:132–147][S37]、[ServiceWorkerNavigationBridge.tsx:6–35][S38]、[NotificationCenter.tsx:92–125][S39]。

## Flutter 当前分歧与最小迁移

`WorkspaceController.section`、选中 channel、threadParent/threadChannelId 是独立字段；`jumpToMessage` 加载上下文时写 section=chat，`closeThread` 只清领域 thread。View 另有 DesktopNavigationState.masterRoute/target 和 mobileSettingsDetail；宽屏使用 masterRoute??section 画主体，但外层标题/加入/归档条仍读 section。因此 Activity/Search picked channel 加载后，主体是 master，标题却可出现频道。resize 也直接重写 Home/chat，移动 Back 按 section 猜根页，没有观察到的同 server history。

精确检查点（整合9bc）：`apps/raft_flutter/lib/data/workspace_controller.dart:916,1866–1875,1942–1955`；`features/desktop_navigation_policy.dart:75–119`；`features/workspace_view.dart:113–169,489–534,643–657,949–1028,1169–1280`；`features/mobile_workspace_navigation.dart:9–34`。

建议迁移顺序是工程方案，下面不是 Source 已存在的 Dart API：

1. 新纯 `RaftLocation` 保存 URI/服务器、已解析表面、content slot、thread/profile/task anchors、消息定位及可选 search background state；保留原始未知 query，Source别名规范化单独返回 REPLACE intent。它不存权限对象、API结果或读水位。
2. 由单一 navigation owner 持有 current location、observed history index/key 和导航版本。页面、tab、permalink、Activity、通知都通过同一个 push/replace/pop 入口。移动 tab memory 与桌面 rail memory 分开，不做 Back 的猜测来源。
3. 将 section/masterRoute/target 变成这份位置的投影；整个 shell 的标题、sidebar、master、detail、mobile tab/Back 和可见会话判定必须读取同一个投影。最小可交付步骤也应同时覆盖这些位置，不能只改标题里的一个 if。视口只选布局，数据加载保留 scope/generation/revision fence；选中频道供草稿恢复可以存在，但不能决定当前 rail 或已读 admission。
4. Controller 继续拥有 API/sync/权限；route loader 加载真实上下文后只接受仍匹配 location identity/version 的响应。清面板或 POP 在同一事件撤销待打开的旧响应。进入新 server/account 撤销旧实体与记忆，能力变化重新判定当前 route。
5. 第一批 pure URI/history 用例通过后，再接全部页面投影。settings分页、独立task/profile、ElectronSearch、workspace多组及平台通知等尚未接入的能力显式保留，不能靠 pure parser 的通过宣布全部导航对齐。

现有 Flutter 回归提供保留边界：`test/desktop_workspace_routes_test.dart:136` 保留 Search query/master；`:194` Members 列不卸载；`:244` 旧 DM 创建不能覆盖新选择；`:304,360` 慢首屏保留 composer/timeline。`test/mobile_workspace_navigation_test.dart:131,180,213,244,281,446` 分别覆盖根/详情切分、Home 不误读隐藏会话、折叠主列表的读 ACK、通知抑制、真实 Home drill-in/设置回根。这些都不是 observed-history 与完整 URI 互转验收。

## 加载、可见窗口与位置共同所有权

完整的 Source 加载审计由并行 Agent 在同一固定版本完成，见 [消息加载与实体 hydration 合同](source-message-loading-contract.md)，原文提交 `cbed05953e19153967db560b306c2b2152812aa5`。导航和加载必须共同接受以下边界，不能在 URI 解析完成时宣布消息已经可见：

| 位置动作 | Source 首帧与完成条件 | 具体来源 |
| --- | --- | --- |
| 已缓存频道消息定位 | 使用该频道自己的 accepted bucket/元数据，不重复 context GET | `packages/web/src/store/messageStore.ts:2374–2392` |
| 未缓存消息定位 | 同频道已有窗口保留；known-channel 的标题/eligible tabs/composer保留，空pending body才显示Loading | `messageStore.ts:2393–2411`；`components/message/ChatPanel.tsx:1345–1534` |
| 接受消息上下文 | bundled summaries先存在，然后同次更新rows、pagination、loading、error及**response targetMessageId**；不是永远原请求ID | `messageStore.ts:2425–2460` |
| 已接受定位 | 真实target存在才居中，临时highlight为2000ms；prepend保阅读anchor，append是否跟尾由follow/context状态决定 | `ChatPanel.tsx:581–597`；`MessageTimeline.tsx:595–727` |
| 返回尾部 | 有hasNewer时清highlight/count、退出context、保留窗口待tail加载、完成后scroll；活跃tail则直接scroll | `ChatPanel.tsx:654–683`；`messageStore.ts:2001–2024` |
| ID-only详情 | 路由身份不能生成offline/default model等数据事实。profile overlay保留操作标题与Loading；独立Agent route缺projection是Unavailable，Computer缺store row是not-found，不统一伪造hydration skeleton | `components/profile/ProfilePanel.tsx:67–172,349–401`；`MainLayout.tsx:547–580` |
| 旧请求晚到 | 位置版本、server/principal和请求generation共同决定接受；成功或失败都不能重开旧位置或污染新窗口 | `messageStore.ts:643–655`；`rightPanelUrlSync.ts:106–108,373–379` |

加载合同另列10组待执行状态序列：cache hit、延迟focus/canonical ID、highlight timer、晚到成功/失败、fallback-tail、实际return-to-bottom、arrival/paging、cold channel、entity first frame和member hydration。当前Flutter数据路径尚未接受response targetMessageId、实际reveal为.3且没有两秒paint expiry；ID-onlyFleetDetail也会先画默认事实。上述是审计发现，修复/真实原生验证尚未由这份文档完成。Root的数据迁移、聊天代理的真实中心定位与测试代理的状态序列应共享同一location token，避免各自维护互相覆盖的选择。

## 可执行验收表

以下可直接转成新纯模型的 table-driven tests；包含 action、精确 expected 和原 Source 用例位置。只允许测试真实 reducer/模型输出，不写一份与生产无连接的模拟导航器再报行为通过。P 表示纯模型，W 表示挂载页面测试；原生 OS/生命周期仍需独立验收。

| ID | 类型、输入/动作 | 必须断言 | Source 测试/代码 |
| --- | --- | --- | --- |
| N01 | P：解析 channel 与 dm 相同 ID 的 URL | 不同 kind；slug/ID/msg 保真；输出 URI 编码冒号一次 | [useAppNavigate:446–464][S11] |
| N02 | P：`open=thread:t&msg=r&thread=c:p` | 槽thread t；anchor c/p；回复focus r；消息父ID p不会作为回复focus | [rightPanel tests:1013–1055][T2] |
| N03 | P：`open=wrong:x`、`:x`、`channel:`、无键 | 有效内容槽为null；不伪造ID | [searchContentStore:63–79][S8] |
| N04 | P：已有thread c/p，增加task c/t | 保留thread，task独立；恰好一次PUSH | [rightPanel tests:385–448][T3] |
| N05 | P/W：删task，thread保持 | 只关闭任务；REPLACE；thread mount/scroll不换 | [rightPanel tests:492–511][T4] |
| N06 | P：同thread新增msg=r2 | 更新focus不再open/fetch相同thread；msg=p不作回复focus | [rightPanel tests:1058–1077][T5] |
| N07 | P：thread c/p→c/p2；关thread | retarget和关面板REPLACE；保留其他query | [rightPanel tests:134–211及560–585][T6] |
| N08 | P：external:c:m加载未完→Back→结果返回 | 结果不恢复已关profile；Forward仍可按冻结作者恢复 | [rightPanel tests:248–333][T7] |
| N09 | P/W：open→close→晚到旧query effect | 当前无thread，旧快照被拒；POP到不同idx/key使pending marker失效 | [rightPanel tests:656–752][T8] |
| N10 | P：旧machine、sidebarTab根/详情 | 只REPLACE正确canonical路径；保留其他query/hash；详情路径优先 | [useRailLegacyRedirect:29–64][S5] |
| N11 | P：cold `/s/dev/channel/c?thread=c:p`，连续Back | 父频道REPLACE，再`/s/dev`REPLACE，depth保持0 | [mobileBackNavigation.test:110–124][T9] |
| N12 | P：root→search PUSH→q REPLACE→channel PUSH→Back两次 | 回确切search query，再root；不PUSH首频道、不循环 | [mobileBackNavigation.test:126–145][T10] |
| N13 | P：前一entry `/s/a/...`，当前`/s/b/...` | 不跨server POP；按b的semantic parent REPLACE或callback close | [mobileBack behavior:544–618][T11] |
| N14 | P：显式fallback server与当前/前entry不同 | 用显式fallback scope判定；不能沿当前server猜POP | [mobileBack behavior:804–842][T12] |
| N15 | P：other→b→c→d→e，go(-3),go(+3),go(-2) | 在c的真实前entry是b；Back选b；Forward不截分支 | [mobileBack behavior:904起][T13] |
| N16 | P：reload落idx2，旧entry未知；再PUSH/REPLACE/POP | unknown不作安全Back；同步写入与commit不双计；同key/不同idx仍处理 | [mobileBack pure:163–182][T14]、[behavior:438–478,711–802][T15] |
| N17 | P/W：任务叠thread→任务Back | teardown先发生；原thread/query恢复且idx回原值，不只URL相同 | [mobileBack behavior:389–428][T16] |
| N18 | P/W：View in channel，桌面/移动 | desktop PUSH；mobile REPLACE；同步关thread；旧effect不重开 | [rightPanel tests:754–873][T17] |
| N19 | P/W：两个tab各有子页→点击active或inactive tab | 均到目标tab根，PUSH且清目标子页记忆 | [mobile tab E2E:155–204][T18] |
| N20 | P：desktop chat→Search→Chat / Activity→Chat | Search不覆盖chat memory；search/activity入口新landing，chat恢复自己的有效位置 | [useSidebarTab:61–83][S3]、[useTabRouteMemory:12–36,101–112][S17] |
| N21 | W：各已挂载路径与thread/content槽 | 根4tab可见；已列详情均隐藏；guest隐藏Members；embed首帧无tab | [MainLayout:227–330][S34] |
| N22 | P/W：767/768/1023/1024，old/newInbox两组 | 一般rail为768；old Activity预览1024，new为768；grid低于1024禁止 | [ThreadsInbox:572–574][S29]、[MainLayout:1691–1715][S26] |
| N23 | W：portrait1279/1280；landscape；内容679.98/680 | 同排仅满足orientation/xl且实际容器680；resize保留位置/消息anchor | [index.css:857–979][S31] |
| N24 | W：desktop Activity单击channel、DM、thread；双击 | 单击220ms后preview；双击取消timer，只PUSHcanonical一次；正确msg优先级 | [inbox行为:255–562][T1] |
| N25 | W：mobile channel/DM mention与thread点击 | 即刻PUSH；channel/DM先mention；thread保留Source unread/latest规则；无预open第二PUSH | [inbox行为:322–401,583–634][T1] |
| N26 | P/W：Electron Search背景跨server、search背景、page marker | 拒绝不合法背景；同server回退顺序；仅page marker允许完整页；Web忽略背景 | [searchOverlayLocation:47–175][S13] |
| N27 | W：保留Activity/Search选中channel，Data loader写section/chat | 标题、rail、master、detail、tab/back仍投影同一location；隐藏频道不误ACK | Flutter现有保留测试 + 单location迁移新用例 |
| N28 | P/W：通知message type错、跨origin、有效thread URI | 无效不导航；有效保真URI并一次PUSH；cold Back按N11 | [ServiceWorkerNavigationBridge:6–29][S38] |

## 来源链接

下列链接全部固定 Source 提交，可用于独立复查；Flutter行号绑定上面声明的9bc整合快照。加载、空/error状态与滚动可见性另有单独移植合同；本合同不以静态URL或截图代替实际消息已可见、焦点和读 ACK 验收。

[S1]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/App.tsx#L1164-L1185
[S2]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/MainLayout.tsx#L1423-L1516
[S3]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/hooks/useSidebarTab.ts#L7-L84
[S4]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/MainLayout.tsx#L2439-L2463
[S5]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/hooks/useRailLegacyRedirect.ts#L16-L64
[S6]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/MainLayout.tsx#L726-L728
[S7]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/MainLayout.tsx#L914-L996
[S8]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/store/searchContentStore.ts#L63-L83
[S9]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/rightPanelUrlSync.ts#L258-L425
[S10]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/rightPanelUrlSync.ts#L427-L550
[S11]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/hooks/useAppNavigate.ts#L403-L464
[S12]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/hooks/useAppNavigate.ts#L493-L547
[S13]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/search/searchOverlayLocation.ts#L15-L175
[S14]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/MainLayout.tsx#L1287-L1335
[S15]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/MainLayout.tsx#L1519-L1619
[S16]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/hooks/useAppNavigate.ts#L111-L127
[S17]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/hooks/useTabRouteMemory.ts#L12-L172
[S18]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/MainLayout.tsx#L1929-L1944
[S19]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/hooks/useAppNavigate.ts#L50-L109
[S20]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/hooks/useAppNavigate.ts#L192-L315
[S21]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/hooks/useAppNavigate.ts#L363-L400
[S22]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/rightPanelUrlSync.ts#L139-L208
[S23]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/MainLayout.tsx#L1153-L1159
[S24]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/hooks/useMobileNav.ts#L30-L109
[S25]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/store/mobileNavStore.ts#L120-L183
[S26]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/MainLayout.tsx#L1691-L1715
[S27]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/MainLayout.tsx#L1954-L2008
[S28]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/MainLayout.tsx#L2170-L2173
[S29]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/thread/ThreadsInbox.tsx#L572-L574
[S30]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/workspace/workspaceGridDemoConfig.ts#L12-L25
[S31]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/index.css#L857-L979
[S32]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/MainLayout.tsx#L1772-L1796
[S33]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/masterDetailPanelSizing.ts#L1-L24
[S34]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/MainLayout.tsx#L227-L330
[S35]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/thread/ThreadsInbox.tsx#L1018-L1175
[S36]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/MainLayout.tsx#L795-L910
[S37]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/public/sw.js#L132-L147
[S38]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/pwa/ServiceWorkerNavigationBridge.tsx#L6-L35
[S39]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/src/components/layout/NotificationCenter.tsx#L92-L125
[T1]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/inboxDoubleClickNavigation.behavior.test.tsx#L255-L634
[T2]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/rightPanelUrlSyncContract.test.tsx#L1013-L1055
[T3]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/rightPanelUrlSyncContract.test.tsx#L385-L448
[T4]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/rightPanelUrlSyncContract.test.tsx#L492-L511
[T5]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/rightPanelUrlSyncContract.test.tsx#L1058-L1077
[T6]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/rightPanelUrlSyncContract.test.tsx#L134-L585
[T7]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/rightPanelUrlSyncContract.test.tsx#L248-L333
[T8]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/rightPanelUrlSyncContract.test.tsx#L656-L752
[T9]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/mobileBackNavigation.test.ts#L110-L124
[T10]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/mobileBackNavigation.test.ts#L126-L145
[T11]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/mobileBackNavigation.behavior.test.tsx#L544-L618
[T12]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/mobileBackNavigation.behavior.test.tsx#L804-L842
[T13]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/mobileBackNavigation.behavior.test.tsx#L904-L928
[T14]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/mobileBackNavigation.test.ts#L163-L182
[T15]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/mobileBackNavigation.behavior.test.tsx#L438-L802
[T16]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/mobileBackNavigation.behavior.test.tsx#L389-L428
[T17]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/rightPanelUrlSyncContract.test.tsx#L754-L873
[T18]: https://github.com/botiverse/raft-source/blob/26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6/packages/web/tests/e2e/tests/mobile/tab-bar-sidebar.spec.ts#L155-L201
