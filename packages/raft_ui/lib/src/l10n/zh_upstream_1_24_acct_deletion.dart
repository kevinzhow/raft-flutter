// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.24.0-source.1 en.ts / zh-cn.ts wording verbatim: WP-ACCT delete account
// (accountDeletion.*). ICU plurals are split into their one / other English
// sentences (the catalog does not interpret ICU); the Chinese is the same for both.
const Map<String, String> zhCatalogUpstream124AcctDeletion = <String, String>{
  // accountDeletion.rowTitle
  "Delete account": "注销账号",
  // accountDeletion.rowDescription
  "Sign out everywhere and schedule your account for deletion. You can cancel until the date it's deleted.":
      "在所有设备上退出登录，并安排注销你的账号。在注销日期之前，你随时可以取消。",
  // accountDeletion.effectGrace
  "Sign in before the deletion date to cancel": "注销日期前登录可以撤销",
  // accountDeletion.failed
  "Couldn't delete your account. Try again.": "账号没能注销，请再试一次。",
  // accountDeletion.verifySecondFactor
  "Confirm it's you to delete your account.": "注销账号前，请先确认是你本人。",
  // accountDeletion.emailSendCode
  "Send code": "发送验证码",
  // accountDeletion.emailCodeSentLabel
  "Code sent to {email}": "发到 {email} 的验证码",
  // accountDeletion.emailBeforeSend
  "We'll email a code to {email}.": "我们会把验证码发到 {email}。",
  // accountDeletion.emailResend
  "Send a new code": "重新发送验证码",
  // accountDeletion.emailCodeInvalid
  "That code didn't work. Check the email or ask for a new code.":
      "这个验证码不对。请检查邮件，或重新获取一个验证码。",
  // accountDeletion.emailRecentlySent
  "A code was just sent. Wait a minute before asking for another.":
      "验证码刚刚发出。请等一分钟再重新获取。",
  // accountDeletion.signInAgain
  "This sign-in can't be used to delete your account. Sign in again, then try once more.":
      "当前登录不能用来注销账号。请重新登录后再试一次。",
  // accountDeletion.pendingTitle
  "Your account will be deleted": "你的账号将被注销",
  // accountDeletion.pendingDescriptionNoDate
  "Your account is scheduled for deletion. Cancel the deletion to keep using Raft.":
      "你的账号已安排注销。取消注销即可继续使用 Raft。",
  // accountDeletion.cancelDeletion
  "Cancel deletion": "取消注销",
  // accountDeletion.cancelFailed
  "Couldn't confirm the deletion status. Check the current request and try again.":
      "无法确认删除状态，请核对当前请求后重试。",
  // accountDeletion.transferNeeded
  "Choose a new Owner to take it over first": "先指定一位新所有者来接管",
  // accountDeletion.transferLabel
  "New owner of {serverName}": "{serverName} 的新所有者",
  // accountDeletion.transferPlaceholder
  "Transfer to…": "转让给…",
  // accountDeletion.transferConfirm
  "Make owner": "设为所有者",
  // accountDeletion.transferDone
  "Goes to {memberName}, who manages it from now on":
      "转给 {memberName}，以后由 {memberName} 管理",
  // accountDeletion.transferNoMembers
  "No one here can become an Owner. Delete the server instead.":
      "这里没有人能成为所有者。请改为删除这个服务器。",
  // accountDeletion.openServerSettings
  "Open server settings": "打开服务器设置",
  // accountDeletion.transferLoadFailed
  "Couldn't load this server's members.": "没能加载这个服务器的成员。",
  // accountDeletion.transferFailed
  "Couldn't make them an Owner. Try again.": "没能设为所有者，请再试一次。",
  // accountDeletion.cancellingDeletion
  "Cancelling deletion…": "正在取消注销…",
  // accountDeletion.makingOwner
  "Making owner…": "正在设为所有者…",
  // accountDeletion.scheduledTitle
  "Deletion scheduled": "已安排注销",
  // accountDeletion.lead
  "Here's what happens to your servers and agents when the deletion takes effect.":
      "下面是注销生效时，你的服务器和 Agent 会怎样。",
  // accountDeletion.groupNeedsAction
  "Needs action ({count})": "需要处理（{count}）",
  // accountDeletion.groupAutomatic
  "The rest happens automatically ({count})": "其余会自动处理（{count}）",
  // accountDeletion.serverMembers
  "{count} other member": "还有 {count} 名成员",
  // accountDeletion.serverMembers
  "{count} other members": "还有 {count} 名成员",
  // accountDeletion.serverMembersSoleOwner
  "{count} other member, and you're the only Owner": "还有 {count} 名成员，只有你是所有者",
  // accountDeletion.serverMembersSoleOwner
  "{count} other members, and you're the only Owner": "还有 {count} 名成员，只有你是所有者",
  // accountDeletion.transferDoneBadge
  "Handled": "已处理",
  // accountDeletion.serverOnlyYou
  "Only you": "只有你",
  // accountDeletion.serverCloses
  "Closes, and its channels and files can no longer be opened":
      "关闭，频道和文件都无法再打开",
  // accountDeletion.yourAgents
  "Your agents": "你的 Agent",
  // accountDeletion.agentsGeneral
  "Go to their server's Owner; your personal assistant is archived":
      "转给所在服务器的所有者，你的个人助理会被归档",
  // accountDeletion.agentsGeneralNote
  "They stop now.": "现在就停止。",
  // accountDeletion.agentsOnComputer
  "{count} agent on {computerName}": "{computerName} 上的 {count} 个 Agent",
  // accountDeletion.agentsOnComputer
  "{count} agents on {computerName}": "{computerName} 上的 {count} 个 Agent",
  // accountDeletion.agentsInServer
  "{count} agent in {serverName}": "{serverName} 里的 {count} 个 Agent",
  // accountDeletion.agentsInServer
  "{count} agents in {serverName}": "{serverName} 里的 {count} 个 Agent",
  // accountDeletion.agentsToOwner
  "Goes to {ownerName}": "转给 {ownerName}",
  // accountDeletion.agentsToOwner
  "Go to {ownerName}": "转给 {ownerName}",
  // accountDeletion.agentsToOwnerNewComputer
  "Goes to {ownerName}, who needs another computer to run it":
      "转给 {ownerName}，需要 {ownerName} 换一台计算机运行",
  // accountDeletion.agentsToOwnerNewComputer
  "Go to {ownerName}, who needs another computer to run them":
      "转给 {ownerName}，需要 {ownerName} 换一台计算机运行",
  // accountDeletion.agentsToNewOwner
  "Goes to the new Owner of {serverName}": "转给 {serverName} 的新所有者",
  // accountDeletion.agentsToNewOwner
  "Go to the new Owner of {serverName}": "转给 {serverName} 的新所有者",
  // accountDeletion.agentsToNewOwnerNewComputer
  "Goes to the new Owner of {serverName}, who needs another computer to run it":
      "转给 {serverName} 的新所有者，需要换一台计算机运行",
  // accountDeletion.agentsToNewOwnerNewComputer
  "Go to the new Owner of {serverName}, who needs another computer to run them":
      "转给 {serverName} 的新所有者，需要换一台计算机运行",
  // accountDeletion.assistantArchived
  "Your personal assistant is archived": "你的个人助理会被归档",
  // accountDeletion.agentsStopNow
  "It stops now.": "现在就停止。",
  // accountDeletion.agentsStopNow
  "Your personal assistant is archived.": "你的个人助理会被归档。",
  // accountDeletion.namesMore
  "{count} more": "另外 {count} 个",
  // accountDeletion.computerDeleted
  "Deleted on the deletion date": "注销生效时删除",
  // accountDeletion.computerOnServer
  "Connected to {serverName}": "连接到 {serverName}",
  // accountDeletion.optionalActions
  "You can also": "也可以",
  // accountDeletion.billingOf
  "Billing for {serverName}": "{serverName} 的付费",
  // accountDeletion.billingPaidByYou
  "Paid by you": "由你付款",
  // accountDeletion.billingStopsOn
  "Billing stops on {date}": "{date} 停止计费",
  // accountDeletion.billingStopsAtPeriodEnd
  "Billing stops at the end of the current period": "本期结束时停止计费",
  // accountDeletion.learnMore
  "Learn more: messages, sign-in and keys": "了解更多：消息、登录和密钥",
  // accountDeletion.moreMessages
  "Messages you sent stay, shown as “Deleted user”.": "你发过的消息会保留，显示为“已删除的用户”。",
  // accountDeletion.moreSignedOut
  "Once you confirm, you're signed out on every device.": "确认后，所有设备立即退出登录。",
  // accountDeletion.moreKeys
  "Your computers' and agents' keys stop working right away; on the deletion date your computers are deleted.":
      "计算机和 Agent 的密钥立即失效；注销生效时计算机自动删除。",
  // accountDeletion.moreProfile
  "On the deletion date your profile and avatar are deleted.":
      "注销生效时删除你的个人资料和头像。",
  // accountDeletion.whyBlocked
  "First choose a new Owner for {servers}": "先为 {servers} 指定新所有者",
  // accountDeletion.scheduledEffective
  "Takes effect on {date}": "{date} 生效",
  // accountDeletion.howToCancel
  "How to cancel": "如何撤销",
  // accountDeletion.cancelBySignIn
  "Sign in to Raft before {date}": "{date} 前登录 Raft",
  // accountDeletion.signedOutEverywhere
  "You've been signed out on every device.": "你已在所有设备退出登录。",
  // accountDeletion.pendingTitleDate
  "Your account will be deleted on {date}": "你的账号将在 {date} 注销",
  // accountDeletion.pendingDaysLeft
  "{count} day left": "还剩 {count} 天",
  // accountDeletion.pendingDaysLeft
  "{count} days left": "还剩 {count} 天",
  // accountDeletion.afterCancelReconnect
  "Once cancelled, sign in again on your devices and reconnect your computers.":
      "撤销后，需要在各设备上重新登录，并重新连接你的计算机。",
  // accountDeletion.subscriptionNotResumed
  "Your subscription wasn't automatically restored. Go to Plan & Billing to subscribe again.":
      "订阅未自动恢复，请到账单页重新订阅。",
  // accountDeletion.subscriptionRestorationUnknown
  "We couldn't confirm your subscription's renewal status. Check Plan & Billing before making another subscription change.":
      "无法确认订阅的续费状态，请到账单页检查后再操作。",
  // accountDeletion.subscriptionCancellationUnconfirmed
  "We could not confirm cancellation of subscription renewal. To check your subscription, cancel account deletion first, then open Plan & Billing.":
      "未能确认订阅续费已取消。如需核对，请先撤销账号删除，再前往「方案与账单」。",
  // accountDeletion.requestChanged
  "A newer deletion request is still scheduled. Review it before cancelling.":
      "新的删除请求仍在等待执行，请先核对再撤销。",
  // accountDeletion.requestUnconfirmed
  "The current deletion request could not be confirmed. Load it again before cancelling.":
      "无法确认当前的删除请求，请重新加载后再撤销。",
  // accountDeletion.cancelLinkDoneTitle
  "Deletion cancelled": "已撤销注销",
  // accountDeletion.leadDays
  "It takes effect {count} day after you confirm. Here's what happens to your servers and agents then.":
      "确认后 {count} 天生效。下面是到时你的服务器和 Agent 会怎样。",
  // accountDeletion.leadDays
  "It takes effect {count} days after you confirm. Here's what happens to your servers and agents then.":
      "确认后 {count} 天生效。下面是到时你的服务器和 Agent 会怎样。",
  // accountDeletion.actionWithDate
  "Delete account · Effective {date}": "注销账号 · {date}生效",
  // accountDeletion.effectGraceDays
  "Sign in within {count} day to cancel": "{count} 天内登录即可撤销",
  // accountDeletion.effectGraceDays
  "Sign in within {count} days to cancel": "{count} 天内登录即可撤销",
  // accountDeletion.groupOthersAgents
  "Other people's agents on your computers": "别人放在你的计算机上的 Agent",
  // accountDeletion.othersAgentDetail
  "Owner: {ownerName} · {serverName} · {computerName}":
      "主人：{ownerName} · {serverName} · {computerName}",
  // accountDeletion.othersAgentDetailNoOwner
  "No owner · {serverName} · {computerName}":
      "没有主人 · {serverName} · {computerName}",
  // accountDeletion.othersAgentMustMove
  "Has to move to another computer first": "需要先迁到别的计算机",
  // accountDeletion.notifyAllOwners
  "Notify all owners": "全部通知",
  // accountDeletion.whyBlockedOthersAgents
  "First wait for {count} other person's agent to leave your computers":
      "先等别人的 {count} 个 Agent 从你的计算机迁走",
  // accountDeletion.whyBlockedOthersAgents
  "First wait for {count} other people's agents to leave your computers":
      "先等别人的 {count} 个 Agent 从你的计算机迁走",
  // accountDeletion.forceUnbindAndRequest
  "Force unbind and request deletion": "强制解绑并申请注销",
  // accountDeletion.forceConflict
  "More agents were added to your computers, so nothing was unbound. Check the list and confirm again.":
      "你的计算机上又多了别人的 Agent，这次没有解绑任何 Agent。请看一下列表，再确认一次。",
};
