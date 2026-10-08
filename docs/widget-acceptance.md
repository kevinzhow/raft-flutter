# 逐组件验收

## 当前恢复工作与还原验收门槛

2026-10-08 的 b98 安装包通过了功能和制品检查，但没有通过逐路由、逐消息类型和逐交互状态的还原验收。用户随后指出桌面页面组合、侧栏选中、头像、加载区、编辑器、底部导航、消息和线程的缺失。当前任务已恢复实施；下方历史平台通过记录不证明这些新修改。

还原验收必须从固定版本 Web 的实际挂载组件和路由分支建立清单，不能只从 Flutter 已有实现或测试清单反推覆盖。

| 必需范围 | 必需动作或变体 |
| --- | --- |
| 页面壳与导航 | 桌面各入口的侧栏类型和可见性；移动底栏点击、选中和返回；浏览器、Electron 搜索覆盖层与可选 workspace grid 分开记录 |
| 主列表与详情 | Search/Activity 点击前后、查询及筛选保留、详情和线程关闭、成员/计算机目录与详情、设置侧栏与内容、Saved 的 Chat 导航归属 |
| 消息与线程 | 人类、代理、紧凑系统消息、任务/动作消息、线程回复；原版实际存在的头像、时间、间距、文本层级和控制项分别记录 |
| 输入与时间线 | 首屏/分页等待、失败/重试、空内容、已加载内容；加载区归属；编辑器焦点、文本、附件、建议弹层、发送等待和错误；底部与安全区 |
| 共享组件状态 | 静止、hover、按下、选中、键盘焦点、展开、禁用、等待、错误；按角色列适用性，不能把普通按钮样式套给侧栏、rail、底栏或反应控件 |
| 头像 | 自定义图片、允许的地址格式、原版 Gravatar/default 优先级；实际请求和解码、加载/失败回退、身份切换后迟到响应 |

每个案例必须保存稳定 ID、Web 版本及组件来源、Flutter 源码哈希、实际挂载角色、测试数据、主题、窗口/DPR、状态适用性和具体动作。Brutal light、Elegant light 和 Elegant dark 各自保留操作前/后原图、实际布局/样式测量和结果。声明不适用须引用原版执行分支及原因；缺失、未实现、未运行和失败须分别保留。

组件预览、定向测试和完整功能测试各自保留证据；任何一种都不能替代产品实际挂载状态的配对。诊断页面使用公开 fixture 时必须标明其范围，不证明真实账户/API、原生运行或完整页面。缺失必需案例、无法对应当前源码的证据、未解决差异和未运行状态，均阻止把该范围宣称为“已还原”。交付安装包的功能验收与还原验收分别给出结果。

代码清单须区分模块导出、结构 slot、交互控件和状态拥有者。逐一核对实际挂载标签、产品覆写、默认/复合变体以及编译后样式优先级，再列出三主题适用状态；静态 recipe 行数或导出数量不构成交互控件覆盖率。清单尚未完成时须明确标为部分审计。

配对证据分别记录 Web 单帧捕获时间、原生单帧时间或明确的运行开始时间，以及实际生成/审查对照的时间。归档或文件时间不替代精确对比时间。修复状态和复验结果必须关联同一源码与案例；原失败不能被新截图覆盖。报告主视图展示成对对照、缺项及当前工作，不以单边最新图库代替。

响应式证据须同时记录真实窗口、MediaQuery/容器可用宽度、捕获边界、DPR和焦点来源。390×480的RepaintBoundary不能证明实际窗口为390×480；断点或键盘焦点不一致的配对须保留为诊断，按匹配上下文重拍。

消息/附件复用另需实际前后验证：会话切换立即恢复现有持久窗口与读取位置，继续保存已加载历史，后台刷新遵守最新权限与可见范围；重复挂载附件应复用已解码资源，账号切换、退出和权限撤销清空相应数据。Tooltip按实际全局600ms、本地成员250ms及相邻提示规则验证，持续观测打开时滚动位置、焦点和布局，不能只凭默认库延迟或最终截图判定。

发布前需要执行清单覆盖检查：固定 Web 清单中的每个必需 ID 必须对应实现或明确缺失记录，并对应状态结果；不能以单张首页截图、已存在的测试数或旧源码平台通过解除缺失项。当前全量外观验收仍未通过。

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
| RaftAttachmentCard | attachment_previews.dart 的 attachmentPreview，经 RaftPreviews 生成 Brutal light、Elegant light、Elegant dark；打开/下载/分享/错误重试回调与无操作按钮的 exportMode | 三主题打开/下载、48px 目标、上传时可编辑、exportMode callback；App 撤权/宿主消失/迟到 bytes/关闭缓存清理 | GTK/X11 与 Android DocumentsUI 真实选择/保存/取消；Linux 主应用图片检查点已通过。历史 Android 6ab 完整主运行通过；系统文件查看器打开断言未证明 |
| PNG/文件分享与接收 | 纯 PNG review/消息选择组件由独立组件验收覆盖；平台 FileProvider/chooser 没有浏览器 SDK Preview | 私有 lease、fresh scope、迟到读取、草稿追加/取消、grant/path/数量边界 | Android 独立系统 chooser/receiver/ContentResolver 实际 bytes 与 URL 接收通过；Linux 真实保存。主应用新版本分享/接收完整链路待验收 |
| 通知/内容 URI | 产品设置复用现有 RaftPanel/表单组件；原生通知 daemon、系统 permission 和 URI 转发不属于纯 UI Preview | scope/persistent preference/restart/race、fresh message routing、body/credential stripping | 隔离 Android 权限拒绝/允许、通知栏点击、warm/cold URI；Linux X11/private DBus popup 与 GLib 转发通过。Linux 服务端 desktop push 不支持；历史主应用仅验收在线 Socket；后台冷进程兜底另见 android-background-evidence.md |
| Fleet 私有页/操作 | 复用既有 RaftPanel/表单/菜单；本轮无新增纯 raft_ui 组件 | 五项同代账户/角色、迟到目录/凭证/文件、socket 删除与 HTTP 删除顺序回归通过 | Linux 01:49:11 完整主运行的 CRUD/inspection/runtime 检查点通过；历史 Android 6ab 源码整轮已通过；Linux同源码整轮已通过（6ab功能基线）。凭证与权限回归不由 Preview 代替 |
| Search/Saved/Activity/Tasks 筛选 | 已迁移共享筛选、选择与页面控件，Search/Saved/Activity/Tasks 保留作用域和权限约束；新源码的完整平台结果见下方 | exact mounted 参数、typed identity OR/AND、Unassigned、storage frontier、迟到目录/权限 popup、360px 布局 | Linux 01:49:11 完整主运行通过 Search/self-mentions/Saved query-sort/Activity grouping、Task 多选/board 检查点；终态清理为定向测试证据，历史 Android 6ab 源码整轮已通过；Linux同源码整轮已通过（6ab功能基线） |

Attachment SDK 的真实交互截图由组件验收报告记录；它们不是与 Web 同数据逐像素比较的 golden，也不证明 TalkBack、Linux 辅助技术或全部 hover/focus/text-scale 状态已验收。PDF/media 现提供原生应用内预览，text/Markdown/CSV/XLSX 提供结构化服务端预览；未知格式保留系统查看器。新增原生 media helper 已随较早 b20 源码的 Linux 01:49:11 完整主运行通过，历史 Android 6ab 源码整轮已通过；Linux同源码整轮已通过（6ab功能基线）。

Document/media 的 SDK browser 三主题实际交互已通过：XLSX 第二工作表数据与语义文本、Play/Pause、键盘定位 0:06、音量 95%；报告为 agent workspace `reports/raft-reference/html/preview-interactions.json`。新增 media 解码及 PDF 页面截图仍以父 native helper 为平台证明。

## 已验证的源码与当前边界

| 源码检查点 | 工程检查 | Linux 完整主应用 | Android 完整主应用 |
| --- | --- | --- | --- |
| 历史 `6ab79f33` | 353 Dart、29 host、分析器通过 | 通过；53 检查点，03:11:25 run | 通过；54 检查点，03:02:43 run |
| 历史 `0ea636e6` | 不由旧平台结果推断新版工程状态 | 通过；53 检查点，07:53:47 run | 失败；08:00:19 run，8 检查点后旧移动导航定位失效 |
| 移动导航 `518ad5e4` | 533 Dart、29 host、分析器通过 | 未运行 | 失败；08:56:29 run，44 检查点后 Mermaid 窄屏工具栏溢出及退出选择定位歧义 |
| 后续修正 `1b8906fa` | 541 Dart、29 host、分析器通过 | 未运行 | 未运行 |
| 共享布局 `348911c8` | 548 Dart、29 host、分析器通过 | 未运行 | 已开始后中断；09:28:15 run，Home/详情/历史通过，Search 全局等待停滞 |
| 历史修正 `e1ac2c23` | 549 Dart、29 host、分析器通过 | 未运行 | 失败；09:41:21 run，三主题 Home 与 Search 目标可见通过，随后显示源码后的复制点击失败 |
| 分组基础 `2b85d1b4` | 562 Dart、29 host、分析器通过 | 未运行 | 失败；10:01:22 run，分组组件挂载后，Search 部分遮挡的消息被接受，真实操作点击失败 |
| 可见范围修正 `d6cf1b57` | 563 Dart、33 host、分析器通过 | 未运行 | 失败；10:13:43 run，Search/Save 真实点击与 Copy 精确剪贴板通过；Expand 原本可点击，辅助滚动后移出命中区域 |
| 富文本点击辅助修正 `4df9efd8` | 563 Dart、33 host、分析器通过 | 未运行 | 失败；10:24:11 run，25 个检查点后切回聊天时 pumpAndSettle 超时；运行时采样确认持续重排 |
| 新导航、通知、Feedback 与初始布局 `ad337ead` | 696 Dart、33 host、分析器通过 | 未运行 | 失败；11:36:09 run，60 个检查点通过后，侧栏标题测试仍按旧大小写定位；保留此失败后修正测试 |
| 侧栏定位与独立复验 `7f39a5f4` | 696 Dart、33 host、分析器通过 | 未运行 | 独立侧栏实际操作、API 结果与恢复设置通过；完整流程未开始，此通过不替代整轮验收 |
| 共享会话规则与桌面铃铛复验 `1ca110f6` | 709 Dart、33 host、分析器通过 | 未运行 | 通过；12:06:34 run，66 个完整流程检查点与实际退出登录通过，原始证据已归档 |
| 共享规则与完整原生复验 `3ac80c8f` | 709 Dart、33 host、分析器通过 | 通过；12:13:48 run，56 检查点 | 通过；12:20:19 run，66 检查点；两平台实际退出登录与会话清除通过 |
| 发布配置显式化 `1844d4af` | 709 Dart、33 host、分析器通过 | 已开始后因补齐会话备份策略而中断；无整轮通过 | 未运行 |
| 最终备份策略 `14fd1064` | 709 Dart、33 host、分析器通过；实际 APK 发布构建预检通过 | 通过；12:44:12 run，56 检查点，实际退出及会话清除 | 失败；12:50:22 run，首轮 53 检查点后 HTTP 响应解析异常；12:55:15 同源第二轮 42 检查点后 PDF 真实点击未命中 |
| 最终附件命中辅助与完整复验 `b98e0a30` | 709 Dart、33 host、分析器通过 | 通过；13:10:10 run，56 检查点，实际退出及会话清除 | 通过；13:04:28 run，66 检查点，真实 PDF 点击与原生解码、管理操作、退出清空会话通过 |

以上时间均为 2026-10-08 UTC；完整源码哈希分别为 `6ab79f33a7f39f98523dadd38dfc1430fd2d7f8e75d10736d0c80050bd1c5701`、`0ea636e658e0d8042b6342e9e50d9ba504cc87492f1e51ad2e9b1a4f99b7baed`、`518ad5e4ca0686df5eb7805fcbde752a4d774fab9bd627a4dbae44e9f36947e3`、`1b8906fa579960daa933c0c18dc18cda7ecc3d648834e83967e2269840040d95`、`348911c8c934e37a7d5dcc39d5a8812115400a4e6aae9866c6a6de5fccbca916`、`e1ac2c23eff8c980e405b01ed92beaed54dd9e69e953aeb9429d5860fe216c5d`、`2b85d1b4a9ee271ab23eb582add5c8277d1e22821d6a37ddf645a3833413e9a6`、`d6cf1b57d689b28d4c2d88adb524ce727771ffd4aab79e88f217c822981d2a12`、`4df9efd8a0374ecaa877fe925c22377ec0ba273835d122a410546de93f96f032`、`ad337eade5901c79658179a06863646ea5f7d3b1a76398eb51878151c9e20b87`、`7f39a5f4f8b4d4265da6fb00a128dcb880e05f432b2803a11399b7bbdae64b40`、`1ca110f694349b8a540d073a810f8e77fdfdce34ce336c28b4f23f1082229877`、`3ac80c8fe00d6dd9cf1e5f58407a8c526cfccec9a28790fa3bbce5aa35a416d6`、`1844d4afe53cb45c150cca1e608adc313e83104f577520435d83500bbe79d884`、`14fd1064f16f726a7835c33e9a22b2239407fb422ab80b698777215bc4f7b72e`、`b98e0a301b74980654be7a5268f2ada2202541b2c2ba026b9a8b3f575a7fc079`。6ab 基线归档于 `.local/functional-baseline-6ab`，0ea Linux 归档于 `.local/functional-phase4-0ea636e658e0`。源码和 runId 决定证据适用范围；旧通过不能计为当前修改通过。

Search、Account、Appearance 和移动四项导航已有后续实现与定向回归。依据用户要求继续完善共享尺寸、响应式与布局约束；后续 348、e1ac、2b85、d6cf、4df9 与 ad337 已分别冻结并实际运行 Android，均未完成通过两平台流程。3ac 已完成同源码 Linux 56 与 Android 66 个原生功能检查点，证据已保留。发布构建随后要求明确三个 loopback 域名的 includeSubdomains=false；该默认值显式化形成 1844 源码，709 Dart、33 host 与全工程分析器已通过；Linux 复验开始后因还需明确会话备份策略而中断，Android 尚未运行。最终会话备份策略已冻结为 14fd 源码，配置为排除云端与设备转移备份中的本地状态；实际 APK 发布构建预检及 709 Dart、33 host、全工程分析器已通过；当前 Linux 56 个完整检查点已通过，Android 首轮在 53 个检查点后出现 HTTP 响应解析异常，已记录失败；同源码第二轮又在 42 个检查点后 PDF 真实点击未命中；随后仅修正附件测试的滚动定位与命中就绪辅助；b98 工程检查及同源码 Linux 56、Android 66 个完整检查点已通过；最终 APK／Linux 包构建、实际安装／移目录基本交互、媒体解码及发布报告浏览器下载 SHA 校验已通过。

视觉验收未完成。旧 `0e049d15` 的 30 组实际失败配对保留为历史；`518ad5e4`、`348911c8`、`e1ac2c23`、`2b85d1b4` 与 `d6cf1b57` 的三主题 Android Home 结构对照也均未通过。e1ac 背景色与按钮居中已有实测改进，2b85 已显示共享分组计数、折叠与排序操作；触摸适配后的布局、导航分组间距及原版提醒中心仍未完整验收。ad337 的三主题 Home 与真实系统通知弹窗已发布为六张原始截图；实际打开、320×288 尺寸及关闭操作通过，但没有判定像素通过。固定清单为 523 项，另有三组移动诊断。移动诊断使用原 Web 和原生各自真实的 412×915 图，不裁剪或缩放，但公开参考数据与原生工作区数据、安全区不同，不能充当同数据逐像素验收。原生根页面操作通过不代表字体、布局、颜色或全部状态与 Web 一致。

## 共享尺寸和响应式验收

提取组件 recipe 及产品 CSS 的共同合同：主题、密度、宽高断点、方向性 inset、图标与文字度量、布局/绘制/命中范围、安全区和容器可用空间。共享组件处理其约束；页面不另写相同尺寸。尺寸相同仍不足以证明布局正确：伸展与居中、Wrap/Row、浮动覆盖和正常流需要相应组合合同。

用同源真实渲染度量与组件测试验证长文本、窄屏、多个操作和文本缩放，检查回调、键盘顺序、命中范围与内容无重叠。触摸目标扩大不得默默扩大原版绘制尺寸或截取邻接内容的输入。当前源码的源绑定尺寸合同和这批原生复验仍在完善中。

## 历史 SDK 与平台证据

75 项历史实际 SDK 浏览器主题交互及对应截图已验证，包含附件、多主题文档/media 和 inline thread reply。它们不是同数据逐像素 golden，不证明 TalkBack、Linux 辅助技术或全部 hover/focus/text-scale 状态。较早 Android 042 MediaCodec Surface 与 Linux 原生 media helper 的定向结果仍保留各自源码边界；最终包中的实际解码和系统文件查看器打开还需验证。

共享尺寸来源及尚未绑定的布局规则见 [尺寸合同](design-dimensions.md)；详细源文件、行号、摘录与 SHA 在同名 JSON 中。该审计快照不代表像素或原生验收通过。

当前完整输入为 b98：仅附件测试使用支持的 Scrollable.ensureVisible 将真实标题居中，并等待有限时间内真实命中检查通过，再执行原有真实点击；PDF、音频、视频断言未改。工程与同源码 Linux／Android 整轮、最终制品运行与下载校验均已通过；这不证明 Search 自动定位或已解决此前 HTTP 异常。

## Final released artifact scope

The delivered b98 APK and Linux archive match the manifest bound to product commit `032f9f0442cf972c3e566c57ee9a19e8f361e2f3`. The real browser downloaded both archives and confirmed their sizes and SHA-256 against the independently reviewed manifest; all 221 report images decoded. See [released artifact evidence](release-evidence.md) for exact hashes and probe boundaries.

The released APK smoke used an owned 16KiB Android emulator and synthetic input without authentication. Linux basic GUI/CJK interaction used a relocated archive, the build host’s isolated GTK/X11 session and an initialized empty SecretService keyring. Its live text readback passed, while the separately attempted AT-SPI Component.GetExtents method still timed out; screenshot-measured pointer input does not certify that coordinate method. Bundled libmpv PCM decoding passed separately. These checks do not establish store signing, physical devices, authenticated release workflows, Wayland or arbitrary Linux distributions. Pixel-level parity remains unaccepted, and the earlier HTTP parser failure has no confirmed cause.
