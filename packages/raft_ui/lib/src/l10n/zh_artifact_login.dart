// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Login with Raft in the in-app artifact browser. The Web messages are
// pages.humanLogin.* / oauth.* of the pinned Web (v1.21.23) zh-cn catalog,
// verbatim; the rest is native-only copy.
const Map<String, String> zhCatalogArtifactLogin = <String, String>{
  "{serviceName} wants to connect to {serverName}":
      "{serviceName} 想要连接到 {serverName}",
  "Use your Raft account with <b>{serviceName}</b> on an available Raft Server.":
      "在可用的 Raft Server 上，使用你的 Raft 账户配合<b>{serviceName}</b>。",
  "{appName} is requesting access it has not been granted: {scopes}. Ask the app owner to add these scopes to the OAuth client before trying again.":
      "{appName} 请求了尚未获准的权限：{scopes}。请让应用负责人先把这些 scope 加到 OAuth client，再重试。",
  "{appName} requested OAuth scopes Raft does not support: {scopes}. Update the app's requested scopes before trying again.":
      "{appName} 请求了 Raft 不支持的 OAuth scope：{scopes}。请先修改应用请求的 scope，再重试。",
  "{appName} requested scopes that are unsupported or not granted to this OAuth client: {scopes}. Update the app request or client permissions before trying again.": "{appName} 请求的 scope 中包含 Raft 不支持或该 OAuth client 尚未获准的项：{scopes}。请先修改应用请求或 client 权限，再重试。",
  "Read the IDs, handles, display names and avatars of agents in the Server you authorize. This permission does not allow sending messages or reading conversations, activity or unread counts.":
      "读取你授权的 Server 内 Agent 的 ID、名称、显示名和头像。此权限不允许发送消息，也不允许读取对话、活动或未读数。",
  // Install and continue (pages.humanLogin.* of the same catalog, verbatim).
  "Selected <b>{serverName}</b>.": "已选择 <b>{serverName}</b>。",
  "<b>{serverName}</b> has not installed {appName}. You are an admin of this Server. Continuing will install the App as you.":
      "<b>{serverName}</b> 尚未安装 {appName}。你是该 Server 的管理员，继续将以你的身份安装。",
  "<b>{serverName}</b> has not installed {appName}. Only an owner or admin of this Server can install it.":
      "<b>{serverName}</b> 尚未安装 {appName}，只有该 Server 的所有者或管理员能安装。",
  "Access granted: {scopes}": "将授予：{scopes}",
  // Native-only: the in-app browser for artifact links.
  "Open in browser": "在浏览器中打开",
  "This page could not be loaded.": "无法加载此页面。",
  "Download cancelled.": "下载已取消。",
  "Cancelling…": "正在取消…",
  "This download is not available in the app. Open it in your browser.":
      "此下载暂不支持在 App 内保存，请在浏览器中打开。",
};
