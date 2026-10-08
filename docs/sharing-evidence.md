# 原生分享与接收

源码基准 26f77ef。Web SelectShareLightbox 的原始行为是选择消息、预览 PNG，再通过支持文件的系统分享或下载导出。原生截图选择与预览 UI 由对应界面模块实现；本平台模块提供私有 PNG bytes lease、Android 系统分享及 Linux/Android 原生保存接口。

Android 消息链接使用源码 `/s/:slug/{channel,dm}/:id?msg=:id&thread=:channelId:parentId` 形状。分享前重新读取服务器成员资格、频道和消息上下文。可配置 RAFT_FRONTEND_ORIGIN，它只对同次编译明确绑定的 RAFT_ORIGIN 生效；切换其他 coordinator 不继承这个别名。Linux 保留复制链接和保存文件，未声称有通用原生分享面板。

附件分享重新取签名地址，再下载到 app 私有 cache/raft-share；FileProvider 只暴露这一目录，每次只授予目标文件的读取权限。签名地址不进入持久缓存或分享正文。导出在作用域变化、宿主关闭、失败或最长 15 分钟后删除，重启清理过期目录。系统 chooser 返回只表示关闭，不证明收件人已经发送内容。

ACTION_SEND/MULTIPLE 是新增原生接收能力，未宣称源码 Web 存在该 Android 契约。接收只接受 content URI，最多 10 个文件、单文件最大 50 MB；文本有长度上限。当前已登录账户、已加入频道和服务器必须通过 fresh authority 检查。用户明确预览并选择添加后，文件才读取、暂存到现有 composer，文本追加现有草稿；不会自动发送。取消和账户/服务器/频道切换使 review 失效。源码内容链接选择打开后仍须重新验证消息上下文。OAuth、含认证参数或签名资源的分享文本不进入草稿。

## 证据边界

- 独立 Android app.raft.attachment_probe 使用生产 MainActivity/NativeSharingBridge（仅 package 改名），实际系统 chooser 将 37 bytes 文件交给另一个独立 app.raft.share_receiver。接收 app 通过授予的 ContentResolver 权限读到 SHA256 `921f61ecb862b1e0eecc02d97c20a3b004cd8ea7a2cf99553377930f75b3322d`，再通过真实 ACTION_SEND 把 grant 交回 probe，probe 读取相同 bytes。源码形状的无凭证 URL 也通过真实 chooser 到达同一个隔离 receiver。真实 BACK 关闭 chooser。
- 原始截图和 UI XML 断言在 agent workspace reports/sharing-platform；主应用及真实服务器未作为这个 OS probe 的发送方。主应用完整分享 UI 的验收由整体 native 测试另行执行。
- 新针对性测试覆盖 content grant 与数量限制、路径清理、迟到文件读取失效、接收器替换所有权、实际 HTTP 下载与临时文件清理、PNG lease/save 取消、API 绑定的 frontend origin、草稿追加及取消、review 权限拒绝与作用域关闭。
- 独立 probe 和 receiver 已 force-stop；自身的 proof 导出已清理，未删除主应用账户数据或更改其他设备。


主 Linux 运行已在 2026-10-07 UTC 的当前检查点覆盖 PNG review/forwarded content；主测试仍在执行且该编译早于最终任务/发送修补，因此这里不将其记作新版本完整 Linux/Android 分享验收。独立 OS chooser 只证明授予接收者的文件与 URL，不证明任何外部服务已发送，也不包含公开上传。
