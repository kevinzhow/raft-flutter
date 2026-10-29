// Native account-wide message history settings.
const Map<String, String> zhCatalogMessageHistory = <String, String>{
  'Local changes could not be saved on this device.': '本地更改无法保存到此设备。',
  'Local history changed while loading. Try again.': '加载期间本地历史记录已变化，请重试。',
  'Message history could not be synced.': '无法同步消息历史记录。',
  'Copy diagnostics': '复制诊断信息',
  'Diagnostics copied': '诊断信息已复制',
  'Could not copy diagnostics. Try again.': '无法复制诊断信息，请重试。',
  'Local error diagnostics': '本地错误诊断',
  'Copy app version, foreground/background state and any storage errors recorded in this app run. Excludes messages, credentials and server addresses.':
      '复制 App 版本、前后台状态及本次运行记录的存储错误（如有），不含消息、凭据或服务器地址。',
  'No storage errors recorded in this app run. Copy app version and foreground/background state; excludes messages, credentials and server addresses.':
      '本次运行尚未记录到存储错误。可复制 App 版本和前后台状态，不含消息、凭据或服务器地址。',
  'Copy recent storage errors from this app run for a bug report. Includes app version and foreground/background state; excludes messages, credentials and server addresses.':
      '复制本次运行的近期存储错误以便反馈问题。包含 App 版本和前后台状态，不含消息、凭据或服务器地址。',
  'Unable to load messages.': '无法加载消息。',
  'Sign in to load messages.': '请登录后加载消息。',
  'You do not have permission to load these messages.': '你没有权限加载这些消息。',
  "Storage limit reached. New messages are not being saved offline; existing messages and drafts are kept.":
      "已超出，新消息暂不离线保存；已有消息和草稿仍保留。",
  "Messages will fill in automatically when connected.": "联网后自动补齐消息。",
  "Loading missing messages…": "正在补齐消息…",
  "Device message storage is full. Increase the message history limit in Storage settings.":
      "此设备的消息存储已满。请在存储设置中提高历史消息容量。",
  "Storage estimate unavailable": "暂时无法估算存储占用",
  "Messages are managed automatically across this account. Recently opened and important conversations stay available offline. Attachments and previews use the separate cache below.":
      "此账号的消息会自动管理。近期打开和重要会话保留在本机，可离线查看。附件和预览使用下方独立缓存。",
  "Older unused messages are removed first. Conversations opened in the last seven days, pinned conversations, drafts, uploads, unread messages, mentions and open windows are protected, even when they exceed this limit.":
      "优先移除较早且未使用的消息。最近七天打开过、已置顶、有草稿或上传、有未读或提及，以及窗口中打开的会话都会保留，即使超过此容量。",
  "Protected conversations exceed the selected limit. They stay available offline; only older unused messages are removed.":
      "受保护会话已超过所选容量，仍会保留供离线查看；仅移除较早且未使用的消息。",
  "Older unused messages may be removed and need a connection to open again. Conversations opened in the last seven days, pinned conversations, drafts, uploads, unread messages, mentions and open windows are protected.":
      "较早且未使用的消息可能被移除，再次打开需要网络连接。最近七天打开过、已置顶、有草稿或上传、有未读或提及，以及窗口中打开的会话都会保留。",
  "Couldn't check saved history.": "无法检查已保存的历史消息。",
  "There may be more messages between saved sections.": "已保存的消息片段之间可能还有消息。",
  "Load this gap": "补载这段消息",
  "Clean up": "清理",
  "Refresh messages": "刷新消息",
  // Native, account-wide device message history.
  "Messages on this device": "此设备上的消息",
  "Message history": "历史消息",
  "Messages you open are kept within this limit across all servers for this account. No age limit applies. Attachments and previews use the separate cache below.":
      "此账号在所有服务器上打开过的消息会保存在此设备上，不按天数过期，受下方容量限制。附件和预览使用另设的缓存。",
  "Estimated message storage: {size}": "消息占用估算：{size}",
  "Shared database and pending writes: {size}": "共享数据库及待写入数据：{size}",
  "The account estimate includes message indexes and space reserved for writes. The shared database also holds drafts, settings and other accounts.":
      "账号占用估算包含消息索引和写入预留空间。共享数据库还保存草稿、设置及其他账号的数据。",
  "Protected messages fill the limit. Existing messages and drafts stay available. Increase the limit or stop keeping a conversation to save new messages.":
      "受保护消息已占满容量。已有消息和草稿仍可使用。请提高上限或取消保留某个会话，以继续保存新消息。",
  "Freed space is still reserved on this device. Clean up message storage to reclaim it.":
      "已清理的空间仍被此设备保留。可通过清理消息存储回收空间。",
  "Message history limit": "历史消息容量上限",
  "When full, the oldest unused messages are removed first. Messages in use, draft references and conversations you keep are protected.":
      "容量不足时，优先移除最久未使用的消息。正在查看的消息、草稿引用和选择保留的会话会受到保护。",
  "Keep all": "保留全部",
  "Keep the open conversation": "保留当前会话",
  "Excludes this conversation from automatic cleanup on this device. Permission changes and signing out still remove its saved messages.":
      "此会话不参与本设备的自动清理。权限变更和退出账号仍会移除其已保存的消息。",
  "Clean up message storage": "清理消息存储",
  "Removes old unprotected messages when over the limit and reclaims freed space. Drafts, sign-in and files you saved are kept.":
      "超出容量时移除不受保护的旧消息，并回收空闲空间。保留草稿、登录信息和另存的文件。",
  "Measure again": "重新计算",
  "Refresh shown messages": "刷新已显示的消息",
  "Checks the open conversations against the server. Saved messages stay visible while it runs. An internet connection is required.":
      "联网校验已打开的会话。校验期间仍会显示已保存的消息。",
  "Shown messages refreshed.": "已显示的消息已刷新。",
  "Some messages could not be refreshed. Saved messages are still available. Check your connection and try again.":
      "部分消息未能刷新。已保存的消息仍可使用。请检查网络后重试。",
  "The account changed. Close this dialog and try again.": "账号已更改。请关闭此对话框后重试。",
  "Older unused messages may be removed immediately and will need an internet connection to open again. Messages in use, draft references and conversations you keep are protected.":
      "较旧且未使用的消息可能立即从本机移除，再次查看时需要联网。正在使用的消息、草稿引用和已选择保留的会话不会被移除。",
  "Available disk space could not be checked. No full cleanup was run. Try again.":
      "无法检查磁盘可用空间，未执行整库整理。请重试。",
  "Full cleanup needs {needed} of free disk space; {available} is available. Free up device space and try again.":
      "整库整理需要 {needed} 可用磁盘空间，当前可用 {available}。请释放设备空间后重试。",
  "Rebuild message storage?": "整理整个消息数据库？",
  "This older database needs a full rebuild to release space. It may take a while and pause local message reads and saves. At least {needed} of free disk space is required; {available} is available. Drafts and saved files are kept.": "此旧版数据库需要整库整理才能释放空间。此操作可能耗时较长，并暂时暂停本地消息的读取和保存。至少需要 {needed} 可用磁盘空间，当前可用 {available}。草稿和已另存的文件会保留。",
  "Rebuild storage": "整理数据库",
  "Rebuilding…": "正在整理…",
  "Message storage could not be measured. Try again.": "无法计算消息占用，请重试。",
  "Message storage could not be updated. Existing messages and drafts are kept. Try again.":
      "无法更新消息存储。已有消息和草稿已保留，请重试。",
  "Device message storage is full. Increase the message history limit or stop keeping a conversation in Storage settings.":
      "此设备的消息存储已满。请在存储设置中提高历史消息容量上限，或取消保留某个会话。",
};
