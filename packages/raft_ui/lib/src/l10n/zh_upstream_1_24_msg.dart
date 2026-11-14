// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.24.0-source.1 en.ts / zh-cn.ts wording verbatim: WP-MSG (message rows).
const Map<String, String> zhCatalogUpstream124Msg = <String, String>{
  // Hover toolbar (message.messageItem.quickReaction.*; moreActions is in
  // zh_upstream_1_24_pin.dart).
  "Like": "点赞",
  "Remove like": "取消点赞",
  "Remove {emoji}": "取消 {emoji}",
  "{action} · hover for more reactions": "{action} · 悬停选择其他表情",
  // Agent typing line (message.agentTyping.typing.*). The Web "many" form
  // counts every agent in Chinese, the others past two in English: the
  // caller passes the whole count as {others} in Chinese.
  "{first} is typing…": "{first} 正在输入…",
  "{first} and {second} are typing…": "{first} 和 {second} 正在输入…",
  "{first}, {second} and {third} are typing…":
      "{first}、{second} 和 {third} 正在输入…",
  "{first}, {second} and {others} other agent are typing…":
      "{first}、{second} 等 {others} 个 Agent 正在输入…",
  "{first}, {second} and {others} other agents are typing…":
      "{first}、{second} 等 {others} 个 Agent 正在输入…",
  // RFC 077 delegated messages (message.delegated.*).
  "sent by {name}": "由 {name} 代发",
  "(sent by {name})": "（由 {name} 代发）",
  "sent by a deleted assistant": "由已删除的助理代发",
  "(sent by a deleted assistant)": "（由已删除的助理代发）",
  "This message was retracted.": "这条消息已撤回。",
  // External identities (message.externalIdentity.*, message.author.*).
  "App": "应用",
  "{provider} · {kind}": "{provider} · {kind}",
  "Posted as {name}": "以 {name} 名义发送",
  "Slack user {id}": "Slack 用户 {id}",
  // Card messages (message.messageCard.updated).
  "Updated {time}": "更新于 {time}",
  // Typing line in a channel (message.agentTyping.workingHere, typingAndOthers,
  // typingRow).
  "{count} agent working here": "{count} 个 Agent 正在这里工作",
  "{count} agents working here": "{count} 个 Agent 正在这里工作",
  "{typing} · {others} other working": "{typing} · 另外 {others} 个在工作",
  "{typing} · {others} others working": "{typing} · 另外 {others} 个在工作",
  "Typing…": "正在输入…",
  // Forwarded bundles (message.forwardedBundle.fromTask).
  "from {target} · {title}": "来自 {target} · {title}",
  // Mention hover activity (activity.log.freshnessHold.*).
  "Reading new messages before sending": "发送前先读新消息",
  "Reading new messages before claiming the task": "认领任务前先读新消息",
  "Reading new messages before changing the task": "修改任务前先读新消息",
  "Reading new messages before updating the task": "更新任务前先读新消息",
};
