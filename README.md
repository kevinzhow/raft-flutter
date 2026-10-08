# Raft Flutter

Linux 和 Android 优先、已加入 macOS 和 iOS 宿主的 Raft Flutter 客户端，参照 Web 1.17.5 / `26f77ef`。当前同源码两平台完整功能流程已通过，移动布局和共享设计系统的视觉验收仍未完成，最终 Android APK 和 Linux 压缩包已构建，并通过实际安装／移目录运行及浏览器下载校验。Android 后台通知的冷进程投递、周期去重、系统点击及关闭/注销已实测通过；iOS 仅源码接入，编译和运行待 Mac／设备验证。

- [架构与阶段](docs/architecture.md)
- [Web 来源版本](docs/source-reference.json)
- [功能对齐清单](docs/feature-parity.csv)
- [逐组件验收](docs/widget-acceptance.md)
- [本地服务对照](docs/local-test-stack.md)
- [macOS 构建、权限与验收](docs/macos-evidence.md)
- [Android／iOS 后台收件箱兜底及验证边界](docs/background-inbox.md)

工程结构：`apps/raft_flutter`（产品）、`packages/raft_ui`（主题/组件）、`packages/raft_client`（协议）、`packages/raft_sync`（同步），原生存储/文件选择适配位于产品的 `lib/platform`。组件及主题生成物应有明确来源版本；公共源码镜像只作为参照。


工具链固定 Flutter 3.47.6 / Dart 3.13.5，通过 `tool/flutter` 调用。登录会话使用系统安全存储，工作区缓存使用 Drift SQLite；私有验收资料放于忽略的 `.local/`。

已在 Linux 和 Android 验证：登录和安全会话恢复、持久化草稿、刷新丢响应重试、幂等发送、中日文编辑、线程、断线消息回放、跨客户端未读状态、反应、任务创建/认领/状态/历史、搜索与收藏跳转、三种主题及退出。`packages/raft_ui` 提供独立 SDK Widget Preview；平台测试不由浏览器预览替代。

开发检查：`tool/flutter analyze --no-pub`，`tool/flutter test packages/raft_client/test packages/raft_sync/test packages/raft_ui/test --no-pub`。原生缓存测试及集成测试在 `apps/raft_flutter` 目录运行 `../../tool/flutter`。

附件、分享和通知的独立 OS 证据见 [附件](docs/attachment-evidence.md)、[分享](docs/sharing-evidence.md)、[通知与内容链接](docs/notification-content-evidence.md)。它们不替代主应用完整链路。历史功能基线覆盖线程、文档/PDF/音频/视频、操作卡、资源控制、管理/联合频道、侧栏、中文 Locale、主题与安全退出；后续源码需重跑。Android 后台兜底的独立原生证据见 [后台通知](docs/background-inbox.md)。Linux 服务端 desktop 消息 push 和 FCM/APNs 注册不由这些结果证明。

Linux 首次构建先运行 `tool/prepare-media-linux`，它只下载并展开固定 media 运行库到被忽略的本地目录，不修改主机或 Pub 缓存。PDF 应用内预览需要系统提供 `poppler-utils`；缺少时显示下载回退。具体版本、打包及兼容边界见 [Linux media 运行时](docs/linux-media-runtime.md)。

macOS 在安装 Xcode 与 CocoaPods 的本机运行以下命令；最低系统版本为 macOS 12，仅构建 Apple Silicon（ARM64）版本。构建产物为 `Raft.app`，后台打开方式及实际平台覆盖见 [macOS 验收记录](docs/macos-evidence.md)。

```sh
fvm install
fvm use 3.47.6
cd apps/raft_flutter
fvm flutter pub get
fvm flutter build macos --release
open -g build/macos/Build/Products/Release/Raft.app
```

完整工程检查用 `tool/check-project`。原生验收分别用 `tool/native-linux` 和 `tool/native-test emulator-5580`，需要自行建立隔离本地服务并在 `.local/test-user.json` 配置私有验收身份，不能把登录资料放进源码、资源或编译参数。两平台当前源码验收通过后，`tool/build-deliverables` 串行生成 Linux bundle 和 Android APK，并附 SHA256。APK 使用本地验收签名，尚未接入商店发布签名。

当前能力边界见 [对齐审查](docs/parity-review.md)：独立原生工作区多窗口尚未实现，超出原生 Mermaid 解析器的语法显示源码回退；外部 OAuth、Slack、Stripe、默认关闭的 conversion worker 与完整 Computer/Cindy 流程尚无配置后真实执行证明。

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

设计系统使用共享 tokens 与组件 recipes。尺寸来源、画面尺寸、原生触摸范围、安全区、窄屏换行与容器约束须统一表达并实际验证；新增页面复用这些规则。详见 [组件验收](docs/widget-acceptance.md)。

共享尺寸来源及尚未绑定的布局规则见 [尺寸合同](docs/design-dimensions.md)；详细源文件、行号、摘录与 SHA 在同名 JSON 中。该审计快照不代表像素或原生验收通过。

当前完整输入为 b98：仅附件测试使用支持的 Scrollable.ensureVisible 将真实标题居中，并等待有限时间内真实命中检查通过，再执行原有真实点击；PDF、音频、视频断言未改。工程与同源码 Linux／Android 整轮、最终制品运行与下载校验均已通过；这不证明 Search 自动定位或已解决此前 HTTP 异常。

## Final released artifact scope

The delivered b98 APK and Linux archive match the manifest bound to product commit `032f9f0442cf972c3e566c57ee9a19e8f361e2f3`. The real browser downloaded both archives and confirmed their sizes and SHA-256 against the independently reviewed manifest; all 221 report images decoded. See [released artifact evidence](docs/release-evidence.md) for exact hashes and probe boundaries.

The released APK smoke used an owned 16KiB Android emulator and synthetic input without authentication. Linux basic GUI/CJK interaction used a relocated archive, the build host’s isolated GTK/X11 session and an initialized empty SecretService keyring. Its live text readback passed, while the separately attempted AT-SPI Component.GetExtents method still timed out; screenshot-measured pointer input does not certify that coordinate method. Bundled libmpv PCM decoding passed separately. These checks do not establish store signing, physical devices, authenticated release workflows, Wayland or arbitrary Linux distributions. Pixel-level parity remains unaccepted, and the earlier HTTP parser failure has no confirmed cause.
