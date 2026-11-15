// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.24.0-source.1 en.ts / zh-cn.ts wording verbatim: WP-AGENT (stop current turn, tool-stuck notice, runtime config applies when idle).
const Map<String, String> zhCatalogUpstream124AgentTurn = <String, String>{
  // agent.status.toolStuck
  "Stuck on {tool} · no output for {minutes} min{queued, plural, =0 {} one { · # message waiting} other { · # messages waiting}}": "卡在 {tool} 上 · {minutes} 分钟没有输出{queued, plural, =0 {} other { · # 条消息在等待}}",
  // agent.status.toolStuckHint
  "A command started by this agent has produced no output for a while. New messages wait until it ends or this turn is stopped.":
      "这个 Agent 运行的一个命令已经很久没有输出。新消息会一直等到命令结束，或者停止这一轮。",
  // agent.detail.stopTurn.restarted
  "To stop the turn, the agent was restarted. Its conversation context is kept.":
      "为了停止这一轮，Agent 被重启了，对话上下文都还在。",
  // agent.detail.stopTurn.upgradeRequired
  "Upgrade this agent's Computer to stop a single turn. You can stop the whole agent instead.":
      "升级这个 Agent 所在的 Computer，即可只停这一轮。也可以停止整个 Agent。",
  // agent.detail.stopTurn.computerOffline
  "This agent's Computer is offline.": "这个 Agent 所在的 Computer 离线了。",
  // agent.detail.runtimeConfigSavedTitle
  "{name}'s settings saved": "{name} 的设置已保存",
  // agent.detail.runtimeConfigAppliesWhenIdle
  "They apply when it's next idle.": "下次空闲时生效。",
  // agent.detail.runtimeConfigNewSessionWhenIdle
  "It starts a new session when it's next idle.": "下次空闲时开始新会话。",
  // agent.detail.runtimeConfigAppliesNextStart
  "They apply the next time it starts.": "下次启动时生效。",
  // agent.detail.restartNow
  "Restart now": "立即重启",
  // agent.detail.saveRuntimeChange
  "Save runtime change": "保存运行时变更",
};
