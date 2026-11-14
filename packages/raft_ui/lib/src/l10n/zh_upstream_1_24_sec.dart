// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.24.0-source.1 en.ts / zh-cn.ts wording verbatim: WP-SEC (two-step verification, recovery, passkeys).
const Map<String, String> zhCatalogUpstream124Sec = <String, String>{
  // Sign-in second step (auth.secondFactor.*).
  "Can't use any of these?": "这些都用不了？",
  // Reset by email (auth.recovery.*).
  "Reset requested": "已申请重置",
  "Reset ready": "重置可以完成了",
  "Too many requests. Try again later.": "请求次数太多，请稍后再试。",
  "The email wasn't sent. Try again.": "邮件没有发出，请再试一次。",
  "This reset can't be finished now: it was cancelled, has lapsed, or isn't ready yet. Use your second step, or start a new reset.":
      "现在无法完成这次重置：它已取消、已过期，或还没到时间。请用第二步验证，或重新申请重置。",
  "Someone asked to reset two-step verification on your account, and the next sign-in can finish it without the second step, until {time}. Not you? Cancel the reset and change your password.":
      "有人申请重置你账户的两步验证，下次登录时可以不经第二步完成重置，截止到 {time}。不是你本人？请取消重置并修改密码。",
  "Someone asked to reset two-step verification on your account. Signing in can finish it after {time}. Not you? Cancel the reset.":
      "有人申请重置你账户的两步验证。{time} 之后，登录时可以完成重置。不是你本人？请取消重置。",
  "This account has no password yet: set one with Forgot Password on the sign-in page, then sign in to finish it.":
      "这个账户还没有密码：请先在登录页用“忘记密码”设置一个，再登录完成重置。",
  "Cancel reset": "取消重置",
  "Reset cancelled. Two-step verification stays on, and we emailed you.":
      "已取消重置。两步验证保持开启，我们已发邮件通知你。",
  "The reset wasn't cancelled. Try again.": "重置没有取消，请再试一次。",
  "Your reset is ready": "重置可以完成了",
  "The two-step verification reset you asked for by email can finish now, without your second step.":
      "你通过邮件申请的两步验证重置现在可以完成，不需要第二步。",
  "Finish reset": "完成重置",
  "Can't verify?": "无法验证？",
  "No backup codes?": "没有备用码？",
  "If an account uses this email, we sent it a link to reset two-step verification.":
      "如果有账户使用这个邮箱，我们已向它发送重置两步验证的链接。",
  "The link works for 30 minutes. The 72-hour wait starts when you open it.":
      "链接 30 分钟内有效。72 小时从你打开链接时开始计算。",
  "We can email you a link that resets two-step verification. For your safety, the reset takes 72 hours, and you can cancel it from any browser where you're still signed in.":
      "我们可以发邮件给你一个重置两步验证的链接。为了安全，重置要等 72 小时，期间可以在任何仍登录着的浏览器里取消。",
  "Reset by email": "通过邮件重置",
  "A backup code works in place of your authenticator app or passkey.":
      "备用码可以代替验证器 App 或通行密钥。",
  "Finish the reset": "完成重置",
  "Finishing removes your authenticator app, passkeys and backup codes, and turns two-step verification off. Every other browser, device and app signed in to your account is signed out, and the agent keys they created stop working.": "完成后，你的验证器 App、通行密钥和备用码都会被移除，两步验证会关闭。其他浏览器、设备和 App 上的登录都会退出，它们发放的 Agent 密钥也会失效。",
  "You'll be signed in here. You can turn two-step verification on again in Settings › Account.":
      "你会在这里登录。之后可以在 设置 › 账户 重新开启两步验证。",
  // Settings › Account › Two-step verification and Verify it's you (settings.twoStep.*).
  "That password is incorrect. Try again.": "密码不对，请再试一次。",
  "Too many wrong passwords. Try again after {time}.":
      "密码输错次数太多。请在 {time} 之后再试。",
  "This setup has expired. Close this and turn it on again.":
      "这次设置已失效。请关闭后重新开启。",
  "Sign in again to manage two-step verification.": "请重新登录后再管理两步验证。",
  "Raft backup codes for {email}. Each code works once.":
      "Raft 备用码（{email}）。每个备用码只能用一次。",
  "Save these backup codes somewhere safe. If you can't use your authenticator app, each code lets you sign in once. You won't see them again.":
      "把这些备用码存到安全的地方。用不了验证器 App 时，每个备用码可以登录一次。它们只显示这一次。",
  "Couldn't copy the codes. Select and copy them yourself, or download them.":
      "无法复制备用码。请手动选中复制，或者下载。",
  "New backup codes": "新的备用码",
  "Two-step verification is on.": "两步验证已开启。",
  "Passkeys": "通行密钥",
  "Your account signs in without a password. Sign out and sign in again, then turn on two-step verification within 10 minutes.":
      "你的账户不用密码登录。请退出登录后重新登录，并在 10 分钟内开启两步验证。",
  "Enter your password to set up an authenticator app. You won't be asked again for 10 minutes.":
      "输入密码以设置验证器 App。10 分钟内不会再问。",
  "Turning it on signs you out of your other browsers. Computers and the raft CLI stay connected.":
      "开启后，你在其他浏览器上会退出登录。电脑和 raft CLI 保持连接。",
  "Turn on two-step verification": "开启两步验证",
  "Set up authenticator app": "设置验证器 App",
  "Turn on": "开启",
  "Can't scan it? Enter this key instead:": "扫不了？改为输入这个密钥：",
  "Copy key": "复制密钥",
  "Regenerate backup codes?": "重新生成备用码？",
  "Your old backup codes stop working right away, and your other browsers are signed out. Computers and the raft CLI stay connected. You'll get 10 new ones to save.":
      "旧的备用码会立即失效，你在其他浏览器上也会退出登录。电脑和 raft CLI 保持连接。你会拿到 10 个新的备用码，请保存好。",
  "Turn off two-step verification?": "关闭两步验证？",
  "Signing in will only ask for your password or connected account. Your authenticator app and backup codes stop working; your passkeys stay. Your other browsers are signed out. Computers and the raft CLI stay connected.": "登录时只需要密码或已连接的账户。你的验证器 App 和备用码都会失效，通行密钥会保留。你在其他浏览器上会退出登录。电脑和 raft CLI 保持连接。",
  "Signing in will only ask for your password or connected account. Your authenticator app and backup codes stop working. Your other browsers are signed out. Computers and the raft CLI stay connected.":
      "登录时只需要密码或已连接的账户。你的验证器 App 和备用码都会失效。你在其他浏览器上会退出登录。电脑和 raft CLI 保持连接。",
  "Turn off": "关闭",
  "Couldn't load two-step verification. Reload the page to try again.":
      "无法加载两步验证。请刷新页面重试。",
  "Authenticator app": "验证器 App",
  "{count, plural, one {# passkey also works for this step} other {# passkeys also work for this step}}":
      "{count, plural, other {# 个通行密钥也可用于这一步}}",
  "Backup codes": "备用码",
  "{remaining} of {total} left": "还剩 {remaining} 个，共 {total} 个",
  "{count, plural, one {Only # backup code left.} other {Only # backup codes left.}} Regenerate them so you don't get locked out.":
      "{count, plural, other {只剩 # 个备用码。}}请重新生成，免得以后进不来。",
  "On": "已开启",
  "Required every time you sign in to this account, including with Google, GitHub or Apple.":
      "每次登录这个账户都需要，包括用 Google、GitHub 或 Apple 登录。",
  "Ask for a second step every time you sign in, including with Google, GitHub or Apple.":
      "每次登录都多一步验证，包括用 Google、GitHub 或 Apple 登录。",
  "Generating a login token needs a fresh second step. It lasts 10 minutes.":
      "生成登录 token 前需要重新验证一次，10 分钟内有效。",
  "Giving an app access to your account needs a sign-in that passed the second step.":
      "授权 App 访问你的账户前，这次登录需要先通过第二步验证。",
  "Letting an app act as an agent needs a sign-in that passed the second step.":
      "允许 App 以 Agent 的身份行动前，这次登录需要先通过第二步验证。",
  "Creating a new secret needs a fresh second step. It lasts 10 minutes.":
      "生成新的密钥前需要重新验证一次，10 分钟内有效。",
  "Sign in again": "重新登录",
  // Settings › Account › Passkeys (settings.passkeys.*).
  "Passkeys aren't available right now. Try again later.": "通行密钥暂时不可用。请稍后再试。",
  "Rename passkey": "重命名通行密钥",
  "Delete “{name}”?": "删除“{name}”？",
  "You can't sign in or verify with this passkey after this. It stays in your password manager until you remove it there too. Your other browsers are signed out. Computers and the raft CLI stay connected.": "之后不能再用这个通行密钥登录或验证。它会留在你的密码管理器里，直到你在那边也删掉。你在其他浏览器上会退出登录。电脑和 raft CLI 保持连接。",
  "Delete passkey": "删除通行密钥",
  "Two-step verification is on. Verify it's you to delete this passkey.":
      "两步验证已开启。删除这个通行密钥前，请先确认是你本人。",
  "Couldn't load your passkeys. Reload the page to try again.":
      "无法加载通行密钥。请刷新页面重试。",
  "This browser can't create passkeys. Add one from a browser that supports them, such as a recent Chrome, Safari, Edge or Firefox.":
      "这个浏览器不能创建通行密钥。请在支持通行密钥的浏览器里添加，如新版 Chrome、Safari、Edge 或 Firefox。",
  "No passkeys yet": "还没有通行密钥",
  "Add passkey": "添加通行密钥",
  "Actions for {name}": "{name} 的操作",
  "Synced": "已同步",
  "Added {added} · Not used yet": "添加于 {added} · 还没用过",
  "Added {added} · Last used {used}": "添加于 {added} · 上次使用 {used}",
  "Rename": "重命名",
  "This is your only passkey or authenticator app, so it can't be deleted while two-step verification is on. Add another passkey first, or <turnOff>turn off two-step verification</turnOff>.":
      "这是你唯一的通行密钥或验证器，两步验证开着时不能删。请先再加一个通行密钥，或<turnOff>关闭两步验证</turnOff>。",
  "Enter a name of up to 64 characters.": "请输入不超过 64 个字符的名称。",
  "Only you see this name.": "只有你能看到这个名称。",
};
