// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// RaftBench (Web v1.21.23-source.1): `raftbench.*`, message.chatPanel.raftbenchServiceDm and the
// cloud-agent spend / USD notes the overview shows, zh-cn.ts wording verbatim. ICU `{n, number}`
// is written `{n}` (raftText does not interpret ICU).
const Map<String, String> zhCatalogRaftbench = <String, String>{
  // raftbench.aiAvailableHistoryHelp
  "The selected channels contain {count} messages across all history. Start with the newest message's UTC date to see a smaller slice. Restarting replaces current findings and may still require multiple model calls.": "所选频道全部历史共有 {count} 条消息。先从最新消息所在的 UTC 日期开始，查看较小范围。重新分析会替换当前发现，仍可能产生多次模型调用。",
  // raftbench.aiBatchProgress
  "This batch has read {count} messages. The background scan continues in further batches.":
      "本批已读取 {count} 条消息。后台扫描会继续处理后续批次。",
  // raftbench.aiBatchReadCount
  "This batch: {count} messages read": "本批已读取 {count} 条消息",
  // raftbench.aiCoverageCounts
  "Selected channels: {total} messages total; {count} in the analysis range.":
      "所选频道共有 {total} 条消息，分析范围内有 {count} 条。",
  // raftbench.aiCumulativeRead
  "Read {count} of {total} messages · {batches} batches accepted":
      "累计已读 {count} / {total} 条消息 · 已处理 {batches} 批",
  // raftbench.aiCumulativeUnknown
  "Read {count} messages · {batches} batches accepted":
      "累计已读 {count} 条消息 · 已处理 {batches} 批",
};
