// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.24.0-source.1 en.ts / zh-cn.ts wording verbatim: the server v1.24 compatibility patch.
const Map<String, String> zhCatalogUpstream124 = <String, String>{
  // Two-step verification sign-in (auth.secondFactor.*, SecondFactorSignInStep).
  "Two-step verification": "两步验证",
  "Signing in as {email}.": "正在登录 {email}。",
  "Signing in as {email}. This sign-in expires at {time}.":
      "正在登录 {email}。这次登录在 {time} 失效。",
  "Authenticator code": "验证器验证码",
  "Enter the 6-digit code from your authenticator app.": "输入验证器 App 里的 6 位验证码。",
  "Backup code": "备用码",
  "Each code works once. Capitals and the hyphen are optional.":
      "每个备用码只能用一次。大小写和连字符都可以不管。",
  "Use authenticator code": "使用验证器验证码",
  "Use a backup code": "使用备用码",
  "That code didn't work. Check your authenticator app and try again.":
      "验证码不对。请看一下验证器 App 再试。",
  "That backup code didn't work. Check it and try again.": "备用码不对。请检查后再试。",
  "That backup code was already used. Each code works once, so try another one.":
      "这个备用码已经用过了。每个只能用一次，请换一个。",
  "This sign-in has expired. Sign in again.": "这次登录已过期。请重新登录。",
  "Too many wrong codes for this sign-in. Sign in again.": "这次登录输错次数太多。请重新登录。",
  "Too many wrong tries. The second step is paused until {time}, and we've emailed you.":
      "输错次数太多。第二步暂停到 {time}，我们已发邮件通知你。",
  "Two-step verification isn't available right now. Try again later.":
      "两步验证暂时不可用。请稍后再试。",
  "This browser can't use passkeys. Use another way, or open Raft in a browser that has your passkey.":
      "这个浏览器不能使用通行密钥。请换一种方式，或在有你通行密钥的浏览器里打开 Raft。",
  "Back to sign in": "返回登录",
  "Sign-in failed": "登录失败",
  // Step-up for sensitive actions (settings.twoStep.*, VerifyItsYouDialog).
  "Verify it's you": "确认是你本人",
  "Changing how you sign in needs a fresh second step. It lasts 10 minutes.":
      "更改登录方式前需要重新验证一次，10 分钟内有效。",
  "This action needs your second step first.": "执行这个操作前，需要先通过第二步验证。",
  "This needs a fresh second step. It lasts 10 minutes.":
      "这个操作需要重新验证一次，10 分钟内有效。",
  "That code didn't work. Check the time on your phone is set automatically, then try the newest code.":
      "验证码不对。请确认手机时间设为自动，然后试试最新的验证码。",
  "Too many wrong codes. Try again after {time}.": "验证码输错次数太多。请在 {time} 之后再试。",
  "This sign-in can't be verified. Sign in again, then try once more.":
      "无法验证当前登录。请重新登录后再试一次。",
  // App private share links (settings.connectedApps.*, ConnectedAppShareLinks).
  "Let one other server install this app without listing it in the public marketplace. Each link works once, only on the server you name, for one of its owners or admins.":
      "让另一个服务器安装此应用，而无需在公共市场中列出。每个链接只能使用一次，只能安装到你指定的服务器，并且只能由该服务器的所有者或管理员使用。",
  "Target server": "目标服务器",
  "The server's slug, from its address after /s/. Raft doesn't say whether that server exists, so check the slug: a link for the wrong one never works.": "服务器的 slug，即其地址中 /s/ 之后的部分。Raft 不会告诉你该服务器是否存在，所以请核对 slug：slug 写错的链接永远无法使用。",
  "Enter a server slug: lowercase letters, digits and hyphens, starting with a letter.":
      "请输入服务器 slug：小写字母、数字和连字符，以字母开头。",
  "Link for {slug}. Copy it now: it's shown only once.":
      "{slug} 的链接。请现在复制：它只显示这一次。",
  "Expires {when}": "过期时间：{when}",
  "Revoke the link for {slug}": "撤销 {slug} 的链接",
  "Working...": "处理中…",
  "Create link": "创建链接",
  // Task v2: create a task from a message (task.create.fromMessageHeading).
  "Create tasks from message": "从消息创建任务",
  // Sign-up usage-data notice (auth.legalAcceptance.usageDataNotice, privacy 2026-10-14).
  "Raft collects usage data to improve the product. You can turn it off anytime in Settings.":
      "Raft 会收集使用数据来改进产品，你可以随时在设置中关闭。",
  // SSO_REQUIRED (pages.ssoCallback.title).
  "Sign in with SSO": "使用 SSO 登录",
  // 426 APP_UPDATE_REQUIRED (server legacyMobileOAuthUpgrade.ts zh-cn text).
  "This version of Raft is no longer supported. Download the latest version at app.raft.build/download, then sign in.":
      "当前版本过旧，请访问 app.raft.build/download 下载最新版 Raft 后再登录。",
  "Please refresh the page, or download the latest Raft at app.raft.build/download, to sign up.":
      "请刷新页面，或访问 app.raft.build/download 下载最新版 Raft 后再注册。",
};
