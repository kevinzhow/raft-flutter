// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.24.0-source.1 en.ts / zh-cn.ts wording verbatim: WP-INBOX Activity rows
// (activity.list.time.*, activity.list.taskFallbackTitle, activity.list.objectHome,
// message.delegated.previewSender*, agent.appBadge*, artifacts.dashboard.newVersions).
// Keys another catalog file declares with the same Chinese are not repeated here.
const Map<String, String> zhCatalogUpstream124InboxRow = <String, String>{
  // activity.list.time.now
  "now": "刚刚",
  // activity.list.time.yesterdayAt
  "yesterday at {time}": "昨天 {time}",
  // activity.list.time.dayAt
  "{day} at {time}": "{day} {time}",
  // The time in words (Intl.RelativeTimeFormat "minute" / "hour", numeric always).
  "{count, plural, one {# minute ago} other {# minutes ago}}":
      "{count, plural, other {# 分钟前}}",
  "{count, plural, one {# hour ago} other {# hours ago}}":
      "{count, plural, other {# 小时前}}",
  // activity.list.taskFallbackTitle
  "{channel} task": "{channel} 的任务",
  // activity.list.objectHome
  "· {home}": "· {home}",
  // message.delegated.previewSender
  "{sender} (sent by {name})": "{sender}（由 {name} 代发）",
  // message.delegated.previewSenderDeleted
  "{sender} (sent by a deleted assistant)": "{sender}（由已删除的助理代发）",
  // agent.appBadgeWithApp
  "App · {app}": "应用 · {app}",
  // agent.appBadgeTooltip
  "Created by the {app} app": "由 {app} 应用创建",
  // artifacts.dashboard.newVersions
  "{count, plural, one {# new version} other {# new versions}}":
      "{count} 个新版本",
};
