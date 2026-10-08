# Raft Flutter

Linux 和 Android 优先的 Raft Flutter 客户端，参照 Web1.17.5 / `26f77ef`。6ab功能基线已通过Linux与Android完整主应用验收、353项Dart/29项host及全仓analyze。逐组件像素级设计对齐仍未完成；新视觉修正正在进行，最终安装包与新版验收尚未完成。

- [架构与阶段](docs/architecture.md)
- [Web 来源版本](docs/source-reference.json)
- [功能对齐清单](docs/feature-parity.csv)
- [逐组件验收](docs/widget-acceptance.md)
- [本地服务对照](docs/local-test-stack.md)

工程结构：`apps/raft_flutter`（产品）、`packages/raft_ui`（主题/组件）、`packages/raft_client`（协议）、`packages/raft_sync`（同步），原生存储/文件选择适配位于产品的 `lib/platform`。组件及主题生成物应有明确来源版本；公共源码镜像只作为参照。


工具链固定 Flutter 3.47.6 / Dart 3.13.5，通过 `tool/flutter` 调用。登录会话使用系统安全存储，工作区缓存使用 Drift SQLite；私有验收资料放于忽略的 `.local/`。

已在 Linux 和 Android 验证：登录和安全会话恢复、持久化草稿、刷新丢响应重试、幂等发送、中日文编辑、线程、断线消息回放、跨客户端未读状态、反应、任务创建/认领/状态/历史、搜索与收藏跳转、三种主题及退出。`packages/raft_ui` 提供独立 SDK Widget Preview；平台测试不由浏览器预览替代。

开发检查：`tool/flutter analyze --no-pub`，`tool/flutter test packages/raft_client/test packages/raft_sync/test packages/raft_ui/test --no-pub`。原生缓存测试及集成测试在 `apps/raft_flutter` 目录运行 `../../tool/flutter`。

附件系统选择/保存与通知/分享平台适配的独立 OS 证据见 [附件](docs/attachment-evidence.md)、[分享](docs/sharing-evidence.md)、[通知与内容链接](docs/notification-content-evidence.md)。这些隔离平台探针不替代主应用完整链路。高级 Search/Saved/Activity 的请求与权限回归见 [源码审计](docs/resource-controls-source-audit.md)；当前Android整轮 `2026-10-08T03:02:43.361866Z` 已完成通过，54个同runId截图检查点及对应PNG均已核验。覆盖真实线程inline导航、文档/PDF/音频/视频、操作卡、资源控制、管理/联合频道、侧栏、中文Locale、Dark/Light与安全退出；终态任务清理另有定向测试。同源码Linux整轮已于03:11:25启动并完成通过，53个检查点已核验。Linux当前服务器不提供desktop消息通知；Android通知限在线Socket，不包含FCM或系统终止后的后台推送。

Linux 首次构建先运行 `tool/prepare-media-linux`，它只下载并展开固定 media 运行库到被忽略的本地目录，不修改主机或 Pub 缓存。PDF 应用内预览需要系统提供 `poppler-utils`；缺少时显示下载回退。具体版本、打包及兼容边界见 [Linux media 运行时](docs/linux-media-runtime.md)。

完整工程检查用 `tool/check-project`。原生验收分别用 `tool/native-linux` 和 `tool/native-test emulator-5580`，需要自行建立隔离本地服务并在 `.local/test-user.json` 配置私有验收身份，不能把登录资料放进源码、资源或编译参数。两平台当前源码验收通过后，`tool/build-deliverables` 串行生成 Linux bundle 和 Android APK，并附 SHA256。APK 使用本地验收签名，尚未接入商店发布签名。

当前能力边界见 [最终对齐审查](docs/parity-review.md)：独立原生工作区多窗口尚未实现，超出原生 Mermaid 解析器的语法显示源码回退；外部 OAuth、Slack、Stripe、默认关闭的 conversion worker 与完整 Computer/Cindy 流程尚无配置后真实执行证明。最终工程检查已通过353项 Dart 测试、29项 Python host 测试与全仓 analyze。当前工程源码哈希 `6ab79f33a7f39f98523dadd38dfc1430fd2d7f8e75d10736d0c80050bd1c5701`；Android54与Linux53检查点整轮均已完成通过。这是功能基线；视觉修正后的新版必须重新验收，功能与平台结果不等于组件视觉验收。

设计对齐仍有明确缺口：默认Material控件与Web组件的形状、间距、字体和状态尚需逐项审查、修正，并以同版本、同数据、同主题、同尺寸的截图与差异报告验证。当前没有逐组件像素等价证明；详见[组件验收](docs/widget-acceptance.md)。
