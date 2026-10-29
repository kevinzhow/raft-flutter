// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.21.23-source.1 zh-cn.ts wording verbatim: every id added or rewritten since v1.21.12-source.1 whose
// English text had no entry yet (ids another zh_*.dart file already carries are not repeated). ICU plural /
// select messages are left out: raftFormat fills simple {name} placeholders only, so a surface that needs one
// adds the flattened singular / plural keys it actually uses.
const Map<String, String> zhCatalogW23Pin = <String, String>{
  "#{name}": "#{name}",
  "Verify {name} on a Computer": "在 Computer 上验证 {name}",
  "Service": "服务",
  "Client key": "客户端标识",
  "Redirect URL": "回调地址",
  "App URL": "应用地址",
  "Agent manifest": "Agent manifest",
  "Recovery owner": "恢复后的所有者",
  "Required computer": "指定的计算机",
  "Suggested computer": "建议的计算机",
  "Try Again": "重试",
  "Raft creates the agent in the cloud and connects it for you. No command line needed.":
      "Raft 会在云端创建这个 Agent 并自动完成连接，无需命令行操作。",
  "Runs in the cloud": "在云端运行",
  "Message delivery to this cloud agent is not registered yet.":
      "尚未为这个云端 agent 注册消息推送。",
  "This cloud agent no longer exists in the cloud. Connections are unavailable; recreate the agent.":
      "这个云端 agent 在云端已不存在，连接不可用；请重新创建该 Agent。",
  "Archive Agent": "归档 Agent",
  "Choose light, dark, or follow your device. Your choice is saved on this device.":
      "选择浅色、深色或跟随设备。选择会保存在此设备上。",
  "Show which agents are working, and what they are doing, at the top of the window and on the Home bar.":
      "在窗口顶部和首页顶栏显示正在工作的 Agent 及其在做的事。",
  "Regenerate Client Secret": "重新生成客户端密钥",
  "App Admin must approve before this app is removed from the public marketplace. Until then <code>{clientId}</code> stays listed, installable, and usable by existing connections. If approved, the source Server keeps its installation and access. Other Servers lose their installations, and their grants and tokens are revoked.": "需经应用管理员批准，此应用才会从公开市场移除。在此之前，<code>{clientId}</code> 仍会保持在列表中、可安装，并可被现有连接使用。批准后，来源 Server 的安装和访问权限会保留；其他 Server 的安装会被移除，其授权和令牌会被撤销。",
  "Raft palette in real surfaces": "真实界面中的 Raft 调色板",
  "Runs as a cloud agent using its configured model and budget. Each batch reads at most 2,000 messages / 64,000 source characters; unfinished history continues in the background. These are batch limits, not a limit on the analysis range. Per-batch model tokens and cost are not yet available.": "由云端 agent 使用已配置的模型和预算运行。每批最多读取 2,000 条消息 / 64,000 个来源字符，未读完的历史会在后台继续。这是单批限制，不是分析范围的总量上限。暂不提供每批模型 token 和费用。",
  "Evidence: insufficient to determine the outcome": "证据：不足以判断实际结果",
  "Evidence: conversation only; actual task or tool outcome is unverified":
      "证据：仅对话，尚未核实实际任务或工具结果",
  "{from} – {to}": "{from} – {to}",
  "{label} {target} · {message}": "{label} {target} · {message}",
  "A source message changed or was deleted. The old result is hidden; the service will analyze refreshed material.":
      "来源消息已编辑或删除，旧结果已隐藏；服务会重新分析最新材料。",
  "Current cloud agent model: {model}": "云端 agent 当前模型：{model}",
  "A chunk from {from} to {to} ({count} messages) was not analyzed after 3 failed attempts. Its outcome is unknown.":
      "{from} 至 {to} 的一段材料（{count} 条消息）在 3 次失败后未能分析，实际结果未知。",
  "This batch: {count, number} messages read": "本批已读取 {count, number} 条消息",
  "This batch has read {count, number} messages. The background scan continues in further batches.":
      "本批已读取 {count, number} 条消息。后台扫描会继续处理后续批次。",
  "Sources and historical range": "来源和历史范围",
  "Analyze messages since (UTC)": "分析此日期起的消息（UTC）",
  "Past {days} days": "最近 {days} 天",
  "Choose how far back the first scan starts. Messages are processed in batches; a batch budget is not a total data limit. Changing the range restarts analysis and clears its current results.":
      "选择首次扫描的开始日期。消息会分批处理，单批预算不是数据总量上限。修改范围会重新开始分析并清空当前结果。",
  "Apply changes and restart": "应用修改并重新分析",
  "Selected channels: {total, number} messages total; {count, number} in the analysis range.":
      "所选频道共有 {total, number} 条消息，分析范围内有 {count, number} 条。",
  "Newest source message: {time}": "最新源消息时间：{time}",
  "No messages exist in the selected channels.": "所选频道没有消息。",
  "The selected channels contain {count, number} messages across all history. Start with the newest message's UTC date to see a smaller slice. Restarting replaces current findings and may still require multiple model calls.": "所选频道全部历史共有 {count, number} 条消息。先从最新消息所在的 UTC 日期开始，查看较小范围。重新分析会替换当前发现，仍可能产生多次模型调用。",
  "Analyze the newest source day from {date}": "从 {date} 开始分析最新消息当天",
  "Messages exist, but they are outside this range. Choose an earlier start date to analyze them.":
      "频道中有消息，但都不在此范围内。请选择更早的开始日期。",
  "Read {count, number} of {total, number} messages · {batches, number} batches accepted":
      "累计已读 {count, number} / {total, number} 条消息 · 已处理 {batches, number} 批",
  "Read {count, number} messages · {batches, number} batches accepted":
      "累计已读 {count, number} 条消息 · 已处理 {batches, number} 批",
  "The background scan continues in batches. Accepted findings stay visible while the next batch runs. Batch limits do not cap the total data range.":
      "后台会分批继续扫描；下一批运行时，已产生的发现仍会保留。单批预算不限制整个数据范围。",
  "No new messages in this batch. Earlier accepted findings are kept.":
      "本批没有新消息，已产生的发现仍保留。",
  "Conversation insights": "对话洞察",
  "Reads selected channels · no DM replies": "读取所选频道 · 不回复私信",
  "RaftBench service agent": "RaftBench 专用 agent",
  "This agent reads selected sources and submits dashboard results. It does not reply to DMs. Open its card to inspect it.":
      "此 agent 只读来源并提交看板结果，不回复私信。点击名称可查看 agent 卡片。",
  "Create service agent": "创建专用 agent",
  "Assigned to this analysis": "已分配给此分析",
  "Ready to assign": "可以分配",
  "Setting up; assignment available when ready": "正在配置，完成后可分配",
  "Assign agent": "分配 agent",
  "Cloud is available now. Computer assignment will appear when its runner supports this read-only agent profile.":
      "现在可选云端运行；Computer 运行端支持此只读 agent 类型后才会开放分配。",
  "Enable once to analyze collaboration patterns automatically. This AI analysis does not classify sentiment or frustration; the separate legacy phrase scan provides those signals. Results appear here after each run.":
      "启用后自动分析协作模式。本 AI 分析不分类情绪或挫败；相关信号由独立的旧版词句扫描提供。每轮结果会显示在这里。",
  "Disable and clear results": "关闭并清除结果",
  "Enable and start analysis": "启用并开始分析",
  "Loading analysis settings…": "正在读取分析设置…",
  "Analysis settings could not be loaded or saved. Check access and try again.":
      "无法读取或保存分析设置，请检查权限后重试。",
  "Channels to analyze (up to 50)": "分析频道（最多 50 个）",
  "I authorize this read-only agent to analyze these channels on staging. Findings accumulate within this analysis range on staging; disabling or changing the range clears them. No export.":
      "我授权这个只读 agent 分析 staging 上的这些频道。发现会在本次分析范围内持续积累，关闭或更改范围会清空；不导出。",
  "{sources} channels · history continues in background; checks for new messages every {count} minutes":
      "{sources} 个频道 · 后台继续读历史；每 {count} 分钟检查新消息",
  "The analysis agent could not start. An administrator needs to check the cloud agent service.":
      "分析 agent 未能启动，需要管理员检查云端 agent 服务。",
  "Starting your analysis agent…": "正在启动分析 agent…",
  "Waiting for the analysis agent…": "正在等待分析 agent…",
  "Reading channel messages…": "正在读取频道消息…",
  "Analyzing the messages read…": "正在分析已读取的消息…",
  "Analysis progress": "分析进度",
  "{count} messages read": "已读取 {count} 条消息",
  "{count} messages read. The total is not known yet; this bar does not show a percentage.":
      "已读取 {count} 条消息。总量尚未知，进度条不代表百分比。",
  "Analysis complete": "本轮分析已完成",
  "Partial analysis — coverage is incomplete": "部分分析结果 — 覆盖不完整",
  "Analysis did not finish": "本轮分析未完成",
  "The agent did not finish within 30 minutes. This is a failed run, not a finding of no problems. The service will try a new run.":
      "agent 未在 30 分钟内完成。这是运行失败，不代表没有问题；服务会重新安排下一轮。",
  "Conversation evidence only. Tool outcomes and thread replies are not included. Suggestions need human review and never create or publish skills automatically.":
      "仅依据对话证据，不含工具执行结果和线程回复。建议需要人工复核，不会自动创建或发布技能。",
  "No material in this window": "本窗口没有分析材料",
  "No messages were read in this window; nothing was analyzed. Try a channel with recent messages.":
      "本窗口未读取到消息，未进行分析。可选择近期有消息的频道。",
  "No supported pattern was returned in the material read. This does not mean all collaboration is healthy.":
      "已读取材料中未返回有证据支持的模式，不代表所有协作都没有问题。",
  "Repeated clarification": "反复澄清",
  "Repeated attempts": "重复尝试",
  "Completion claim needs verification": "完成声明需要核实",
  "Practice worth reusing": "值得复用的做法",
  "Actively pursued": "正在推进",
  "Deliberately paused": "主动暂停",
  "Task intent: {intent}": "任务意图：{intent}",
  "Evidence": "证据",
  "Source unavailable in this view": "当前视图无法打开此来源",
  "Counterevidence": "反证",
  "{count} counterexamples were considered": "已考虑 {count} 条反证",
  "Draft improvement or shared-skill proposal": "改进或共享技能建议草稿",
  "Analysis result pages": "分析结果分页",
  "Previous page": "上一页",
  "Next page": "下一页",
  "Page {page} of {total} · {count} findings":
      "第 {page} / {total} 页 · {count} 条发现",
  "RaftBench is not enabled for this server": "此服务器尚未启用 RaftBench",
  "This pilot is off by default and only available to explicitly enrolled servers.":
      "此试点默认关闭，仅向明确加入白名单的服务器开放。",
  "RaftBench is for server administrators": "RaftBench 仅供服务器管理员使用",
  "Only this server’s owner or administrators can open this overview. Existing channel permissions still apply.":
      "仅此服务器的所有者和管理员可打开总览，仍受原有频道访问权限限制。",
  "Enable analysis for this page session": "同意在本页会话中启用分析",
  "I choose to read accessible task, billing and message data for this session. Results stay in this browser; this pilot has no export. Unchecking clears the current results and notes.":
      "我选择在本次会话读取有权访问的任务、费用和消息数据。结果保留在本人浏览器内，本试点不提供导出。取消勾选会清空当前结果和备注。",
  "{count} channels could not be read and contribute no evidence or signal counts. This overview is partial.":
      "{count} 个频道未能读取，不计入证据或信号数量。此总览覆盖不完整。",
  "Bounded overview: up to {limit} visible channels. {omitted} other channels are not scanned; choose one directly to inspect it.":
      "总览最多扫描 {limit} 个可见频道。另有 {omitted} 个频道未扫描，可直接选择查看。",
  "Public channels not joined: {available} available; {read} read in this snapshot. Scope includes accessible public/joint channels and joined private channels.":
      "未加入的公开频道：共 {available} 个，本次已读取 {read} 个。候选范围包含有权访问的公开/联合频道及已加入的私有频道。",
  "{read} of {requested} requested channels read · {visible} visible channels in this workspace":
      "已读取 {read}/{requested} 个请求频道 · 工作区内共 {visible} 个可见频道",
  "All scanned channels": "全部已扫描频道",
  "Coverage & limitations": "覆盖范围与局限",
  "{count} awaiting review": "{count} 条待复核",
  "Detection settings": "检测设置",
  "Current task inventory and coverage": "当前任务存量与覆盖说明",
  "Task efficiency": "任务效率",
  "Load task metrics": "读取任务指标",
  "Current period: {start} to {end} (end excluded, UTC).":
      "本期：{start} 至 {end}（不含结束日，UTC）。",
  "Legacy phrase and repetition rules": "旧版短语与重复规则",
  "Continuous AI analysis is being connected. The overview currently provides task and cost metrics.":
      "持续 AI 分析接入中，当前总览提供任务与费用统计。",
  "Manual phrase matching only, without AI interpretation. Positive and negative counts are wording matches; unscored does not mean neutral. The same messages and rules produce the same counts.":
      "仅手动匹配短语，没有 AI 理解。正负面数量是措辞命中数，未评分不等于中性；相同消息与规则会得到相同计数。",
  "Tasks and cost": "任务与费用",
  "Database metrics · no AI scan needed": "数据库直接统计 · 无需 AI 扫描",
  "Sources and limits": "来源与口径",
  "Dashboard sections": "看板分区",
  "Task history from the database": "数据库任务历史快照",
  "Current task states across accessible task sources. This is available without starting AI analysis or scanning messages.":
      "直接汇总可访问任务来源中的当前状态；无需启动 AI 分析或扫描消息。",
  "All tasks": "任务总数",
  "Awaiting review": "等待复核",
  "To do": "待办",
  "{surfaces} accessible task sources · created {first}–{latest} · last task update {updated} (UTC). This is a historical snapshot, not a current activity trend.": "{surfaces} 个可访问任务来源 · 创建于 {first}–{latest} · 最近任务更新 {updated}（UTC）。这是历史快照，不代表近期活动趋势。",
  "Created by people: {human} · by agents: {agent}.":
      "由人创建：{human} · 由 agent 创建：{agent}。",
  "Creation → done: median {median}, 90th percentile {p90} ({count} valid completed tasks). Calendar time includes waiting.":
      "创建至完成：中位数 {median}，第 90 百分位 {p90}（{count} 个有效完成样本）；日历时间包括等待。",
  "Refresh task and cost metrics": "读取总览",
  "Aggregating all accessible task sources…": "正在汇总所有可访问的任务来源…",
  "Reading cloud agent billing…": "正在读取云端 agent 费用…",
  "Task aggregation is unavailable. No task totals have been inferred from a partial sample.":
      "任务汇总暂不可用，未从部分样本推算任务总量。",
  "Source aggregation over {count} accessible task surfaces; no task-page cap.":
      "从 {count} 个可访问任务来源直接汇总，不使用任务分页截断样本。",
  "Task efficiency · period comparison": "任务效率 · 同期对比",
  "No tasks were completed in either comparison period.": "这两个比较时段内没有已完成任务。",
  "Task and cost comparison: latest 7 complete UTC days / previous 7 days. Today is excluded. This is separate from the AI historical start date.":
      "任务和费用比较：最近 7 个完整 UTC 日 / 前 7 日，不含今天；与 AI 历史分析起点分别计算。",
  "Completed · current / previous": "完成任务 · 本期 / 上期",
  "Median creation → done · current / previous": "创建至完成中位时长 · 本期 / 上期",
  "Mean creation → done · current / previous": "创建至完成平均时长 · 本期 / 上期",
  "Duration samples: {current} / {previous}. Calendar time includes waiting. Current done tasks only; reopened tasks and historical backlog are not reconstructed.":
      "时长样本：{current} / {previous}。日历时间含等待；仅按当前完成任务统计，未重建重开任务和历史积压。",
  "Partial task sample: these figures are not workspace totals and cannot establish a trend.":
      "任务样本未读完：这些数值不是工作区总量，不能据此判断趋势。",
  "Pilot results stay inside staging. Export is unavailable.":
      "试点结果仅留在 staging 内，暂不提供导出。",
  "Cloud agent cost · whole server": "云端 agent 运行费用 · 整个 server",
  "Load cost comparison": "读取费用对比",
  "Uses existing billing, separately from task/message reads. Always server-wide, even when a channel is selected.":
      "独立读取现有 billing，不读取任务或消息。即使选择单个频道，费用也始终覆盖整个 server。",
  "Cloud agent billing is not available for this server. This does not mean zero cost.":
      "此 server 暂无可用的云端 agent 运行费用数据，不代表零成本。",
  "PR merges and tokens are not connected. Cloud agent spend excludes other runtimes and is not attributed to tasks; no cost-per-task or savings are inferred. ":
      "PR 合并数和 tokens 尚未接入。费用只覆盖云端 agent，未归因到任务，不推算单任务成本或节省金额。",
  "A separate, on-demand task snapshot for the selected scope. No message scan is needed.":
      "按需读取当前范围的任务快照，无需扫描频道消息。",
  "Tasks observed": "已观察任务",
  "Done / observed": "已完成 / 已观察",
  "Median creation → done": "创建至完成的中位时长",
  "{value} h": "{value} 小时",
  "Current owners: {user} human · {agent} agent · {unassigned} unassigned":
      "当前负责人：{user} 人类 · {agent} agent · {unassigned} 未分配",
  "Elapsed time includes waiting; {samples} completed tasks have valid timestamps. Owner type is not end-to-end execution or quality. Closed is separate from done.":
      "耗时包含等待；{samples} 个完成任务有有效时间。负责人类型不代表全程执行者或质量。关闭与完成分开统计。",
  "All currently accessible task pages read; {count} tasks in this scope. This is an all-time status snapshot, not a time-window completion rate.":
      "已读完当前可访问的任务分页；当前范围 {count} 个任务。这是全部历史的状态快照，不是某段时间的完成率。",
  "Partial snapshot: read cap {limit}. {count} tasks in this scope; counts and durations are incomplete, not workspace totals.":
      "部分快照：读取上限 {limit}。当前范围 {count} 个任务，计数和耗时不完整，不代表工作空间总量。",
  "Open task board": "打开任务看板",
  "In review": "待复核",
  "Rollout status could not be refreshed. Your current evidence and review are preserved; new reads are paused until the status is confirmed.":
      "暂时无法确认功能开关状态。当前证据与复核备注已保留；确认状态前暂停新的读取。",
  "Channel breakdown": "按频道查看",
  "Task metrics and phrase-scan scope": "任务指标及短语扫描范围",
  "Workspace overview": "工作区总览",
  "RaftBench": "RaftBench",
  "Workspace efficiency and cost": "工作区效率与成本",
  "Two views: task metrics from the database and AI insights from conversations.":
      "两块内容：数据库任务指标，以及 AI 对话洞察。",
  "Back to settings": "返回设置",
  "Scan phrases and repeats": "扫描短语与重复",
  "Refresh phrase scan": "刷新短语扫描",
  "Reading selected scope…": "正在读取所选范围…",
  "Could not read the requested scope. Check your access and retry. Previous evidence has been cleared.":
      "无法读取所选范围，请检查权限后重试。旧证据已清除。",
  "Start a workspace overview, or choose a channel. Messages are read only when you start.":
      "开始工作区总览，或选择单个频道。仅在开始后读取消息。",
  "Snapshot of {count} messages · {time}": "{count} 条消息快照 · {time}",
  "Each scanned channel covers up to its latest 200 top-level messages. Older history and thread replies are not included.":
      "每个已扫描频道最多覆盖最近 200 条顶层消息，不含更早历史或线程回复。",
  "The server also applied a plan-based history limit.": "服务器还应用了套餐历史记录限制。",
  "Tool execution outcomes are unavailable in channel history; tool failure loops are not assessed.":
      "频道消息不包含工具执行结果，因此不评估工具失败循环。",
  "Review cues": "待复核信号",
  "Messages observed": "已观察消息",
  "Human wording": "用户措辞",
  "{positive} positive · {negative} negative · {mixed} mixed · {unscored} unscored":
      "{positive} 正向 · {negative} 负向 · {mixed} 混合 · {unscored} 未评分",
  "Review queue": "复核队列",
  "All signals": "全部信号",
  "Human frustration": "用户不满",
  "Negative sentiment": "负向措辞",
  "Repeated agent messages": "Agent 重复消息",
  "Explicit English/Chinese frustration phrase. Quotations, negation and sarcasm can be misread; inspect the context.":
      "匹配中英文显式不满短语。引用、否定或反讽可能误报，请检查上下文。",
  "Negative wording in a human message. This is a review cue, not proof of failure.":
      "用户消息中的负向措辞，仅提示复核，不代表任务失败。",
  "Identical text after case/whitespace normalization, at least 16 characters, from the same agent in the same channel within 15 minutes. Legitimate reminders can match.":
      "同一 Agent 在同一频道 15 分钟内发送相同文本，忽略大小写和空白，至少 16 字符。正常重复提醒也可能匹配。",
  "No matching cues in this window. This does not establish that the agent succeeded.":
      "此窗口内没有匹配信号，不代表 Agent 任务成功。",
  "Evidence and nearby context": "证据与附近上下文",
  "Matched": "已匹配",
  "Nearby context": "附近上下文",
  "Open original message": "打开原始消息",
  "Confirm signal": "确认信号",
  "Mark as false positive": "标为误报",
  "Reopen": "重新复核",
  "Needs review": "待复核",
  "Confirmed": "已确认",
  "Dismissed": "已标误报",
  "Reviewer note": "复核备注",
  "Export evidence and review": "导出证据和复核结果",
  "Review labels last until you refresh or leave this page; export to save them. No messages or labels are sent to another service.":
      "刷新或离开此页会清除复核标注，请导出保存。消息和标注不会发送至其他服务。",
  "Minimum repeats (2–20)": "最少重复次数（2–20）",
  "Rule version: {version}. Exact repetition and phrase rules only; semantic loops and indirect frustration may be missed.":
      "规则版本：{version}。仅使用精确重复和短语匹配，可能遗漏语义循环或间接不满。",
  "Select a cue to inspect its original messages.": "选择信号查看原始消息。",
  "{count} cues": "{count} 条信号",
  "Cloud agent · Free for a limited time": "云端 agent · 限时免费",
  "You're an admin of both {source} and {target}. The connection will be made directly as admin of both, and no email will be sent.":
      "你同时是 {source} 和 {target} 的管理员。将以两边管理员的身份直接建立连接，不会发送邮件。",
  "Connect directly as admin of both servers": "以两边管理员的身份直接建立连接",
  "Confirm the direct connection, or remove yourself from the invited people.":
      "请确认直接建立连接，或从被邀请人中移除自己。",
  "Connected {server} directly.": "已直接连接 {server}。",
  "Stripe checks this code at Checkout. Leave blank to enter a code there.":
      "Stripe 会在结账时校验优惠码；留空也可以到 Stripe 页面再填写。",
  "This promotion code is unavailable. Check it or remove it to continue.":
      "此优惠码不可用。请检查或移除后继续。",
  "Promotion code: {code}. The final discount is confirmed on Stripe Checkout.":
      "优惠码：{code}。最终优惠以 Stripe 结账页确认为准。",
  "Cloud agent spend": "云端 agent 费用",
  "Loading cloud agent spend": "正在加载云端 agent 费用",
  "Failed to load cloud agent spend": "云端 agent 费用加载失败",
  "Today (UTC)": "今天（UTC）",
  "{spent} of the {limit} daily limit": "{spent}，每日限额 {limit}",
  "{spent}, no daily limit": "{spent}，无每日限额",
  "Resets {time}": "{time} 重置",
  "This server has reached its daily limit. Cloud agents' model calls are refused until {time}.":
      "本服务器已达到每日限额，云端 agent 的模型调用在 {time} 前会被拒绝。",
  "The platform's daily limit has been reached. Cloud agents' model calls are refused until {time}.":
      "平台已达到每日限额，云端 agent 的模型调用在 {time} 前会被拒绝。",
  "No spend in the last 30 days": "近 30 天没有费用",
  "By agent": "按 agent",
  "Deleted agents": "已删除的 agent",
  "Some usage has no price and is not included.": "部分用量没有定价，未计入。",
  "Estimated, in USD by UTC day, as reported by the cloud agent provider. For reference, not a bill.":
      "估算值，美元，按 UTC 日期统计，数据来自云端 agent 服务方，仅供参考，不是账单。",
  "In USD by UTC day, as reported by the cloud agent provider. For reference, not a bill.":
      "美元，按 UTC 日期统计，数据来自云端 agent 服务方，仅供参考，不是账单。",
  "Runs on": "运行位置",
  "Cloud agent": "云端 agent",
  "Cloud agent, model {model}": "云端 agent，模型 {model}",
  "Confirm again": "需重新确认",
  "Reason": "原因",
  "Permissions ({count})": "权限（{count}）",
  "Show or hide details": "展开或收起详情",
  "under {amount}": "不到 {amount}",
  "Last on {name}": "最后所在：{name}",
  "Stop current turn": "停止当前这一轮",
  "Stopped the current turn.": "已停止当前这一轮。",
  "Nothing was running.": "当前没有在运行。",
  "Couldn't stop the current turn.": "没能停止当前这一轮。",
  "Cloud agent, runs in the cloud · Free for a limited time":
      "云端 agent，在云端运行 · 限时免费",
  "{name} couldn't start in the cloud. Connect a computer to run her there instead.":
      "{name} 没能在云端启动。连接一台计算机，改在计算机上运行她。",
  "Couldn't load the models, so the agent starts on the provider's default. You can change its model later in its profile.":
      "无法加载模型列表，Agent 会先用服务商的默认模型。之后可以在它的资料页里修改模型。",
  "The provider refused the model this agent was set to start on. Choose a model, then retry.":
      "服务商拒绝了这个 Agent 选定的模型。请重新选一个模型，然后重试。",
  "Retry with {model}": "用 {model} 重试",
  "Free for a limited time": "限时免费",
  "Cost": "费用",
  "Unpriced": "未定价",
  "Some usage, such as tool calls, has no price and is not included.":
      "部分用量（如工具调用）没有定价，未计入。",
  "In USD by UTC day, as reported by the provider. For reference, not a bill.":
      "美元，按 UTC 日期统计，数据来自提供方，仅供参考，不是账单。",
  "Archive {name}?": "归档 {name}？",
  "The agent stops and no longer counts toward your plan's agent limit. Its profile and message history stay visible, read-only.":
      "Agent 会停止运行，不再占用套餐的 Agent 名额。它的资料页和历史消息仍可只读查看。",
  "What should happen to its workspace?": "它的工作区怎么处理？",
  "Keep it on the Computer": "留在 Computer 上",
  "Nothing is deleted. You can browse it read-only while {computer} is online, and delete it later.":
      "不删除任何文件。{computer} 在线时可以只读浏览，之后也可以再删除。",
  "Delete the workspace": "直接删除工作区",
  "The workspace is removed from {computer}. The profile and messages stay.":
      "从 {computer} 上删除工作区。资料页和消息仍然保留。",
  "Deleting the workspace cannot be undone.": "删除工作区后无法恢复。",
  "Failed to archive the agent": "归档 Agent 失败",
  "Couldn't load the archive details": "归档信息加载失败",
  "Archived on": "归档时间",
  "{date} by {name}": "{date}，由 {name} 归档",
  "On {computer}": "在 {computer} 上",
  "Deleted from the Computer": "已从 Computer 删除",
  "Deleting from {computer}…": "正在从 {computer} 删除…",
  "Waiting for {computer} to come online.": "等待 {computer} 上线。",
  "its Computer": "原来的 Computer",
  "Delete workspace from Computer": "从 Computer 删除工作区",
  "The workspace is deleted from {computer}. This cannot be undone.":
      "从 {computer} 删除工作区，无法恢复。",
  "The workspace was not found on the Computer.": "在 Computer 上没有找到这个工作区。",
  "The Computer took too long to confirm the delete. It may still be deleting, or may be done: delete the workspace again to check.":
      "Computer 迟迟没有确认删除完成。它可能还在删，也可能已经删完：再删除一次工作区即可确认。",
  "The last workspace operation failed. Try again.": "上一次工作区操作失败了，请重试。",
  "The last delete did not go through. It is retried automatically.":
      "上一次删除没有成功，会自动重试。",
  "{computer} is still deleting the workspace. Raft checks again shortly.":
      "{computer} 还在删除工作区，Raft 稍后会再确认一次。",
  "Archived agents": "已归档的 Agent",
  "Archived {date} · {workspace}": "归档于 {date} · {workspace}",
  "View workspace": "查看工作区",
  "View the workspace of {name}": "查看 {name} 的工作区",
  "Workspace on {computer}": "工作区在 {computer} 上",
  "Workspace deleted": "工作区已删除",
  "Workspace location unknown": "工作区位置未知",
  "Deleting workspace…": "正在删除工作区…",
  "This agent is being migrated. Wait for the migration to finish or cancel it, then archive it.":
      "这个 Agent 正在迁移。请等迁移结束或取消迁移后再归档。",
  "Suggest a random name": "随机起一个名字",
  "Load this list again, right now": "立即重新获取这个列表",
  "Refresh this list": "刷新此列表",
  "This workspace was deleted from its Computer, so there is nothing to browse.":
      "这个工作区已从 Computer 删除，没有可浏览的内容。",
  "The Computer that holds this workspace is offline. Files can be browsed again when it reconnects.":
      "保存这个工作区的 Computer 离线了，重新连上后才能浏览文件。",
  "{detail} — automatic wakes are paused until the runtime is available on this computer, or you move the agent or switch its runtime":
      "{detail}——已暂停自动唤醒，等这台计算机上有了这个运行时、或把 Agent 移到别的计算机或换运行时后恢复",
  "Working now": "工作中",
  "Activity view": "动态视图",
  "Overview": "概览",
  "Raw log": "原始日志",
  "Last turn ended at {time}": "上一轮 {time} 结束",
  "Last turn ended at {time}: {trigger}": "上一轮 {time} 结束：{trigger}",
  "{seconds}s": "{seconds} 秒",
  "{minutes}m {seconds}s": "{minutes} 分 {seconds} 秒",
  "{hours}h {minutes}m": "{hours} 小时 {minutes} 分",
  "took {duration}": "用时 {duration}",
  "{trigger} · took {duration}": "{trigger} · 用时 {duration}",
  "{start}–{end}": "{start}–{end}",
  "replying to {sender} in {channel}": "回应 {channel} 里 {sender} 的消息",
  "replying to {sender} in a thread in {channel}":
      "回应 {channel} 里一个 thread 中 {sender} 的消息",
  "replying to a direct message from {peer}": "回应 {peer} 的私信",
  "handling an app event": "处理一条应用通知",
  "woken by a message in {channel}": "被 {channel} 的消息叫醒",
  "replying to a message in a private channel": "回应一个私有频道里的消息",
  "replying to a direct message": "回应一条私信",
  "Ended with an error": "出错结束",
  "Ended, outcome unknown": "已结束，结局未知",
  "No tool calls": "没有调用工具",
  "{time} some tests or checks failed": "{time} 测试或检查有失败",
  "{time} a command exited with code {code}": "{time} 命令退出码 {code}",
  "{time} a tool call failed": "{time} 一次工具调用失败",
  "{time} a message was held as a draft: there were unread messages first":
      "{time} 消息没发出去：有未读消息，被存成了草稿",
  "Last reply": "最后回复",
  "Last reply · {time}": "最后回复 · {time}",
  "Loading the reply…": "正在加载回复…",
  "The reply is in a conversation you can't see.": "这条回复所在的对话你看不到。",
  "No message sent this turn": "这一轮没有发消息",
  "No overview yet": "还没有概览",
  "The overview shows one line per finished turn. The Raft on this agent's computer records turns from the latest version on; if it is older, upgrade it on the computer's page and new turns will show up here.": "概览按轮显示，每完成一轮记一行。这个 agent 所在电脑上的 Raft 要是最新版本才会记录；如果版本较旧，在电脑页面里升级后，新的每一轮都会出现在这里。",
  "The overview shows one line per finished turn. This agent hasn't reported a finished turn yet.":
      "概览按轮显示，每完成一轮记一行。这个 agent 还没有报告过完成的一轮。",
  "Open the computer to upgrade": "打开电脑页面升级",
  "Show raw log": "看原始日志",
  "Show earlier turns": "显示更早的轮次",
  "Couldn't load the overview.": "概览加载失败。",
  "This read-only analysis agent does not reply to DMs. Results appear on the RaftBench page.":
      "这是只读分析 agent，不会回复私信。结果显示在 RaftBench 页面。",
  "Invitation to join #{channel}": "邀请加入 #{channel}",
  "{server} invited this server to a joint channel.": "{server} 邀请本服务器加入联合频道。",
  "Accept": "接受",
  "Next unread thread ({count})": "下一个未读 thread（{count}）",
  "Earliest unread thread ({count})": "最早的未读 thread（{count}）",
  "Couldn't load this video preview.": "视频预览加载失败。",
  "Retry loading {filename}": "重新加载 {filename}",
  "#{number}": "#{number}",
  "{channel} ·": "{channel} ·",
  "All conversations": "全部会话",
  "Continue searching": "继续搜索",
  "No matches yet": "暂时还没有找到",
  "Searched messages back to {time}. Older messages have not been searched yet.":
      "已搜索到 {time} 的消息，更早的消息还没有搜索。",
  "Only part of the messages has been searched so far.": "目前只搜索了一部分消息。",
  "Cookie choice": "Cookie 选择",
  "Cookies on Raft": "Raft 上的 Cookie",
  "We'd like to use analytics cookies so we can understand how you use this page and make improvements.":
      "我们想使用分析类 Cookie，以便了解你如何使用这个页面并加以改进。",
  "Reject": "拒绝",
  "Cookie settings": "Cookie 设置",
  "cloud": "云端",
  "Mark All as Read": "全部已读",
  "Choose your display style": "选择你的显示风格",
  "Which style do you prefer?": "你喜欢哪种风格？",
  "Only changes what you see. You can change it anytime in Settings.":
      "只影响你自己看到的样子，之后可以随时在设置里改。",
  "Server settings": "服务器设置",
  "Servers": "服务器",
  "{name}, unread activity": "{name}，有未读动态",
  "{name}, other servers have unread activity": "{name}，其他服务器有未读动态",
  "Press Space to pick up the server, arrow keys to move it, Space to drop, Escape to cancel. Press Enter to switch to it.":
      "按空格键拿起服务器，用方向键移动，再按空格键放下，按 Esc 取消。按回车键切换到该服务器。",
  "Picked up {name}.": "已拿起 {name}。",
  "{name} is over {target}.": "{name} 位于 {target} 上方。",
  "{name} is no longer over a server.": "{name} 已不在任何服务器上方。",
  "{name} dropped at the position of {target}.": "{name} 已放到 {target} 的位置。",
  "{name} dropped.": "{name} 已放下。",
  "Moving {name} cancelled.": "已取消移动 {name}。",
  "Desktop app": "桌面版",
  "Get Raft Desktop for your computer.": "在电脑上安装 Raft 桌面版。",
  "Download for Mac": "下载 Mac 版",
  "Download for Mac (Apple silicon)": "下载 Mac 版（Apple 芯片）",
  "Download for Mac (Intel)": "下载 Mac 版（Intel 芯片）",
  "Mac with an Intel chip? Choose macOS (Intel) below.":
      "Intel 芯片的 Mac，请选下方的 macOS（Intel 芯片）。",
  "macOS": "macOS",
  "Download for Windows": "下载 Windows 版",
  "Download for Linux": "下载 Linux 版",
  "The Windows version is coming soon. Until then, use Raft in your browser.":
      "Windows 版即将推出。在那之前，请在浏览器里使用 Raft。",
  "Other platforms": "其他平台",
  "Choose your platform": "选择你的平台",
  "macOS (Apple silicon)": "macOS（Apple 芯片）",
  "macOS (Intel)": "macOS（Intel 芯片）",
  "Linux (AppImage)": "Linux（AppImage）",
  "Linux (.deb)": "Linux（.deb）",
  "{platform} (coming soon)": "{platform}（即将推出）",
  "Cloud": "云端",
  "the cloud": "云端",
  "Move to": "迁移到",
  "Move to the cloud": "迁移到云端",
  "The agent stops on {source} while the cloud checks its files and you review what moves.":
      "云端检查文件、你确认要迁过去的内容期间，{source} 上的 Agent 会停止运行。",
  "Its workspace files will be stored in the cloud, and the copy on {source} will be archived.":
      "工作区文件会存到云端，{source} 上的副本会被归档。",
  "The current session context isn't carried over: the agent starts a new session in the cloud.":
      "当前会话上下文不会带过去，Agent 会在云端开始新的会话。",
  "You'll need to reconnect GitHub once after the move.": "迁移后需要重新连接一次 GitHub。",
  "Once you confirm the move, it can't be undone.": "确认迁移后就无法撤销。",
  "Uploading the workspace from {source} to the cloud.":
      "正在把工作区从 {source} 上传到云端。",
  "Checking which files can move to the cloud.": "正在检查哪些文件可以迁到云端。",
  "Review what moves to the cloud, then confirm. The agent stays stopped on {source} until you decide.":
      "请查看要迁到云端的内容，然后确认。在你决定之前，{source} 上的 Agent 保持停止。",
  "Switching the agent to the cloud.": "正在把 Agent 切换到云端。",
  "The agent now runs in the cloud.": "Agent 现在在云端运行。",
  "The agent switched to the cloud but did not finish setting up there. If you contact support, include the migration ID.":
      "Agent 已切换到云端，但没能在云端完成设置。联系支持时请附上迁移编号。",
  "The agent hasn't switched to the cloud, so it stays on {source}. Raft is cleaning up.":
      "Agent 还没有切换到云端，所以仍在 {source} 上。Raft 正在清理。",
  "The move to the cloud was canceled. The agent is still on {source}.":
      "迁移到云端已取消，Agent 仍在 {source} 上。",
  "Raft couldn't finish cleaning up on {source}. Keep it online. If you contact support, include the migration ID.":
      "Raft 没能完成 {source} 上的清理。请让它保持在线。联系支持时请附上迁移编号。",
  "Raft will stop moving the agent to the cloud. The agent and its workspace stay on {source}, and it goes back to work there.":
      "Raft 会停止把 Agent 迁到云端。Agent 和它的工作区留在 {source} 上，并在那里继续工作。",
  "Canceling finishes once {source} confirms. Keep it online until then.":
      "{source} 确认后取消才会完成，在此之前请让它保持在线。",
  "Moving to the cloud": "正在迁移到云端",
  "Moved to the cloud": "已迁移到云端",
  "Move to the cloud canceled": "迁移到云端已取消",
  "Canceling the move to the cloud": "正在取消迁移到云端",
  "Move to the cloud needs attention": "迁移到云端需要处理",
  "Progress of the move to the cloud": "迁移到云端的进度",
  "Prepare and upload": "准备并上传",
  "Check files": "检查文件",
  "Your review": "等你确认",
  "Switch to the cloud": "切换到云端",
  "Running in the cloud": "在云端运行",
  "What moves to the cloud": "迁到云端的内容",
  "Brought over": "会迁过去",
  "Left behind: {reason}": "不会迁过去：{reason}",
  "Left behind": "不会迁过去",
  "No files": "没有文件",
  "and {count, number} more": "还有 {count, number} 个",
  "When you confirm, the agent switches to the cloud and the copy on {source} is archived. This can't be undone.":
      "确认后，Agent 会切换到云端，{source} 上的副本会被归档。此操作无法撤销。",
  "Confirm by {deadline}. After that the move stops and the agent stays on {source}.":
      "请在 {deadline} 前确认，否则迁移会停止，Agent 继续留在 {source} 上。",
  "Confirm and move": "确认迁移",
  "Moving…": "正在迁移…",
  "The cloud agent needs attention": "云端 agent 需要处理",
  "The agent is already in the cloud.": "Agent 已经在云端。",
  "The cloud couldn't import the workspace files. This can still finish, and the Raft team has been alerted. If you contact support, include the migration ID.":
      "云端没能导入工作区文件。迁移仍有可能完成，Raft 团队已收到提醒。联系支持时请附上迁移编号。",
  "The cloud still hasn't imported the workspace files, long after the switch. This can still finish, and the Raft team has been alerted. If you contact support, include the migration ID.":
      "切换到云端已经很久，云端仍未导入工作区文件。迁移仍有可能完成，Raft 团队已收到提醒。联系支持时请附上迁移编号。",
  "The cloud couldn't set up the agent. This can still finish, and the Raft team has been alerted. If you contact support, include the migration ID.":
      "云端没能设置好这个 Agent。迁移仍有可能完成，Raft 团队已收到提醒。联系支持时请附上迁移编号。",
  "The agent was deleted in the cloud, and the cloud can't set it up again for this agent. The Raft team has been alerted. If you contact support, include the migration ID.":
      "这个 Agent 在云端已被删除，云端无法再为这个 Agent 重新设置。Raft 团队已收到提醒。联系支持时请附上迁移编号。",
  "The cloud found this agent under a different account than Raft expected, a configuration problem on Raft's side. The Raft team has been alerted. If you contact support, include the migration ID.": "云端找到的这个 Agent 属于与 Raft 预期不同的账户，这是 Raft 这边的配置问题。Raft 团队已收到提醒。联系支持时请附上迁移编号。",
  "The cloud never set the agent up, so Raft put it back on {source} unchanged. You can try again.":
      "云端始终没有设置好这个 Agent，Raft 已把它原样放回 {source}。你可以再试一次。",
  "The upload to the cloud was interrupted. Make sure {source} is online, then try again.":
      "上传到云端的过程中断了。请确认 {source} 在线，然后再试一次。",
  "Symbolic links": "符号链接",
  "Git data (.git)": "Git 数据（.git）",
  "Raft's own files": "Raft 自身的文件",
  "Names the cloud can't store": "云端无法保存的文件名",
  "Names the cloud reserves": "云端保留的文件名",
  "Too large for a single file": "单个文件过大",
  "Not text": "非文本文件",
  "Over the cloud's size or file limit": "超出云端的大小或文件数量上限",
  "Refused by the cloud": "被云端拒绝",
  "Other reasons": "其他原因",
  "Moving agents to the cloud is not available on this server right now. Try again later, or move the agent to a computer.":
      "这个服务器暂时无法把 agent 迁到云端。请稍后再试，或者先迁到另一台计算机。",
  "This agent has already run in the cloud, so it cannot move there again.":
      "这个 agent 已经在云端运行过，不能再迁过去。",
  "That model is not available for cloud agents on this server. Pick another model, or leave it on the default.":
      "这个服务器上的云端 agent 不能用这个模型。请换一个模型，或者使用默认模型。",
  "This migration is not waiting for your confirmation any more. Refresh to see where it stands.":
      "这次迁移已经不在等你确认了。刷新一下看看现在的状态。",
  "The agent's MEMORY.md can't be brought to the cloud: it is too large, is not plain text, or the cloud refused it. Ask the agent to trim MEMORY.md to plain text, then try again.": "Agent 的 MEMORY.md 没法迁到云端：文件太大、不是纯文本，或者被云端拒绝。请让 Agent 把 MEMORY.md 精简成纯文本后再试。",
  "The agent already moved to the cloud, so this migration can no longer be canceled.":
      "agent 已经迁到云端，这次迁移不能再取消了。",
  "The target computer is still detecting its runtimes. Try again in a moment.":
      "目标计算机正在检测运行时，请稍后重试。",
  "The target computer's last runtime detection did not finish for {runtime}. Rescan its runtimes on the Computer page, then try again.":
      "目标计算机上一次运行时检测没有完成 {runtime} 的检测。请在该计算机页面重新检测运行时后重试。",
  "This selection is too long for one image. Select fewer messages and try again.":
      "选中的内容太长，无法生成一张图片。请少选几条消息后重试。",
  "The image came out empty. Try again, or select fewer messages.":
      "生成的图片是空的。请重试，或少选几条消息。",
};
