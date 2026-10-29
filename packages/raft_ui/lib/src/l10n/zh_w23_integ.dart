// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.21.23-source.1 zh-cn.ts wording verbatim: app installation setup (appSetup.*) and the Slack @-menu mention-sync hint.
// The ICU plural of mentionSyncNameTaken is split into its one/other English forms (raftText does not interpret ICU).
const Map<String, String> zhCatalogW23Integ = <String, String>{
  // appSetup.title
  "Installation setup": "安装后配置",
  // appSetup.requiresConfiguration
  "Requires configuration after installation": "安装后需要配置",
  // appSetup.urlLabel
  "Setup page URL": "配置页面地址",
  // appSetup.urlHint
  "Use an HTTPS page. Raft adds installation and Server identifiers; this is separate from the login callback.":
      "使用 HTTPS 页面。Raft 会附带安装与 Server 标识；此地址与登录回调分开。",
  // appSetup.descriptionLabel
  "Configuration instructions": "配置说明",
  // appSetup.requiredAfterInstall
  "Setup required": "需要配置",
  // appSetup.beforeInstall
  "After installation, continue configuration at {domain}.":
      "安装后需前往 {domain} 完成配置。",
  // appSetup.pending
  "Installed, setup pending": "已安装，待配置",
  // appSetup.manage
  "Manage configuration": "管理配置",
  // appSetup.continue
  "Continue setup": "前往配置",
  // appSetup.opensAt
  "Opens {domain} in a new tab": "将在新标签页打开 {domain}",
  // appSetup.adminManage
  "A Server administrator can manage configuration.": "Server 管理员可以管理配置。",
  // appSetup.adminRequired
  "Ask a Server administrator to complete configuration.": "请 Server 管理员完成配置。",
  // appSetup.refresh
  "Refresh status": "刷新状态",
  // appSetup.loadFailed
  "Could not load configuration status. Try again.": "无法读取配置状态，请重试。",
  // appSetup.invalidUrl
  "Enter an HTTPS setup URL (loopback HTTP is allowed for local development).":
      "请输入 HTTPS 配置地址（本地开发允许回环 HTTP）。",
  // appSetup.notRequired
  "No setup required": "无需配置",
  // appSetup.editorHint
  "Tell installers where to connect an external account or configure your App.":
      "告知安装者在哪里连接外部账号或完成 App 配置。",
  // settings.slackBridge.mentionSyncTitle
  "Some members can't be picked from Slack's @ menu yet":
      "部分成员暂时无法在 Slack 的 @ 列表里选到",
  // settings.slackBridge.mentionSyncRestricted
  "Messages sync normally, and typing a Raft member's @name in Slack still reaches them when no one else in the channel has that name. To also list them in Slack's @ menu, a Slack admin needs to let members create user groups: Workspace settings → Permissions → User groups.": "消息同步不受影响；在 Slack 里手动输入 @名字，只要频道里没有同名的人，仍然能 @ 到对应的 Raft 成员。如果想让他们也出现在 Slack 的 @ 列表里，需要 Slack 管理员允许成员创建用户组：工作区设置 → 权限 → 用户组。",
  // settings.slackBridge.mentionSyncMissingScope
  "Messages sync normally, and typing a Raft member's @name in Slack still reaches them when no one else in the channel has that name. To also list them in Slack's @ menu, Raft needs one more Slack permission: use “Update Slack authorization” below.": "消息同步不受影响；在 Slack 里手动输入 @名字，只要频道里没有同名的人，仍然能 @ 到对应的 Raft 成员。如果想让他们也出现在 Slack 的 @ 列表里，Raft 还需要一项 Slack 权限：请点击下方的“更新 Slack 授权”。",
  // settings.slackBridge.mentionSyncGeneric
  "Messages sync normally, and typing a Raft member's @name in Slack still reaches them when no one else in the channel has that name. Slack refused to list some of them in its @ menu ({code}); Raft keeps retrying.": "消息同步不受影响；在 Slack 里手动输入 @名字，只要频道里没有同名的人，仍然能 @ 到对应的 Raft 成员。Slack 拒绝把其中一些成员放进 @ 列表（{code}），Raft 会继续重试。",
  // settings.slackBridge.mentionSyncNameTaken#one
  "Messages sync normally, and typing a Raft member's @name in Slack still reaches them when no one else in the channel has that name. {count} member couldn't get an entry in Slack's @ menu because every name Raft tried is already used in Slack. Renaming them in Raft, or freeing the name in Slack, fixes it.": "消息同步不受影响；在 Slack 里手动输入 @名字，只要频道里没有同名的人，仍然能 @ 到对应的 Raft 成员。有 {count} 位成员没能出现在 Slack 的 @ 列表里，因为 Raft 尝试的名字在 Slack 里都已被占用。在 Raft 里给他们改名，或在 Slack 里腾出这个名字即可。",
  // settings.slackBridge.mentionSyncNameTaken#other
  "Messages sync normally, and typing a Raft member's @name in Slack still reaches them when no one else in the channel has that name. {count} members couldn't get an entry in Slack's @ menu because every name Raft tried is already used in Slack. Renaming them in Raft, or freeing the name in Slack, fixes it.": "消息同步不受影响；在 Slack 里手动输入 @名字，只要频道里没有同名的人，仍然能 @ 到对应的 Raft 成员。有 {count} 位成员没能出现在 Slack 的 @ 列表里，因为 Raft 尝试的名字在 Slack 里都已被占用。在 Raft 里给他们改名，或在 Slack 里腾出这个名字即可。",
  // agent.detail.agentManifest
  "Agent manifest: {url}": "Agent manifest：{url}",
  // No Web key: Web opens links with plain anchors. Wording follows Web's "Failed to open billing portal" / "无法打开…" family.
  "Could not open this address.": "无法打开此地址。",
};
