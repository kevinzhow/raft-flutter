# 原生消息呈现与操作卡验收

参照 Web/服务端固定版本：`26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`。本页记录消息 UI 的合同和证据；平台完整流程以最终功能矩阵为准。

## 消息正文

`RaftMessageBody` 使用原生 Markdown 布局，支持标题、段落、列表、表格、引用、链接和代码。正文、文件名、图表节点和用户资料不按界面语言翻译。链接有真实语义 URL、焦点反馈和键盘激活动作。

Mermaid 代码块使用 [mermaid_flutter 0.3.0](https://github.com/orestesgaolin/mermaid) 的 Dart 解析与原生绘制。默认显示图表，可以查看源代码、复制和打开可缩放的大图。节点提供语义标签。解析失败时明确显示错误和原始代码，不保留先前成功图形。该实现没有执行消息中的 JavaScript、Mermaid `click` 指令或远程加载。

库支持的语法与 Web Mermaid 并不完全相同；没有通过库解析的图表使用源代码回退，不能把所有 Mermaid 家族都报告为已支持。未关闭的围栏和外层更长的代码围栏保持普通代码。

## 引用与身份

频道、DM、线程和消息引用使用当前工作空间已知的真实标识。资料目录和结构化 mention 元数据提供身份；未知名称保持文本。代码、已有 Markdown 链接、邮件地址、较长名称与无法解析的 DM 令牌不会被误转成身份链接。同名的人类与 Agent 必须用 `~human`/`~agent` 区分；未知类型后缀保持文本。跨服务器来源或外部投影消息不会套用本地身份。

任务的明确 `task #N` 引用真实频道任务查询端点；查看资料、任务或线程之前重新取当前数据并检查账号、服务器、权限和会话代际。未知裸 `#N` 不声称是已存在的任务。

## 操作卡

操作卡保留服务端 prepared/executed/frozen/reconfirm 状态和确认版本。完成归属、目标工作空间、忙碌、错误和不可操作理由可见。五类 integration 操作调用挂载的执行/重新确认接口。频道创建、成员批量添加和托管 Agent 创建使用各自真实资源表单及 `actionCardMessageId`/确认版本，成员选择来自当前真实目录；Agent 创建要求在线电脑和当前可用 runtime，不用 external Agent 替代。

频道/成员创建成功后单独同步操作卡结果；结果同步失败会明确说明资源已创建，避免自动重复创建。客户端不发送伪造的 execute_success 事件。未知操作、冻结状态、跨工作空间、权限撤回、版本更改均停止执行；不会把原始密钥/授权负载当作预览字段显示。

## 私有窗口与提交竞态

账号、服务器、角色和代际变化关闭旧私有路由；频道权限真正减少时也关闭。普通频道导航、初次权限投影、授权增加、归档和取消归档不等同于查看权限撤回。异步表单成功后仅在其拥有的路由仍为 `isCurrent` 时退出，避免旧回调关闭主页或后来打开的窗口。

## 当前证据

- 9 个消息组件测试覆盖引用保护、三主题原生图表节点/源代码/复制/大图、错误回退、URL 语义与键盘激活。
- 8 个应用测试覆盖真实操作卡请求字段、版本、成员选择、权限撤回，以及路由移除与提交完成同帧的竞态。竞态测试确认旧表单在回调完成时仍 mounted，主页仍保留；另外验证旧回调不能关闭后来打开的路由。
- SDK Widget Preview 的 Rich message、Action card、Attachment 三组各三个主题，共 9 个配置通过真实浏览器交互与截图检查。图表节点、源代码、大图、身份/任务回调、操作卡状态、附件预览/下载/重试回调均可观察。控制台无错误。
- SDK Preview 不提供完整原生平台剪贴板，因此复制步骤验证源代码回调；组件测试验证 Clipboard.setData 的实际参数。原生系统剪贴板证明应由平台测试补充。
- 浏览器 SDK 透明语义层会拦截普通指针，交互使用呈现后的 DOM 语义动作；不能将此报告解释为原生鼠标、触摸、网络执行或系统分享证明。

证据位置：agent workspace `reports/raft-reference/rich/preview-interactions.json` 与同目录三主题截图。SDK Preview 更新后的本地端口为 43799；端口属于临时测试环境。

## Assisted composer references

The composer offers fresh, typed human/agent suggestions and visible channel suggestions. Picking a person binds `type`, `id` and `name` in the real message payload. Duplicate human/agent handles remain separate choices. Failed sends retain those bindings; editing the handle or moving it into code removes the binding. Channel completion inserts the source's textual `#name` reference. The pinned source has no task-number autocomplete; its task send controls are a separate contract.

The member roster is lazy. Private and joint channels use their membership projection; other conversations can use authorized server directories. Computer/app suggestions and their directory requests require the resolved `composer_resource_references_v0` flag. They insert canonical Markdown targets rather than person notification payloads. Opening a computer reference validates current flag/capability and a fresh machine projection before showing its detail. An app reference validates an installed app and current management authority before opening the integrations section.

Arrow keys, Tab, Enter and Escape operate the suggestion list. Ctrl/Cmd+Enter keeps the existing send behavior. IME composition is preserved and cannot trigger completion/send. Send and draft callbacks capture account/server/channel/window authority, so an accepted old reply arriving before old composer disposal cannot clear a newly selected channel's draft.

Five pure composer tests pass, including all three themes and IME/identity retry behavior. Three app directory tests verify lazy private membership, stale response rejection and gated canonical resource targets. `chat_jump_test.dart` verifies same-frame old ACK protection and stable same-channel context navigation. Real SDK browser keyboard runs in all three themes are recorded in `reports/raft-reference/composer/preview-interactions.json` in the agent workspace. `integration_test/composer_suggestions_flow.dart` supplies the native human-self-mention flow with a fresh backend mention receipt; the parent owns its platform execution.

The native `action_card_flow.dart` helper creates an isolated external agent and carrier channel through mounted, authorized APIs, mints a credential in memory, prepares a real channel action, and verifies the human edits, confirmation, executed attribution and canonical created resource. It removes both created channels and the agent in `finally`. Credential issuance, seats and preparation gates are respected; this helper is ready for the parent serial runner and is not claimed as a completed native checkpoint yet.

Chat regressions also cover same-channel context scrolling, an old accepted ACK arriving before the composer unmounts, and successful sending from older history. Only the controller's explicitly reported intentional latest-history refresh may advance the composer's captured window; unrelated navigation cannot clear another draft. The message actions sheet scrolls in a short window with a keyboard inset.

## Context replacement viewport correction

A fresh Linux run on 2026-10-08 at 00:27 UTC exposed a blank message viewport after a same-channel context jump. The workspace and display adapter both contained the target among 16 rows, but the retained scroll position was 5,364 px while the new maximum was 1,654 px. This was a viewport failure rather than missing message data or Markdown parsing.

ChatView now owns the scroll controller. A committed context or conversation replacement resets the old position before applying the new rows, then repairs any out-of-range position after layout before focusing the target. Normal message updates and history prepend keep the same list and controller. The asynchronous focus callback rechecks the selected message and window generation before acting.

A regression first failed with the measured 5,364 px offset after the 16-row commit. It now passes and verifies visible target focus and unchanged position during an ordinary update. All five chat jump/composer tests pass, including delayed repeated replacement, history list preservation and both send-receipt fences. The fresh whole native suite remains the platform confirmation for this correction.
