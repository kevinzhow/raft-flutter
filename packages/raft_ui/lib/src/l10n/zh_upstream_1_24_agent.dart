// Chinese (zh) strings, see the catalog header in ../localization.dart.
// English source text is the key. Part of `raftChinese` (merged by the generated zh_index.g.dart).
// Web v1.24.0-source.1 en.ts / zh-cn.ts wording verbatim: WP-AGENT (agent detail status chip and runtime error banner).
const Map<String, String> zhCatalogUpstream124Agent = <String, String>{
  "Computer update required": "Computer 需要更新",
  "Computer access revoked: move the agent to another computer (re-attaching adds a new one)":
      "Computer 访问权限已撤销：请把 Agent 移到另一台 Computer（重新加入会新增一台 Computer）",
  "Sign-in needed for {runtime}": "需要重新登录 {runtime}",
  "Plan doesn't include {model}": "套餐不包含 {model}",
  "Plan doesn't include this model": "套餐不包含这个模型",
  "Provider balance exhausted": "服务商余额已用完",
  "Change model": "更换模型",
  "Likely online": "可能在线",
  "{count} deliveries written since the runtime last responded (episode {episode}, last via {path})":
      "运行时上次响应后已写入 {count} 条投递（第 {episode} 轮，最近一次经 {path}）",
  "{count} early exits in a row (episode {episode}, last: {exitKind}{signal}); Raft stopped waking this agent until someone starts it": "连续 {count} 次启动后很快退出（第 {episode} 轮，最近一次：{exitKind}{signal}）；Raft 已停止自动唤醒该 Agent，直到有人手动启动",
  "Couldn't start: there's a problem with the API key. Copy the full key again from your provider's dashboard, save, and retry.":
      "无法启动：API 密钥有问题。请从提供方控制台重新完整复制密钥，保存后重试。",
  "This runtime's account or plan doesn't include \"{model}\". Change the model, or sign in with an account that includes it":
      "这个运行时的账号或套餐不包含模型「{model}」。请更换模型，或登录包含该模型的账号",
  "This runtime's account or plan doesn't include this agent's model. Change the model, or sign in with an account that includes it":
      "这个运行时的账号或套餐不包含这个 Agent 的模型。请更换模型，或登录包含该模型的账号",
  "Kept failing the same way after starting — automatic wakes are paused; Raft tries again by itself at {time}. Restart the agent to try now":
      "启动后多次以同样的方式失败——已暂停自动唤醒，Raft 会在 {time} 自动重试；重启 Agent 可立即重试",
  "Kept failing the same way after starting — automatic wakes are paused; Raft tries again by itself later. Restart the agent to try now":
      "启动后多次以同样的方式失败——已暂停自动唤醒，Raft 稍后会自动重试；重启 Agent 可立即重试",
  "{detail} — automatic wakes are paused; Raft tries again by itself at {time}. Restart the agent or switch its model to resume now":
      "{detail}——已暂停自动唤醒，Raft 会在 {time} 自动重试；重启 Agent 或换一个模型可立即恢复",
  "{detail} — automatic wakes are paused; Raft tries again by itself later. Restart the agent or switch its model to resume now":
      "{detail}——已暂停自动唤醒，Raft 稍后会自动重试；重启 Agent 或换一个模型可立即恢复",
  "Model \"{model}\" is not available for this runtime — it may have been renamed or removed, or its provider has no API key on this computer. Pick another model or fix the key in the agent settings": "该运行时没有可用的模型「{model}」：可能已改名或下架，或它的服务商在这台电脑上没有可用的 API 密钥——请在 Agent 设置里换模型或修正密钥",
  "Claude Code cannot start with root or sudo privileges while permission checks are disabled. Run Raft Computer as a non-root user, then start the agent again.": "Claude Code 在跳过权限检查时，不能以 root 或 sudo 权限启动。请用非 root 用户运行 Raft Computer，然后重新启动 Agent。",
  "Model service balance too low": "模型服务余额不足",
  "{agent} can't reply right now. Check the balance and billing for the model service this agent uses, then start it again.":
      "{agent} 暂时无法回复。请检查这个 Agent 所用模型服务的余额和计费状态，处理好后再启动。",
  "View model settings": "查看模型配置",
  "Ask a server admin to fix this.": "请联系服务器管理员处理。",
  "{runtimeName} is not installed on this Computer. Install it there, move the agent to a Computer that has it, or switch the agent's runtime.": "这台 Computer 上没有安装 {runtimeName}。请在这台 Computer 上安装它，或把 Agent 移到装有它的 Computer，或更换 Agent 的运行时。",
  "Set up": "去设置",
  "Finish setting up {name}": "完成 {name} 的设置",
  "Usage limit reached": "已达到用量上限",
  "The agent's model provider usage limit has been reached. Wait for the limit to reset, or ask the agent's owner to switch it to another model or account.":
      "Agent 所用模型服务的用量已达上限。请等待额度重置，或请 Agent 的所有者换用其他模型或账号。",
  "The model provider's usage limit has been reached. Wait for the limit to reset, or switch the agent to another model or account in its settings.":
      "模型服务的用量已达上限。请等待额度重置，或在 Agent 设置中换用其他模型或账号。",
  "The agent's model provider billing or credit balance is exhausted. Ask the agent's owner to add credits or switch it to another model or provider.":
      "Agent 所用模型服务的余额或额度已用完。请 Agent 的所有者充值，或换用其他模型或服务商。",
  "The model provider's billing or credit balance is exhausted. Add credits with the provider, or switch the agent to another model or provider in its settings.":
      "模型服务的余额或额度已用完。请向服务商充值，或在 Agent 设置中换用其他模型或服务商。",
  "Model not available": "模型不可用",
  "The agent's configured model is not available to its provider account. Ask the agent's owner to choose another model or change the plan.":
      "Agent 配置的模型对其服务商账号不可用。请 Agent 的所有者选择其他模型，或更换套餐。",
  "The agent's model is not available to its provider account. Choose another model in the agent's settings, or change the plan.":
      "Agent 的模型对其服务商账号不可用。请在 Agent 设置中选择其他模型，或更换套餐。",
  "Sign-in required": "需要登录",
  "The agent's runtime is not signed in, or its provider credential was rejected. Ask the agent's owner to sign in again or update the credential.":
      "Agent 的运行时未登录，或服务商凭据被拒绝。请 Agent 的所有者重新登录或更新凭据。",
  "The agent's runtime is not signed in, or its provider credential was rejected. Sign in again on the agent's computer, or update the credential.":
      "Agent 的运行时未登录，或服务商凭据被拒绝。请在 Agent 所在的 Computer 上重新登录，或更新凭据。",
  "Provider unreachable": "无法连接模型服务",
  "The agent could not reach its model provider, or the request timed out. Try again later; if it keeps happening, ask the agent's owner to check the computer's network.":
      "Agent 无法连接到模型服务，或请求超时。请稍后再试；如果反复出现，请 Agent 的所有者检查 Computer 的网络。",
  "The agent could not reach its model provider, or the request timed out. Try again later; if it keeps happening, check the network on the agent's computer.":
      "Agent 无法连接到模型服务，或请求超时。请稍后再试；如果反复出现，请检查 Agent 所在 Computer 的网络。",
  "Input too large": "输入过长",
  "The agent's input is larger than its model accepts. Ask the agent's owner to reset the session or reduce the startup context.":
      "Agent 的输入超出了模型可接受的长度。请 Agent 的所有者重置会话，或精简启动上下文。",
  "The agent's input is larger than its model accepts. Reset the session, or reduce the startup context.":
      "Agent 的输入超出了模型可接受的长度。请重置会话，或精简启动上下文。",
  "Message too long": "消息过长",
  "A message to the agent was too long for its runtime to take at once, so it was not delivered. Shorten it, or split it into several messages.":
      "发给 Agent 的消息过长，运行时无法一次接收，因此未送达。请缩短消息，或拆分为多条发送。",
  "A message was too long for this agent's runtime to take at once, so it was not delivered. Shorten it, or split it into several messages, and send again.":
      "消息过长，此 Agent 的运行时无法一次接收，因此未送达。请缩短消息，或拆分为多条后重新发送。",
};
