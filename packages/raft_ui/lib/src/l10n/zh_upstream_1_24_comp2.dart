// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.24.0-source.1 en.ts / zh-cn.ts wording verbatim: WP-COMP2 (runtime sign-in and sign-out on a
// Computer, provider connect, runtime account usage, Codex and Claude limit resets, Computer owner and
// other people's agents ids that WP-COMP1 part 3 did not carry, and the runtime availability ids).
const Map<String, String> zhCatalogUpstream124Comp2 = <String, String>{
  // machine.othersAgents.revokedNotRemoved
  "This computer's key is revoked and it's offline now, but it couldn't be removed from the list: {reason, select, agents {an agent is still on it. Move or remove that agent first.} migration {an agent is moving to or from it. Wait for the move to finish.} profile {an agent's settings still point to it. Move or remove that agent first.} other {something went wrong on our side.}} Trying again is safe.": "这台计算机的密钥已作废，现在已离线，但没能从列表里移除：{reason, select, agents {上面还有 Agent。请先迁走或删除它。} migration {有 Agent 正在迁入或迁出这台计算机。请等迁移完成。} profile {有 Agent 的设置还指向这台计算机。请先迁走或删除那个 Agent。} other {我们这边出了问题。}}可以放心再试一次。",
  // machine.runtimeAuth.notSignedIn
  "Signed out": "未登录",
  // machine.runtimeAuth.signedIn
  "Signed in": "已登录",
  // machine.runtimeAuth.dialogLabel
  "{runtime} sign-in": "{runtime} 登录状态",
  // machine.runtimeAuth.upgradeRequired
  "Upgrade this Computer to sign in from here": "升级这台 Computer 后即可在这里登录",
  // machine.runtimeAuth.unavailable.notInstalled
  "Install this runtime's command-line tool on the Computer, then use Rescan runtimes on the Computer's page.":
      "在这台 Computer 上安装这个运行时的命令行工具，然后在这台 Computer 的页面上点「重新检测运行时」。",
  // machine.runtimeAuth.unavailable.installOn
  "On macOS or Linux:": "macOS 或 Linux：",
  // machine.runtimeAuth.unavailable.versionUnsupported
  "Update this runtime's command-line tool on the Computer, then use Rescan runtimes on the Computer's page.":
      "在这台 Computer 上更新这个运行时的命令行工具，然后在这台 Computer 的页面上点「重新检测运行时」。",
  // machine.runtimeAuth.unavailable.unsupportedInstallation
  "Sign in to this runtime on the Computer itself.":
      "请直接在那台 Computer 上登录这个运行时。",
  // machine.runtimeAuth.notAttached
  "This Computer has no owner, so its runtimes can't be signed in from here":
      "这台 Computer 没有所有者，无法在这里登录它的运行时",
  // machine.runtimeAuth.thisComputer
  "this Computer": "这台 Computer",
  // machine.runtimeAuth.signIn.title
  "Sign in to {runtime}": "登录 {runtime}",
  // machine.runtimeAuth.signIn.regionPrompt
  "Choose your {runtime} account.": "选择你的 {runtime} 账号。",
  // machine.runtimeAuth.signIn.region.mainlandChina
  "Kimi Code (kimi.com/code)": "Kimi Code (kimi.com/code)",
  // machine.runtimeAuth.signIn.region.international
  "Kimi Code (kimi.ai/code)": "Kimi Code (kimi.ai/code)",
  // machine.runtimeAuth.signIn.regionSearch
  "Search regions": "搜索地区",
  // machine.runtimeAuth.signIn.starting
  "Starting sign-in on {computer}…": "正在 {computer} 上开始登录…",
  // machine.runtimeAuth.signIn.authUrlHint
  "Open the sign-in page and finish signing in to {runtime} there.":
      "打开登录页面，在那里完成 {runtime} 的登录。",
  // machine.runtimeAuth.signIn.openPage
  "Open sign-in page": "打开登录页面",
  // machine.runtimeAuth.signIn.deviceCodeHint
  "Open this page and enter the code below:": "打开这个页面，输入下面的代码：",
  // machine.runtimeAuth.signIn.copyCode
  "Copy code": "复制代码",
  // machine.runtimeAuth.signIn.deviceCodeExpiry
  "The code expires in {minutes, plural, one {# minute} other {# minutes}}.":
      "代码 {minutes} 分钟后失效。",
  // machine.runtimeAuth.signIn.codeLabel
  "Paste the code shown after signing in": "粘贴登录后显示的代码",
  // machine.runtimeAuth.signIn.codeHint
  "Once you finish signing in, the page shows a code. Paste it here.":
      "登录完成后，页面会显示一段代码，把它粘贴到这里。",
  // machine.runtimeAuth.signIn.codeHintAntigravity
  "After signing in with Google, paste the code shown, or the full address your browser landed on.":
      "用 Google 登录后，粘贴页面显示的代码，或浏览器最后停留页面的完整地址。",
  // machine.runtimeAuth.signIn.codeRetry
  "That code was not accepted, paste it again": "这段代码没有通过，请重新粘贴",
  // machine.runtimeAuth.signIn.codeInvalid
  "Paste the whole code from the sign-in page.": "请粘贴登录页面上的完整代码。",
  // machine.runtimeAuth.signIn.checkingCode
  "Checking the code…": "正在验证代码…",
  // machine.runtimeAuth.signIn.success
  "{runtime} is signed in on {computer}": "{runtime} 已在 {computer} 上登录",
  // machine.runtimeAuth.error.computerOffline
  "This Computer is offline. Connect it, then try again.":
      "这台 Computer 已离线。连接后再试一次。",
  // machine.runtimeAuth.error.busy
  "A sign-in is already running on this Computer.": "这台 Computer 上已经有一个登录在进行。",
  // machine.runtimeAuth.error.rateLimited
  "Too many sign-in attempts on this Computer. Try again in a few minutes.":
      "这台 Computer 上的登录尝试太多了，请过几分钟再试。",
  // machine.runtimeAuth.error.forbidden
  "Only the person who connected this Computer, or an owner or admin, can sign its runtimes in or out.":
      "只有连接这台 Computer 的人，或服务器所有者、管理员，才能为它的运行时登录或退出登录。",
  // machine.runtimeAuth.error.loginGone
  "This sign-in has ended. Start it again.": "这次登录已经结束，请重新开始。",
  // machine.runtimeAuth.error.notFound
  "This Computer or runtime wasn't found.": "找不到这台 Computer 或这个运行时。",
  // machine.runtimeAuth.signIn.codeSendFailed
  "Couldn't send the code. Try again.": "没能发送代码，请再试一次。",
  // machine.runtimeAuth.signIn.sendingCode
  "Sending the code": "正在发送代码",
  // machine.runtimeAuth.error.startFailed
  "The sign-in could not start. Try again.": "没能开始登录，请再试一次。",
  // machine.runtimeAuth.error.cancelled
  "The sign-in was cancelled.": "登录已取消。",
  // machine.runtimeAuth.error.versionUnsupported
  "{runtime} on this Computer is too old to sign in from the web; update it there.":
      "这台 Computer 上的 {runtime} 版本太旧，无法从网页登录；请在那台 Computer 上更新它。",
  // machine.runtimeAuth.error.notInstalled
  "{runtime} is not installed on this Computer.":
      "这台 Computer 上没有安装 {runtime}。",
  // machine.runtimeAuth.error.unsupportedInstallation
  "This {runtime} installation can't be signed in from the web. Sign in on the Computer itself.":
      "这个 {runtime} 安装无法从网页登录，请直接在那台 Computer 上登录。",
  // machine.runtimeAuth.error.timedOut
  "The sign-in took too long and stopped. Try again.": "登录等待太久，已经停止。请再试一次。",
  // machine.runtimeAuth.error.rejected
  "{runtime} did not accept the sign-in. Try again.":
      "{runtime} 没有接受这次登录，请再试一次。",
  // machine.runtimeAuth.error.notLoggedIn
  "The sign-in finished, but {runtime} is still not signed in. Try again.":
      "登录流程结束了，但 {runtime} 仍未登录。请再试一次。",
  // machine.runtimeAuth.error.interactionFailed
  "{runtime} asked for something this page can't show. Sign in on the Computer itself.":
      "{runtime} 需要的操作无法在这个页面上显示，请直接在那台 Computer 上登录。",
  // machine.runtimeAuth.error.processFailed
  "{runtime} stopped before the sign-in finished. Try again.":
      "{runtime} 在登录完成前退出了，请再试一次。",
  // machine.runtimeAuth.signOut.title
  "Sign out of {runtime}?": "退出 {runtime} 登录？",
  // machine.runtimeAuth.signOut.description
  "{runtime} will be signed out on {computer}.":
      "将在 {computer} 上退出 {runtime} 的登录。",
  // machine.runtimeAuth.signOut.agents
  "{count, plural, one {This agent on this Computer uses {runtime}. It keeps running, but its next start can't authenticate until someone signs in again:} other {These # agents on this Computer use {runtime}. They keep running, but their next start can't authenticate until someone signs in again:}}": "{count, plural, other {这台 Computer 上有 # 个 Agent 使用 {runtime}。它们会继续运行，但在有人重新登录之前，下次启动时会认证失败：}}",
  // machine.runtimeAuth.signOut.noAgents
  "No agents on this Computer use {runtime}.":
      "这台 Computer 上没有 Agent 使用 {runtime}。",
  // machine.runtimeAuth.signOut.stillLoggedIn
  "Still signed in: an API key in that Computer's environment is used":
      "仍处于登录状态：那台 Computer 的环境变量里有 API 密钥在生效",
  // machine.runtimeAuth.signOut.stillLoggedInAntigravity
  "Still signed in: another sign-in is active on that Computer, such as GEMINI_API_KEY in its environment or a sign-in kept in its system keyring. Remove it on that Computer.": "仍处于登录状态：那台 Computer 上还有其他登录在生效，例如环境变量里的 GEMINI_API_KEY，或系统钥匙串里保存的登录。请在那台 Computer 上移除它。",
  // machine.runtimeAuth.signOut.stillLoggedInGrok
  "Still signed in: another xAI sign-in is active on that Computer, such as an API key in its environment. Remove it on that Computer.":
      "仍处于登录状态：那台 Computer 上还有其他 xAI 登录在生效，例如环境变量里的 API 密钥。请在那台 Computer 上移除它。",
  // machine.runtimeAuth.signOut.timedOut
  "The Computer did not answer in time. Try again.": "Computer 没有及时响应，请再试一次。",
  // machine.runtimeAuth.signOut.failed
  "{runtime} could not be signed out. Try again.": "没能退出 {runtime} 的登录，请再试一次。",
  // machine.runtimeAuth.provider.configured
  "Provider configured": "已配置服务商",
  // machine.runtimeAuth.provider.notConfigured
  "No provider configured": "未配置服务商",
  // machine.runtimeAuth.provider.connectAction
  "Connect provider": "连接服务商",
  // machine.runtimeAuth.provider.dialogLabel
  "{runtime} provider": "{runtime} 服务商",
  // machine.runtimeAuth.provider.upgradeRequired
  "Upgrade this Computer to connect a provider from here":
      "升级这台 Computer 后即可在这里连接服务商",
  // machine.runtimeAuth.provider.notAttached
  "This Computer has no owner, so its runtimes can't be connected from here":
      "这台 Computer 没有所有者，无法在这里为它的运行时连接服务商",
  // machine.runtimeAuth.provider.title
  "Connect {runtime} to a provider": "为 {runtime} 连接服务商",
  // machine.runtimeAuth.provider.loading
  "Reading the providers on {computer}…": "正在读取 {computer} 上的服务商…",
  // machine.runtimeAuth.provider.choosePrompt
  "Choose the provider your API key is from.": "选择你的 API 密钥所属的服务商。",
  // machine.runtimeAuth.provider.search
  "Search providers": "搜索服务商",
  // machine.runtimeAuth.provider.noMatch
  "No matching providers": "没有匹配的服务商",
  // machine.runtimeAuth.provider.empty
  "{runtime} on this Computer lists no providers.":
      "这台 Computer 上的 {runtime} 没有列出任何服务商。",
  // machine.runtimeAuth.provider.alreadyConfigured
  "Already configured on this Computer": "已在这台 Computer 上配置",
  // machine.runtimeAuth.provider.group.thirdParty
  "Other providers": "其他服务商",
  // machine.runtimeAuth.provider.endpointLabel
  "Endpoint": "接入点",
  // machine.runtimeAuth.provider.endpointPlaceholder
  "Choose an endpoint": "选择接入点",
  // machine.runtimeAuth.provider.endpointHint
  "Choose the one your API key belongs to.": "选择你的 API 密钥所属的那个。",
  // machine.runtimeAuth.provider.baseUrlHint
  "The address of your server's OpenAI-compatible API.":
      "你的服务器的 OpenAI 兼容 API 地址。",
  // machine.runtimeAuth.provider.modelHint
  "The model's name as your provider spells it.": "服务商使用的模型名称。",
  // machine.runtimeAuth.provider.scopeNote
  "Saved in the {runtime} settings of the account that runs {computer}. It applies to all its {runtime} agents, and also to {runtime} used outside Raft by that account.": "保存到运行 {computer} 的账户的 {runtime} 设置中，对它的所有 {runtime} Agent 生效，也对这个账户在 Raft 之外使用的 {runtime} 生效。",
  // machine.runtimeAuth.provider.connecting
  "Connecting": "正在连接",
  // machine.runtimeAuth.provider.success
  "Saved on this Computer. {runtime} checks the key when an agent runs.":
      "已保存在这台 Computer 上。{runtime} 会在 Agent 运行时检查这个密钥。",
  // machine.runtimeAuth.provider.error.forbidden
  "Only the person who connected this Computer, or an owner or admin, can connect its runtimes to a provider.":
      "只有连接这台 Computer 的人，或服务器所有者、管理员，才能为它的运行时连接服务商。",
  // machine.runtimeAuth.provider.error.rateLimited
  "Too many attempts on this Computer. Try again in a few minutes.":
      "这台 Computer 上的尝试太多了，请过几分钟再试。",
  // machine.runtimeAuth.provider.error.requestFailed
  "Couldn't reach the Computer. Try again.": "无法连接到 Computer，请再试一次。",
  // machine.runtimeAuth.provider.error.invalidInput
  "Check the details and try again.": "请检查填写的内容后再试一次。",
  // machine.runtimeAuth.provider.error.rejected
  "{runtime} did not accept these settings. Check the key and try again.":
      "{runtime} 没有接受这些设置。请检查密钥后再试一次。",
  // machine.runtimeAuth.provider.error.listTimedOut
  "{runtime} took too long to answer. Try again.": "{runtime} 响应太慢，请再试一次。",
  // machine.runtimeAuth.provider.error.connectTimedOut
  "{runtime} took too long to answer. The key may or may not be saved: check the card, then try again if needed.":
      "{runtime} 响应太慢，密钥可能已保存，也可能没有：请先查看卡片，需要的话再试一次。",
  // machine.runtimeAuth.provider.error.processFailed
  "{runtime} could not run on this Computer. Try again.":
      "{runtime} 无法在这台 Computer 上运行，请再试一次。",
  // machine.runtimeAuth.provider.error.invalidResponse
  "{runtime} answered in a way this page can't read. Update {runtime} on the Computer, then try again.":
      "{runtime} 的响应无法读取。请在 Computer 上更新 {runtime} 后再试一次。",
  // machine.runtimeAuth.provider.error.unsupported
  "{runtime} on this Computer can't be connected from the web.":
      "这台 Computer 上的 {runtime} 不能从网页连接。",
  // machine.runtimeAuth.provider.error.busy
  "Another provider is being connected on this Computer. Try again in a moment.":
      "这台 Computer 上正在连接另一个服务商，请稍后再试。",
  // machine.runtimeAuth.provider.field.apiKey
  "Paste the whole API key, with no spaces.": "请粘贴完整的 API 密钥，不要包含空格。",
  // machine.runtimeAuth.provider.field.baseUrl
  "Enter an http or https URL.": "请输入 http 或 https 地址。",
  // machine.runtimeAuth.provider.field.model
  "Enter one model name, with no spaces.": "请输入一个模型名称，不要包含空格。",
  // machine.runtimeAuth.pi.noProviders
  "No provider signed in on this Computer": "这台 Computer 上没有已登录的提供商",
  // machine.runtimeAuth.pi.addProvider
  "Add provider": "添加提供商",
  // machine.runtimeAuth.pi.method.subscription
  "Subscription account": "订阅账户",
  // machine.runtimeAuth.pi.removeKey.title
  "Remove the {runtime} key?": "移除 {runtime} 密钥？",
  // machine.runtimeAuth.pi.removeKey.description
  "The {runtime} key will be removed from {piRuntime} on {computer}.":
      "{computer} 上 {piRuntime} 的 {runtime} 密钥将被移除。",
  // machine.runtimeAuth.pi.signOut.description
  "{runtime} will be signed out of {piRuntime} on {computer}. Its other providers stay signed in.":
      "{computer} 上的 {piRuntime} 将退出 {runtime} 的登录，其他提供商仍保持登录。",
  // machine.runtimeAuth.pi.signOut.agents
  "{count, plural, one {This {piRuntime} agent on this Computer may use {runtime}. It keeps running, but can't use {runtime} until someone adds it again:} other {These # {piRuntime} agents on this Computer may use {runtime}. They keep running, but can't use {runtime} until someone adds it again:}}": "{count, plural, other {这台 Computer 上有 # 个 {piRuntime} Agent 可能在使用 {runtime}。它们会继续运行，但在有人重新添加之前无法使用 {runtime}：}}",
  // machine.runtimeAuth.pi.title
  "Add a provider to {runtime}": "为 {runtime} 添加提供商",
  // machine.runtimeAuth.pi.choosePrompt
  "Choose a provider for {piRuntime} on {computer}. Sign in with your account, or paste an API key.":
      "为 {computer} 上的 {piRuntime} 选择一个提供商。用你的账户登录，或粘贴 API 密钥。",
  // machine.runtimeAuth.pi.group.account
  "Sign in with an account": "用账户登录",
  // machine.runtimeAuth.pi.group.apiKey
  "Use an API key": "使用 API 密钥",
  // machine.runtimeAuth.pi.flow.deviceCode
  "Sign in with a device code": "用设备代码登录",
  // machine.runtimeAuth.pi.flow.pasteCode
  "Sign in, then paste a code": "登录后粘贴代码",
  // machine.runtimeAuth.pi.flow.pasteAddress
  "Sign in, then paste the page address": "登录后粘贴页面地址",
  // machine.runtimeAuth.pi.flow.computerOnly
  "Needs a browser on the Computer itself: sign in there":
      "需要在这台 Computer 上的浏览器登录：请在那里登录",
  // machine.runtimeAuth.pi.key.moreFields
  "Asks for more than a key: set it up on the Computer":
      "需要的不只是密钥：请在这台 Computer 上设置",
  // machine.runtimeAuth.pi.key.outside
  "Set up outside Pi, on the Computer": "在 Pi 之外设置，在这台 Computer 上",
  // machine.runtimeAuth.pi.key.chosen
  "API key · {provider}": "API 密钥 · {provider}",
  // machine.runtimeAuth.pi.key.refused
  "Pi would run a key that starts with ! or fill in a \$ name. Paste the key itself.":
      "Pi 会把以 ! 开头的密钥当作命令运行，或把 \$ 名称替换为环境变量。请粘贴密钥本身。",
  // machine.runtimeAuth.pi.key.hint
  "Find it in your {provider} account settings.": "可在你的 {provider} 账户设置中找到。",
  // machine.runtimeAuth.pi.key.success
  "Saved on this Computer. Pi checks the key when an agent uses {runtime}.":
      "已保存到这台 Computer。Agent 使用 {runtime} 时，Pi 会检查这个密钥。",
  // machine.runtimeAuth.pi.signedIn
  "Signed in on this Computer": "已在这台 Computer 上登录",
  // machine.runtimeAuth.pi.scopeNote
  "Saved on this Computer for every {piRuntime} agent of this account, and for {piRuntime} run outside Raft.": "保存在这台 Computer 上，对这个账户的所有 {piRuntime} Agent 生效，也对在 Raft 之外运行的 {piRuntime} 生效。",
  // machine.runtimeAuth.pi.paste.addressLabel
  "Paste the address of the page you land on": "粘贴你最终到达的页面地址",
  // machine.runtimeAuth.pi.paste.addressHint
  "After signing in, your browser lands on a page that won't load. Paste the full address from the address bar here.":
      "登录后，浏览器会跳转到一个无法打开的页面。把地址栏中的完整地址粘贴到这里。",
  // machine.runtimeAuth.pi.paste.codeHint
  "After signing in, the page shows a code like abc…#xyz. Paste all of it.":
      "登录后，页面会显示一个类似 abc…#xyz 的代码。请完整粘贴。",
  // machine.runtimeAuth.pi.error.busy
  "Another Pi sign-in is in progress on this Computer, for this or another provider. Finish or cancel it, then try again.":
      "这台 Computer 上已有另一个 Pi 登录正在进行（这个或其他提供商的）。请先完成或取消它，再重试。",
  // machine.runtimeAuth.opencode.versionUnsupported
  "Upgrade OpenCode on the Computer to 2.x, then use Rescan runtimes on the Computer's page.":
      "在这台 Computer 上把 OpenCode 升级到 2.x，然后在这台 Computer 的页面上点「重新检测运行时」。",
  // machine.runtimeAuth.opencode.flow.link
  "Sign in on the provider's page": "在提供商的页面上登录",
  // machine.runtimeAuth.opencode.methodLabel
  "{provider} · {method}": "{provider} · {method}",
  // machine.runtimeAuth.opencode.key.refused
  "OpenCode can't take this as a key. Paste the key itself, not a reference to an environment variable or a file.":
      "OpenCode 无法把它当作密钥。请粘贴密钥本身，而不是对环境变量或文件的引用。",
  // machine.runtimeAuth.opencode.key.outside
  "Set up outside OpenCode, on the Computer": "在 OpenCode 之外设置，在这台 Computer 上",
  // machine.runtimeAuth.opencode.key.success
  "Saved on this Computer. OpenCode checks the key when an agent uses {runtime}.":
      "已保存到这台 Computer。Agent 使用 {runtime} 时，OpenCode 会检查这个密钥。",
  // machine.runtimeAuth.opencode.error.busy
  "Another OpenCode sign-in is in progress on this Computer, for this or another provider. Finish or cancel it, then try again.":
      "这台 Computer 上已有另一个 OpenCode 登录正在进行（这个或其他提供商的）。请先完成或取消它，再重试。",
  // machine.runtimeAuth.opencode.error.signInInProgress
  "A sign-in is in progress on this Computer. Finish or cancel it, then try again.":
      "这台 Computer 上有登录正在进行。请先完成或取消它，再重试。",
  // machine.runtimeAuth.error.loopbackRequired
  "This way of signing in to {runtime} needs a browser on the Computer itself. Choose another way, or sign in on the Computer.":
      "用这种方式登录 {runtime} 需要在这台 Computer 上的浏览器。请换一种方式，或在这台 Computer 上登录。",
  // machine.runtimeUsage.line.fiveHour
  "5h": "5 小时",
  // machine.runtimeUsage.line.week
  "Week": "本周",
  // machine.runtimeUsage.line.used
  "{window} {percent}% used": "{window} 已用 {percent}%",
  // machine.runtimeUsage.line.limit
  "{window} used up · back {reset}": "{window} 已用完 · {reset}恢复",
  // machine.runtimeUsage.line.limitNoReset
  "{window} used up": "{window} 已用完",
  // machine.runtimeUsage.line.all
  "{plan} · {windows}": "{plan} · {windows}",
  // machine.runtimeUsage.line.pair
  "{first} · {second}": "{first} · {second}",
  // machine.runtimeUsage.windowUsedUp
  "Used up · back {reset}": "已用完 · {reset}恢复",
  // machine.runtimeUsage.windowUsedUpResetUnavailable
  "Used up": "已用完",
  // machine.runtimeUsage.updated
  "Updated {updated}": "{updated}更新",
  // machine.runtimeUsage.limitResets.left
  "{count, plural, one {# reset left} other {# resets left}}":
      "{count, plural, other {剩余 # 次重置}}",
  // machine.runtimeUsage.limitResets.none
  "No resets left": "没有剩余重置",
  // machine.runtimeUsage.limitReset.action
  "Use a reset": "使用重置",
  // machine.runtimeUsage.limitReset.title
  "Use a limit reset?": "使用一次额度重置？",
  // machine.runtimeUsage.limitReset.description
  "This uses one of {account}'s resets to restore its {runtime} usage limits now. {count, plural, one {# reset} other {# resets}} left.": "这会用掉 {account} 的一次重置，立即恢复它的 {runtime} 用量额度。剩余 {count, plural, other {# 次}}。",
  // machine.runtimeUsage.limitReset.accountFallback
  "this account": "这个账户",
  // machine.runtimeUsage.limitReset.done
  "Limits reset.": "额度已重置。",
  // machine.runtimeUsage.limitReset.nothingToReset
  "Nothing to reset right now. No reset was used.": "现在没有需要重置的额度，未使用重置。",
  // machine.runtimeUsage.limitReset.noReset
  "No resets left.": "没有剩余的重置。",
  // machine.runtimeUsage.limitReset.alreadyRedeemed
  "This reset already went through.": "这次重置已经生效。",
  // machine.runtimeUsage.limitReset.unknown
  "We couldn't confirm whether a reset was used. Try again — it won't use a second one.":
      "无法确认是否用掉了一次重置。请再试一次，不会再用掉第二次。",
  // machine.runtimeUsage.limitReset.reauth
  "Sign in to {runtime} again on this Computer. No reset was used.":
      "请在这台 Computer 上重新登录 {runtime}。未使用重置。",
  // machine.runtimeUsage.limitReset.unsupported
  "{runtime} on this Computer can't use a limit reset from here. No reset was used.":
      "这台 Computer 上的 {runtime} 无法在这里使用额度重置。未使用重置。",
  // machine.runtimeUsage.limitReset.forbidden
  "Only the person who connected this Computer, or an owner or admin, can use its resets.":
      "只有连接这台 Computer 的人，或服务器所有者、管理员，才能使用它的重置。",
  // machine.runtimeUsage.limitReset.upgradeRequired
  "Upgrade this Computer to use a reset from here.":
      "升级这台 Computer 后即可在这里使用重置。",
  // machine.runtimeUsage.limitReset.rateLimited
  "Too many attempts on this Computer. No reset was used. Try again in a few minutes.":
      "这台 Computer 上的尝试次数过多。没有用掉任何重置，请几分钟后再试。",
  // machine.runtimeUsage.limitReset.refused
  "This request was refused before it reached the Computer. No reset was used.":
      "请求在到达 Computer 之前就被拒绝了。没有用掉任何重置。",
  // machine.runtimeUsage.claudeReset.disabled
  "Claude limit resets can't be used here. No reset was used.":
      "这里无法使用 Claude 额度重置。没有用掉任何重置。",
  // machine.runtimeUsage.claudeReset.viewAction
  "View available resets": "查看可用的重置",
  // machine.runtimeUsage.claudeReset.useFiveHourAction
  "Use 5-hour reset": "使用 5 小时重置",
  // machine.runtimeUsage.claudeReset.ownerOnly
  "Only the person who connected this Computer can use its Claude resets.":
      "只有连接这台 Computer 的人，才能使用它的 Claude 额度重置。",
  // machine.runtimeUsage.claudeReset.kind.five_hour
  "5-hour reset": "5 小时重置",
  // machine.runtimeUsage.claudeReset.kind.weekly
  "weekly reset": "每周重置",
  // machine.runtimeUsage.claudeReset.kind.fable
  "Fable reset": "Fable 重置",
  // machine.runtimeUsage.claudeReset.kind.full
  "full reset": "全部重置",
  // machine.runtimeUsage.claudeReset.dialogTitle
  "Claude limit resets": "Claude 额度重置",
  // machine.runtimeUsage.claudeReset.listLabel
  "Limit resets": "额度重置",
  // machine.runtimeUsage.claudeReset.reading
  "Reading your resets in Claude Code on this Computer. This can take up to a minute.":
      "正在通过这台 Computer 上的 Claude Code 读取你的重置，最多可能需要一分钟。",
  // machine.runtimeUsage.claudeReset.readFailed
  "Couldn't read your resets. Try again.": "无法读取你的重置，请再试一次。",
  // machine.runtimeUsage.claudeReset.readTimeout
  "The Computer didn't answer in time. Try again.": "Computer 没有及时响应，请再试一次。",
  // machine.runtimeUsage.claudeReset.readFiveHourSpent
  "Opening the list used this account's 5-hour reset: it has only Claude's older once-a-week 5-hour reset.":
      "打开列表时用掉了这个账号的 5 小时重置：它只有 Claude 旧版的每周一次 5 小时重置。",
  // machine.runtimeUsage.claudeReset.legacy
  "This account has only Claude's older once-a-week 5-hour reset, so there is nothing else to list. When you reach your 5-hour limit, use it with Use 5-hour reset on the card.":
      "这个账号只有 Claude 旧版的每周一次 5 小时重置，没有其他可列出的。达到 5 小时上限时，用卡片上的“使用 5 小时重置”。",
  // machine.runtimeUsage.claudeReset.atLimitHint
  "At your 5-hour limit, only a 5-hour reset can be used from here. To use a weekly, Fable or full reset now, go to Settings › Usage on claude.ai.": "达到 5 小时上限时，这里只能使用 5 小时重置。想现在使用每周、Fable 或全部重置，请到 claude.ai 的 Settings › Usage。",
  // machine.runtimeUsage.claudeReset.useSelectedAction
  "Use this reset": "使用这个重置",
  // machine.runtimeUsage.claudeReset.consentTitle
  "Check your resets at the 5-hour limit?": "要在 5 小时上限时查看重置吗？",
  // machine.runtimeUsage.claudeReset.consentBody
  "You're at your 5-hour limit. Checking or using a reset opens Claude Code on this Computer for a moment and sends one small request, which counts against your 5-hour window. On some Claude accounts (those with only the older once-a-week 5-hour reset), just opening Claude Code's reset list now uses that 5-hour reset right away, without asking. Continue only if that's OK.": "你已达到 5 小时上限。查看或使用重置时，会在这台 Computer 上短暂打开 Claude Code，并发送一个小请求，计入你的 5 小时额度。部分 Claude 账号（只有旧版每周一次 5 小时重置的）此时只要打开 Claude Code 的重置列表，就会立即用掉这次 5 小时重置，不会询问。只有你能接受时才继续。",
  // machine.runtimeUsage.claudeReset.confirmTitle
  "Use your {kind}?": "使用你的{kind}？",
  // machine.runtimeUsage.claudeReset.confirmBody
  "Claude Code on this Computer uses {account}'s {kind} now. This can't be undone.":
      "这台 Computer 上的 Claude Code 会立即使用 {account} 的{kind}。此操作无法撤销。",
  // machine.runtimeUsage.claudeReset.confirm
  "Use {kind}": "使用{kind}",
  // machine.runtimeUsage.claudeReset.state.left
  "{count, plural, one {# left} other {# left}}":
      "{count, plural, other {剩余 # 次}}",
  // machine.runtimeUsage.claudeReset.state.useBy
  "use by {date}": "{date} 前使用",
  // machine.runtimeUsage.claudeReset.state.unknown
  "Couldn't read": "读取失败",
  // machine.runtimeUsage.claudeReset.state.notChecked
  "Not checked yet": "尚未检查",
  // machine.runtimeUsage.claudeReset.state.notOffered
  "Not on this account": "此账号没有",
  // machine.runtimeUsage.claudeReset.done
  "Used your {kind}.": "已使用你的{kind}。",
  // machine.runtimeUsage.claudeReset.noReset
  "No {kind} to use. No reset was used.": "没有可用的{kind}。没有用掉任何重置。",
  // machine.runtimeUsage.claudeReset.fiveHourSpent
  "Your 5-hour reset was used instead of the {kind}: this account has only Claude's older once-a-week 5-hour reset.":
      "用掉的是 5 小时重置，而不是{kind}：这个账号只有 Claude 旧版的每周一次 5 小时重置。",
  // machine.runtimeUsage.claudeReset.unknown
  "We couldn't confirm whether a reset was used. Check /usage in Claude Code before trying again.":
      "无法确认是否用掉了重置。再次尝试前，请先在 Claude Code 里查看 /usage。",
  // machine.runtimeUsage.claudeReset.timeout
  "The Computer didn't answer in time, so it's not known whether a reset was used. Check /usage in Claude Code before trying again.":
      "Computer 没有及时响应，不确定是否用掉了重置。再次尝试前，请先在 Claude Code 里查看 /usage。",
  // machine.runtimeUsage.claudeReset.notAttempted
  "Nothing was used: the Computer was busy or ran out of time. Try again.":
      "没有用掉任何重置：Computer 正忙或时间不够。请再试一次。",
  // machine.runtimeUsage.claudeReset.notAttemptedAtLimit
  "Nothing was used. At your 5-hour limit, only a 5-hour reset can be used from here. To use your {kind} now, go to Settings › Usage on claude.ai.": "没有用掉任何重置。达到 5 小时上限时，这里只能使用 5 小时重置。想现在使用{kind}，请到 claude.ai 的 Settings › Usage。",
  // machine.runtimeUsage.claudeReset.notSupportedHere
  "Claude limit resets aren't supported on this Computer. No reset was used.":
      "这台 Computer 不支持 Claude 额度重置。未使用重置。",
  // machine.runtimeUsage.claudeReset.notAvailableYet
  "Your {kind} isn't available for this account on this Computer yet. No reset was used.":
      "这台 Computer 上的这个账号暂时还不能使用{kind}。未使用重置。",
  // runtime.availability.notSignedIn
  " (not signed in)": "（未登录）",
  // runtime.availability.needsNewerComputer
  "Update Raft Computer to use {runtime}.": "更新 Raft Computer 即可使用 {runtime}。",
  // runtime.picker.notSignedIn
  "{runtime} is not signed in on {computer}.": "{runtime} 在 {computer} 上没有登录。",
};
