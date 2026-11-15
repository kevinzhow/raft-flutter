// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.24.0-source.1 en.ts / zh-cn.ts wording verbatim: WP-AGENT PR 2 (Activity overview, operator events, quiet failures, Now card).
const Map<String, String> zhCatalogUpstream124AgentActivity = <String, String>{
  // activity.overview.turn.runningFor
  "running for {duration}": "已进行 {duration}",
  // activity.overview.turn.triggerAndRunningFor
  "{trigger} · running for {duration}": "{trigger} · 已进行 {duration}",
  // activity.overview.trigger.appEventFrom
  "handling a notification from {app}: {summary}": "处理 {app} 的通知：{summary}",
  // activity.overview.trigger.unresolved
  "woken by a message": "被一条消息叫醒",
  // activity.overview.outcome.noMessage
  "No message sent": "未发消息",
  // activity.overview.retries.usageLimitUntil
  "Usage limit reached · resets {reset} · {count, plural, one {# attempt} other {# attempts}}":
      "额度已用完 · {reset} 恢复 · 共尝试 {count} 次",
  // activity.overview.retries.usageLimit
  "Usage limit reached · {count, plural, one {# attempt} other {# attempts}}":
      "额度已用完 · 共尝试 {count} 次",
  // activity.overview.retries.failed
  "{count} turns in a row ended with an error, with no tools used and no message sent":
      "连续 {count} 轮出错结束，都没调用工具，也没发消息",
  // activity.overview.retries.show
  "Show each turn": "展开每一轮",
  // activity.overview.retries.hide
  "Hide turns": "收起",
  // activity.overview.trigger.open
  "Open message": "打开消息",
  // activity.overview.sent.more
  "Show {count} more": "还有 {count} 条",
  // activity.overview.sent.hidden
  "{count, plural, one {# more in a conversation you can't see} other {# more in conversations you can't see}}":
      "另有 {count} 条发在你看不到的地方",
  // activity.overview.sent.unlisted
  "{count, plural, one {# more not listed} other {# more not listed}}":
      "另有 {count} 条未列出",
  // activity.overview.appEvents.title
  "{count, plural, one {Received # app notification} other {Received # app notifications}}":
      "这一轮收到 {count} 条应用通知",
  // activity.overview.output.label
  "Agent's output (not sent)": "Agent 的输出（未发送）",
  // activity.overview.newTurn
  "New turn ↓": "有新的一轮 ↓",
  // activity.overview.operator.start
  "{actor} started the agent": "{actor} 启动了 Agent",
  // activity.overview.operator.stop
  "{actor} stopped the agent": "{actor} 停止了 Agent",
  // activity.overview.operator.restart
  "{actor} restarted the agent": "{actor} 重启了 Agent",
  // activity.overview.operator.resetSession
  "{actor} reset the session and restarted": "{actor} 重置了会话并重启",
  // activity.overview.operator.resetFull
  "{actor} reset the agent, workspace included": "{actor} 完全重置了 Agent（包括工作区）",
  // activity.overview.operator.turnStopped
  "{actor} stopped the current turn": "{actor} 停止了当前这一轮",
  // activity.overview.operator.migrationStartedTo
  "{actor} started moving the agent from {from} to {to}":
      "{actor} 开始把 Agent 从 {from} 迁移到 {to}",
  // activity.overview.operator.migrationStarted
  "{actor} started moving the agent to another computer":
      "{actor} 开始把 Agent 迁移到另一台计算机",
  // activity.overview.operator.migrationCancelled
  "{actor} cancelled the move": "{actor} 取消了迁移",
  // activity.overview.operator.modelChanged
  "{actor} changed the model: {before} → {after}":
      "{actor} 改了模型：{before} → {after}",
  // activity.overview.operator.runtimeChanged
  "{actor} changed the runtime: {before} → {after}":
      "{actor} 改了运行时：{before} → {after}",
  // activity.overview.operator.configChanged
  "{actor} changed the agent's settings": "{actor} 改了 Agent 的设置",
  // activity.overview.operator.systemRestart
  "Raft restarted the agent after failed starts": "启动失败后，Raft 自动重启了 Agent",
  // activity.overview.operator.folded
  "{count} actions · latest: {latest}": "{count} 次操作 · 最近：{latest}",
  // agent.now.workingFor
  "{state} · for {duration}": "{state} · 已持续 {duration}",
  // agent.now.lastEnded
  "{state} · last turn ended {time}": "{state} · 上一轮 {time} 结束",
  // agent.now.thisTurn
  "{trigger} · {actions}": "{trigger} · 这一轮{actions}",
  // agent.now.lastTurn
  "Last turn: {trigger} · {actions}": "上一轮：{trigger} · {actions}",
  // agent.now.trigger.inChannel
  "{sender} · #{channel}": "{sender} · #{channel}",
  // agent.now.trigger.dm
  "DM from {sender}": "{sender} 的私信",
  // agent.now.trigger.private
  "a private channel": "一个私有频道",
  // agent.now.trigger.someDm
  "a DM": "一条私信",
  // agent.now.trigger.unknown
  "a message": "一条消息",
};
