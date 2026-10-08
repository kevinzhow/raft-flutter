# Raft Flutter

Linux 和 Android 优先的 Raft Flutter 客户端，参照 Web 1.17.5 / `26f77ef`。当前源码已通过全部工程检查；修复移动线程/主聊天状态复用及 Android MediaCodec 视频输出后的当前 Android 完整验收正在运行，Linux 将随后串行重跑。之前 Linux b20 版本完整验收通过，不能替代当前源码结果。能力边界与逐项证据见功能清单，尚未封版。

- [架构与阶段](docs/architecture.md)
- [Web 来源版本](docs/source-reference.json)
- [功能对齐清单](docs/feature-parity.csv)
- [逐组件验收](docs/widget-acceptance.md)
- [本地服务对照](docs/local-test-stack.md)

工程结构：`apps/raft_flutter`（产品）、`packages/raft_ui`（主题/组件）、`packages/raft_client`（协议）、`packages/raft_sync`（同步），原生存储/文件选择适配位于产品的 `lib/platform`。组件及主题生成物应有明确来源版本；公共源码镜像只作为参照。


工具链固定 Flutter 3.47.6 / Dart 3.13.5，通过 `tool/flutter` 调用。登录会话使用系统安全存储，工作区缓存使用 Drift SQLite；私有验收资料放于忽略的 `.local/`。

已在 Linux 和 Android 验证：登录和安全会话恢复、持久化草稿、刷新丢响应重试、幂等发送、中日文编辑、线程、断线消息回放、跨客户端未读状态、反应、任务创建/认领/状态/历史、搜索与收藏跳转、三种主题及退出。`packages/raft_ui` 提供独立 SDK Widget Preview；平台测试不由浏览器预览替代。

开发检查：`tool/flutter analyze --no-pub`，`tool/flutter test packages/raft_client/test packages/raft_sync/test packages/raft_ui/test --no-pub`。原生缓存测试及集成测试在 `apps/raft_flutter` 目录运行 `../../tool/flutter`。

附件系统选择/保存与通知/分享平台适配的独立 OS 证据见 [附件](docs/attachment-evidence.md)、[分享](docs/sharing-evidence.md)、[通知与内容链接](docs/notification-content-evidence.md)。这些隔离平台探针不替代主应用完整链路。高级 Search/Saved/Activity 的请求与权限回归见 [源码审计](docs/resource-controls-source-audit.md)；2026-10-08 UTC 01:49:11 启动的较早 b20 版本 Linux 整轮已通过高级控制、任务多选、实际侧栏拖动、线程 inline 跳转、原生媒体/PDF、中文 Locale、Dark/Light 和安全退出，共53个截图检查点；终态清理另有定向测试，修复后的两平台当前源码整轮仍待实际结果。Linux 当前服务器不提供 desktop 消息通知；Android 通知限在线 Socket，不包含 FCM 或系统终止后的后台推送。

Linux 首次构建先运行 `tool/prepare-media-linux`，它只下载并展开固定 media 运行库到被忽略的本地目录，不修改主机或 Pub 缓存。PDF 应用内预览需要系统提供 `poppler-utils`；缺少时显示下载回退。具体版本、打包及兼容边界见 [Linux media 运行时](docs/linux-media-runtime.md)。

完整工程检查用 `tool/check-project`。原生验收分别用 `tool/native-linux` 和 `tool/native-test emulator-5580`，需要自行建立隔离本地服务并在 `.local/test-user.json` 配置私有验收身份，不能把登录资料放进源码、资源或编译参数。两平台当前源码验收通过后，`tool/build-deliverables` 串行生成 Linux bundle 和 Android APK，并附 SHA256。APK 使用本地验收签名，尚未接入商店发布签名。

当前能力边界见 [最终对齐审查](docs/parity-review.md)：独立原生工作区多窗口尚未实现，超出原生 Mermaid 解析器的语法显示源码回退；外部 OAuth、Slack、Stripe、默认关闭的 conversion worker 与完整 Computer/Cindy 流程尚无配置后真实执行证明。最终工程检查已通过353项 Dart 测试、29项 Python host 测试与全仓 analyze。当前工程源码哈希 `a05a8dd506db705120502b656e4641e38fcf9685fa245167ab0aaa9f0752415b`；Android 整轮正在运行，Linux 同版本将随后串行重跑。此前 Linux 完整验收的 b20 哈希和53检查点作为较早版本证据保留。
