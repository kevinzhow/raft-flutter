// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.24.0-source.1 en.ts / zh-cn.ts wording verbatim: WP-APPLOGIN (sign-in pages).
const Map<String, String> zhCatalogUpstream124Applogin = <String, String>{
  // Social sign-in failures (auth.desktopSignIn.*, utils/desktopOAuth.ts).
  "This email already has a Raft account created another way. Sign in with email and password (or an email code) first, then link {provider} in Settings → Connected accounts.": "该邮箱已有一个用其他方式创建的 Raft 账号。请先用邮箱和密码（或邮箱验证码）登录，再到「设置 → 已关联账号」中关联 {provider}。",
  "Your {provider} account isn't registered with Raft yet and sign-up is currently closed. Ask for an invite, or sign in with an existing account.":
      "你的 {provider} 账号还没有注册过 Raft，而目前已关闭新用户注册。请获取邀请，或用已有账号登录。",
  "The sign-in request expired before the browser finished. Please try again.":
      "浏览器还没完成，这次登录请求就已过期。请重试。",
  "That sign-in request was already used or cancelled. Please try again.":
      "这次登录请求已被使用或已取消。请重试。",
  "{provider} sign-in was cancelled before Raft was authorized.":
      "在授权 Raft 之前，{provider} 登录已被取消。",
  "{provider} sign-in was denied at the provider. Try again if that was unintended.":
      "{provider} 拒绝了这次登录。如果是误操作，请重试。",
  "Raft couldn't finish verifying your {provider} account. Please try again; if it keeps failing, an unverified email at {provider} is one possible cause.":
      "Raft 没能完成对你 {provider} 账号的核实。请重试；如果反复失败，一个可能的原因是你在 {provider} 的邮箱尚未验证。",
  "Couldn't complete {provider} sign-in — please try again, or sign in with email and password.":
      "没能完成 {provider} 登录，请重试，或用邮箱和密码登录。",
  "Couldn't complete {provider} sign-in — please try again, or sign in with email and password. (reason: {reason})":
      "没能完成 {provider} 登录，请重试，或用邮箱和密码登录。（原因：{reason}）",
  // Settings "Connect" failures (pages.socialCallback.link*).
  "Verify your Raft account email first. Until it's verified, you can only connect a {provider} account whose primary email matches your Raft email.":
      "请先验证你的 Raft 账户邮箱。验证之前，只能连接主邮箱与 Raft 邮箱相同的 {provider} 账号。",
  "This {provider} account is already connected to another Raft account. Disconnect it there first, then try again.":
      "这个 {provider} 账号已经连接到另一个 Raft 账户。请先在那个账户里断开它，再回来重试。",
  "This {provider} account is already used by another Raft account, so it couldn't be connected here.":
      "这个 {provider} 账号已被另一个 Raft 账户使用，没能连接到这里。",
  // EmailVerificationPage (pages.emailVerification.*).
  "Can't find it? Check your spam folder.": "没收到？看看垃圾邮件文件夹。",
  "Paste link": "粘贴链接",
  "Paste the verification link": "粘贴验证链接",
  // ResetPasswordPage (pages.resetPassword.deviceLoginNotice).
  "Setting a new password signs you out everywhere. Computers and agent credentials set up through a device login (Raft Computer, the raft CLI) stop working too, so you'll need to log in on them again.": "设置新密码会让你在所有设备上退出登录。通过设备登录（Raft Computer、raft CLI）设置的电脑连接和 Agent 凭证也会失效，需要在这些地方重新登录。",
  // TextLinkExternalIcon label (common.opensInNewTab), read after a link that leaves Raft.
  "(opens in a new tab)": "（在新标签页打开）",
};
