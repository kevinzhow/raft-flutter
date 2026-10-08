# 原生通知与内容链接

源码基准为 26f77ef。`messageService.ts` 发出的 `notification:push` 已经过 DM、个人提及、线程关注和静音策略筛选，并含服务器生成的纯文本标题、正文及目标身份。`socket/platformScope.ts` 明确只向 mobile 客户端投递；Linux 保留 desktop 声明，设置页明确说明当前服务器不投递桌面消息通知。Android 只在应用 Socket 仍连接时投递本地系统通知；`push.ts` 的原生设备注册只接受 APNS，未注册或声称提供 Android FCM/被系统终止后的后台推送。另一个原生通知 SSE 协议有独立功能开关和设备注册授权，本实现不默认启用它。

通知默认关闭，在设置中由用户启用；Android 13+ 请求系统通知权限，拒绝时保持关闭并提供系统设置入口。偏好按 coordinator、账户及服务器散列隔离。目标载荷不含 token、签名资源 URL 或通知正文。切换作用域及退出账户清除已发通知，排队中的旧作用域投递失效。正文使用服务器的通知预览，不从所有 `message:new` 自行推断投递策略；Android 锁屏可见性为 private。

内容链接接受源码 `raft://v1/servers/:id/{channels,dms}/:id/messages/:id`、线程 `.../channels/:parent/threads/:thread?parentMessageId=:parent&messageId=:reply` 和同源 Web `/s/:slug/{channel,dm}/:id?msg=:id&thread=:channelId:parentId`。OAuth 回调独立处理。链接只在当前已登录账户、当前 coordinator、当前选中服务器中打开；其他服务器须先在应用中选择。每次打开重新读取成员服务器、频道及消息上下文；历史链接、无权访问的消息或线程身份矛盾均不导航，不切换登录账户或服务器地址。

Android 注册 raft://v1 内容 intent。Linux runner 使用 GLib 单实例命令行转发，冷启动参数传给 Dart，热启动由 app_links 接收并呈现当前窗口。bundle 含 `data/applications/app.raft.raft_flutter.desktop`；发行打包需将 launcher 安装到 XDG applications 目录并由用户选择 raft: handler。未在此开发机替换其他应用的全局 raft: handler，也未宣称任意自定义 coordinator HTTPS 域名已通过 Android Digital Asset Links 验证。

## 验证

- 11 个针对性测试通过：Web/native 链接形状、恶意 URL/重复参数/错源拒绝、fresh 成员与上下文授权、账户切换迟到请求、通知目标账户/服务器绑定、仅消费 eligible 事件、重复/正在阅读的消息抑制、作用域偏好及排队投递隔离。
- K8-Plus emulator-5580 的隔离应用 app.raft.attachment_probe 使用生产通知 facade、内容 parser 与同样的 manifest/build 配置；真实权限拒绝后再允许、真实通知栏点击返回 `s/c/m`、warm/cold 原生内容链接均通过 UIAutomator 和截图验证。保留主应用账户数据；probe 已停止。
- Linux 使用隔离 Xvfb/private DBus，会话内的真实 dunst 通知 daemon（仅本地下载解包，无系统安装）显示 popup；XTest 点击 popup 回到 `s/c/m`。同一生产 runner 的 cold 参数和 GLib warm 转发均正确。该证据属于 X11 daemon，不证明宿主 GNOME Wayland 的全局输入自动化或当前服务器桌面消息推送。
- 原始截图、UI assertions 与结果位于 agent workspace `reports/notification-platform/`。`integration_test/content_flow.dart` 可加入主 native 验收，对实际 Main coordinator 与真实服务器上下文导航取证；这与独立 OS probe 的证据边界分开。


通知偏好持久化进一步使用串行写入和 revision fence：重启恢复同一 principal 的布尔开关；旧缓存读取及迟到的启用操作不能覆盖新选择。关闭立即生效。读写失败保持关闭并显示错误，系统权限查询失败禁止投递。启动先捕获待验证的点击目标，再清除上一进程遗留的系统通知。针对性测试覆盖重启、跨账户、读写失败、迟到写入和旧缓存读取竞争。
