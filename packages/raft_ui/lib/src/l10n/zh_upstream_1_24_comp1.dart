// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.24.0-source.1 en.ts / zh-cn.ts wording verbatim: WP-COMP1 (the Computers rack, its toolbar,
// counts and needs-attention summary, readiness copy, Delete Computer and force unbind, the row's
// Restart / Upgrade confirmations). ICU plurals and selects are separate English keys here.
const Map<String, String> zhCatalogUpstream124Comp1 = <String, String>{
  "Low disk space: {free} free of {total}": "磁盘空间不足：剩余 {free}，共 {total}",
  "{free} free of {total}": "剩 {free}，共 {total}",
  "Upgrade soon": "请尽快升级",
  "Upgrade soon: from {date}, agents on this computer stop running":
      "请尽快升级：从 {date} 起，这台计算机上的 Agent 将停止运行",
  "This version needs a reinstall": "这个版本需要重新安装",
  "Reinstall soon: from {date}, agents on this computer stop running":
      "请尽快重新安装：从 {date} 起，这台计算机上的 Agent 将停止运行",
  "Agents on this computer aren't running: the version is too old":
      "这台计算机上的 Agent 没有在运行：版本太旧",
  "v{version} is out of date. Please upgrade to v{floor} or later.":
      "v{version} 已过时，请升级到 v{floor} 或更高版本。",
  "v{version} is too old to upgrade from here. Run this on that machine to reinstall Raft Computer:":
      "v{version} 太旧，无法从这里升级。在那台机器上运行下面的命令重新安装 Raft Computer：",
  "Agents on this computer aren't running: it doesn't report its version":
      "这台计算机上的 Agent 没有在运行：它未上报版本",
  "This computer doesn't report its version": "这台计算机未上报版本",
  "This computer doesn't report its version, so it's too old for Raft. Reinstall it to keep its agents running. Run this on that machine:":
      "这台计算机未上报版本，所以对 Raft 来说太旧了。重新安装才能让它上面的 Agent 继续运行。在那台机器上运行：",
  "Ask an admin to upgrade it.": "请管理员升级。",
  "Ask an admin to reinstall it.": "请管理员重新安装。",
  "Install guide": "安装指南",
  "A laptop, a desktop or a cloud server (VPS): run this command on it.":
      "笔记本、台式机或云服务器（VPS）都可以：在它上面运行下面这条命令。",
  "A server admin can fix it": "服务器管理员可以处理",
  "A server admin can fix it.": "需要服务器管理员处理。",
  "A server admin can sign in": "服务器管理员可以登录",
  "A server admin can update this computer": "服务器管理员可以更新这台 Computer",
  "A server admin can verify the account": "服务器管理员可以验证账户",
  "A to Z": "A 到 Z",
  "Account needs verification": "账户需要验证",
  "Agents to unbind": "要解绑的 Agent",
  "All statuses": "全部状态",
  "Are you sure you want to delete \"{name}\"?": "确定要删除“{name}”吗？",
  "Back in {count}d": "{count}d 后重置",
  "Back in {count}h": "{count}h 后重置",
  "Back in {count}m": "{count}m 后重置",
  "Can't reply right now": "暂时无法回复",
  "Cards": "卡片",
  "Collapse {group}, {count}": "收起{group}，{count}",
  "Computer restarting": "Computer 正在重启",
  "Computer too old": "Computer 版本太旧",
  "Computer updating": "Computer 正在更新",
  "Computers view": "计算机视图",
  "Copy command": "复制命令",
  "Disk": "磁盘",
  "Disk used": "磁盘用量",
  "Expand {group}, {count}": "展开{group}，{count}",
  "Force unbind and delete": "强制解绑并删除",
  "Force unbind {count} agent?": "强制解绑 {count} 个 Agent？",
  "Force unbind {count} agents?": "强制解绑 {count} 个 Agent？",
  "Group: {group}": "分组：{group}",
  "Least remaining first": "余量最少在前",
  "Least used first": "用量最低在前",
  "Memory": "内存",
  "Memory used": "内存用量",
  "Mine first": "我的优先",
  "More agents were added to this computer, so nothing was unbound. Check the list and confirm again.":
      "这台计算机上又多了别人的 Agent，这次没有解绑任何 Agent。请看一下列表，再确认一次。",
  "Most remaining first": "余量最多在前",
  "Most used first": "用量最高在前",
  "Name prefix": "名称前缀",
  "Needs attention": "需要处理",
  "No computers match": "没有匹配的 Computer",
  "No grouping": "不分组",
  "No owner · {computerName}": "没有主人 · {computerName}",
  "Open the Anthropic verification portal": "打开 Anthropic 验证门户",
  "Other runtimes": "其他运行时",
  "Owner: {name}": "所有者：{name}",
  "Owner: {ownerName} · {computerName}": "主人：{ownerName} · {computerName}",
  "Personal computers": "个人电脑",
  "Public (no owner)": "公共（无所有者）",
  "Restart computer": "重启 Computer",
  "Restarting {name} disconnects it and its {count} agent until it comes back online.":
      "重启 {name} 会让它和其上的 {count} 个 Agent 断开连接，直到它重新上线。",
  "Restarting {name} disconnects it and its {count} agents until it comes back online.":
      "重启 {name} 会让它和其上的 {count} 个 Agent 断开连接，直到它重新上线。",
  "Restarting {name} disconnects it until it comes back online.":
      "重启 {name} 会让它断开连接，直到它重新上线。",
  "Search computers": "搜索计算机",
  "Search computers by name, hostname or owner": "按名称、主机名或所有者搜索 Computer",
  "Sort: {sort}": "排序：{sort}",
  "The agent's owner can fix it": "Agent 的所有者可以处理",
  "The agent's owner can fix it.": "需要 Agent 的所有者处理。",
  "The agent's owner can sign in": "Agent 的所有者可以登录",
  "The agent's owner can update this computer": "Agent 的所有者可以更新这台 Computer",
  "The agent's owner can verify the account": "Agent 的所有者可以验证账户",
  "The computer's owner can fix it": "Computer 的所有者可以处理",
  "The computer's owner can fix it.": "需要 Computer 的所有者处理。",
  "The computer's owner can sign in": "Computer 的所有者可以登录",
  "The computer's owner can update this computer":
      "Computer 的所有者可以更新这台 Computer",
  "The computer's owner can verify the account": "Computer 的所有者可以验证账户",
  "The {runtime} account signed in here can't receive replies until it is verified. The account holder must finish the step in the Anthropic Verification Portal, then choose Retry. Messages are kept and will be delivered.": "这里登录的 {runtime} 账户在完成验证前无法收到回复。账户持有人需要在 Anthropic 验证门户完成验证，然后选择“重试”。消息会保留，之后送达。",
  "Their workspaces on your computers are lost. The agents themselves stay, with their messages and settings, and their owners can keep using them on another computer. Each owner gets a system notice.":
      "这些 Agent 在你的计算机上的工作区会丢失；Agent 本身保留，消息和设置都还在，主人可以换一台计算机继续用。主人会收到系统通知。",
  "This Computer is installing an update and will be back in a few minutes. Messages are kept and will be delivered when it is back.":
      "这台 Computer 正在安装更新，几分钟后回来。消息会保留，回来后送达。",
  "This Computer is offline. Messages are kept and will be delivered when it reconnects.":
      "这台 Computer 已离线。消息会保留，重新连接后送达。",
  "This Computer just disconnected and is likely to be back in a moment. Messages are kept and will be delivered.":
      "这台 Computer 刚断开连接，很可能马上回来。消息会保留，之后送达。",
  "This Computer was stopped or restarted on purpose. Messages are kept and will be delivered when it is back.":
      "这台 Computer 是按计划停止或重启的。消息会保留，回来后送达。",
  "This Computer's Raft version is too old to run agents. Update Raft Desktop on it. Messages are kept and will be delivered.":
      "这台 Computer 上的 Raft 版本过旧，无法运行 Agent。请在上面更新 Raft Desktop。消息会保留，之后送达。",
  "This Computer's Raft version is too old to run agents. Upgrade or reinstall Raft Computer on it. Messages are kept and will be delivered.":
      "这台 Computer 上的 Raft 版本过旧，无法运行 Agent。请在上面升级或重装 Raft Computer。消息会保留，之后送达。",
  "This Computer's problem": "这台 Computer 的问题",
  "This agent can't reply right now. Its messages are kept and will be delivered.":
      "这个 Agent 暂时无法回复。消息会保留，之后送达。",
  "This agent's problem": "这个 Agent 的问题",
  "This computer has {count} agent assigned. Remove all agents before deleting the computer.":
      "这台 Computer 还有 {count} 个 Agent。请先移除所有 Agent，再删除 Computer。",
  "This computer has {count} agents assigned. Remove all agents before deleting the computer.":
      "这台 Computer 还有 {count} 个 Agent。请先移除所有 Agent，再删除 Computer。",
  "This computer's key is revoked and it's offline now, but it couldn't be removed from the list: {reason} Trying again is safe.":
      "这台计算机的密钥已作废，现在已离线，但没能从列表里移除：{reason}可以放心再试一次。",
  "This server's problem": "这个服务器的问题",
  "Try another search, or clear the filters.": "换个关键词，或清除筛选。",
  "Unbinding…": "正在解绑…",
  "Update available: v{version}": "有可用更新：v{version}",
  "Update available: v{version} · Offline": "有可用更新：v{version} · 离线",
  "Update required": "需要更新",
  "Upgrade to v{version}": "升级到 v{version}",
  "Verify account": "验证账户",
  "Waiting for {count} agent on this server…": "正在等待本服务器上的 {count} 个 Agent…",
  "Waiting for {count} agents on this server…": "正在等待本服务器上的 {count} 个 Agent…",
  "Z to A": "Z 到 A",
  "an agent is moving to or from it. Wait for the move to finish.":
      "有 Agent 正在迁入或迁出这台计算机。请等迁移完成。",
  "an agent is still on it. Move or remove that agent first.":
      "上面还有 Agent。请先迁走或删除它。",
  "an agent's settings still point to it. Move or remove that agent first.":
      "有 Agent 的设置还指向这台计算机。请先迁走或删除那个 Agent。",
  "back in {count}d": "{count} 天后恢复",
  "back in {count}h": "{count} 小时后恢复",
  "back in {count}m": "{count} 分钟后恢复",
  "something went wrong on our side.": "我们这边出了问题。",
  "{count} agent": "{count} 个 Agent",
  "{count} agent can't run": "{count} 个 Agent 无法运行",
  "{count} agent waiting": "{count} 个 Agent 在等待",
  "{count} agents": "{count} 个 Agent",
  "{count} agents can't run": "{count} 个 Agent 无法运行",
  "{count} agents waiting": "{count} 个 Agent 在等待",
  "{count} computer": "{count} 台 Computer",
  "{count} computer needs attention": "{count} 台 Computer 需要处理",
  "{count} computers": "{count} 台 Computer",
  "{count} computers need attention": "{count} 台 Computer 需要处理",
  "{count} need attention": "{count} 台需要处理",
  "{count} online": "{count} 台在线",
  "{detail} {actor}": "{detail}{actor}",
  "{filter}: {value}": "{filter}：{value}",
  "{name} can fix it": "{name} 可以处理",
  "{name} can sign in": "{name} 可以登录",
  "{name} can update this computer": "{name} 可以更新这台 Computer",
  "{name} can verify the account": "{name} 可以验证账户",
  "{name} restarts into v{version}, which disconnects it and its {count} agent until it reconnects.":
      "{name} 会重启并升级到 v{version}，它和其上的 {count} 个 Agent 会断开连接，直到重新连上。",
  "{name} restarts into v{version}, which disconnects it and its {count} agents until it reconnects.":
      "{name} 会重启并升级到 v{version}，它和其上的 {count} 个 Agent 会断开连接，直到重新连上。",
  "{name} restarts into v{version}, which disconnects it until it reconnects.":
      "{name} 会重启并升级到 v{version}，它会断开连接，直到重新连上。",
  "{percent}% used": "已用 {percent}%",
  "{runtime} isn't installed on this Computer. Install it there, or move the agent to a Computer that has it. Messages are kept and will be delivered.":
      "这台 Computer 上没有安装 {runtime}。请在上面安装，或把 Agent 移到装有它的 Computer。消息会保留，之后送达。",
  "{runtime} not installed": "未安装 {runtime}",
  "{runtime} remaining": "{runtime} 余量",
  "{runtime}: {title}": "{runtime}：{title}",
  "{scope}: {text}": "{scope}：{text}",
  "{title} on {computer}": "{computer} 上：{title}",
  "{title} · {who}": "{title} · {who}",
};
