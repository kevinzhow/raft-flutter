// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.21.23-source.1 zh-cn.ts wording verbatim for the Activity overview messages that carry ICU plural
// arms. The key is the English ICU message and the value the zh-cn one: the Activity overview expands the plural
// arms itself (features/icu_message.dart), exactly as Web's formatMessage does.
const Map<String, String> zhCatalogW23Agent = <String, String>{
  "{turns, plural, one {# turn} other {# turns}} below · {steps, plural, one {# step} other {# steps}} · {problems, plural, =0 {nothing went wrong} one {# step went wrong} other {# steps went wrong}}":
      "下面共 {turns} 轮 · {steps} 步 · {problems, plural, =0 {都很顺利} other {# 步不顺}}",
  "Done, {count, plural, one {# step} other {# steps}} went wrong":
      "完成，中途有 {count} 步不顺",
  "ran {count, plural, one {a command} other {# commands}}": "跑了 {count} 条命令",
  "read {count, plural, one {a file} other {files # times}}": "看了 {count} 次文件",
  "edited {count, plural, one {a file} other {files # times}}":
      "改了 {count} 次文件",
  "searched {count, plural, one {once} other {# times}}": "搜了 {count} 次代码",
  "searched the web {count, plural, one {once} other {# times}}":
      "查了 {count} 次网页",
  "opened {count, plural, one {a web page} other {# web pages}}":
      "打开了 {count} 个网页",
  "started {count, plural, one {a subagent} other {# subagents}}":
      "派了 {count} 个子 agent",
  "used {count, plural, one {an MCP tool} other {MCP tools # times}}":
      "用了 {count} 次 MCP 工具",
  "waited {count, plural, one {once} other {# times}}": "等了 {count} 次",
  "used {count, plural, one {a tool} other {tools # times}}":
      "用了 {count} 次其他工具",
  "sent {count, plural, one {a message} other {# messages}}": "发了 {count} 条消息",
  "read messages {count, plural, one {once} other {# times}}": "看了 {count} 次消息",
  "made {count, plural, one {a Raft change} other {# Raft changes}}":
      "做了 {count} 次 Raft 操作",
  "used git {count, plural, one {once} other {# times}}": "用了 {count} 次 git 命令",
  "ran tests or checks {count, plural, one {once} other {# times}}":
      "跑了 {count} 次测试或检查",
  "and {count, plural, one {# more} other {# more}}": "还有 {count} 步",
  "· {count, plural, one {# message} other {# messages}} sent this turn":
      "· 这一轮共发了 {count} 条",
};
