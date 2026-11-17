// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.24.0-source.1 en.ts / zh-cn.ts wording verbatim: WP-BILL limit notices (upgradeDialog.* title and
// hint of the history / uploadQuota / fileSize / externalLimit / general gates, message.composer.notAttached.*).
// ICU plurals are split per form (count one/other x agentTries 0/one/other for the history hints), `#` is
// the named placeholder. `Not checked` (message.composer.notAttached.unchecked, 无法检查) collides with the
// Linux dependency probe's '尚未检测', so its call site passes the Web Chinese through raftTextZh.
const Map<String, String> zhCatalogUpstream124BillLimits = <String, String>{
  "See your whole chat history": "查看全部聊天记录",
  "On Free, you and your agents can only read the last {days} days of messages, while on Pro all of {server}'s history can be read and searched.":
      "免费版下你和你的 Agent 只能读到最近 {days} 天的消息，升级到 Pro 就能查看和搜索 {server} 的全部历史。",
  "This month's uploads are used up": "本月的上传额度已用完",
  "Not enough uploads left this month": "本月上传额度不够了",
  "Free uploads up to {monthly} a month. Pro has no monthly limit.":
      "免费版每月可上传 {monthly}。升级到 Pro，没有每月上限。",
  "{server} has used this month's {monthly} of uploads; it resets on {date}. Pro has no monthly limit.":
      "{server} 本月 {monthly} 的上传额度已用完，{date} 重置。升级到 Pro，没有每月上限。",
  "{file} is {size}, and {server} has {remaining} left of this month's {monthly} of uploads; it resets on {date}. Pro has no monthly limit.": "{file} 有 {size}，但 {server} 本月 {monthly} 的上传额度只剩 {remaining}，{date} 重置。升级到 Pro，没有每月上限。",
  "{server} has {remaining} left of this month's {monthly} of uploads, not enough for these {count} files; it resets on {date}. Pro has no monthly limit.": "{server} 本月 {monthly} 的上传额度只剩 {remaining}，放不下这 {count} 个文件，{date} 重置。升级到 Pro，没有每月上限。",
  "Upload larger files": "上传更大的文件",
  "Free uploads files up to {single} each. On Pro, a file can be up to {proSingle}.":
      "免费版单个文件最大 {single}。升级到 Pro，单个文件可以到 {proSingle}。",
  "{file} is {size}. Free uploads files up to {single} each; on Pro, a file can be up to {proSingle}.":
      "{file} 有 {size}。免费版单个文件最大 {single}，升级到 Pro 可以到 {proSingle}。",
  "{count} files are over {single}. Free uploads files up to {single} each; on Pro, a file can be up to {proSingle}.":
      "有 {count} 个文件超过 {single}。免费版单个文件最大 {single}，升级到 Pro 可以到 {proSingle}。",
  "Upgrade {server} to Pro": "将 {server} 升级到 Pro",
  "Pro lifts the Free limits on chat history, file uploads and Joint Channels.":
      "升级到 Pro，免费版在聊天记录、文件上传和联合频道上的限制都会解除。",
  "Share more channels outside {server}": "与 {server} 之外的人共享更多频道",
  "Free includes 1 external channel, and {server} already has one. On Pro, {server} can share as many as it needs.":
      "免费版包含 1 个外部频道，{server} 已经有一个了。升级到 Pro 后，{server} 需要多少就能共享多少。",
  "Free includes 1 external channel, and {server}'s is {channel}. On Pro, {server} can share as many as it needs.": "免费版包含 1 个外部频道，{server} 的这个名额已用于 {channel}。升级到 Pro 后，{server} 需要多少就能共享多少。",
  "Free includes 1 external channel, and {server} has an open invite to {channel}. On Pro, {server} can share as many as it needs.": "免费版包含 1 个外部频道，{server} 有一个加入 {channel} 的邀请还没被接受。升级到 Pro 后，{server} 需要多少就能共享多少。",
  "Connect {server} to {channel}": "将 {server} 连接到 {channel}",
  "{server}'s Free plan allows 1 external channel. Pro has no limit.":
      "{server} 的免费版只能有 1 个外部频道。Pro 不限数量。",
  "Too large": "文件太大",
  "Too many": "超出数量",
  "Empty": "空文件",
  "Remove files that can't be attached": "先移除无法添加的文件",
  "It's {size}. Files can be up to {limit} each. Share a link instead.":
      "文件大小为 {size}。单个文件最大 {limit}。可以改为分享链接。",
  "It's {size}. Free uploads files up to {limit} each, and Pro up to {proLimit}. Share a link instead.":
      "文件大小为 {size}。免费版单个文件最大 {limit}，Pro 最大 {proLimit}。可以改为分享链接。",
  "A message can have up to {max} attachments.": "每条消息最多 {max} 个附件。",
  "Empty files can't be attached.": "空文件无法添加。",
  "{channel} has {count} message older than {days} days that you and your agents can't read on Free.":
      "{channel} 有 {count} 条超过 {days} 天的消息，免费版下你和你的 Agent 都读不到。",
  "{channel} has {count} message older than {days} days that you and your agents can't read on Free, and your agents ran into this once in the past 7 days.": "{channel} 有 {count} 条超过 {days} 天的消息，免费版下你和你的 Agent 都读不到，过去 7 天你的 Agent 已经有 {agentTries} 次想读没读到。",
  "{channel} has {count} message older than {days} days that you and your agents can't read on Free, and your agents ran into this {agentTries} times in the past 7 days.": "{channel} 有 {count} 条超过 {days} 天的消息，免费版下你和你的 Agent 都读不到，过去 7 天你的 Agent 已经有 {agentTries} 次想读没读到。",
  "{channel} has {count} messages older than {days} days that you and your agents can't read on Free.":
      "{channel} 有 {count} 条超过 {days} 天的消息，免费版下你和你的 Agent 都读不到。",
  "{channel} has {count} messages older than {days} days that you and your agents can't read on Free, and your agents ran into this once in the past 7 days.": "{channel} 有 {count} 条超过 {days} 天的消息，免费版下你和你的 Agent 都读不到，过去 7 天你的 Agent 已经有 {agentTries} 次想读没读到。",
  "{channel} has {count} messages older than {days} days that you and your agents can't read on Free, and your agents ran into this {agentTries} times in the past 7 days.": "{channel} 有 {count} 条超过 {days} 天的消息，免费版下你和你的 Agent 都读不到，过去 7 天你的 Agent 已经有 {agentTries} 次想读没读到。",
  "{channel} has over {count} messages older than {days} days that you and your agents can't read on Free.":
      "{channel} 有 {count} 多条超过 {days} 天的消息，免费版下你和你的 Agent 都读不到。",
  "{channel} has over {count} messages older than {days} days that you and your agents can't read on Free, and your agents ran into this once in the past 7 days.": "{channel} 有 {count} 多条超过 {days} 天的消息，免费版下你和你的 Agent 都读不到，过去 7 天你的 Agent 已经有 {agentTries} 次想读没读到。",
  "{channel} has over {count} messages older than {days} days that you and your agents can't read on Free, and your agents ran into this {agentTries} times in the past 7 days.": "{channel} 有 {count} 多条超过 {days} 天的消息，免费版下你和你的 Agent 都读不到，过去 7 天你的 Agent 已经有 {agentTries} 次想读没读到。",
  "This thread has {count} reply older than {days} days that you and your agents can't read on Free.":
      "这个消息列有 {count} 条超过 {days} 天的回复，免费版下你和你的 Agent 都读不到。",
  "This thread has {count} reply older than {days} days that you and your agents can't read on Free, and your agents ran into this once in the past 7 days.": "这个消息列有 {count} 条超过 {days} 天的回复，免费版下你和你的 Agent 都读不到，过去 7 天你的 Agent 已经有 {agentTries} 次想读没读到。",
  "This thread has {count} reply older than {days} days that you and your agents can't read on Free, and your agents ran into this {agentTries} times in the past 7 days.": "这个消息列有 {count} 条超过 {days} 天的回复，免费版下你和你的 Agent 都读不到，过去 7 天你的 Agent 已经有 {agentTries} 次想读没读到。",
  "This thread has {count} replies older than {days} days that you and your agents can't read on Free.":
      "这个消息列有 {count} 条超过 {days} 天的回复，免费版下你和你的 Agent 都读不到。",
  "This thread has {count} replies older than {days} days that you and your agents can't read on Free, and your agents ran into this once in the past 7 days.": "这个消息列有 {count} 条超过 {days} 天的回复，免费版下你和你的 Agent 都读不到，过去 7 天你的 Agent 已经有 {agentTries} 次想读没读到。",
  "This thread has {count} replies older than {days} days that you and your agents can't read on Free, and your agents ran into this {agentTries} times in the past 7 days.": "这个消息列有 {count} 条超过 {days} 天的回复，免费版下你和你的 Agent 都读不到，过去 7 天你的 Agent 已经有 {agentTries} 次想读没读到。",
  "This thread has over {count} replies older than {days} days that you and your agents can't read on Free.":
      "这个消息列有 {count} 多条超过 {days} 天的回复，免费版下你和你的 Agent 都读不到。",
  "This thread has over {count} replies older than {days} days that you and your agents can't read on Free, and your agents ran into this once in the past 7 days.": "这个消息列有 {count} 多条超过 {days} 天的回复，免费版下你和你的 Agent 都读不到，过去 7 天你的 Agent 已经有 {agentTries} 次想读没读到。",
  "This thread has over {count} replies older than {days} days that you and your agents can't read on Free, and your agents ran into this {agentTries} times in the past 7 days.": "这个消息列有 {count} 多条超过 {days} 天的回复，免费版下你和你的 Agent 都读不到，过去 7 天你的 Agent 已经有 {agentTries} 次想读没读到。",
  "This conversation has {count} message older than {days} days that you and your agents can't read on Free.":
      "这段对话有 {count} 条超过 {days} 天的消息，免费版下你和你的 Agent 都读不到。",
  "This conversation has {count} message older than {days} days that you and your agents can't read on Free, and your agents ran into this once in the past 7 days.": "这段对话有 {count} 条超过 {days} 天的消息，免费版下你和你的 Agent 都读不到，过去 7 天你的 Agent 已经有 {agentTries} 次想读没读到。",
  "This conversation has {count} message older than {days} days that you and your agents can't read on Free, and your agents ran into this {agentTries} times in the past 7 days.": "这段对话有 {count} 条超过 {days} 天的消息，免费版下你和你的 Agent 都读不到，过去 7 天你的 Agent 已经有 {agentTries} 次想读没读到。",
  "This conversation has {count} messages older than {days} days that you and your agents can't read on Free.":
      "这段对话有 {count} 条超过 {days} 天的消息，免费版下你和你的 Agent 都读不到。",
  "This conversation has {count} messages older than {days} days that you and your agents can't read on Free, and your agents ran into this once in the past 7 days.": "这段对话有 {count} 条超过 {days} 天的消息，免费版下你和你的 Agent 都读不到，过去 7 天你的 Agent 已经有 {agentTries} 次想读没读到。",
  "This conversation has {count} messages older than {days} days that you and your agents can't read on Free, and your agents ran into this {agentTries} times in the past 7 days.": "这段对话有 {count} 条超过 {days} 天的消息，免费版下你和你的 Agent 都读不到，过去 7 天你的 Agent 已经有 {agentTries} 次想读没读到。",
  "This conversation has over {count} messages older than {days} days that you and your agents can't read on Free.":
      "这段对话有 {count} 多条超过 {days} 天的消息，免费版下你和你的 Agent 都读不到。",
  "This conversation has over {count} messages older than {days} days that you and your agents can't read on Free, and your agents ran into this once in the past 7 days.": "这段对话有 {count} 多条超过 {days} 天的消息，免费版下你和你的 Agent 都读不到，过去 7 天你的 Agent 已经有 {agentTries} 次想读没读到。",
  "This conversation has over {count} messages older than {days} days that you and your agents can't read on Free, and your agents ran into this {agentTries} times in the past 7 days.": "这段对话有 {count} 多条超过 {days} 天的消息，免费版下你和你的 Agent 都读不到，过去 7 天你的 Agent 已经有 {agentTries} 次想读没读到。",
  "The message you opened was sent on {date}, more than {days} days ago, so you and your agents can't read it on Free.":
      "你打开的这条消息发于 {date}，已超过 {days} 天，免费版下你和你的 Agent 都读不到。",
  "The message you opened was sent on {date}, more than {days} days ago, so you and your agents can't read it on Free, and your agents ran into this once in the past 7 days.": "你打开的这条消息发于 {date}，已超过 {days} 天，免费版下你和你的 Agent 都读不到，过去 7 天你的 Agent 已经有 {agentTries} 次想读没读到。",
  "The message you opened was sent on {date}, more than {days} days ago, so you and your agents can't read it on Free, and your agents ran into this {agentTries} times in the past 7 days.": "你打开的这条消息发于 {date}，已超过 {days} 天，免费版下你和你的 Agent 都读不到，过去 7 天你的 Agent 已经有 {agentTries} 次想读没读到。",
  "{server} · {name} couldn't join": "{server} · {name} 没能加入",
  "Upgrade needed for {name} to join": "需要升级，{name} 才能加入",
  "Ask an owner": "找所有者加席位",
};
