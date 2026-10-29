import 'package:flutter/widgets.dart';

import 'l10n/zh_index.g.dart' show zhCatalogAll;

// Plain-text catalog derived from pinned Web en/zh-cn catalogs (26f77ef),
// plus native UI entries. ICU messages are not interpreted by this helper.
// English is the stable source key. User-provided text is never translated.
//
// WHERE NEW STRINGS GO: the Chinese catalog is not edited here. It lives in
// l10n/zh_<feature>.dart files, each a public top-level
// `const Map<String, String> zhCatalog<Feature> = {...}` (English source ->
// Chinese, Web zh-cn.ts wording verbatim). Add your strings as a NEW file named
// after your feature; tool/gen_l10n_index.py (run by tool/flutter) merges every
// l10n/zh_*.dart into the git-ignored l10n/zh_index.g.dart, so no shared file is
// edited and parallel branches do not conflict. A key may live in only one file
// (packages/raft_ui/test/zh_catalog_files_test.dart fails on duplicates). The
// l10n/zh_web_catalog_*.dart files keep the historical Web-catalog order and are
// not a place to add.
//
// Merging a branch that still appended to the old single `raftChinese` map: git
// conflicts here (or inside this file's old tail). Take the added `"English":
// "中文",` lines out of the conflict and put them into l10n/zh_<your feature>.dart
// (a fresh file, same const-map shape), leave this file as it is. The few entries
// in [raftChineseLateAdditions] below are the former tail of the map; appending
// right after them still merges cleanly, but move such lines into a feature file.
String raftText(BuildContext context, String source) {
  if (Localizations.maybeLocaleOf(context)?.languageCode != 'zh') return source;
  return raftChinese[source] ?? source;
}

/// Fixed UI copy whose Chinese differs per Web catalog key although the English
/// source collides (for example `Unassigned`: the task property says 未指派,
/// the board filter 未分配, the history detail 取消指派). The call site names
/// the Web key's Chinese; non-Chinese locales show [source].
String raftTextZh(BuildContext context, String source, String zh) =>
    Localizations.maybeLocaleOf(context)?.languageCode == 'zh' ? zh : source;

/// Localizes fixed UI copy before inserting untouched user-provided values.
String raftFormat(
  BuildContext context,
  String source,
  Map<String, Object?> values,
) {
  return raftText(context, source).replaceAllMapped(
    RegExp(r'\{([a-zA-Z0-9_]+)\}'),
    (match) =>
        values.containsKey(match[1]) ? '${values[match[1]] ?? ''}' : match[0]!,
  );
}

/// Localized rich text: [source] is a catalog key carrying `<tag>inner</tag>`
/// markup (the Web catalog's own rich-message form). [tags] builds the span for
/// each tag; plain text and unknown tags become plain [TextSpan]s. `{name}`
/// placeholders are filled from [values] first.
List<InlineSpan> raftRichText(
  BuildContext context,
  String source,
  Map<String, InlineSpan Function(String inner)> tags, {
  Map<String, Object?> values = const {},
}) {
  final text = raftFormat(context, source, values);
  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final m in RegExp(r'<(\w+)>(.*?)</\1>').allMatches(text)) {
    if (m.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, m.start)));
    }
    final build = tags[m[1]];
    spans.add(build == null ? TextSpan(text: m[2]) : build(m[2]!));
    cursor = m.end;
  }
  if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
  return spans;
}

/// Every Chinese catalog entry: the l10n/zh_*.dart files plus [raftChineseLateAdditions].
const raftChinese = <String, String>{
  ...zhCatalogAll,
  ...raftChineseLateAdditions,
};

/// Former tail of the single catalog map. Keys here must not repeat in a
/// l10n/zh_*.dart catalog (zh_catalog_files_test.dart).
const raftChineseLateAdditions = <String, String>{
  "Show": "显示",
  "Hide": "隐藏",
  "Share": "分享",
  "Discard your changes?": "放弃更改？",
  "Loading Activity": "正在加载动态…",
  // Added with the members new-pages port (Web catalog).
  // agent.detail.switchModelResetMessage (ICU select: without / with reasoning).
  "This will switch the runtime from {from} to {to} and reset the active runtime session.":
      "这会将运行时从 {from} 切换到 {to}，并重置当前运行时会话。",
  "This will switch the runtime from {from} to {to}.":
      "这会将运行时从 {from} 切换到 {to}。",
  "{model} (not in this computer's config)": "{model}（不在此计算机的配置中）",
  "Switching to {model} resets the current runtime session.":
      "切换到 {model} 会重置当前运行时会话。",
  "Switching to {model} ({reasoning} reasoning) resets the current runtime session.":
      "切换到 {model}（{reasoning} 推理）会重置当前运行时会话。",
  "Apply {changes} and restart this agent now?": "应用 {changes} 并立即重启此 Agent？",
  "Value for {name}": "{name} 的值",
  // Added with the members new-pages port (Web catalog).
  // settings.memberGraph.nodeLinks (ICU plural: one / other).
  "{count} link": "{count} 个连接",
  "{count} links": "{count} 个连接",
  "{count, plural, one {# link} other {# links}}":
      "{count, plural, other {# 个连接}}",
  // Added with the members new-pages port (Web catalog).
  "External · Last active {time}": "外部 · 上次活跃 {time}",
  // Added with the members new-pages port (Web catalog).
  "Step {step}": "第 {step} 步",
  "Select Raft, enter profile slug {slug}, and keep RAFT_EXPECTED_AGENT_ID={agentId} in the gateway environment when you restart or reload it. The bridge sends nothing if the profile resolves to another Agent.": "选择 Raft，输入 profile slug {slug}，并在重启或重新加载 gateway 时保留 RAFT_EXPECTED_AGENT_ID={agentId}。如果 profile 解析到其他 Agent，bridge 不会发送任何请求。",
  "Run RAFT_PROFILE={slug} raft manual get raft-cli-overview to review the operating guide after setup.":
      "运行 RAFT_PROFILE={slug} raft manual get raft-cli-overview 以在设置后查看操作指南。",
  "Last used {time}": "上次使用 {time}",
  "Created {date}": "创建于 {date}",
  // Added with the members new-pages port (Web catalog).
  "Issue report for {name}": "针对 {name} 的问题报告",
  "HTTP {status}: {detail}": "HTTP {status}：{detail}",
  // Settings copy aligned with the Web catalog (Web sentence-case wording).
  "Cancel subscription": "取消订阅",
  "Confirm Pro Checkout": "确认 Pro 结账",
  "Confirm Seat Update": "确认席位更新",
  "Delete connection": "删除连接",
  "Make public": "设为公开",
  "Uninstall {name}?": "卸载 {name}？",
  "Upload image": "上传图片",
  "Test connection": "测试连接",
  "Delete {name}? This removes it from every Agent runtime and usage view.":
      "删除 {name}？这会将它从所有 Agent 运行时和使用记录视图中移除。",
};
