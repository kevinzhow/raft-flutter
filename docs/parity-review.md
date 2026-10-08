# Client parity review

Mounted source `26f77ef` / Web 1.17.5 / raft-ui 0.5.27. Functional results, visual reviews, native execution and final artifact verification are separate evidence.

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

## Remaining client implementation and rendering limits

- **Independent authenticated native workspace windows remain unimplemented.** Linux has one engine with single-instance URI forwarding. Separate workspace engines, focus/reuse and a shared secure session broker are missing. The configured Web-browser fallback is a separate capability and does not satisfy native-window parity. See `desktop-window-evidence.md`.
- **Full Web Mermaid grammar is not reproduced by the native renderer.** Supported diagrams, source/copy/large-view interactions and failure fallback are implemented and tested. Syntax outside the native parser uses source fallback; a complete diagram-family rendering claim is unsupported. See `message-presentation-evidence.md`.

No mandatory mounted management/auth/joint/resource flow is intentionally replaced by a generic JSON form or fabricated server success. The repaired enabled reply/preference adapters are not classified as experimental gaps.

## Current implementation and acceptance work

Search, Account, Appearance and mobile navigation now use newer source-backed controls and have targeted regressions. Mobile Home has four authorized roots (three for guests), and channel/thread/resource details hide the root bar. These changes are newer than the historical full-platform baseline. The 518ad5 Android run exercised actual root/detail navigation before later failures. The e1ac Android run additionally proved the actual Search target was attached and visible without test scrolling; it later failed on the real Mermaid Copy code tap after switching to source. The d6cf run then passed actual Search/Save taps and exact Copy clipboard readback, but failed Expand after the helper scrolled an already hit-testable control. None of these runs is an aggregate pass.

Shared dimensions and responsive composition are being consolidated before the next native attempt. The e1ac Home images now match all three source body background roles and prove centered native tab glyphs. Grouped headers/counts/disclosure/sort are mounted in the later 2b85 and d6cf runs. Remaining differences include their declared 48-pixel touch adaptation versus the source 24-pixel action layout, generic navigation recipes and native/source data/inset boundaries. The current integration batch adds explicit mounted navigation roles, a scoped system Notification Center and read-only Feedback pages through shared components and domain adapters. Their focused tests do not establish current full native or visual acceptance. Notification Center pointer/keyboard behavior, Home scroll retention, same-case visual equality, system screen-reader behavior and large-history performance require their own evidence. The system Notification Center is separate from message Activity and OS notifications; a similar bell icon alone is insufficient.

The ad337 Android run completed 60 checkpoints, including the retained-history transition, rich media/actions and OS notification navigation, before an obsolete sidebar title finder failed. Its failure remains preserved. The later 7f39 standalone sidebar run passed actual create/edit/drag, API result, DM visibility and snapshot restoration; this is a focused pass. Whole7f39 engineering checks passed, The mounted-channel and shared unread variant is now integrated. The 1ca Android run passed all66 checkpoints; the3ac helper-only correction subsequently passed all56 Linux and66 Android checkpoints on its own exact source hash. The historical pass is not reassigned. The final b98 release artifacts passed actual APK installation, relocated Linux basic GUI and PCM decode checks, followed by real browser byte-size and SHA-256 download verification.

Both Linux and Android functional suites passed on source 3ac. Android release lint then required explicit includeSubdomains=false on the existing three loopback domains. The resulting source 1844 passed all 709 Dart tests, 33 host tests and whole-project analysis; its Linux suite started and was interrupted for the subsequently identified secure-session backup policy correction, and Android did not start. The final policy source 14fd configures exclusions for local state in cloud backup and device transfer. Actual cloud restore and device transfer are not covered. Its actual APK release preflight and all 709 Dart tests, 33 host tests and whole-project analysis passed. The current Linux suite passed 56 complete checkpoints; The Android run failed after 53 checkpoints with an uncaught HTTP response parser exception; the same-source second run failed after 42 checkpoints when the real PDF title tap missed. Only attachment test scroll/reveal readiness was corrected. Source b98 passed engineering and all 56 Linux and 66 Android checkpoints, including actual logout and session clearing. The exact b98 released APK and Linux archive passed supplemental installed/relocated checks and actual published-download SHA verification. External account/provider callback and email delivery remain unconfigured; internal UI tests do not prove them.

## External or deployment prerequisites

| Capability | Implemented conditional client behavior | Unproved external operation |
| --- | --- | --- |
| Account/MCP/provider OAuth | Scoped callback, PKCE/nonce, link/unlink, refresh and masked credentials | Configured provider login/link/tool callback on Linux and Android |
| Slack bridge | Real flag, provisioning/readiness, pairing, preflight, epochs and disconnect | Configured Slack OAuth, provisioning and message delivery |
| Billing | Actual subscription summary, owner portal/checkout, proration/seat review and scheduled states | Configured Stripe purchase/portal/webhook/cancellation; no charge was made |
| Channel conversion | Real default-OFF gate, source command/job progress, retry/cancel/upload recovery and send fence | Enabled durable-worker conversion/recovery; no rollout/config was forced |
| Computer/provider onboarding | Source Computer instructions, scoped probes, correlated receipts, real runtime forms and setup projection | Configured Computer/provider canary and complete managed Cindy onboarding |
| Invitation/email flows | Mounted request/review/verification/reset surfaces | External email delivery; local fixture has no Resend client |

A missing deployment prerequisite is not a simulated success or an excuse to omit its conditional UI. Ordinary/private → joint is the mounted conversion route; completed joint → ordinary is not mounted. Production delivery needs its actual external configuration and explicit evidence.

## Source exclusions and platform contracts

The Activity TypeSpec transport remains experimental/off under the pinned Web contract; existing inbox/read-state APIs are used. Removed thread/task open-new-tab entrypoints are not restored. The mounted server restricts notification:push to mobile; Linux desktop message push is unsupported by that source. Android online-Socket local notifications are implemented, while an FCM/killed-app remote-push contract is absent from the mounted native registration route. These source/platform boundaries must not be reported as completed background-push or independent-window parity.

## Native media evidence

The historical 6ab full runs cover native document/PDF/audio/video controls, supported Mermaid and source fallback. The earlier 042 native-player receipt is auxiliary EGL/MediaCodec evidence. Android 518ad5 reached actual PDF/audio/media checks before its later failure; it is not an aggregate pass. These earlier receipts do not replace final verification of the latest source and packaged runtime.

Android cold-process background inbox delivery, the subsequent periodic deduplication check, actual OS notification activation and opt-out/logout cleanup were separately verified against c598e2c; see [background evidence](android-background-evidence.md). This does not prove iOS execution or later UI-source acceptance.

当前完整输入为 b98：仅附件测试使用支持的 Scrollable.ensureVisible 将真实标题居中，并等待有限时间内真实命中检查通过，再执行原有真实点击；PDF、音频、视频断言未改。工程与同源码 Linux／Android 整轮、最终制品运行与下载校验均已通过；这不证明 Search 自动定位或已解决此前 HTTP 异常。

## Final released artifact scope

The delivered b98 APK and Linux archive match the manifest bound to product commit `032f9f0442cf972c3e566c57ee9a19e8f361e2f3`. The real browser downloaded both archives and confirmed their sizes and SHA-256 against the independently reviewed manifest; all 221 report images decoded. See [released artifact evidence](release-evidence.md) for exact hashes and probe boundaries.

The released APK smoke used an owned 16KiB Android emulator and synthetic input without authentication. Linux basic GUI/CJK interaction used a relocated archive, the build host’s isolated GTK/X11 session and an initialized empty SecretService keyring. Its live text readback passed, while the separately attempted AT-SPI Component.GetExtents method still timed out; screenshot-measured pointer input does not certify that coordinate method. Bundled libmpv PCM decoding passed separately. These checks do not establish store signing, physical devices, authenticated release workflows, Wayland or arbitrary Linux distributions. Pixel-level parity remains unaccepted, and the earlier HTTP parser failure has no confirmed cause.
