# Raft Flutter 性能调优实战手册

> 本文档面向 `raft-flutter` 日常开发与 Review，对应仓库基线 `origin/cindy/integration`（`v1.21.23+40` / `94aa4eb03`）。
> 配套索引与专题文档：[performance.md](performance.md)（开关与门禁总览）、[performance-lab.md](performance-lab.md)（Perf Lab 场景与对比）、[message-performance.md](message-performance.md)（P01 基准）、[idle-cpu.md](idle-cpu.md)（空闲 CPU 与帧调度）。

---

## 1. 性能预算与基本原则

- **帧预算**：每帧 UI 线程与 Raster 线程各自控制在 **8.33 ms** 以内（120 Hz 目标）；当前 Linux 60 Hz 门禁要求 **0 帧超过 16.7 ms** 且连续运动中 **0 掉帧（stutter）**。
- **体验优先**：滚动、切频道、打开页面和拖拽改窗的流畅度是硬门槛，优先于像素级对齐（见 `AGENTS.md`）。
- **首帧即最终、再次访问即时呈现**：已访问频道/消息串/列表直接展示缓存，后台静默刷新；数据更新原地增量替换，不触发 loading 闪烁或整页重建。
- **只信 Profile 真机/原生测量**：Debug 模式数据无效；Widget 测试的挂载计数不能替代原生 Profile 帧耗时；单次结论必须注明环境、主题、语义开关与宿主机负载。

---

## 2. 性能排查与基准工作流

### 2.1 标准测量工具

| 目的 | 命令 | 关键产出与注意点 |
| --- | --- | --- |
| **帧耗时 & 归因（日常首选）** | `python3 tool/performance/lab.py run --out .local/performance/lab/<name> --scenarios steady-scroll,mount-*` | 输出 `summary.md`、最差 5 帧 UI CPU 采样与 Raster Timeline（`*.attribution.json`）。宿主机 1 分钟负载 > `0.35 × CPUs` 会拒绝启动（强制运行会标 `NOISY`，不可作基线）。 |
| **改动前后回归对比** | `python3 tool/performance/lab.py compare .local/performance/lab/<before> .local/performance/lab/<after>` | UI/Raster p90/p99 增长 >10% 且 >0.5 ms、超 16.7 ms 帧数增加、stutter 增加、超 8.33 ms 占比涨 >2pp 或每行 mount p50 变差均判回归。 |
| **Linux 快速异常探测** | `python3 tool/performance/lab.py detect --out .local/performance/detect-<name> --scenarios all` | 自动拉起独立 Weston GPU 会话；单场景加 `--scenarios keyboard`，归因加 `--details`；以 `detection.md` 的 `ISSUE / REVIEW / NOT_RUN` 为准。 |
| **空闲 CPU / 后台唤醒** | `tool/idle-cpu/run.sh <label> [seconds] [scenario,...]` | 用独立 Profile App 测真实空闲（`flutter_test` 绑定会每帧自动重排帧，会掩盖空闲唤醒问题）。 |
| **Android 真机页面切换** | `python3 tool/performance/android_transitions.py --device <serial> --out .local/performance/android-transitions/<run> --themes brutal-light --scenarios nav-home-channel,nav-tabs` | 强制使用隔离包名 `app.raft.raft_flutter.linkperf` 与 `--keep-app-running`，绝不触碰正式 App。 |
| **P01 消息滚动回归门禁** | `python3 tool/performance/run.py --out .local/performance/candidate --reference .local/performance/reference` | 500 条中英文 Markdown/代码/图片/表情消息，3 主题 × 3 场景（滚动、上下文滚动、原生改窗），分别测 `--semantics` 开/关。 |

### 2.2 深度采样开关

- **深调用栈归因**：`RAFT_LAB_DEEP=1 FLUTTER_ENGINE_SWITCHES=1 FLUTTER_ENGINE_SWITCH_1=dart-flags=--max_profile_depth=600`（防止深层 Widget 栈丢弃叶子帧）。
- **冷字体回退检测**：`RAFT_LAB_FONT_KEYS=1`（列出未被 `raftFontWarmUpStyles` 覆盖的字体组合；首次命中冷字体会造成 50–200 ms 引擎卡顿）。
- **区分 Dart 重建 vs 原生 Present 等待**：如果一帧出现极长 Raster（例如 41.8 ms）搭配极短 UI（0.9 ms），通常是原生 `queueBuffer`/VSync 等待，不要误判为 Dart Widget 成本。
- **Linux VSync 统计**：`RAFT_LINUX_VSYNC_STATS=1` 每秒打印帧时钟投递分类（`tick` / `late after a tick` / `timer`）；`RAFT_LINUX_IMPELLER=0|1` 用于 Skia/Impeller A/B。

---

## 3. 用结构化门禁阶梯根治重复性能问题

`raft-flutter` 遵循「把教训编码进结构」的原则：**假设下一个修改代码的人（或 Agent）只打开了当前文件、照抄最近的写法、走能编译通过的最短路径。** 同一类性能退化出现两次，就必须按从高到低的层级永久封堵：

```
1. 架构消除（Architecture）  ── 状态唯一归属、只留一条正确路径、删掉旧 API（例如 WorkspaceEntitySelection 替代裸 entityDirectory）
        │ 做不到时降级
2. 类型约束（Types）         ── 用不可变值对象/强类型 revision 让错误状态写不出来（例如 _ReactionRevision 替代裸 Map/List）
        │ 仍能编译通过时降级
3. 静态门禁（Lint + Ratchet）── tool/raft-lints / tool/perf-audit 报错直接写明替换方案；存量多时用 baseline 只降不升
        │ 语义无法静态判定时降级
4. 行为回归测试（Test）      ── 用 widget/perf 测试断言逐帧不重建、零空闲唤醒、零重复请求（先在旧代码跑红）
        │ 仅剩主观判断时
5. 文档规范（Docs）          ── 本手册与 AGENTS.md；没有门禁保护的纯文档条款会在后续迭代中退化
```

---

## 4. 高频性能反模式与真实 Before / After 示例

以下 10 类反模式全部来自 `raft-flutter` 真实提交（PR #716、PR #719）及 2026-11 全仓性能审计。

### 4.1 渲染期 `UniqueKey()` 破坏元素复用（PR #719 `c7153ab55`）

**根因**：在 `build()` 或子组件构造中生成 `UniqueKey()`，每次重建都会强制销毁并重建整个 `Element` 与 `RenderParagraph`，丢失文字排版缓存。

```dart
// ❌ Before (b9e9b57af — third_party/flutter_markdown_plus/lib/src/builder.dart:1031)
Widget _buildRichText(TextSpan text, {TextAlign? textAlign, String? key}) {
  final Key k = key == null ? UniqueKey() : Key(key);
  return Text.rich(text, key: k);
}

// ✅ After (PR #719 c7153ab55)
Widget _buildRichText(TextSpan text, {TextAlign? textAlign}) {
  return Text.rich(text, textScaler: styleSheet.textScaler);
}
```

**门禁**：`perf.unique_key_in_render`（零基线）。

---

### 4.2 全局 `setState` 误伤整条消息流（PR #719 `6aed01172` / `2c4e79f69`）

**根因**：覆写 `setState` 调用 `timelineKeys.invalidateRows()`，导致任何局部 chrome 状态变更（右键菜单、滚底按钮、悬浮条、输入框辅助栏）都把全屏所有消息行判为失效。

```dart
// ❌ Before (b9e9b57af — apps/raft_flutter/lib/features/chat_view.dart:212)
@override
void setState(VoidCallback fn) {
  timelineKeys.invalidateRows();
  super.setState(fn);
}

// ✅ After (PR #719 2c4e79f69)
void setRowState(VoidCallback fn) {
  timelineKeys.invalidateRows();
  setState(fn);
}
```

**门禁**：`perf.global_row_invalidation_in_setstate`（零基线）。

---

### 4.3 行级 Revision Key 里放入可变/新分配集合或 `jsonEncode`（PR #716/#719 + 全仓审计 P0）

**根因**：Dart 的 `Map` / `List` / `Set` 默认按引用相等（`identical`）比较；把每次 getter 新建的 `Map.unmodifiable(...)` 放进 Record revision key，会让缓存命中率归零。另一方面，在每行 revision 或 `addListener` 里做 `jsonEncode(...)` 会按可见行数 × 推送频率制造 CPU 与 GC 风暴。

```dart
// ❌ Before (apps/raft_flutter/lib/features/chat_timeline_semantics.dart:4-14)
// ModelLabelCatalogStore.catalog 每次读取都构造新的 AgentModelLabelCatalog + Map.unmodifiable
Object externalRowRevision(RaftMessage message) => (
  ...,
  message.string('senderType') == 'agent'
      ? (agentPresentation.authorized, agentPresentation.modelLabels.catalog?.machines)
      : null,
);

// ❌ Before (b9e9b57af — chat_timeline_presentation.dart:158-159)
jsonEncode(threadSummary),
jsonEncode([w.reactionViewer.reacted(id)?.toList(), w.pendingReactionTargets(id)]),

// ✅ After
// 1. Store 维护单调递增 int revision，仅在数据变化时 ++revision
agentPresentation.modelLabels.revision,
// 2. 用不可变值对象（如 _ReactionRevision / rowDeepEquals）替代 jsonEncode
reacted == null && pending == null ? null : _ReactionRevision(reacted, pending),
```

**门禁**：`perf.json_encode_in_hot_path`（ratchet）。

---

### 4.4 跨 Store 转发与根 `WorkspaceController` 通知风暴（全仓审计 P0）

**根因**：
1. `receipts.addListener(w.notifyListeners)` 把单频道已读进度放大为全工作区广播。
2. `WorkspaceSession.event` 对未识别事件默认落到 `context.changed()`，导致 `agent:typing`、`activity:changed`、`daemon:status` 等高频或专属事件全部触发根 `WorkspaceController.notifyListeners()`。
3. `buildWorkspace` 顶层用 `Listenable.merge([w, ...])`（且在 `build()` 内联新建），每次广播都会重跑整个 Shell、甚至在非聊天页白算并丢弃 `sidebar()`。
4. `dueWindows` 把 `changes.isEmpty`（ledger 未变）误判为 overrun，触发全部最多 64 个历史窗口重扫与 `jsonEncode(permissions)`。

```dart
// ❌ Before (apps/raft_flutter/lib/features/agent_read_badge.dart:82)
receipts.addListener(w.notifyListeners);

// ❌ Before (apps/raft_flutter/lib/features/workspace_view.dart:1275)
Widget buildWorkspace(BuildContext context) => QuietListenableBuilder(
  listenable: Listenable.merge([w, ChannelAccessLoss.of(w.client), ...]),
  ...
);

// ✅ After
// 1. 徽章/已读头像直接在叶子组件监听 ReadReceipts，绝不转发到 w.notifyListeners
// 2. Listenable.merge 缓存为 State 字段，仅在 didUpdateWidget 依赖变更时重建
late Listenable _shellChanges = Listenable.merge([_shellSelection, ...]);
// 3. 只需要身份/作者名称的页面使用 WorkspaceEntitySelection(dir, (d) => d.authorRevision)
```

**门禁**：`perf.cross_notifier_forward`（P0 ratchet）、`perf.inline_listenable_merge_in_build`（P0 ratchet）、`perf.external_workspace_notify`（P2 ratchet）。

---

### 4.5 `CustomPainter.shouldRepaint` 按引用比对列表 + 无条件 `RenderObject.invalidate()` / `alwaysNeedsCompositing`（全仓审计 P0）

**根因**：
- `RaftOuterShadowPainter.shouldRepaint` 写了 `old.shadows != shadows`，而 `RaftRecipeBox.build` 每次都生成新 `List<BoxShadow>`，导致全站按钮/卡片每次重建都重绘阴影并执行 `Path.combine`。
- `RaftCollapsible` 对所有未展开消息行（即使只有 1 行、根本没有溢出）返回 `alwaysNeedsCompositing => true`，强迫合成器为每行分配独立 Layer。
- `RaftUnderlines.updateRenderObject` 每次父组件重建都调用 `renderObject.invalidate()`，清空已缓存的 `_paragraphs` 文字选区框。

```dart
// ❌ Before (packages/raft_theme/lib/src/outer_shadow_painter.dart:169)
bool shouldRepaint(RaftOuterShadowPainter old) =>
    old.shadows != shadows || old.radius != radius;

// ✅ After
bool shouldRepaint(RaftOuterShadowPainter old) =>
    !listEquals(old.shadows, shadows) || old.radius != radius;

// ✅ RaftCollapsible 仅在真正溢出裁切时申请合成层
@override
bool get alwaysNeedsCompositing => _fadeColor != null && _builtFor == true;
```

**门禁**：`perf.should_repaint_collection_identity`（P0 ratchet）。

---

### 4.6 `build()` / `paint()` 中重复创建 Formatter、Markdown 解析器、`TextPainter` 与 `RegExp`（PR #719 `fc7dd9e79` + 全仓审计 P1）

**根因**：在 `build()`、Widget getter 或 `paint()` 循环内反复构造 `SourceTimeFormatter`、`md.Document(...).parse(...)`、`utf8.decode(bytes)`、`TextPainter(..layout())` 或字面量 `RegExp(...)`。

```dart
// ❌ Before (b9e9b57af — chat_view.dart:1662; 现状见 thread_outline_list.dart:257)
SourceTimeFormatter get timeFormatter => SourceTimeFormatter(
  locale: Localizations.localeOf(context).toLanguageTag(),
);

// ❌ Before (packages/raft_ui/lib/src/icons.dart:299)
while (true) {
  if (RegExp('[a-zA-Z]').hasMatch(source[i])) { ... } // 每个 SVG 命令编译一次 RegExp！
}

// ✅ After
// 1. 参考 ChatTimelinePresentation.timeFormatter(context, user)，按 settings 元组缓存实例
// 2. 常量 RegExp 全部提升到 top-level final 或 static final
// 3. TextPainter 测量统一走 raftTextMetricsCache 或下沉至 RenderObject.performLayout
```

**门禁**：`perf.uncached_formatter_or_parser_in_render`、`perf.text_painter_in_render`、`perf.regexp_in_hot_method`、`perf.sort_in_hot_path`。

---

### 4.7 宽泛 `MediaQuery.of(context)` 与绕过 `RaftViewportBreakpointScope`（全仓审计 P1）

**根因**：`MediaQuery.of(context)` 订阅所有维度，移动端软键盘动画（60/120 fps `viewInsets`）和桌面窗口缩放会带动整棵子树重建。同理，在 `RaftViewportBreakpointScope` 外读取 `MediaQuery.sizeOf(context).width` 并写入 `rowStyle`，会导致桌面拖拽缩放每 1 px 都废掉所有消息行缓存和 `TimelineExtentIndex`。

```dart
// ❌ Before (packages/raft_ui/lib/src/adaptive_workspace.dart:1334)
final media = MediaQuery.of(context);
final keyboard = media.viewInsets.bottom;

// ✅ After
final keyboard = MediaQuery.viewInsetsOf(context).bottom;
// 仅按断点分栏的组件使用 raftBreakpointWidth(context)
```

**门禁**：`perf.broad_media_query_of`（ratchet）。

---

### 4.8 `AnimatedBuilder` 内直接返回 `Opacity` 与 `Offstage` 漏包 `TickerMode`（全仓审计 P1）

**根因**：
- 在 `AnimatedBuilder` 里 `return Opacity(...)` 每帧触发 Dart build 和 `saveLayer` 开销；改用 `RepaintBoundary` + `FadeTransition` 可把动画留在合成层。
- `Offstage` 不会暂停子树 `Ticker`（见 `docs/idle-cpu.md`），也会让依赖 `TickerMode.valuesOf(context).enabled` 的页面（如 `SourceChannelFilesView`）误判自己仍可见。

```dart
// ❌ Before (packages/raft_ui/lib/src/indicators.dart:516-525)
AnimatedBuilder(
  animation: pulse,
  builder: (context, child) => Opacity(opacity: ..., child: child),
  child: box,
)

// ✅ After (参照 packages/raft_ui/lib/src/quoted_message_card.dart:227-247)
RepaintBoundary(child: FadeTransition(opacity: _opacity, child: box))

// ❌ Before (apps/raft_flutter/lib/features/channel_side_column.dart:350)
Offstage(offstage: !shown, child: card)

// ✅ After
Offstage(offstage: !shown, child: TickerMode(enabled: shown, child: card))
```

**门禁**：`perf.animated_builder_opacity`、`perf.offstage_without_ticker_mode`（与现有 `avoid_unreviewed_idle_work` 形成闭环）。

---

### 4.9 高频输入/上传/播放流与周期时钟重建整棵容器树（全仓审计 P0/P1）

**根因**：
- **Composer 按键**：每次击键既向 `ComposerSlot` 回弹 `draftChanges` 重建整个输入包装层，又无防抖触发 `saveDraftScope`（SQLite 事务 + >32 KB 时启 `Isolate.run`）。
- **上传进度**：multipart 上传未量化 `onSendProgress`，每次分片回调重建整个 `ComposerSlot` 和所有附件缩略图 chip。
- **音视频播放**：15–60 Hz `position` 流直接驱动 `AttachmentPreviewDialog` / `MediaVideoPage` / `InlineAudioAttachment` 顶层 `setState`/`notifyListeners`，连控制栏隐藏时都在每帧重排 `LayoutBuilder`。
- **相对时间时钟**：1s/15s/60s `RaftForegroundPeriodic` 驱动整张 `AgentNowCard` / `RaftDmHeader` / `RaftInboxItem` 重建。

**标准解法**：
1. 拆分「结构/离散状态」与「高频标量流（`ValueListenable<Duration>` / `ValueListenable<int>`）」；高频流只绑定到进度条/时间文字叶子节点。
2. 本地编辑器回写草稿与外部草稿更新分离，磁盘草稿保存做 300–500 ms 防抖并在发送/切页/`dispose` 时 flush。
3. 周期时钟只包住最小的时间文本叶子节点，并在 `didChangeDependencies` 遵循 `TickerMode.valuesOf(context).enabled`。

---

### 4.10 非懒加载长列表与冷启动/切频道串行 `await` 瀑布（全仓审计 P0/P1）

**根因**：
- 多个二级页（`ComputersRack`、`ChannelMembers`、`AgentActivityOverview`、`ThreadOutlineList`、`ChannelSideTasksPanel`、`ArtifactFilesPanel`、`ArtifactCommentsPanel`）把无界数据塞进 `ListView(children: [for ...])`、`SingleChildScrollView(child: Column([for ...]))` 或 `SliverToBoxAdapter(child: Column(...))`，叠加卡片 `IntrinsicHeight` 二次布局与离屏 `initState` HTTP 扇出。
- `selectServer` 与 `selectChannel` 串行 `await` 多条互不依赖的 SQLite 读/写（草稿、窗口、位置、写回），阻塞缓存首帧与网络 tail GET 发起。

**标准解法**：
1. 无界集合一律使用 `ListView.builder` / `SliverList.builder` / `SliverList.separated` + 稳定 `ValueKey(id)` + `findChildIndexCallback`；避免在滚动列表项内使用 `IntrinsicHeight`。
2. 独立磁盘读取与网络请求用 `Future.wait` 并行；先渲染缓存、接受新数据后立即关闭 loading，再异步落盘（保留 `request.current` / `generation` 围栏）。

**门禁**：`perf.eager_scroll_loop`（ratchet）。

---

## 5. 自动化性能门禁一览

### 5.1 已有门禁（`tool/raft-lints` + `tool/preflight`）

- `avoid_unreviewed_idle_work`：禁止 `scheduleTask` / `Priority.idle` / 零延迟 Timer / 未审 `Timer.periodic` / `.repeat(` / 原始 `Ticker`。
- `avoid_raw_image_decode`：禁止裸 `Image` / `NetworkImage` / `instantiateImageCodec`，强制走 `RaftSizedImage` 按显示尺寸解码。
- `avoid_unreleased_resource`：强制释放 `AnimationController`、`ScrollController`、`TextEditingController`、`FocusNode`、`ValueNotifier`、`Timer`、`StreamSubscription`、Observer。
- `tool/structure-audit`：限制热点文件（`chat_view`、`workspace_view`、`workspace_controller`、`resource_view`、`main`）的行数、token 数和字段膨胀。

### 5.2 性能审计门禁（`tool/perf-audit`）

`tool/perf-audit --check` 已接入 `tool/preflight`，与 `tool/ds-audit` 一致采用 **Ratchet（只降不升）** 工作流：基线保存在 `tool/perf-audit-baseline.json`，功能分支不得增加任何文件的违规计数，也不要在功能分支手动修改基线文件（合入后由集成负责人运行 `tool/perf-audit --update-baseline` 统一下调）。合理特例在当行或上一行写 `// perf-allow: <具体原因>` 并经 Review 批准。

| 规则 ID | 级别 | 拦住的问题 | 报错中给出的修复指引 |
| --- | --- | --- | --- |
| `perf.unique_key_in_render` | P0 | `build`/渲染方法内的 `UniqueKey()` | 改用稳定 `ValueKey(id)` 或省略 key |
| `perf.global_row_invalidation_in_setstate` | P0 | `@override setState` 内调用 `invalidateRows()` | 拆分为 `setRowState()` 与按行 revision |
| `perf.cross_notifier_forward` | P0 | `store.addListener(w.notifyListeners)` | 叶子组件直接监听目标 store |
| `perf.inline_listenable_merge_in_build` | P0 | `build()` 内联创建 `Listenable.merge([...])` | 缓存为 `State` 字段，仅在 `didUpdateWidget` 更新 |
| `perf.should_repaint_collection_identity` | P0 | `shouldRepaint` 中用 `!=`/`==` 比较 `List/Map/Set` | 改用 `listEquals` / `mapEquals` / `setEquals` |
| `perf.json_encode_in_hot_path` | P1 | 渲染/revision/authority/listener 中同步 `jsonEncode` | 改用 `rowDeepEquals`、值对象或引用缓存 token |
| `perf.uncached_formatter_or_parser_in_render` | P1 | `build()`/getter 内未缓存构造 `SourceTimeFormatter`/`DateFormat`/`md.Document`/`utf8.decode` | 按 locale/输入缓存，或使用 `raftMarkdownAstCache` |
| `perf.offstage_without_ticker_mode` | P1 | `Offstage` 缺少配对 `TickerMode` | 包裹 `TickerMode(enabled: !offstage, ...)` |
| `perf.broad_media_query_of` | P1 | 裸 `MediaQuery.of(context)` | 改用 `sizeOf`/`viewInsetsOf`/`paddingOf`/`textScalerOf` |
| `perf.animated_builder_opacity` | P1 | `AnimatedBuilder` 直接返回 `Opacity(...)` | 改用 `RepaintBoundary(child: FadeTransition(...))` |
| `perf.text_painter_in_render` | P1 | `build()`/`LayoutBuilder` 内未缓存 `TextPainter.layout` | 走 `raftTextMetricsCache` 或 `RenderObject.performLayout` |
| `perf.sort_in_hot_path` | P1 | `build()`/高频 `update()`/getter 内未缓存 `.sort()` | 在写入/变更时预排序或按引用缓存 |
| `perf.eager_scroll_loop` | P1 | `ListView`/`SingleChildScrollView(Column)`/`SliverToBoxAdapter(Column)` 动态 `for` 循环 | 改用 `ListView.builder` / `SliverList.builder` |
| `perf.regexp_in_hot_method` | P1 | 方法/函数体内重复编译常量 `RegExp(...)` | 提升到 `static final` 或顶层 `final` |
| `perf.external_workspace_notify` | P2 | `features/` 直接调用 `w.notifyListeners()` | 功能 store 自持独立 `ChangeNotifier` |

---

## 6. PR 提交前性能自检清单

1. **跑静态门禁**：`tool/preflight`（含 `raft-lints`、`structure-audit`、`ds-audit`、`perf-audit --check`）。
2. **检查监听粒度**：新加的 `ListenableBuilder` / `addListener` 是否只订阅最小变更源？是否避开了根 `WorkspaceController` 与裸 `entityDirectory`？
3. **检查列表与媒体**：无界集合是否全部懒加载并带稳定 `ValueKey`？高频流（输入/上传/播放/秒表）是否收敛在叶子节点？
4. **检查空闲与动画**：所有 `Offstage` 是否配对 `TickerMode`？动画是否用 `FadeTransition`/`RepaintBoundary` 且响应减弱动效？
5. **涉及滚动/切页/渲染热点时跑 Profile 对比**：在空闲宿主机跑 `tool/performance/lab.py run` + `compare`，并在 PR 描述贴出前后指标、设备与未覆盖范围。
