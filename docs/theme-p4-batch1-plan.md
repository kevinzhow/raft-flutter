# P4 第一批：11 个核心组件迁移到契约

准备稿。范围是"11 个核心组件 → 只读契约"，验收是"三套主题对 P2 基准，分数只升不降"。

## 1. 现状核过一遍的结果

11 个组件都在 `packages/raft_ui/lib/src/raft/`：

| 组件 | 文件 | 颜色已走契约？ | 写死的几何/字级处数 |
| --- | --- | --- | --- |
| Button | `button.dart` | 是（`t.ui`） | 7 |
| Badge | `badge.dart` | 是 | 1 |
| Status | `status.dart` | 是 | 0 |
| Avatar | `avatar.dart` | 是 | 5 |
| IconTile | `icon_tile.dart` | 是 | 1 |
| Input | `recipes/field.g.dart` 的 `RaftFieldRecipe` | 是 | 已部分走契约（见 §1.1） |
| Switch | `switch.dart` | 是 | 0 |
| Checkbox | `checkbox.dart` | 是 | 1 |
| Tabs | `tabs.dart` | 是 | 3 |
| SegmentedControl | `segmented_control.dart` | 是 | 5 |
| ListRow | `list_row.dart` | 是 | 6 |

**好消息**：P1 已经把颜色接通了——`RaftTokens.ui` 从当前主题包的映射里取值，
`RaftUiColors.fromMap` 就是那条路。所以 P4 第一批**不用再动颜色**，
难点全部在几何与字级。

### 1.1 已经读契约的只有三处

`RaftTokens` 上真正从 `geometry` 取值的只有三个 getter：

```dart
double get radius      => _mode?.geometry['radius.control'] ?? 8;
double get fieldRadius => _mode?.geometry['radius.field'] ?? 6;
double get border      => _mode?.geometry['stroke.container'] ?? 1;
```

也就是说 `radius.control`、`radius.field`、`stroke.container` 三个令牌已经生效
（Input 的圆角就走 `fieldRadius`），**其余约 34 个令牌还没有任何组件读**。
这决定了 P4 的实际形态：不是"把写死的值挪进令牌"，而是
"**先让令牌真的被读到**，再逐个替换字面量"。

**真正的工作**：29 处写死的尺寸/圆角/字号。典型是 `button.dart` 的
`static const _md/_lg/_xl/_onFrame/...` 一组 `RaftButtonMetrics`
（height 32/44/52/36、paddingX 12/16/20/10、icon 16/18/22），
以及 `button.dart:521` 的 `radius: inline ? 0 : 8`。

`static const` 是关键障碍：它们是编译期常量，无法按主题取值。
必须变成"从 `RaftTokens` 现算的实例值"，否则三套主题里有两套永远是 Raft 的尺寸。

## 2. 迁移做法（每个组件一样）

1. 把 `static const` 的度量改成由 `RaftTokens` 派生（读 `geometry`）。
2. widget 里所有字面量换成令牌：`height: 32` → `t.geometry['size.control.md']`。
3. 结构差异（描边画法、选中样式、按下效果等）改读 `options`，**不写 `if (family == brutal)`**。
4. 颜色保持现状（已经正确）。

## 3. 需要先确认的两件事

### 3.1 `radius: inline ? 0 : 8` 这类"局部例外"

Button 的内联形态把圆角写死 0，与主题无关。契约里没有"inline"这个令牌。
两种处理：
- 加一个 `radius.inlineControl` 令牌（三套主题同值 0）——表达更完整，但多一个令牌；
- 保留字面量 0，并在代码注释说明这是形态而非主题。

我倾向后者：内联按钮的直角是**形态定义**，不是主题选择，加令牌会让用户以为能改。
但这条要你确认，因为它决定了"哪些 0 算主题、哪些算形态"的判据。

### 3.2 字级

组件现在用 `RaftTypeScale.footnote/subhead/body`（0.7.1 的静态字级）。
契约 §3.4 定义了槽位表（hero/display/title/headline/…），Elegant/Brutal 的值不同。
这批要不要**同时**把字级换成契约槽位？还是先只做几何，字级留到下一批？

我建议**一起做**：`RaftButtonMetrics` 里的 `text: RaftTypeScale.footnote` 和 height 是同一张表，
分开改要动同一个结构两次。但一起做会让这一批的 diff 变大。

## 4. 验收方式

- 用 P2 基准（`/mnt/data/theme-baseline/p2-a57b9dab`）逐张比。
  实际覆盖情况（核过图名，不是估的）：

  | 有专门基准用例 | 只在组合用例里出现 |
  | --- | --- |
  | Button（含 `.elegant`）、Badge、Checkbox（含 `.elegant`）、SegmentedControl、Avatar（`avatar-list-row`）、Status（`status-dot`）、ListRow（`surface-list-item`、`menu-item`）、Input（`form-field`、`textarea`、`slug-input`、`select`） | IconTile、Tabs、Switch |

  **缺口**：IconTile、Tabs、Switch 没有专门用例。它们的差异会通过组合页面
  （`components.settings.appearance.page`、`components.members.*`）间接体现，
  但不能精确定位到组件。迁移这三个时要么加用例，要么接受"只能从组合页面看出回归"。
  这点需要你定，因为加用例要动官方清单。
- **分数只升不降**：先跑一次记录当前分数作为基线，改完再跑，逐用例比对。
- 注意对比规则：桌面用例用 `TargetPlatform.linux`，手机用例用 `android`。
- 结构选项的实现要一次写对，否则用户自定义主题会出现"转角夹紧"（契约 §7.4 提到）。

## 5. 时间与分批

11 个组件一次改完 diff 太大、也难定位回归。建议按"共享度量"分组，每组一个 PR：

1. **Button + SegmentedControl + Tabs**（都吃 `size.control.*` 与 `radius.control`）
2. **Badge + Status + IconTile + Avatar**（贴纸类，吃 `radius.sticker`、`size.*Glyph`）
3. **Input + Switch + Checkbox**（表单类，吃 `size.field`、`radius.field`、描边）
4. **ListRow**（行高与分隔线，吃 `size.navRow`/`menuRow`、`stroke.hairline`）

每组都跑一次基准对比，分数只升不降才进下一组。
