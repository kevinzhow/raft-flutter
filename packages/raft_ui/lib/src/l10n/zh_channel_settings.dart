// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
const Map<String, String> zhCatalogChannelSettings = <String, String>{
  // Channel / DM settings drawer (EditChannelDialog panel confirmations).
  'Members keep read access to "{name}" and its history, but posting will stop and the channel will be hidden from sidebars. You can unarchive it later.':
      '成员仍可阅读「{name}」及其历史记录，但将无法发送新消息，且该频道会从侧栏中隐藏。你之后可以取消归档。',
  'All server members will regain read access to "{name}". Existing joined humans and agents keep their joined state.':
      '所有服务器成员将恢复对「{name}」的读取权限。已加入的人类和 Agent 会保持加入状态。',
  'Existing joined humans and agents keep access to "{name}". Non-joined server members and historical thread followers will lose access to the channel and its threads.':
      '已加入的人类和 Agent 仍可访问「{name}」。未加入的服务器成员以及历史消息列关注者，将失去对该频道及其消息列的访问权限。',
  "You'll stop getting messages from #{name} and can't post there. You can rejoin any time. Threads you follow will still notify you until you unfollow them.":
      '你将不再收到 #{name} 的消息，也不能在里面发言，随时可以重新加入。你关注的消息列仍会通知你，直到你取消关注。',
  '"{name}" and all of its messages will be permanently deleted. This cannot be undone.':
      '「{name}」及其中的所有消息都会被永久删除，且无法撤销。',
  'Your members and agents will leave #{name}, and it will be removed from this server. The other servers keep the channel and its history.':
      '你的成员和 Agent 将离开 #{name}，这个频道也会从此服务器移除。其他服务器会保留这个频道及其历史记录。',
  '{label} is required': '请填写{label}',
  '{label} must be at least {min} characters': '{label}至少需要 {min} 个字符',
  '{label} must be at most {max} characters': '{label}最多 {max} 个字符',
  '{humans} humans · {agents} agents': '{humans} 位人类 · {agents} 个 Agent',
  '{humans} humans · {agents} agents · {slack} Slack':
      '{humans} 位人类 · {agents} 个 Agent · {slack} 位 Slack 成员',
};
