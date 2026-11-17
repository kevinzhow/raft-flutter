// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.24.0-source.1 en.ts / zh-cn.ts wording verbatim: WP-ADMIN RaftBench (finding feedback, finding index,
// agent access, triage, period tables). ICU `{n, number}` is written `{n}`; plural arms are one key each.
const Map<String, String> zhCatalogUpstream124AdminRaftbench = <String, String>{
  // raftbench.aiBatchReadCount
  "{count} new messages read":
      "已读取 {count} 条新消息",
  // raftbench.aiCumulativeRead
  "Read {count} of {total} messages so far":
      "累计已读 {count} / {total} 条消息",
  // raftbench.aiCumulativeUnknown
  "Read {count} messages so far":
      "累计已读 {count} 条消息",
  // raftbench.aiErrorAccess
  "Your account may not have access to RaftBench on this server.":
      "你的账号可能没有这个服务器上 RaftBench 的访问权限。",
  // raftbench.aiErrorSignIn
  "Your sign-in may have expired. Refresh the page or sign in again.":
      "登录可能已过期，请刷新页面或重新登录。",
  // raftbench.aiLoadError
  "Analysis settings could not be loaded (code: {code}). Refresh the page to try again.":
      "无法读取分析设置（错误码：{code}）。请刷新页面重试。",
  // raftbench.aiReadingReplies
  "Reading thread replies…":
      "正在读取消息列回复…",
  // raftbench.aiSaveError
  "Analysis settings could not be saved (code: {code}). Try again.":
      "无法保存分析设置（错误码：{code}）。请重试。",
  // raftbench.aiStreamRead
  "Channel messages read: {channel} · Thread replies read: {thread}":
      "频道消息已读 {channel} 条 · 消息列回复已读 {thread} 条",
  // raftbench.aiStreamRetryChannel
  "Channel messages failed to load 1 time; unread history is kept for retry.":
      "频道消息读取失败 {count} 次，未读的历史会保留，等待重试。",
  // raftbench.aiStreamRetryChannel
  "Channel messages failed to load {count} times; unread history is kept for retry.":
      "频道消息读取失败 {count} 次，未读的历史会保留，等待重试。",
  // raftbench.aiStreamRetryThread
  "Thread replies failed to load 1 time; unread history is kept for retry.":
      "消息列回复读取失败 {count} 次，未读的历史会保留，等待重试。",
  // raftbench.aiStreamRetryThread
  "Thread replies failed to load {count} times; unread history is kept for retry.":
      "消息列回复读取失败 {count} 次，未读的历史会保留，等待重试。",
  // raftbench.costSpent
  "Spent":
      "花费",
  // raftbench.feedbackAgree
  "Agree":
      "同意",
  // raftbench.feedbackError
  "Feedback was not saved. Refresh and try again.":
      "反馈未保存，请刷新后重试。",
  // raftbench.feedbackInaccurate
  "Inaccurate":
      "不准",
  // raftbench.findingCoverage
  "Analyzed through {scanned}":
      "已分析到 {scanned}",
  // raftbench.findingEvidenceAt
  "Latest evidence: {time}":
      "最近证据时间：{time}",
  // raftbench.findingPeriod
  "Evidence period":
      "证据时间范围",
  // raftbench.findingPeriodEmpty
  "No findings in this view. Check History and data coverage; this does not mean there are no problems.":
      "此范围暂无发现。可查看历史和数据覆盖情况；不代表没有问题。",
  // raftbench.focusAll
  "All patterns":
      "全部模式",
  // raftbench.focusCoverage
  "Reading progress and coverage":
      "读取进度与覆盖范围",
  // raftbench.focusMethod
  "How to interpret these patterns":
      "如何判断这些模式",
  // raftbench.focusMissing
  "PR merge/deploy timing, tool-level loops, verified rework rates, admin chat, and suggestion adoption tracking are not connected yet.":
      "尚未接入 PR 合入/部署耗时、工具级循环、经核实的返工率、管理员对话和建议采纳追踪。",
  // raftbench.focusTitle
  "What deserves attention":
      "值得关注的模式",
  // raftbench.groupUnavailable
  "Grouping by type is unavailable right now. Showing all findings by date; the total and pages below are complete.":
      "暂时无法按类型分组，先按日期列出全部发现；下方的总数和分页是完整的。",
  // raftbench.periodCurrent
  "Last {days} days ({range})":
      "最近 {days} 天（{range}）",
  // raftbench.periodMetric
  "Metric":
      "指标",
  // raftbench.periodPrevious
  "Previous {days} days ({range})":
      "之前 {days} 天（{range}）",
  // raftbench.readerAccess
  "Agent access":
      "Agent 访问",
  // raftbench.readerAccessError
  "Could not update agent access. Try again.":
      "无法更新 Agent 访问权限，请重试。",
  // raftbench.readerAccessHelp
  "Allow an agent to read findings. It can only see findings whose sources it can already read. The agent’s owner can also see these analyses.":
      "允许 Agent 读取发现，但只会显示它本来就能读取全部来源的发现。这个 Agent 的所有者也能看到这些分析。",
  // raftbench.readerGrant
  "Allow access":
      "允许访问",
  // raftbench.readerRevoke
  "Revoke access":
      "撤销访问权限",
  // raftbench.snapshotDurationMethod
  "Completion time includes waiting; based on {count} completed tasks.":
      "完成耗时含等待，基于 {count} 个已完成任务。",
  // raftbench.snapshotMedian
  "Median time to complete":
      "完成耗时中位数",
  // raftbench.snapshotP90
  "90% completed within":
      "90% 的任务在此时长内完成",
  // raftbench.triageBudget
  "Today's labeling budget is used up; it continues tomorrow. {triaged} labeled so far, {labeled} flagged.":
      "已到今日分拣额度，明天继续。目前已分拣 {triaged} 条，标出 {labeled} 条。",
  // raftbench.triageIdle
  "Message labeling is up to date: {triaged} labeled, {labeled} flagged · {usage}% of today's budget used":
      "消息分拣已是最新：已分拣 {triaged} 条，标出 {labeled} 条 · 今日额度已用 {usage}%",
  // raftbench.triageOff
  "Message labeling is not enabled.":
      "消息分拣未开启。",
  // raftbench.triageRunning
  "Labeling messages: {triaged} labeled, {labeled} flagged · {usage}% of today's budget used":
      "正在分拣消息：已分拣 {triaged} 条，标出 {labeled} 条 · 今日额度已用 {usage}%",
};
