# Activity 即时预览原生对比（2026-10-11）

修复后，点击不再等待 220ms 的单/双击仲裁才选择详情。在 MacBook-Pro 的隔离 macOS profile 窗口中，5 次热缓存打开的「鼠标松开 → 详情选中」中位数从 221.895ms 降为 0.414ms，「鼠标松开 → 选中后首帧 raster 完成」中位数从 233.105ms 降为 13.582ms。C 方案未选中时列表全宽，首击立即分栏。2026-10-11 后续按行身份修正：双击必须命中同一条目；点另一条立即换预览并重新计时。本表为修正前 ba6da19 的首击测量，后续修正未重跑原生性能，不能把本表当作新提交的实测。此结果验证移除导航门槛；不代表真实服务器、冷磁盘或稳定 120fps。

## 数据

所有时间从 App 收到真实 PointerUp 开始计，不含系统投递前的输入延迟。第一帧按 FrameTiming 中 buildStart >= selectionUs 的首帧选择；UI 回调与 raster 线程完成先后可不同。

| 条件 / 指标 | Before 70bdfa0 | After ba6da19（C） |
| --- | ---: | ---: |
| 首次冷打开 → 选中（单次） | 223.114ms | 0.253ms |
| 首次冷打开 → 首次 UI 帧回调（单次） | 270.094ms | 28.049ms |
| 首次冷打开 → 首帧 raster 完成（单次） | 275.218ms | 50.447ms |
| 热缓存 → 选中（5 次中位数） | 221.895ms | 0.414ms |
| 热缓存 → 选中（最小–最大） | 221.402–226.259ms | 0.393–0.695ms |
| 热缓存 → 首次 UI 帧回调（5 次中位数） | 233.174ms | 13.637ms |
| 热缓存 → 首帧 raster 完成（5 次中位数） | 233.105ms | 13.582ms |
| 热缓存 → 首帧 raster 完成（最小–最大） | 231.571–263.054ms | 7.993–13.953ms |

冷打开的 After 首帧 build 23.097ms、raster 24.083ms，仍有初始化成本。没有测显示器 present / vblank，也没有用此次数据证明 8.33ms 帧预算。首帧指标是详情被选择后的首帧，不等于完整远端回复已下载和显示的时间。每次观察都确认 Fixture parent 与 Fixture reply 已实际显示；热缓存分类在 PointerUp 时检查真实 ledger 内的回复。

## 相同条件与原始证据

- Before：`70bdfa019bd518870ee93e6e8224edb1d153de6d`。After 产品：`ba6da19`（完整 SHA 在 C 证据回执），基于同一提交；后续仅更新旧合同测试、注释和报告，不改变运行逻辑。
- 两边复制同一 `tool/performance/activity_preview.dart`，SHA256 `6da2f98af5be508b11998cb0ffdb0f1b93f7afd704c8cbce2f672ac3e8ad8005`。真实 WorkspaceView / ResourceView / WorkspaceController；内存账号、目录和本地 HTTP adapter，不连接任何服务器、不读取正式账号。
- Flutter 3.47.6 / Dart 3.13.5，macOS 27.0.1 arm64。两个 Profile 构建所含 FlutterMacOS 二进制 SHA256 都为 `695f85ae21ae7ae46c51855e8c45496a2e882bd9631335eed38718aad6fd1339`；完整 SDK、App/AOT、源提交与协议回执在证据包。
- 窗口截图均 2400×1664 pixels，不改变窗口大小。每边新进程冷点击一次，随后 Reset Activity → 点击五次；重置只关详情，保留 ledger 热窗口。两边都点击截图坐标 `[400, 490]` 的同一行；两边初始列表都全宽，C 在首击后立即分栏。第二次列表点击升级/详情普通点击的功能验收由实际挂载测试覆盖，本原生 harness 只测每次重置后的首击。
- 输入和退出只使用内置 Computer Use 绑定的后台隔离 App，不激活窗口、不移动系统指针。原生 App ID 分别 `app.raft.activityPreviewBefore` / `app.raft.activityPreviewC`；正式 App 没有安装、更新、退出或写数据。测完两隔离进程已退出。
- 样本仅在点击 Export samples 后写盘，测量路径不写日志。证据包保留 activity-preview-c-before/after-native.json、activity-preview-c-native-summary.json、activity-preview-c-native-receipt.json、相同 harness 和构建/相关测试日志。

这是一组顺序运行的本机诊断样本，未控制后台负载、温度及显示器刷新率，样本量也有限。移除固定等待的结论同时由实际点击测试和调用链支持；后续帧耗时不能作严格单因素归因。

初次编译的 Timeline.now 写法与 FramePhase 导入问题已修正，保留失败记录。先前 ff6e87f 校准组的 fixture ledger 未绑定 server，且先点过 AX 语义操作，不能用于冷/热分类；该数据单独归档，未纳入上表。AX 语义点击不产生 PointerUp，正式组全部使用窗口绑定的坐标输入。

## 复测

在隔离 worktree 使用仓库的固定 SDK wrapper，从 `apps/raft_flutter` 执行：

```sh
RAFT_FLUTTER_BIN=/path/to/pinned/flutter ../../tool/flutter build macos --profile --no-pub \
  --target=../../tool/performance/activity_preview.dart \
  --dart-define=RAFT_ACTIVITY_PREVIEW_REVISION=reviewed-commit \
  --dart-define=RAFT_ACTIVITY_PREVIEW_OUT=/absolute/path/samples.json
```

仅将编译后的 App 复制到测试目录，使用独立 CFBundleIdentifier / 名称并重新 ad-hoc 签名。生命周期和指针输入仍使用内置 Computer Use 后台绑定；若绑定不可用，停止依赖窗口的动作，不用 CLI 启动或全局输入替代。观察可点击行后冷点击一次；每次 Reset 后观察列表，再点击同一行五次；确认回复实际显示，然后 Export。保存样本、源提交、harness/engine/AOT 的 SHA256，再退出测试 App。

## 回归与审计

修正前 C 提交 d8908eb 的 35 个相关文件共 434 个测试通过，根静态分析无问题，设计系统审计无增长（未修改 baseline/allow 规则），macOS profile 构建通过。证据包保留日志。新测试覆盖三主题的实际全宽→分栏、350ms 后点击其他行升级首击（该规则后来按真实使用反馈撤销）、501ms 后正常选择其他行、详情关闭不升级、列表空白续接（后来撤销）、500ms 系统窗、Unread 行保留以及实际键盘/语义和嵌套操作；N27 原有未选中无详情容器断言保留。旧 N24d/N24e 使用分栏后的真实列表位置继续第二击；L04 独立选择在系统窗结束后执行，晚到响应、权限、焦点和历史断言保留。全量批次检查由 Cindy 执行。

此前 A 方案预留空列的测量为历史结果（热缓存首帧 250.943→14.955ms），原样保存在第一轮证据包，不纳入此 C 表。首次广泛 C 回归的 21 个失败和修正前日志保留，不能把它们标为未运行。


## 按条目身份修正（2026-10-11）

Kevin 实际使用发现连续点不同条目会误打开前一条。Cindy 9055206b 撤销原先跨行续接规则。现在只有系统窗内第二下命中同一条目 id 才升级完整页面；A→B 立即预览 B 并重启计时，A→B→B 打开 B。空白不升级，详情/工具栏/键盘保持普通行为；未选中全宽的 N27 断言不变。

重新计时保留当时可见行顺序及已测最低高度，防止 A 的已读徽章/行消失挪动 B；窗口结束后正常移除未读行。实际 WorkspaceView 三主题测试在分栏后验证 A→B 和 A→B→B（第三下已超过 A 的旧时间窗、仍在 B 的新时间窗），另有真实 Unread 点击验证 B 的矩形保持、原始未读/提及焦点。初次失败日志保留。L04 和 thread→channel/DM 回归也移除了为旧跨行规则添加的等待，直接在识别窗内切换，保留晚到响应/逐帧/历史断言。此轮为点击判定正确性修复，不新增性能收益结论。
