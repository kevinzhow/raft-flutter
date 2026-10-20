// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.21.12-source.1 zh-cn.ts wording verbatim: ids added since v1.21.2-source.1 and English rewrites whose
// new text our other catalogs did not carry. ICU plural/select messages are not interpreted by raftText and are not listed.
const Map<String, String> zhCatalogUpstream12112 = <String, String>{
  // activity.*
  "No DM activity": "暂无私信动态",
  "DMs and threads in DMs show up here when they have new activity.": "私信和私信里的话题有新动态时会显示在这里。",
  "{detail} — automatic restarts are paused until you change the model or API key, or restart the agent":
      "{detail}——已暂停自动重启，改了模型或 API 密钥、或手动重启 Agent 后恢复",
  "Model \"{model}\" is not available for this runtime — it may have been renamed or removed, or its provider has no API key on this computer. Pick another model or fix the key in the agent settings":
      "该运行时没有可用的模型「{model}」：可能已改名或下架，或它的服务商在这台电脑上没有可用的 API 密钥——请在 Agent 设置里换模型或修正密钥",
  "This agent's conversation no longer fits its model, and context compaction failed several times in a row, so restarting would fail again. To start a new session, open Restart / Reset and choose Reset Session & Restart (Reset Model for members). Raft messages and workspace files, including MEMORY.md, are kept":
      "这个 Agent 的对话已经超出模型能容纳的长度，上下文压缩连续失败了好几次，直接重启还会失败。要开新会话，请打开「重启 / 重置」并选择「重置会话并重启」（成员看到的是「重置模型」）。Raft 消息和工作区文件（包括 MEMORY.md）都会保留",
  // agent.*
  "Set by the hosting administrator for now. Pick a model to use another one.":
      "目前由托管方管理员指定。选一个模型即可改用其他模型。",
  "Default ({label})": "默认（{label}）",
  "Provider default": "服务商默认",
  "The agent uses the chosen model from its next turn; it does not restart.":
      "Agent 从下一轮开始用选中的模型，不会重启。",
  "The model settings could not be loaded. Try again later.": "没能加载模型设置，请稍后再试。",
  "An administrator has set this agent's model, so it can't be changed here.":
      "管理员已为这个 Agent 指定了模型，这里不能修改。",
  "An administrator has set this agent's model, so the change was not saved.":
      "管理员已为这个 Agent 指定了模型，这次修改没有保存。",
  "That model is no longer offered. The list has been refreshed; pick another one.":
      "这个模型已经不再提供。列表已刷新，请换一个。",
  "The model could not be changed. Try again.": "没能修改模型，请重试。",
  "Saved. The agent uses this model from its next turn.": "已保存，Agent 从下一轮开始用这个模型。",
  "Setting up the workspace on {target}.": "正在 {target} 上准备工作区。",
  "The agent migrated to {target} and is now running there.": "Agent 已迁移到 {target}，并已在那里运行。",
  "The workspace is packed. Sending it to {target}.": "工作区已打包完成，正在发送到 {target}。",
  "Migration complete": "迁移完成",
  "Uploading the workspace from {source} to send to {target}.":
      "正在从 {source} 上传工作区，准备传到 {target}。",
  "Migrated to {target}": "已迁移到 {target}",
  "Migrating to {target}": "正在迁移到 {target}",
  "Starting migration…": "正在开始迁移…",
  "Raft will stop the migration from {source} to {target} and clean up on both computers. Your agent and its workspace stay on whichever computer has them now.":
      "Raft 会停止从 {source} 到 {target} 的迁移，并在两台计算机上完成清理。Agent 及其工作区会保留在当前所在的计算机上。",
  "Open computer settings": "打开计算机设置",
  "Copy migration ID {ref}": "复制迁移编号 {ref}",
  "Migration ID": "迁移编号",
  "Move this agent and its workspace to another computer. The agent stops while it migrates, then starts again there.":
      "把这个 Agent 连同工作区迁移到另一台计算机。迁移期间 Agent 会暂停，完成后在新计算机上重新启动。",
  "done": "已完成",
  "failed": "失败",
  "Not in the current list": "不在当前列表中",
  "The saved value {value} is not in the current list. It stays selected until you pick another.":
      "已保存的值 {value} 不在当前列表中。换成别的之前会一直保持选中。",
  "The API key is tied to the saved settings you changed. Enter a new one.":
      "API 密钥与你修改的已保存设置绑定，请输入新的密钥。",
  "Use “{value}”": "使用“{value}”",
  "Could not check for {runtimeName} on this Computer: permission denied. Check permissions on that machine, then retry.":
      "无法检查此 Computer 上的 {runtimeName}：权限被拒绝。请检查那台机器的权限后重试。",
  "Checking for {runtimeName} on this Computer timed out. Retry, or check this Computer's status.":
      "检查此 Computer 上的 {runtimeName} 超时。请重试，或查看此 Computer 的状态。",
  "Could not confirm whether {runtimeName} is available on this Computer. Retry, or check this Computer's status.":
      "无法确认此 Computer 上是否有 {runtimeName}。请重试，或查看此 Computer 的状态。",
  // auth.*
  "Agree to the Terms of Service and acknowledge the Privacy Policy to continue.":
      "请先同意服务条款并确认隐私政策，再继续。",
  // channel.*
  "You can't invite this server to its own joint channel.": "不能邀请本服务器加入它自己的联合频道。",
  "{invitee} must be an owner or admin of server \"{server}\" to be invited.":
      "{invitee} 必须是服务器「{server}」的所有者或管理员，才能被邀请。",
  "No one matching {invitee} was found on server \"{server}\". Check the handle or email.":
      "在服务器「{server}」中找不到 {invitee}，请检查 handle 或邮箱。",
  "Server \"{server}\" wasn't found. Check the slug.": "找不到服务器「{server}」，请检查 slug。",
  // common.*
  "Latest updates": "最新动态",
  // desktop.*
  "New message": "新消息",
  "Enable this Mac": "启用这台 Mac",
  "Enable this computer": "启用这台计算机",
  "This app already includes everything needed — no terminal, no install. Enable this Mac to host your agents right here, signed in as you.":
      "这个应用已经内置了所需的一切，不用终端，也不用安装。启用这台 Mac，就能以你的身份在这里运行你的 Agent。",
  "This app already includes everything needed — no terminal, no install. Enable this computer to host your agents right here, signed in as you.":
      "这个应用已经内置了所需的一切，不用终端，也不用安装。启用这台计算机，就能以你的身份在这里运行你的 Agent。",
  "You need admin access on this server to run a computer here.": "你需要这个服务器的管理员权限，才能在这里运行计算机。",
  "Couldn't enable this computer — try again.": "无法启用这台计算机，请重试。",
  "The computer host isn't available in this build.": "这个版本不支持在本机运行计算机。",
  "Network error — try again.": "网络错误，请重试。",
  "Setting up — this appears below once it's online.": "正在设置，上线后会显示在下方。",
  "Please sign in first.": "请先登录。",
  "Use this Mac": "使用这台 Mac",
  "Use this computer": "使用这台计算机",
  "Managed by the CLI — run: raft-computer attach {slug}":
      "由 CLI 管理，请运行：raft-computer attach {slug}",
  "You need admin access on this server.": "你需要这个服务器的管理员权限。",
  "This computer is managed by the Raft Computer CLI — use raft-computer in Terminal.":
      "这台计算机由 Raft Computer CLI 管理，请在终端里使用 raft-computer。",
  "Another Computer service on this machine already uses this machine key. Stop it first ({command}), then try again.":
      "这台机器上已经有另一个 Computer 服务在使用同一个机器密钥。请先停掉它（{command}），再重试。",
  "Another Computer service on this machine already uses this machine key. Stop that other service first, then try again.":
      "这台机器上已经有另一个 Computer 服务在使用同一个机器密钥。请先停掉那个服务，再重试。",
  "Couldn't complete that — try again.": "操作没有完成，请重试。",
  "Computer host isn't available.": "本机的计算机服务不可用。",
  "This computer is signed in to another Raft account via the CLI.":
      "这台计算机已通过 CLI 登录了另一个 Raft 账号。",
  "The local service isn't reachable.": "无法连接本地服务。",
  "Already up to date.": "已经是最新版本。",
  "This Mac": "这台 Mac",
  "This computer": "这台计算机",
  "Not connected to {server}": "未连接到 {server}",
  "This device": "本机",
  // feedback.*
  "Your session expired. The app is refreshing it; your draft is kept.":
      "登录已过期，正在等待 App 刷新；已保留你的草稿。",
  "Your draft is kept. After signing in, submit again when ready.": "草稿已保留；登录恢复后可重新提交。",
  "Return to editing": "返回编辑",
  "Feedback could not be confirmed. Retry keeps the same message and attachments.":
      "暂未确认反馈提交成功。重试会保留原消息和附件。",
  "Submit without diagnostic log": "去掉诊断日志后提交",
  "Preparing diagnostic log…": "正在准备诊断日志…",
  "The submission was rejected. Return to editing to change it, or retry the same content.":
      "提交被拒绝。可以返回编辑修改内容，或重试相同内容。",
  "Retry submission": "重试提交",
  "Skip log and submit": "跳过日志并提交",
  "Submitting feedback…": "正在提交反馈…",
  "The diagnostic log could not be uploaded. Your feedback will be submitted without it.":
      "诊断信息未能上传，反馈照常提交。",
  "Uploading diagnostic log…": "正在上传诊断日志…",
  "Submit feedback": "提交反馈",
  "Open Feedback from the Raft app to continue.": "请从 Raft App 打开反馈页。",
  // layout.*
  "Delete this server": "删除这个服务器",
  "{provider} usage limit reached": "{provider} 已达到用量限制",
  "{count} agent on {computer} may pause until usage is available again.":
      "{computer} 上的 {count} 个 Agent 可能会暂停，直到用量恢复。",
  "{count} agents on {computer} may pause until usage is available again.":
      "{computer} 上的 {count} 个 Agent 可能会暂停，直到用量恢复。",
  "{count} agent on {computer} may pause. Usage is expected to reset {reset}.":
      "{computer} 上的 {count} 个 Agent 可能会暂停。预计 {reset} 重置用量。",
  "{count} agents on {computer} may pause. Usage is expected to reset {reset}.":
      "{computer} 上的 {count} 个 Agent 可能会暂停。预计 {reset} 重置用量。",
  // machine.*
  "Uses the {runtime} account signed in on this computer.": "使用这台 Computer 上登录的 {runtime} 账号。",
  "Didn't finish": "未完成",
  "Change model": "更换模型",
  "Loading models…": "正在加载模型…",
  "No runtime on this computer can be changed in bulk.": "这台 Computer 上没有可以批量更换的运行时。",
  "{failed} of {total} changes didn't finish.": "{total} 项更改中有 {failed} 项未完成。",
  "Custom settings": "有自定义设置",
  "No change": "无变化",
  "Choose model": "选择模型",
  "Review": "确认",
  "{count} skipped.": "{count} 个已跳过。",
  "Change runtime and model for the selected agents": "为选中的 Agent 更换运行时和模型",
  "{plan} · needs attention": "{plan} · 需要处理",
  "{plan} · limit reached, resets {reset}": "{plan} · 额度已用完，{reset}恢复",
  "{plan} · limit reached": "{plan} · 额度已用完",
  "{plan} · {percent}% used": "{plan} · 已用 {percent}%",
  "It didn't reconnect after the upgrade to v{version}.": "升级到 v{version} 后没有重新连上。",
  "Upgrading to v{version}. The Computer is restarting and will reconnect when it's done.":
      "正在升级到 v{version}。Computer 正在重启，完成后会自动重新连接。",
  "If it doesn't reconnect within a few minutes, run {command} on that machine to check.":
      "如果几分钟内没有重新连接，请在那台机器上运行 {command} 查看。",
  // member.*
  "Members you invite can DM and give instructions to every agent in this server. Keep personal agents in a separate server of your own.":
      "被邀请的成员可以私信并指挥这个服务器里的所有 Agent。个人 Agent 请放在你自己单独的服务器里。",
  // message.*
  "{name} (Slack)": "{name}（Slack）",
  "This link uses the {protocol} protocol and will open in an external application:":
      "此链接使用 {protocol} 协议，将在外部应用中打开：",
  "Open external link?": "打开外部链接？",
  "— #{name}": "— #{name}",
  "Focus mode": "专注模式",
  "Standard mode": "标准模式",
  // settings.*
  "Declares JWT support for this App. Other Servers must separately allow access after installing it.":
      "声明此 App 支持 JWT。其他 Server 安装后仍需各自允许访问。",
  "Enable Agent JWT support": "启用 Agent JWT 支持",
  "Audience: {audience}. Tokens expire after five minutes. Turning off stops new issuance; existing tokens expire normally.":
      "Audience：{audience}。Token 五分钟后过期。关闭会停止新签发，已有 Token 按原有效期过期。",
  "Let agents authenticate to this App with a five-minute JWT, without a browser callback. The App must be configured to verify Raft JWTs.":
      "让 Agent 使用五分钟有效的 JWT 向此 App 认证，无需浏览器回调。App 需先配置好 Raft JWT 验证。",
  "Could not load or save JWT settings. Retry before relying on this change.":
      "无法加载或保存 JWT 设置，请重试后再确认更改已生效。",
  "Allows this Server’s agents to use JWTs with this installed App. Other Servers are unaffected.":
      "允许此 Server 的 Agent 向已安装的 App 使用 JWT，不影响其他 Server。",
  "Allow Agent JWTs on this Server": "允许此 Server 的 Agent 使用 JWT",
  "The App must support JWTs and this installation must be active before access can be enabled.":
      "App 需支持 JWT，且此安装处于有效状态，才能启用访问。",
  "Register the App, then edit its login settings to enable JWT access.":
      "先注册 App，再编辑其登录设置以启用 JWT 访问。",
  "Save JWT settings": "保存 JWT 设置",
  "Agent access JWT": "Agent 访问 JWT",
  "Enable the App and its openid/profile login scopes before turning on JWT access.":
      "启用 App 及其 openid/profile 登录 scope 后，才能开启 JWT 访问。",
  "Permission update pending review": "权限更新待审核",
  "Requested data groups": "申请的数据组",
  "Requested notification events": "申请的通知事件",
  "A marketplace reviewer can approve this permission update.": "Marketplace 审核员可批准此权限更新。",
  "Failed to approve permission update": "批准权限更新失败",
  "{count} / {limit} characters": "{count} / {limit} 字",
  "Use no more than {limit} characters before saving.": "请缩短至 {limit} 字以内再保存。",
  "Slack authorization was cancelled or declined in Slack. Nothing was changed; you can try again.":
      "Slack 授权在 Slack 里被取消或拒绝了。没有做任何改动，可以重试。",
  "Slack authorization didn't complete and nothing was changed. Try again; if it keeps failing, contact Raft support and mention code {code}.":
      "Slack 授权没有完成，也没有做任何改动。请重试；如果一直失败，请联系 Raft 支持并提供代码 {code}。",
  "You authorized a different Slack workspace (or app) than the one this Raft server is already connected to. Authorize the same workspace, or disconnect it first.":
      "你授权的 Slack 工作区（或应用）和这个 Raft server 已经连接的不一致。请用同一个工作区授权，或者先断开再重新连接。",
  "Slack was temporarily unavailable. Nothing was changed; try again in a few minutes.":
      "Slack 暂时不可用。没有做任何改动，请几分钟后重试。",
  "Slack authorization didn't finish": "Slack 授权没有完成",
  "Raft couldn't confirm whether Slack finished the authorization. Refresh this page in a minute and check the current state before trying again.":
      "无法确认 Slack 是否完成了授权。请过一分钟刷新页面，看清当前状态后再决定是否重试。",
  "Update Slack authorization": "更新 Slack 授权",
};
