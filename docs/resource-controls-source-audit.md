# Search、Saved 与 Activity 原生控制

基准：26f77ef。实现只使用当前 mounted API，不引入 groupBy、senderName 等不存在的服务器参数。

| 行为 | 主源码 | 原生请求/结果 |
| --- | --- | --- |
| 消息筛选 | packages/web/src/components/search/MessageSearchPage.tsx 的 buildMessageSearchParams | GET /messages/search；q（允许空串）、senderId、channelId、mentionTarget=self、独占 senderType=user/agent、after/before、limit=20、offset |
| 搜索排序 | 同文件 + searchGrouping.ts | 非空 q 且选择 recent 才发送 sort=recent；默认 relevance 及无文字筛选依照服务器默认行为。Humans+Agents 同选不发送 senderType，选具体 sender 与类型冲突时清理冲突筛选 |
| 日期范围 | searchGrouping.ts 的 buildTimeRangeParams | Today 使用设备当地午夜；7/30 天按当地日历减天数，再转 ISO UTC after/before，与 Web 相同 |
| Saved | packages/web/src/store/savedStore.ts | GET /channels/saved；q、channelId、sort=asc/desc、limit=20、offset |
| Activity | packages/web/src/store/inboxStore.ts、ThreadsInbox.tsx | GET /channels/inbox；filter=all/unread/mentions、q、channelId、sort=asc/desc、limit=30、offset；Done/Unfollowed 使用独立历史端点，保留相同搜索/频道/排序参数 |
| 频道组 | ThreadsInbox.tsx 的 itemActivityGroup 与服务器返回 groups | 同一个 parentChannelId 汇聚 thread；菜单显示服务器授权 facets/counts；原生可按频道分组显示当前已载入页，不发送分组参数或声称已载入全部分页 |
| Thread triage | inboxStore.ts markDone、threadStore.ts | POST /channels/threads/done 或 undone；threadChannelId 独立于频道 ID。follow 发送 parentMessageId；unfollow 发送 threadChannelId |

Done 使用 row.doneFrontierSeq 和 frontierSpace=storage，不使用 latestActivitySeq 显示序号。新响应明确提供但无法使用 frontier 时不提交，刷新并要求重试。仅 legacy 响应完全省略该字段时按源码兼容路径省略序号；这会在旧服务器以请求时最新 frontier 完成，可能覆盖点击前后到达的新活动。mention_action 不误发频道/线程 Done。

频道与 sender 控件显示当前授权目录中的名称，不要求用户输入内部 ID。sender 目录在权限允许时重新读取成员及 agents，并保留当前人类用户；目录、筛选和私有 popup 随账户、coordinator、服务器、角色或频道访问变化清理。已有 ResourceView authority/request/dialog/变更后 refreshUnread fences 全部保留；旧目录读取及迟到 RPC 不进入新作用域。全局 capability 拒绝时仅显示当前账户，不读取受限制的人类管理目录。

针对性验证包括 exact request maps、日期/类型范围组合、frontier 与 legacy 矩阵、实际 widget 点击、thread 请求载荷、scope 变化后的目录迟到拒绝，以及已有 10 项 ResourceView authority 回归。integration_test/resource_flow.dart 供整体 Linux/Android native 验收使用真实已有消息/收藏；本轮未运行 emulator 或整体 native。


## Task 多选与删除频道后的终态清理

TasksPanel.tsx 的频道、Creator、Assignee filter 均启用多选及名称搜索；身份以 user:id/agent:id 区分。原生按同一规则在已授权、已载入的任务中筛选：每个集合内 OR，集合之间 AND；Unassigned 与具体受领者可以同选。频道不包括 DM；当前账户有 Created by me/Assigned to me 入口。目录显示名称及身份类型，支持名字和 handle 搜索，已删除 agent 不列入。它们不是 /tasks/server 查询参数；分页仍按实际 cursor 加载，筛选不把当前页伪装为完整任务集合。多选 review、旧回调及迟到目录保留原 ResourceView authority fences。

服务端 routes/tasks.ts 的 isOrphan 是 requireTaskInServer 内部状态，没有公开 response flag。原生不把目录缺席宣称为“频道已删除”。对 fresh task detail 仍可读取且父频道不在本地目录的任务，仅向具 deleteAnyTask capability 的非 guest 展示 done/closed 请求；creator 或该 capability 可发 Delete。现网 mounted route 重新校验 task 可见性、频道状态及 actor：孤立任务非终态返回 channel_deleted_terminal_only，终态需 deleteAnyTask，删除需 creator 或 deleteAnyTask。历史 joint task 的 readOnlyReason 仍禁止变更；已存在但 archived/unjoined 频道不走此清理入口。

定向新增 typed identity 同 ID 碰撞、OR/AND、Unassigned、搜索多选 UI、fresh task detail 后 terminal payload、已关闭 dialog 的旧 Apply/Clear 不能弹出主页面、fresh history 无权时禁止清理五项回归。2026-10-08 UTC 01:49:11.360590 的较早 b20 源码版本绑定 Linux 主运行已完成通过，包括 Task 多选/board 与 Search/self-mentions/Saved query-sort/Activity grouping 高级控制。终态清理仍以定向回归为证据，Android 同源码整轮仍待父 native runner。

`verifyAdvancedTaskFilters` 同文件供主 runner 使用先前由当前账户创建的真实 task：频道、Created by me、Assigned to me + Unassigned 多选，验证 typed set、实际可见 task 并截图；不创建额外 fixture。


发现性边界：当前 server task list 和 channel/number lookup 使用未删除的 task surface，因此新读取的面板不会成为独立 orphan 目录。对本视图此前已经接收的 task，父频道不在目录且 number lookup 返回 404 时，只继续 GET /tasks/:id/history；该端点通过 includeDeleted 重新验证当前服务器及频道可见性。只有该授权读取成功（含源码 legacy history 的已授权 409）才能展示上述终态动作；history 的无权/不存在响应仍失败，不以 number 404 推定存在或可见性。没有增加未挂载的 orphan listing API。

最终本范围 35 项定向测试通过：resource_filters（6）、resource_controls（12）、resource_authority（10）、task_resource_filters（1）、attachment_scope（6）。8 个相关 Dart 文件的定向 analyze 与 diff check 均通过；未执行共享原生整轮或修改测试服务器 fixture。


Resource modal ownership regression: a removed ResourceView now removes only its captured owned dialog routes after the frame. A widget regression reproduces the prior visible, inert task picker after view disposal. The exact self-selection then Unassigned search/apply sequence also passes in the real widget; this does not establish the cause of the parent native helper failure, which still requires its live-field diagnostic. The three focused resource/control/authority files pass 25 tests after this fix.

Activity special-view regression: Done conversations and Unfollowed threads now leave the All/Unread/Mentions segments unselected. A single All click issues the mounted `/channels/inbox` request again; deselecting an already selected All is ignored safely. Both before/after widget regressions use actual taps and request assertions. Resource control/authority/task-filter tests now pass 27 cases; the earlier b20-source Linux 01:49:11 run passed the advanced Activity checkpoint and complete aggregate; Android same-source full remains pending. Taskboard row visibility was explained by source ordering and real lane scrolling; no board product change was made.

Current acceptance revision: `4baf6f56d45c29caf6d564243bf73e42498fca0495a096faff78d5f800d684b1` includes the mobile main/thread ChatView rebind repair. Engineering 353 Dart/29 host/analyze passes; Current-source Android full is running first, then Linux will rerun serially. The 01:49:11 Linux proof above belongs to the earlier b20 hash, not this revision.
