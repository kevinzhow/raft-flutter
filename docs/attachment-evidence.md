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

本次定向证据：11 项 app 预览/权限测试通过，其中包括实际 Poppler 两页 PDF 解码、PNG 对比及无遗留页文件，真实 HTTP 失败清理、后台暂停/撤权后输入租约删除；3 项 pure UI 测试覆盖两种 family 在窄屏的表格切换、播放器操作、禁用状态与 48 px 播放按钮。SDK Preview 提供三种主题。`verifyNativeMediaPreviewFlow` 为父主运行增加真实上传的 text/PDF/WAV/WebM、PDF 两页、解码器时间推进和实际 video texture 尺寸、播放/暂停/定位/音量断言。2026-10-08 UTC 01:49:11.360590 启动的较早 b20 源码版本绑定 Linux 主应用整轮已完成通过，包括真实 text/PDF/audio/video helper。Android 同源码整轮和系统文件查看器打开仍待实际证据。

实际 SDK browser 三主题 Document and media preview 证据位于 `reports/raft-reference/html/preview-interactions.json`（agent workspace）：第二张工作表显示 Ready；播放/暂停回调更新状态；浏览器键盘实际把定位推进至 0:06、音量降至 95%。三张对应截图及干净 console 记录由 UI 验收代理生成。该证据只覆盖纯控件交互，不代替真实解码或系统设备证明。

2026-10-08 的独立 Linux `integration_test/native_media_test.dart` 已通过：真实账户登录、新建唯一频道、真实上传 TXT/PDF/WAV/WebM，并通过文档内容、PDF 两页、音频时间推进、视频 160×90 纹理、暂停、定位及音量断言；结束时仅删除该测试创建的频道。五张实际应用截图、完成记录与日志位于 `.local/media-smoke/` 和 `.local/native-media-test.txt`。视频截图实际显示彩条及帧内时间；音频显示三秒播放器。此独立运行未传入全套验收的 sourceHash，不能替代主测试的版本绑定报告；较早 b20 源码01:49:11 UTC的版本绑定 Linux 主运行已完成通过，包括全部媒体检查点。Android 同源码媒体及整轮仍由主报告判定。

该运行首先复现了媒体加载失败：禁用外部引用时，media_kit 的临时播放列表 `loadlist` 被 libmpv 拒绝。修复保留 `access-references=no`、禁用脚本/自动配对文件及仅允许 file 协议，使用公开原生 `loadfile` 命令直接加载已授权的私有本地输入；不把签名地址交给播放器，也不启用外部播放列表。[mpv 的引用限制与加载命令](https://mpv.io/manual/stable/) 是该适配的底层合同。

Current acceptance revision: `6ab79f33a7f39f98523dadd38dfc1430fd2d7f8e75d10736d0c80050bd1c5701` includes the mobile main/thread ChatView rebind repair. Engineering 353 Dart/29 host/analyze passes; Current-source Android full is running first, then Linux will rerun serially. The 01:49:11 Linux proof above belongs to the earlier b20 hash, not this revision.

## Android 原生视频 Surface 修复及辅助证据

较早 Android35730整轮通过操作卡/runtime、TXT、PDF两页和WAV暂停/定位/音量后，视频输出失败：mpv `vo=gpu` 在该设备的 EGL GLES context 上发生 fatal，播放进入 idle。Android 已切换为平台专用的 `mediacodec_embed` / MediaCodec Surface 输出，继续使用官方 media_kit1.2.6 / media_kit_video2.0.1；Linux 的视频输出路径不随此修复改变。普通状态流不能覆盖已经确认的错误，fatal 错误保持直到新输入/重试明确清理。

实际 Android `native_player_test` 两项通过。辅助运行 `.local/player-smoke-android/result.json` 记录 completed=true，且 sourceHash记录较早媒体修复版本 `042f2347f3424508538bfbc9dce000d3f63f50935b1490ec37ec2606adfd6295`：真实视频160×90，播放位置332ms，暂停成功，定位1500ms，音量40，原生 `idle-active=no`、`vo=mediacodec_embed`、`pause=yes`。证据还有 `.local/player-smoke-android/video-playing.png`、`android-screen.png` 和 `.local/native-player-android.txt`；截图已存在。该辅助原生 probe证明真实解码、Surface及播放器控制，不能替代整个主应用工作流。较早 Android49113已通过真实主应用视频/media及通知栏点击，但整轮在点击通知后立即查询消息而未等待异步加载的测试断言失败。该测试等待已修复；当前4baf源码先运行 Android19417，再串行重跑 Linux，两平台完整验收仍pending，之前 Linux b20整轮保留为较早版本证据。
