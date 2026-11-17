// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.24.0-source.1 en.ts / zh-cn.ts wording verbatim: WP-INBOX (Activity rows, scopes,
// empty states, swipe and row actions, saved messages notices:
// saved.*, thread.{contextMenu,empty,filter,header,row,loadFailed,newUpdates}.*). Keys another
// catalog file already declares with the same Chinese (thread.filter.pinned / saved,
// thread.row.swipeDone / swipeDoneUndo / swipeUnfollow / swipeMute / swipeRead / swipeUnread /
// markUnreadNothing, thread.loadFailedRetry, thread.unavailableNotice) are not repeated here.
const Map<String, String> zhCatalogUpstream124Inbox = <String, String>{
  // saved.historyHidden.banner
  "{count, plural, one {# more saved message is older than {days} days and isn't listed.} other {# more saved messages are older than {days} days and aren't listed.}}":
      "另有 {count, number} 条保存的消息超过了 {days} 天，没有列出。",
  // saved.historyHidden.bannerAll
  "{count, plural, =1 {Your saved message is older than {days} days.} other {All # of your saved messages are older than {days} days.}}":
      "{count, plural, =1 {你保存的这条消息超过了 {days} 天。} other {你保存的 # 条消息都超过了 {days} 天。}}",
  // saved.loadError
  "Couldn't load saved messages.": "无法加载已保存消息。",
  // thread.contextMenu.muteActivity
  "Mute Activity": "静音动态",
  // thread.contextMenu.unmuteActivity
  "Unmute Activity": "取消静音动态",
  // thread.empty.pinnedTitle
  "No pinned conversations": "没有置顶的会话",
  // thread.empty.pinnedDescription
  "Channels and DMs you pin in the sidebar show up here, with their threads.":
      "在侧栏置顶的频道和私信会显示在这里，连同它们的消息列。",
  // thread.empty.savedTitle
  "No saved threads": "没有已保存的消息列",
  // thread.empty.savedDescription
  "Save a message and its thread shows up here.": "保存一条消息后，它所在的消息列会显示在这里。",
  // thread.empty.artifactsTitle
  "No Artifacts here": "这里没有 Artifact",
  // thread.empty.artifactsDescription
  "Comment on an Artifact or follow it, and its new comments and versions show up here.":
      "评论或关注一个 Artifact 后，它的新评论和新版本会显示在这里。",
  // thread.filter.artifacts
  "Artifacts": "Artifacts",
  // thread.filter.button
  "Filter": "筛选",
  // thread.filter.clear
  "Clear filter": "清除筛选",
  // thread.row.markRowAsDone
  "Mark {conversation} as Done": "将 {conversation} 标记为完成",
  // thread.row.markThreadAsDone
  "Mark the thread in {conversation} as Done": "将 {conversation} 中的消息列标记为完成",
  // thread.row.savedThreadTitle
  "Thread in {conversation}": "{conversation} 中的消息列",
  // thread.row.swipeDoneToast
  "Marked as done": "已标记为完成",
  // thread.row.swipeUnfollowedToast
  "Unfollowed thread in {conversation}": "已取消关注 {conversation} 中的消息列",
  // thread.row.swipeMutedToast
  "Muted activity in {conversation}": "已静音 {conversation} 的动态",
  // thread.row.markReadFailed
  "Couldn't mark it as read. Try again.": "标为已读失败，请重试。",
  // thread.row.markUnreadFailed
  "Couldn't mark it as unread. Try again.": "标为未读失败，请重试。",
  // thread.loadFailed
  "Couldn't load Activity.": "动态加载失败。",
  // thread.header.subtitle (the counts line; the first form carries the mono markup)
  "<mono>{activeCount}</mono> in progress · <mono>{unreadCount}</mono> unread":
      "<mono>{activeCount}</mono> 条进行中 · <mono>{unreadCount}</mono> 条未读",
  "{activeCount} in progress · {unreadCount} unread":
      "{activeCount} 条进行中 · {unreadCount} 条未读",
  // thread.newUpdates (ICU plural split into its two forms, like the other counted keys)
  "{count} new update": "{count} 条新更新",
  "{count} new updates": "{count} 条新更新",
};
