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
| Fleet 私有页/操作 | 复用既有 RaftPanel/表单/菜单；本轮无新增纯 raft_ui 组件 | 五项同代账户/角色、迟到目录/凭证/文件、socket 删除与 HTTP 删除顺序回归通过 | 父测试负责最新 Linux/Android CRUD/inspection/runtime；凭证与权限回归不由 Preview 代替 |
| Search/Saved/Activity/Tasks 筛选 | 标准 Material 控件与有作用域的搜索/多选 dialog；本轮无新增纯 raft_ui 组件 | exact mounted 参数、typed identity OR/AND、Unassigned、storage frontier、迟到目录/权限 popup、360px 布局 | Linux 2026-10-07 UTC 23:09 的 Search/self-mentions/Saved query-sort/Activity grouping 检查点通过；新增 Task 多选/终态清理与最终两平台整轮待验收 |

Attachment SDK 的真实交互截图由组件验收报告记录；它们不是与 Web 同数据逐像素比较的 golden，也不证明 TalkBack、Linux 辅助技术或全部 hover/focus/text-scale 状态已验收。PDF/media 现提供原生应用内预览，text/Markdown/CSV/XLSX 提供结构化服务端预览；未知格式保留系统查看器。新增原生 media helper 的两平台整轮结果仍以主运行检查点为准。

Document/media 的 SDK browser 三主题实际交互已通过：XLSX 第二工作表数据与语义文本、Play/Pause、键盘定位 0:06、音量 95%；报告为 agent workspace `reports/raft-reference/html/preview-interactions.json`。新增 media 解码及 PDF 页面截图仍以父 native helper 为平台证明。
