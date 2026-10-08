# 逐组件验收

使用 Flutter SDK 的 `package:flutter/widget_previews.dart`，`@Preview` 顶层无必填参数函数，并用 `flutter widget-preview start`。不以普通静态截图站替代 Widget Preview。

每个组件为 Brutal light、Elegant light、Elegant dark 建立独立 preview。覆盖日/英/中长文本、文本缩放、窄/宽尺寸及 default、hover、focus、pressed、disabled、loading、error；组件适用哪些状态需明列。

对照 Web 同版本、同主题、同数据、同尺寸的真实组件与产品覆写，检查字体/行高、颜色、alpha、间距、边框、阴影、圆角、图标、动画。字体必须使用实际字体资产并验证 fallback；CSS OKLCH 转 Flutter 色彩需要比较最终渲染值。

交互 preview 使用局部 fixture/controller，点击、切换、菜单、输入、选择、焦点、快捷键真实可用。widget test 断言回调、disabled 不触发、焦点顺序、返回/ESC与状态变化。

无障碍检查 Semantics label/role/value、可用状态、键盘顺序、文本缩放、对比度与触摸目标。Widget Preview 在 Web 运行，不能单独证明 Linux 辅助技术、Android TalkBack、系统 IME、clipboard、通知、拖放；这些另列两平台运行验收。

Preview 不依赖服务端或原生插件，避免 dart:io/ffi 的传递依赖，用平台接口/conditional import fixture。资产使用包路径。

起始组件：Typography、Button/IconButton、TextInput、Checkbox/Switch、Badge/Status、Menu/Popover/Dialog/Sheet、Avatar、SidebarRow、MessageRow、MarkdownBlock、Reaction、ThreadSummary、TaskCard、Composer。

每个组件记录：Web源链接/版本、主题状态矩阵、preview函数、交互断言、语义断言、golden证据、Linux/Android未覆盖项及结果。实际状态应以组件记录及原生报告为准，预览存在不自动算通过。


## 附件与原生资源控制的实际边界

源码基准 26f77ef。本节只列附件/分享/通知/Fleet/资源筛选的验收，不替其他组件宣称全量通过。

| 范围 | SDK Preview 与交互 | 定向验证 | 原生/未覆盖 |
| --- | --- | --- | --- |
| RaftAttachmentCard | attachment_previews.dart 的 attachmentPreview，经 RaftPreviews 生成 Brutal light、Elegant light、Elegant dark；打开/下载/分享/错误重试回调与无操作按钮的 exportMode | 三主题打开/下载、48px 目标、上传时可编辑、exportMode callback；App 撤权/宿主消失/迟到 bytes/关闭缓存清理 | GTK/X11 与 Android DocumentsUI 真实选择/保存/取消；Linux 主应用图片检查点已通过。Android 新主应用完整链路及系统文件查看器打开断言待主报告 |
| PNG/文件分享与接收 | 纯 PNG review/消息选择组件由独立组件验收覆盖；平台 FileProvider/chooser 没有浏览器 SDK Preview | 私有 lease、fresh scope、迟到读取、草稿追加/取消、grant/path/数量边界 | Android 独立系统 chooser/receiver/ContentResolver 实际 bytes 与 URL 接收通过；Linux 真实保存。主应用新版本分享/接收完整链路待验收 |
| 通知/内容 URI | 产品设置复用现有 RaftPanel/表单组件；原生通知 daemon、系统 permission 和 URI 转发不属于纯 UI Preview | scope/persistent preference/restart/race、fresh message routing、body/credential stripping | 隔离 Android 权限拒绝/允许、通知栏点击、warm/cold URI；Linux X11/private DBus popup 与 GLib 转发通过。Linux 服务端 desktop push 不支持；Android 仅在线 Socket |
| Fleet 私有页/操作 | 复用既有 RaftPanel/表单/菜单；本轮无新增纯 raft_ui 组件 | 五项同代账户/角色、迟到目录/凭证/文件、socket 删除与 HTTP 删除顺序回归通过 | Linux 01:49:11 完整主运行的 CRUD/inspection/runtime 检查点通过；Android 扩展/整轮仍待主报告。凭证与权限回归不由 Preview 代替 |
| Search/Saved/Activity/Tasks 筛选 | 标准 Material 控件与有作用域的搜索/多选 dialog；本轮无新增纯 raft_ui 组件 | exact mounted 参数、typed identity OR/AND、Unassigned、storage frontier、迟到目录/权限 popup、360px 布局 | Linux 01:49:11 完整主运行通过 Search/self-mentions/Saved query-sort/Activity grouping、Task 多选/board 检查点；终态清理为定向测试证据，Android 同源码整轮仍待验收 |

Attachment SDK 的真实交互截图由组件验收报告记录；它们不是与 Web 同数据逐像素比较的 golden，也不证明 TalkBack、Linux 辅助技术或全部 hover/focus/text-scale 状态已验收。PDF/media 现提供原生应用内预览，text/Markdown/CSV/XLSX 提供结构化服务端预览；未知格式保留系统查看器。新增原生 media helper 已随较早 b20 源码的 Linux 01:49:11 完整主运行通过，Android 同源码整轮仍待主报告。

Document/media 的 SDK browser 三主题实际交互已通过：XLSX 第二工作表数据与语义文本、Play/Pause、键盘定位 0:06、音量 95%；报告为 agent workspace `reports/raft-reference/html/preview-interactions.json`。新增 media 解码及 PDF 页面截图仍以父 native helper 为平台证明。

## 最终工程与预览检查

父串行工程检查已通过全部 353 项 Dart 测试、29 项 host 测试与全仓 analyze，当前源码哈希为 `8e61f8adae7c81e62ff201d83fe57eb01ed9b8d472b21e10e485a954f65562b0`。75 个实际 SDK 浏览器主题交互记录及所引用截图均已核验通过，包括三主题 inline thread reply preview。它们不替代主应用整轮；较早 b20 源码的 Linux 01:49:11 完整主运行已通过，53个截图检查点记录均已核验。移动线程/主聊天状态复用修复后的当前源码，Linux 完整主运行正在验证，Android 随后串行重跑；两者仍待父报告。

当前源码另有 Linux 窄显示语言测试通过：真实保存 `zh-cn`，验证中文 Locale 和 Appearance/Account 标题，验证外观/深色/浅色译后控件文本后恢复偏好，没有点击主题切换。实际 Dark/Light 切换由较早 b20 Linux 整轮证明；Android 同版本完整主运行仍待主报告。

Android 专用 MediaCodec Surface 视频输出与 sticky-fatal 修复已通过两项实际 native_player_test，当前042哈希辅助receipt有160×90真实帧、332ms推进、暂停/定位1500ms/音量40；见 attachment-evidence.md。该辅助证据不替代当前两平台主应用整轮。
