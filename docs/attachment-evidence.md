# 附件：原生实现与验收证据

实现使用 `file_selector.openFiles` 打开系统多文件选择器。待发送附件显示上传进度，可取消、移除或重试；上传未完成时可以继续编辑文字，发送按钮保持禁用。每条消息最多 10 个文件，空文件在请求前拒绝。

图片通过当前账户、工作区权限下的 `/attachments/:id/url?disposition=inline` 获取临时地址，随后只保存内存中的图片字节。地址不进入本地数据库、偏好或图片缓存的 URL 键。账户、工作区、频道或所属消息离开当前视图时，传输取消、预览关闭，解码图片缓存清除。下载重新请求 `disposition=attachment`。

Linux 使用真实 GTK 保存对话框。Android 使用 `ACTION_CREATE_DOCUMENT`，通过 `ContentResolver` 写入用户选择的文档位置。文件先下载到私有临时目录，完成且权限仍有效后才保存；失败或取消会清理临时文件。保存后的“打开”交给系统文件查看器；没有可用查看器时显示明确错误。PDF 提供原生逐页预览，音视频提供应用内播放器；text/Markdown/CSV/XLSX 使用已挂载的结构化 preview 响应。未知格式仍可下载后交给系统查看器。预览遵守默认开启的服务端 rollback 开关；关闭开关时回退下载。HTML 的原生安全静态预览及明确用户选择的服务端沙箱浏览器路径由独立 HTML 验收记录。

## 已执行证据

- Linux：隔离 Xvfb `:92` 上的真实 GTK 选择器，XTest 键盘和 AT-SPI 操作；同时选择 PNG、TXT，保存的 36 字节 UTF-8 内容与原件完全一致；选择和保存取消分别返回空列表、`null`。
- Android：`emulator-5580`，独立 `app.raft.attachment_probe` 应用的真实 DocumentsUI；相同多选、保存内容比对、两种取消均通过。未改动 Raft 应用包或其他设备。
- 生产服务副本的隔离平台证据、截图及断言位于 `/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/reports/attachment-platform/`，入口为 `README.md` 和 `results.json`。Linux 证据覆盖 GTK/X11；不把它当作宿主 GNOME Wayland 全局注入输入的证明。
- 16 项附件定向测试通过：客户端刷新后 multipart 重放及取消（2），上传状态与路径边界（3），真实 HTTP 下载与临时文件清理（3），撤权、消息离开、预览关闭和解码缓存清除（4），三主题的独立打开/下载与 Android 无障碍目标、上传时继续编辑（4）。既有组件回归此前 12 项通过。
- `raft_ui` 的 Attachment SDK Preview 提供 Brutal light、Elegant light、Elegant dark，独立的打开、下载、失败重试交互。

`integration_test/attachment_flow.dart` 的 `verifyAttachmentFlow` 交给主原生测试运行：真实 multipart 上传、UI 重试、两个附件 ID 与消息绑定、临时签名图片解码及截图。平台探针未使用账户资料，也不代替该 Raft 业务链路测试。系统查看器实际打开文件尚未独立断言。


2026-10-07 UTC 23:09:20 的父 Linux 主应用运行通过 signed image preview 检查点；整轮仍由主报告判定，Android 最新主应用链路尚未在本附件报告标记完成。图片导出另有回归：当前可见 parent 的已载入 ledger thread descendant 可获取授权预览，即使 thread panel 已关闭；parent 消失立即取消传输、移除图片并清除解码缓存。普通附件浏览不扩大到这些非当前 thread row。


## 新增文档与媒体预览边界

Source `attachmentPreviewGate.ts` 默认开启预览；`attachmentPreview.ts` 与 shared 类型定义启用了 PDF、音频、视频、text/Markdown/CSV/XLSX。原生实现复用这些分类、CSV 5 MB / XLSX 10 MB 限额、结构化响应字段与 `/attachments/:id/preview` 路径。PDF/media 单次私有输入最多 50 MB；签名 URL 不传给解码器或持久缓存。播放器无自动播放，可暂停、定位、调音量；应用进入后台暂停，退出预览和撤权关闭解码器并清理文件。PDF 以静态页图呈现，支持翻页和缩放。Linux 的可重建 libmpv bundle 与 Poppler OS 依赖见 `linux-media-runtime.md`。

本次定向证据：11 项 app 预览/权限测试通过，其中包括实际 Poppler 两页 PDF 解码、PNG 对比及无遗留页文件，真实 HTTP 失败清理、后台暂停/撤权后输入租约删除；3 项 pure UI 测试覆盖两种 family 在窄屏的表格切换、播放器操作、禁用状态与 48 px 播放按钮。SDK Preview 提供三种主题。`verifyNativeMediaPreviewFlow` 为父主运行增加真实上传的 text/PDF/WAV/WebM、PDF 两页、解码器时间推进和实际 video texture 尺寸、播放/暂停/定位/音量断言。此文尚未宣称新增媒体 helper 已在 Linux/Android 主应用跑通；最终平台结论由父报告的实际检查点决定。

实际 SDK browser 三主题 Document and media preview 证据位于 `reports/raft-reference/html/preview-interactions.json`（agent workspace）：第二张工作表显示 Ready；播放/暂停回调更新状态；浏览器键盘实际把定位推进至 0:06、音量降至 95%。三张对应截图及干净 console 记录由 UI 验收代理生成。该证据只覆盖纯控件交互，不代替真实解码或系统设备证明。
