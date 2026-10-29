// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.21.23-source.1 zh-cn.ts wording verbatim, Cloud agents (hosted runtime). Messages with an ICU
// plural / select are not repeated: raftFormat fills simple {name} placeholders only.
const Map<String, String> zhCatalogW23Cloud = <String, String>{
  "Last error ({code}): {message}": "最近一次错误（{code}）：{message}",
  "{total} ({succeeded} succeeded, {failed} failed)":
      "{total} 次（成功 {succeeded}，失败 {failed}）",
  "Partial data, as of {time}": "数据不完整，截至 {time}",
  "Runs on:": "运行位置：",
  // `agent.migration.hosted.reviewFileCount` and `reviewMorePaths`, flattened
  // to the singular / plural keys the review uses.
  "{files} file ({size})": "{files} 个文件（{size}）",
  "{files} files ({size})": "{files} 个文件（{size}）",
  "and {count} more": "还有 {count} 个",
  // `agent.detail.connections.*` messages with placeholders.
  "Connected as {account}": "已连接为 {account}",
  "by @{name}": "由 @{name} 连接",
  "Scopes: {scopes}": "权限范围：{scopes}",
  "Opens GitHub to grant this agent access ({scopes}). The token stays with the agent's provider.":
      "打开 GitHub 为此 Agent 授权（{scopes}）。令牌由 Agent 的提供方保管。",
  "GitHub will ask you to grant: {scopes}. The link is single-use and expires in 10 minutes.":
      "GitHub 将请求授予：{scopes}。该链接仅能使用一次，10 分钟后失效。",
  "The provider refused: {reason}": "提供方拒绝了请求：{reason}",
  "Uses @{creator}'s GitHub ({account})": "使用 @{creator} 的 GitHub（{account}）",
  "{account} · created by @{creator}": "{account} · 由 @{creator} 创建",
  "This agent stops using GitHub as {account}. The connection stays available to other agents on this server.":
      "此 Agent 将不再以 {account} 身份使用 GitHub。该连接仍可供此服务器上的其他 Agent 使用。",
  "{account} is disconnected for every agent on this server that uses it, not only this one. Those agents lose GitHub access until they are switched to another connection.": "{account} 将对此服务器上所有使用它的 Agent 断开，而不仅是此 Agent。这些 Agent 在切换到其他连接之前将失去 GitHub 访问权限。",
};
