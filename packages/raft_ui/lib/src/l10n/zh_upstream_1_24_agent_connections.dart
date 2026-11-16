// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.24.0-source.1 en.ts / zh-cn.ts wording verbatim: WP-AGENT (agent connections: GitHub connector states, reconnect, remove and undo, revoke hint).
const Map<String, String>
zhCatalogUpstream124AgentConnections = <String, String>{
  "{agent} works on repos, issues and pull requests as the GitHub account you choose.":
      "{agent} 以所选的 GitHub 账户访问仓库、Issue 和 PR。",
  "Needs reconnecting": "需要重新连接",
  "Created by {creator} · {date}": "由 {creator} 创建 · {date}",
  "Created by {creator}": "由 {creator} 创建",
  "Only this agent's owner can connect a GitHub account to it.":
      "只有这个 Agent 的主人才能为它连接 GitHub 账号。",
  "Removed {account} from {agent}": "已从 {agent} 移除 {account}",
  "{agent} stops using GitHub as {account}. The connection stays available to other agents on this server, but only its creator or a server admin can assign it to {agent} again.": "{agent} 将不再以 {account} 身份使用 GitHub。该连接仍可供此服务器上的其他 Agent 使用，但只有它的创建者或服务器管理员可以再把它分配给 {agent}。",
  "Could not remove the connection from {agent}. Try again.":
      "无法从 {agent} 移除此连接，请重试。",
  "Could not remove the connection from {agent}.": "无法从 {agent} 移除此连接。",
  "Could not restore the connection. Choose it again from the list.":
      "无法恢复此连接，请从列表中重新选择。",
  "{account} (created by {creator} on {date})":
      "{account}（由 {creator} 于 {date} 创建）",
  "{account} (created by {creator})": "{account}（由 {creator} 创建）",
  "An agent still holds a copy of this GitHub credential that can't be removed from here. To stop it working, revoke the app in {link}. That signs out every connection made with this GitHub account.": "某个 Agent 仍持有此 GitHub 凭据的副本，无法在这里删除。要让它失效，请在{link}中撤销该应用。这样做会让这个 GitHub 账户建立的所有连接都失效。",
  "your GitHub settings": "GitHub 设置",
  "After you approve on GitHub, {agent} switches to the new connection.":
      "在 GitHub 上授权后，{agent} 会改用这个新连接。",
  "Repository access": "仓库访问范围",
  "Public repos only": "仅公开仓库",
  "Read and write the public repos you can access. GitHub scope:":
      "读写你有权限的公开仓库。GitHub 权限：",
  "Public and private repos": "公开和私有仓库",
  "Also the private repos you can access. GitHub scope:":
      "也包括你有权限的私有仓库。GitHub 权限：",
  "The token stays with the agent's cloud provider, never with Raft. The GitHub link works for 10 minutes.":
      "令牌由 Agent 的云端提供方保管，不经过 Raft。GitHub 授权链接 10 分钟内有效。",
  "Reconnect": "重新连接",
  "After you approve on GitHub, the agent uses the connection again.":
      "在 GitHub 上授权后，Agent 会重新使用这个连接。",
  "Reconnect {account}": "重新连接 {account}",
  "Only the creator of {account} or a server owner or admin can change this connection.":
      "只有 {account} 的创建者或服务器所有者、管理员可以更改这个连接。",
  "Only {creator}, who created {account}, or a server owner or admin can change this connection.":
      "只有创建 {account} 的 {creator} 或服务器所有者、管理员可以更改这个连接。",
  "{account} was disconnected in the meantime, so it was removed from the list.":
      "{account} 已在此期间被断开，已从列表中移除。",
  "GitHub granted less access than was requested. Reconnect to ask again.":
      "GitHub 授予的权限少于申请的权限。重新连接以再次申请。",
  "Can use public repos only": "仅可访问公开仓库",
  "Can use public and private repos": "可访问公开和私有仓库",
  "Last checked {time}": "上次检查：{time}",
  "{account} needs reconnecting before {agent} can use GitHub again. Only its creator or a server owner or admin can reconnect it.":
      "{account} 需要重新连接，{agent} 才能再次使用 GitHub。只有它的创建者或服务器所有者、管理员可以重新连接。",
  "{account} needs reconnecting before {agent} can use GitHub again.":
      "{account} 需要重新连接，{agent} 才能再次使用 GitHub。",
  "Not restored: {agent} already uses another connection.":
      "未恢复：{agent} 已在使用其他连接。",
  "Could not copy the details": "无法复制详情",
  "Details copied": "已复制详情",
  "Copy details": "复制详情",
  "The agent's provider refused this GitHub request. Try again; if it keeps happening, copy the details for whoever manages the agent's provider.":
      "Agent 的提供方拒绝了这次 GitHub 请求。请重试；如果持续出现，请复制详情，交给负责此 Agent 提供方的人。",
};
