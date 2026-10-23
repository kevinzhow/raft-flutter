# 主题契约（P0 定稿草案）

状态：待评审（Kevin、Cindy）。本文件只定义契约，不含实现代码。
决定来源：Kevin，#raft-flutter:4093da5f（8798cb71 目标是与 Raft UI 无关的主题中间层、100%；
dd6c1674 开始，交给 DeepDesign）。
方案：`plan.md`（Cindy）。实施：DeepDesign。评审与全量检查：Cindy。

配套文件：

| 文件 | 内容 |
| --- | --- |
| `docs/theme-contract/values-appendix.md` | 全部 159 个颜色角色 + 5 级阴影 + 字体度量在三套主题下的取值（生成，不手抄） |
| `docs/theme-contract/values.json` | 同一份数据的机器可读版本，P1 适配器的输入 |
| `tool/theme-contract/dump_theme_values.py` | 生成上面两个文件的脚本，`--check` 可在 CI 里查过期 |
| `tool/tests/test_theme_values.py` | 把上面的 `--check` 接进检查流程（全量检查与 preflight 都会跑） |
| `docs/theme-contract/examples/user-brand.theme.json` | 一份最小用户主题包，演示格式 |

删主题前后五个区域的逐文件清单（G1–G5）不入库：按仓库规矩，盘点类材料放 PR 描述与 Raft。
下面 §3、§4 引用的每个数值与实现点都已写成 `a57b9dab` 的 file:line，出处足够复现；清单本身见 PR #294 的折叠段。

---

## 0. 结论先行

1. **契约的颜色词汇直接用现在的 role schema（159 个角色名）**，不另造一套。理由见 §2：
   组件今天已经按这些名字取值（约 900 处 `RaftTokens.of(context)`），换词汇等于把所有组件重写一遍，
   而收益只是名字好看一点。真正需要清掉的是**按主题名分支**，不是角色名。
2. **几何、字体、阴影要从编译期常量变成主题数据**，新增约 50 个数值令牌。这是本项目的实质工作量，
   也是 Elegant/Brutal 复刻的主要部分。
3. **结构差异收敛成 20 个枚举选项**，每个选项的实现只写一次，主题只选值。清单见 §4。
   旧代码里约 1870 处 `.brutal` 读点，其中约 1066 处是取值三元式（变成数值令牌），
   约 48 处是 `if` 分支（变成结构选项），其余是注释、测试与转发。
4. **主题包 = 一份 JSON**，DTCG 兼容 + 我们的扩展；只写要覆盖的项，没写的继承基准主题。
   Raft 包由官方 `tokens.json` 生成，Elegant/Brutal 包由 `a57b9dab` 生成，用户包走同一条加载路径。
5. **“100%”用像素对比证明**，不用估算。Raft 对官方 React 样例（工具已有，15 个 specimen）；
   Elegant/Brutal 对 `a57b9dab` 的旧版渲染（P2 建基准）。
6. 本文标记 **†** 的取值，是盘点里能定位到代码但还没有像素基准确认的数字。
   它们**在 P2 基准建立后逐项核对再落代码**，不允许带着 † 进 P4。

---

## 1. 契约的形状

```
主题包 JSON（Raft / Elegant / Brutal / 用户上传）
        │  解析 → 校验（名字、类型、对比度、字体）
        ▼
契约（packages/raft_theme）：① 颜色  ② 数值  ③ 结构选项
        │  ThemeExtension: RaftTheme.of(context)
        ▼
组件（只读契约；禁止按主题名判断）
```

三层各自回答一个问题：

| 层 | 回答 | 形态 | 规模 |
| --- | --- | --- | --- |
| ① 颜色 | “这个角色是什么颜色” | 角色 → Color | 159 个角色（附录全量） |
| ② 数值 | “圆角多大、线多粗、多高、字多大” | 令牌 → num | 约 50 个（§3） |
| ③ 结构选项 | “这一处用哪种画法” | 枚举 | 20 个（§4） |

一个主题 = 这三层的取值。内置主题与用户主题的区别只有 `builtIn` 标记，没有别的路径。

### 1.1 为什么必须有第 ③ 层

纯数值做不到 100%：Elegant 的按钮没有描边、用 1px 外圈阴影画边；Brutal 的按钮是 2px 黑边 + 硬阴影。
两者的差别不是“线宽 2 → 1”，而是**边上画的是什么**。这类差异只能靠枚举 + 每个值一份实现。

反过来，凡是能用数值表达的差异（圆角、线宽、颜色、阴影、字重），**一律不放进第 ③ 层**。
第 ③ 层越薄，用户能改的就越多，维护成本也越低。

---

## 2. 颜色：为什么沿用现在的角色名

`RaftSemanticColors`（122）/ `RaftProductColors`（14）/ `RaftComponentColors`（23）合计 159 个角色，
今天由 `raft_token_mapping.dart` 从 0.7.1 的 225 个 token 填充。组件按这些名字取值。

**沿用它的三个理由：**

1. **成本**：改名字要动约 900 处读取点和 `raft_token_mapping.dart` 的 159 行映射，
   换来的只是命名整洁。同样的钱花在第 ② 层（真正缺的东西）上回报高得多。
2. **粒度**：0.7.1 把 `foreground-strong` 并进 `foreground`、把 `line-muted` 并进 `line-hairline`。
   如果契约直接用 0.7.1 的名字，Elegant 需要的区分就丢了 —— 这是 plan.md §2 阻塞 3。
   保留旧角色名，Raft 包把两者填成同一个值，Elegant 包填成不同的值，两边都对。
3. **可校验**：`raft_token_mapping_test.dart` 已经保证“每个角色都有映射且指向存在的 token”。
   Raft 包的正确性可以靠这个测试继续兜底。

**要做的清理（不改变角色集合，只改名字与来源）：**

| 现在 | 契约里 | 说明 |
| --- | --- | --- |
| `color-brutal-yellow-400` 等 96 个 `color-brutal-*` | `palette.yellow.400` | 这些是调色板别名，不是角色。Raft 包保留全量调色板；用户主题只在角色引用时提供 |
| `primary*` / `accent*` | 保留，标注 deprecated alias | 0.7.1 已改名为 brand/attention，1.0 才删。契约两种都接受，写出时用新名 |
| `sticker-ink` / `sticker-paper` / `sticker-edge` / `sticker-pressed` | 保留 | “贴纸”是材质概念，不是主题名；Elegant 用不到就填 transparent 或与邻近角色同值 |
| `layer-frame` / `foreground-on-frame*` / `fill-frame-pressed` | 保留 | Raft 深色框的中性层，Elegant/Brutal 填成与 `layer-canvas` / `foreground` 同值 |

附录给出了 159 个角色在三套主题下的全部取值，以及每个角色对到哪个 0.7.1 token。

### 2.1 三套主题的颜色取值口径

- **Raft**：`tool/design-source/raft-ui-0.7.1/tokens.json` → 现行 `raft_token_mapping.dart`。
  半透明色 0.7.1 保留 authored alpha，未做 Chrome 拟合（见 `docs/design-tokens.md`）。
- **Elegant light / Elegant dark**：`a57b9dab` 的 `RaftSemanticColors/Product/Component.elegantLight|elegantDark`。
- **Brutal**：同文件的 `.brutal`。**Brutal 只有浅色** —— 旧版选 Brutal 时，深色仍旧渲染 Elegant 深色。
  要 100% 复刻旧版，Brutal 包的 `modes.dark` 就填 **Elegant dark** 的取值（不是它自己的浅色值）。
  这样外观设置里“浅色 Brutal + 深色 Elegant”的组合与旧版逐像素一致，包本身也仍是自洽的一份数据。

---

## 3. 数值层：新增令牌

这是契约里唯一“现在没有”的东西。今天圆角、线宽、多数尺寸是编译期常量
（`RaftTokens.radius = 8`、`fieldRadius = 6`、`border = 1`、`RaftRadius.control = 8`，
以及生成样式表里的字面量）。Elegant 和 Brutal 的差别有一半在这里。

### 3.1 圆角

| 令牌 | 用在 | Raft | Elegant | Brutal |
| --- | --- | --- | --- | --- |
| `radius.sticker` | 头像、勾选框、徽章、图标方块、骨架 | 4 | 头像=full，方块=3 | 0 |
| `radius.chip` | 标签、任务标记、胶囊以外的 chip | 6 | 4 | 0 |
| `radius.control` | 按钮、输入框、分段、标签页、导航行 | 8 | 6 | 0 |
| `radius.controlSmall` | 高度 < 32 的控件 | 8 | 4 † | 0 |
| `radius.container` | 卡片、菜单、弹层、编辑器外壳、提示条 | 10 | 8 | 0 |
| `radius.dialog` | 对话框 | 16 | 8 | 0 |
| `radius.sheet` | 底部抽屉顶角 | 16 | 16 | 0 |
| `radius.tooltip` | 提示框 | 6 | 6（Material tooltip 4） | 0 |
| `radius.item` | 菜单项、建议行等小行 | 6 | 2 | 0 |
| `radius.pill` | 开关、单选、圆角胶囊 | 999 | 999 | 0 |
| `radius.avatar` | 头像 | 4 | 999（正圆） | 0 |
| `radius.rail` | rail 与左上角 | 0（官方要求直角） | 8 † | 0 |

`radius.sticker` 与 `radius.avatar` 分开，是因为 Elegant 的头像是正圆、方块仍是 3。
Elegant 的 `radius.pill` 在富卡片徽章、传输条上也是 999。

### 3.2 线宽

| 令牌 | 用在 | Raft | Elegant | Brutal |
| --- | --- | --- | --- | --- |
| `stroke.hairline` | 接缝、分隔 | 1 | 0.5 | 1 |
| `stroke.control` | 控件边、贴纸边 | 1.5 | 0（用 1px spread 阴影画边） | 2 |
| `stroke.container` | 卡片、面板、弹层外框 | 1 | 1 | 2 |
| `stroke.rule` | 区域之间的横线 | 1 | 1 | 2 |

Elegant 的 `stroke.control = 0` 配合 `control.edge = ring`（§5 #1）与 `shadow.control`，
才能做到“边不变形、内容不位移”。

### 3.3 尺寸与密度（节选，全表在 P1 随代码落地）

| 令牌 | Raft | Elegant | Brutal |
| --- | --- | --- | --- |
| `size.control.sm` | 32 | 28 | 28 |
| `size.control.md` | 32 | 32 | 32 |
| `size.control.lg` | 44 | 40 | 36 |
| `size.control.xl` | 52 | — | — |
| `size.control.onFrame` | 36 | 32 † | 32 † |
| `size.field` | 44 | 36 † | 40 † |
| `size.panelHeader` | 56 | 56 | 62 |
| `size.rail` / `railShort`（矮屏 ≤ 600） | 56 / 56 | 56 / 56 | 64 / 50 |
| `size.railGlyph` | 16 | 16 | 18 |
| `size.navRow` / `navRowCompact` | 34 / — | 34 / 30 | 40 / 32 |
| `size.navRowWide`（桌面宽 ≥ 768，非矮屏） | 34 | 34 | 32 |
| `size.menuRow` / `menuRowCompact` | 32 / — | 31.5 / 27.5 | 36 / 28 |
| `size.drawer` | 380 | 380 | 380 |
| `space.controlX` | 12 | 6 | 8 |
| `space.itemX` | 10 | 10 | 12 |
| `space.inset.panel` | 16 | 26 † | 8 |

`size.control.*` 的取值来源（三套各按自己的权威来源，不用当前分支的 recipe 反推）：

- **Raft**：`@botiverse/raft-ui` 0.7.1 的 `button.tsx` —— `xs/sm/md` 共用 `textMd`
  （`h-8` = 32），`lg` = `h-11` = 44，`xl` = `h-13` = 52。另用
  `tool/parity-ui/run dom-dump` 在官方 React 样例上实测确认（md 32 / lg 44 / xl 52）。
- **Brutal / Elegant**：`a57b9dab` 的 `RaftButtonRecipe.resolve(theme:, size:)` 解析结果。
  brutal `sm 28 / md 32 / lg 40`；elegant `sm 28 / md 32 / lg 36`。
  两者都没有 `xl` 这个尺寸（`xl` 是 0.7.1 引入的）。

判据：三套取值相同 → 形态，组件里保留字面量；任一不同 → 主题值，必须进令牌。
按此，`size.control.md` 是形态（32/32/32），`sm` 与 `lg` 是主题值。

`size.*` 的 Raft 列全部来自 raft-ui 0.7.1（`button.md`、`spacing.md`）与已移植的 11 个组件；
Elegant/Brutal 列来自 `inventory/G1…G5` 的 file:line。

### 3.4 字体与字级

字体族与六个度量已进附录（生成）。除此之外契约还需要一条**字级表**：
Raft 有 12 级（`hero…label`、`mono-meta`、`mono-code`，见 `RaftTypeScale`），
Elegant/Brutal 需要同样一套槽位。槽位固定，值按主题；这样组件写 `type(label)`，不写 `fontSize: 11`。

| 槽位 | Raft | Elegant | Brutal |
| --- | --- | --- | --- |
| `hero` | 40/44 w700 −0.03em | — | — |
| `display` | 34/40 w700 −0.02em | — | — |
| `title` | 22/28 w700 −0.01em | 17/21.25 w500 | 18/22.5 w700 |
| `headline` | 17/22 w700 | 17/21.25 w500 | 18/22.5 w700 |
| `body` | 16/24 w400 | 14/20 w400 −0.01em | 14/20 w400 |
| `subhead` | 15/20 w400 | 14/20 w500 | 14/20 w700 |
| `callout` | 14/20 w400 | 13/19.5 w400 −0.01em | 14/20 w400 |
| `footnote` | 13/18 w400 | 13/19.5 w400 | 13/19.5 w400 |
| `caption` | 12/16 w500 | 11/16.5 w500 | 10/15 w700 |
| `label` | 11/13 w600 | 11/12 w600 | 10/10 w700，大写 |
| `mono-meta` | 12/16 | 11/16.5 | 10/15 |
| `mono-code` | 13/20 | 12/18 † | 12/16 † |

† = 盘点未逐值确认。P2 建基准时从旧版渲染反查，写进包再进 P4。

### 3.5 大小写

`textTransform` 只改显示，不改文案字符串，所以它不推翻设计决策 0002（文案不再用全大写）：
Raft 包把它填成 none，旧的两套各自保留自己的写法。三档分开，因为旧版只对大写一部分：

| 令牌 | 用在 | Raft | Elegant | Brutal |
| --- | --- | --- | --- | --- |
| `case.heading` | 对话框标题、分组标题 | none | none | uppercase |
| `case.label` | eyebrow、分组小标题、出发标签 | none | uppercase † | uppercase |
| `case.badge` | 徽章、Done 这类状态小标签 | none | none | uppercase |

† = 旧代码在两种主题下都大写 eyebrow（G3 第 3 条）；Elegant 的对话框标题与状态标签是正常大小写。
P2 基准确认后逐项落值。

### 3.6 取值的权威来源与实测方法

**每套外观只对自己的权威来源负责**，不要拿移植结果反推：

| 外观 | 权威来源 |
| --- | --- |
| Raft | `@botiverse/raft-ui` 0.7.1 的源码（`dist` 里的 `button.tsx` 等），并用 `tool/parity-ui/run dom-dump` 在官方 React 样例上实测复核 |
| Elegant / Brutal | `a57b9dab` 的生成 recipe 解析结果（`RaftButtonRecipe.resolve(theme:, size:)`）或该 commit 的基准渲染 |

**旧版只有两套外观**（`enum RaftFamily { brutal, elegant }`，默认浅色是 Brutal）。
不存在"旧版 Raft"，所以 Raft 永远不拿 `a57b9dab` 作基准。

**为什么不能用移植结果反推**：Raft 的 `lg` 官方是 44，而我们的 Flutter recipe 写死 40。
以移植为准会把偏差固化成"设计"。

**实测方法**（新取一个值时照做，不猜）：
1. Raft：读 raft-ui `dist` 源码里的 class（`h-8`/`h-11`/`h-13` = 32/44/52），再用
   `tool/parity-ui/run dom-dump` 在官方样例上确认。DOM 节点的高度取 `rect.h`（不是 `height`）。
2. Elegant/Brutal：在 `a57b9dab` 的 worktree 里写一次性测试调 recipe 解析，
   读 `root['height']`、`root['padding-left']`、`root.classes`（看 `rounded-*`）。用完即删。
3. 三套都有值后按 §3.3 的判据定性：相同即形态，不同即令牌。
4. **禁止推导**：没有实测来源的值不能用相邻值算出来（例如"xl = lg + 8"）。
   没有调用点可查时，先取 Raft 的值并在代码里注明"无数据"，不要发明中间值。

**同一组件在不同位置取值不同时**（旧版常按用途各写一版），以使用位置为准：
列出该组件在本分支的调用点，在 `a57b9dab` 找到同一位置原来用的那个 widget 取其值；
位置之间不一致就用变体或参数表达。组件名相同不等于外观相同。

### 3.6.1 开关尺寸和时长

令牌名经 Cindy 批准（2026-10-23）。Raft 数据来自官方 0.7.1 `switchRecipe`，
Elegant / Brutal 来自 `a57b9dab` 的 `switch.dart:65-81` 和 `primitive_tokens.dart:12-13`。
同一调用点保留 `sm` / `md` 变体；Raft 两种尺寸相同。

| 令牌 | Raft | Elegant | Brutal 浅色 |
| --- | --- | --- | --- |
| `size.switch.width.sm` / `.md` | 50 / 50 | 28 / 36 | 28 / 36 |
| `size.switch.height.sm` / `.md` | 30 / 30 | 16 / 20 | 16 / 20 |
| `size.switch.thumb.sm` / `.md` | 22 / 22 | 12 / 16 | 10 / 14 |
| `space.switchInset` | 4 | 2 | 3 |
| `motion.switchSlideMs` | 220 | 180 | 180 |
| `motion.switchColorMs` | 150 | 180 | 180 |

`space.switchInset` 是**轨道外缘到拇指外缘的距离，包含边框**。
Raft 的 4 来自 1.5 CSS 边框加 2.5 padding；不能再加一次边框。
绘制仍保留原来的设备像素边框取整：padding 保持 2.5，拇指再按原捕获策略对齐像素，
不把取整后的边框差额重复加到 padding。
位移由 `width − thumb − 2 × inset` 计算，不另设令牌：Raft 为 20，
Elegant / Brutal 为 12 / 16。Brutal 深色整套使用 Elegant 深色数据。

### 3.7 阴影

阴影是 Elegant 与 Brutal 最大的观感差别（G1 第 1 条），但**不需要结构选项**，因为它纯是数据。
契约要求五级阶梯（`xs…xl`）+ 七个角色：

| 角色 | 谁在读 | Raft | Elegant | Brutal |
| --- | --- | --- | --- | --- |
| `shadow.control` | 按钮、输入、开关、行 | 无 | 1px spread `line-muted` 环 | 2px 硬阴影 |
| `shadow.card` | 卡片、消息、编辑器 | `elevation-float` | `sm`（深色 `xs`） | `sm`→`md` hover |
| `shadow.popup` | 菜单、弹层、抽屉、提示 | `float` | `xl`（深色带 inset） | `lg` |
| `shadow.sticker` | 品牌贴纸、头像（仅 Raft 深色） | `elevation-sticker` | 无 | `lg` |
| `shadow.focusRing` | 键盘焦点 | 2px 白 + 2px ink | spread 1/2/3 环，深色 60% | 抬升 `md`，无环 |
| `shadow.navCapsule` | 手机悬浮胶囊导航 | 无 | 3 层 | 无 |
| `shadow.railSelected` | rail 选中项 | 无 | 无 | 2×2 硬阴影 |

五级阶梯 `xs…xl` 的全量取值见附录，是逐层 CSS 原文（含 inset 层），可原样序列化。

---

## 4. 结构选项

下表是契约的第 ③ 层。`实现点` 指每一份实现要改写的位置（`a57b9dab` 行号，便于从 git 恢复）。

| # | 选项 | 取值 | Raft | Elegant | Brutal | 实现点 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `control.edge` | `inkBorder` / `ring` / `none` | inkBorder | ring | inkBorder | `design_primitives.dart:722-806` |
| 2 | `sticker.ring` | `none` / `dieCut` | dieCut（仅深色） | none | none | `raft/button.dart`、`mounted_avatar_recipe.dart` |
| 3 | `emphasis.fill` | `solid` / `soft` | solid | soft | solid | `design_primitives.dart:216,531-536` |
| 4 | `press.effect` | `overlay` / `scale` / `offsetShadow` | overlay | scale | offsetShadow | `design_primitives.dart:1002-1135` |
| 5 | `control.sheen` | `none` / `gradient` | none | gradient | none | `design_primitives.dart:615-657` |
| 6 | `avatar.shape` | `square` / `circle` | square | circle | square | `components.dart:478`、`mounted_avatar_recipe.dart:94` |
| 7 | `indicator.border` | `none` / `ink` | none | none | ink | `indicators.dart:228-273` |
| 8 | `switch.shape` | `pill` / `square` | pill | pill | square | `switch.dart:22-80` |
| 9 | `checkbox.mark` | `fillCheck` / `strokeCheck` / `thickStroke` | fillCheck | strokeCheck | thickStroke | `raft/checkbox.dart`、`indicators.dart:419-470` |
| 10 | `field.style` | `border` / `inset` | border | inset | border | `theme.dart:255-315`、`RaftFieldRecipe` |
| 11 | `tabs.selected` | `sticker` / `tint` / `underline` | sticker | tint | sticker | `design_primitives.dart:578-592` |
| 12 | `segmented.selected` | `sticker` / `tint` | sticker | tint | sticker | `design_primitives.dart:780-806` |
| 13 | `mobileNav.style` | `floatingCapsule` / `docked` | docked | floatingCapsule | docked | `mobile_navigation.dart:287-445` |
| 14 | `mobileNav.labels` | `iconsOnly` / `withLabels` | iconsOnly | iconsOnly | withLabels | 同上 |
| 15 | `header.layout` | `overlay` / `inFlow` | overlay | overlay | inFlow | `design_primitives.dart:138-186` |
| 16 | `panel.edge` | `seam` / `border` | seam | seam | border | `adaptive_workspace.dart:658-670` |
| 17 | `nav.selection` | `sticker` / `softFill` / `outline` | sticker | softFill | sticker | `components.dart:524,735` |
| 18 | `tooltip.arrow` | `yes` / `no` | yes | yes | no | `tooltip.dart:28,550` |
| 19 | `code.innerBorder` | `dashed` / `solid` | dashed | dashed | solid | `copyable_code.dart:78-122` |
| 20 | `spinner.style` | `pixel` / `ring` | pixel | ring | ring | `design_primitives.dart:1580-1690` |

次要、按需再加（P4 时若确有差异才提升为选项）：`timeline.marker`（实心/空心环）、
`suggestion.framedIcon`、`dialog.close`、`listItem.recipeOverride`、`rail.attention`（渐变/实色）。

**明确不进选项的：**

- 断点、布局规则、交互方式。设计规则，不属于主题（plan.md §1 已定）。
- 大小写不是结构选项，而是三个数值令牌（§3.5）：它只改显示、不改字符串，也就不与文案决策冲突。

---

## 5. 主题包格式

### 5.1 结构

```jsonc
{
  "format": "raft-theme/1",
  "id": "elegant",                    // 唯一、不可变；用户包用 "user:<slug>"
  "name": { "en": "Elegant", "zh": "雅致" },
  "version": "1.0.0",
  "extends": "raft",                  // 省略 = 直接继承内置 Raft；内置 Raft 不写
  "builtIn": true,                    // 用户包恒为 false，加载时强制
  "author": "Raft",
  "fonts": {
    "sans":   { "family": "Geist",   "stack": ["Geist", "system-ui", "sans-serif"],
                "asset": null },      // 用户包可带 .ttf，见 5.4
    "heading":{ "family": "Inter",   "stack": ["Inter", "system-ui", "sans-serif"] },
    "mono":   { "family": "Geist Mono", "stack": ["Geist Mono", "ui-monospace", "monospace"] }
  },
  "modes": {
    "light": {
      "colors":   { "foreground": "#191815", "layer-card": "#ffffff", "foreground-muted": "#3d3d3a" },
      "geometry": { "radius.control": 6, "stroke.control": 0, "size.panelHeader": 56 },
      "type":     { "body": [14, 20, 400, -0.01], "title": [17, 21.25, 500, 0] },
      "case":     { "heading": "none", "label": "uppercase", "badge": "none" },
      "shadows":  { "shadow.control": "0 0 0 1px #3d3d3a", "shadow.popup": "/* … */" },
      "options":  { "control.edge": "ring", "mobileNav.style": "floatingCapsule" }
    },
    "dark": { /* 同结构。Brutal 没有深色：dark 必须给出，取 **Elegant dark** 的整套取值
              （颜色、几何、结构选项都比照 Elegant dark），见 §2.1 */ }
  },
  "assets": { "logo": null, "mark": null }   // 可选，见 5.4
}
```

规则：

1. **只写覆盖项。** 没写的键从 `extends` 链继承。内置主题的链是 `raft → (无)`；
   Elegant/Brutal 也 `extends: "raft"`，只写与 Raft 不同的项 —— 这样官方升到 0.8 时，
   两套旧主题不会因为新 token 而缺值。
2. **`modes.dark` 必填**（可以为空对象，表示与 light 相同）。缺 dark 的模式在加载时报错，
   避免“深色下掉回默认”这种难查的问题。
3. **颜色**：`#rrggbb`、`#rrggbbaa`、`oklch()`、`rgb()` 都接受；也接受 DTCG 的
   `{ "$value": { "colorSpace": "oklch", "components": [...] } }`，这样官方 `tokens.json`
   和 Figma Tokens Studio 的导出可以**直接导入**（走适配器换算，不要求用户改写）。
4. **字级**：`[size, lineHeight, weight, trackingEm]` 四元组，短写；
   也可以写对象 `{ "size": 14, "line": 20, "weight": 400, "tracking": -0.01 }`。
5. **阴影**：CSS 原文，多层用逗号分隔，`inset` 支持。解析器只接受这一个语法，
   不引入第二种表达（避免 CSS 与结构化两种真相）。
6. **选项**：只接受 §4 表里的名字与枚举值，拼错即报错，不静默忽略。
7. **大小写**：`case.*` 只接受 `none` / `uppercase` / `lowercase`；它只影响显示，不动字符串。

### 5.2 校验（加载时，内置与用户同一条路径）

| 检查 | 失败处理 |
| --- | --- |
| `format` / `id` / `version` / `modes.dark` 存在 | 拒绝 |
| 名字在契约里存在（着色角色、几何令牌、字级槽、大小写槽、结构选项、阴影角色），类型正确，枚举值在允许集合内 | 拒绝，报出第一个错误与 JSON 路径 |
| 角色值写 `{palette.x.y}` 时，调色板里有这一项 | 拒绝 |
| 角色引用的 `palette.*` 能解析（或继承链上有） | 拒绝 |
| 对比度：`foreground` 对 `layer-canvas` / `layer-card` / `layer-popover`，`foreground-muted` 对 `layer-canvas`，`sticker-ink` 对 `sticker-paper`、`primary`、`attention`、`warning`、`danger` | 正文低于 4.5:1、大字低于 3:1 时**警告并允许“仍然应用”**（用户可能是刻意的），但安装界面上显著提示 |
| 字体资产 ≤ 4 个、单文件 ≤ 8 MB、扩展名白名单 | 拒绝 |
| 无未知顶层键 | 警告（向前兼容：未来版本的包在旧客户端上能加载） |

主题是纯数据：**不执行任何代码、不引用外部路径、不写文件系统**。

### 5.3 三套内置包怎么来（构建期适配器，`tool/theme-adapters/`）

Raft 包已经落地，生成器一次产出三份、由同一个 `--check` 守着
（`tool/tests/test_theme_values.py`）：

| 产物 | 用途 |
| --- | --- |
| `packages/raft_theme/lib/src/raft_pack.g.dart` | 内置包本体，**编译期常量**。首帧必须已经有主题，异步读 asset 会闪色（`docs/theme-flash.md`） |
| `packages/raft_theme/assets/themes/raft.theme.json` | 同样的字节，给工具和想改一份的人 |
| `packages/raft_theme/lib/src/contract_names.g.dart` | 契约自己的名字表：215 个颜色角色 + 30 个几何令牌。拼错即报错，不静默忽略 |

`packages/raft_theme/test/raft_tokens_parity_test.dart` 证明它与现行
`RaftTokenSet` 逐值相等。内置主题走常量、**同步可用**；JSON 解析只给用户上传的包用。

| 包 | 来源 | 做法 |
| --- | --- | --- |
| `raft.theme.json` | `tool/design-source/raft-ui-0.7.1/tokens.json` | 现有 `gen-tokens` 管线加一个导出步骤：把 159 个角色按 `raft_token_mapping.dart` 解析成具体值，调色板原样带上；几何/字级/阴影从 `styles.css @theme` 与 `tokens.json` 取 |
| `elegant.theme.json` | `a57b9dab` 的 `*.g.dart` 生成的 `elegantLight/elegantDark` 静态值 | 值直接取；结构选项按 §4 表填；几何取 `inventory/G1…G5` 的 file:line |
| `brutal.theme.json` | 同上的 `.brutal` | 同上；**dark = Elegant dark**（旧版深色整套走 Elegant，见 §2.1） |

三份包都进版本库，和代码一起评审。漂移检查由 `tool/tests/test_theme_values.py` 跑
`dump_theme_values.py --check`：全量检查的 host tests 会带上它，`tool/preflight` 也单列一步，
所以改了两处任一源头却没重生成，CI 会直接失败。

### 5.4 用户上传（收尾阶段）

- 入口：设置 › 外观 › 导入主题 → 选文件 → 预览（浅色/深色并排，几个代表性界面）→ 应用。
- 支持 `.json`；带字体或 Logo 时用 `.zip`，解包后限制文件数与大小。
- 主题存本机（用户级），不写服务器。服务器统一下发是平台侧能力，本期不做（plan.md §1）。
- 导出：把当前主题导出成 `.json`，方便分享与二次修改（导出即“完整的、可再次导入的包”）。

---

## 6. 官方还没定的地方怎么处理

`decisions/open-questions.md` 里仍然开放的一条，加上四条“产品已定”的：

| 地方 | 官方状态 | 契约怎么处理 |
| --- | --- | --- |
| 手机顶层页顶栏：大标题 vs 56px 导航行 | **未定**，默认大标题，Web 用导航行 | 不做成主题选项（这是布局，不是主题）。按默认（大标题）实现，等官方定稿；颜色/字号仍走契约 |
| 手机推入页顶栏 | 已定：纸白 + 接缝，位置方块仍是黄贴纸 | 数值 + 颜色，无选项 |
| 桌面 rail | 已定：纯图标 56px + 接缝，左上角保持直角 | `size.rail` + `radius.rail`（0 = 直角，见 §3.1） |
| 标签页 | 已定：黄色贴纸；下划线保留为变体 | `tabs.selected` 的 `underline` 值正好对应官方保留的变体 |
| 频道内 Chat/Tasks/Files | 已定：一行贴纸标签，可排序 | 无选项；排序是产品能力 |

设计决策 0009（45% 接缝、控件不投影）、0011（黄色选中）、0012（深色框中性 + rail 选中仍黄）、
0014（未读粉底 ink 字）、0023（深色下贴纸不变，加 die-cut 边）都是 **Raft 包的取值**，
不是契约条款 —— 换句话说：Elegant 包可以合法地违反它们，这正是“主题”的意义。

---

## 7. 迁移与强制

### 7.1 P1 打底（Raft 外观零变化）

1. 新建 `packages/raft_theme`：契约类型、解析、校验、`RaftTheme` ThemeExtension。不 import `raft_ui`。
2. 适配器生成 `raft.theme.json`，加载后与现行 `RaftTokenSet.light/dark` 逐值相等 —— 用一个
   测试断言 159 个角色 + 5 级阴影 + 6 个度量的值完全一致。这是“零变化”的机器证明。
3. `RaftTokens` 改为从契约构造（它保留为兼容视图，900 处读取点不动）。
4. 修 plan.md 的两个阻塞：
   - `RaftTokenSet` 增加公开构造（或由契约直接构造）；
   - `RaftUiColors` 不再绑 `RaftLight/RaftDark` 常量，改成从当前 `RaftTokens` 的颜色表取值。
     它是**单点**：`extension RaftTokensUi on RaftTokens { RaftUiColors get ui => … }`
     （`raft/ui_tokens.dart:91`，19 处调用），改这一处，11 个移植组件同时生效。
5. 顺带修一个隐患：`raftColorMap` 以 `set.id`（枚举）为缓存键（`theme.dart:36-45`），
   自定义主题会撞键拿到 Raft 的值。改成以 token set 身份为键。

### 7.2 分批迁移（P4…）

按组件批次改成只读契约：11 个核心组件 → 外壳 → 聊天 → 设置 → 任务。
每批以“三套主题对基准，分数只升不降”为验收。

### 7.3 收尾：lint 强制

| 规则 | 例外 |
| --- | --- |
| 禁止按主题名判断（`theme.id ==`、`isElegant`、`if (raft)`） | 无 |
| 禁止 `Color(0x…)` / `Colors.black` / `Colors.white` | 白名单：媒体 chrome、品牌插画、Chromium 混合工具 |
| 禁止直接读 `RaftLight` / `RaftDark` / 生成的 token 类 | 适配器与测试 |
| 禁止在组件里写字面量圆角/线宽/字号 | 白名单：几何计算（`/2`、`-1`） |
| 每批新增的数值令牌必须在 `raft.theme.json` 里有值 | 无 |

---

## 8. 验收

| 层 | 方法 | 门槛 |
| --- | --- | --- |
| 令牌 | 三套包的值与来源逐值相等（单元测试）；附录漂移由 `tool/tests/test_theme_values.py` 拦，全量检查与 `tool/preflight` 都会跑 `dump_theme_values.py --check` | 100% 相等 |
| 组件 | 15 个 raft-ui specimen（工具已在，`tool/parity-ui`）：Raft 对官方 React；Elegant/Brutal 对 `a57b9dab` 旧版渲染 | 官方 pass 线（>99%） |
| 页面 | 现有的 parity case（官方 Web 用例 + 扩展用例）在 5 个尺寸（320/390/768/1024/1280）+ 矮窗下逐页对照 | 同上；布局断言（谁并排、谁盖住）单独跑 |
| 用户主题 | 极端测试主题（全红、超大圆角、无描边）跑全量截图，抓漏网写死值 | 无未主题化区域 |

**Elegant/Brutal 的基准必须在 P2 真跑出来**，不是估算：在临时 worktree 检出 `a57b9dab`，
用当时的主题矩阵渲染固定清单，产物放 `build/`（不入库，与其他 parity 参考一致）。

清单必须**同时覆盖手机和桌面**，因为手机独有的差异正好在主题里：
`mobileNav.style`（Elegant 的悬浮胶囊 vs 贴底栏）、`mobileNav.labels`、手机推入页的悬浮标题栏、
底部 tab 的贴纸。`desktop_screens_test` 只有桌面矩阵，所以 P2 还要用当时的手机入口
（390 宽，外加 320 边界）渲染：手机首页、频道、任务、成员、设置、个人资料，浅色与深色各一份。
桌面清单沿用 `desktop_screens_test` 的页面集合。

---

## 9. 已定的四件事（Kevin，2026-10-19）

| # | 问题 | 决定 |
| --- | --- | --- |
| Q1 | 颜色词汇：沿用 159 个旧角色名，还是重命名成一套干净的？ | **沿用** 159 个角色名，只清理 `color-brutal-*` 这类调色板别名（§2） |
| Q2 | Raft 包是否带全量调色板？ | **带全量调色板**。用户包只在角色引用时提供 |
| Q3 | 大小写（全大写）怎么表达？ | **三个数值令牌**（§3.5）：`case.heading` / `case.label` / `case.badge`；Raft 全填 none，Brutal 按旧版填大写。只改显示，不改字符串 |
| Q4 | Brutal 深色怎么办？ | **Brutal 包的 `modes.dark` = Elegant dark**，与旧版一致（选 Brutal 时深色永远渲染 Elegant） |

---

## 10. 已知风险与待定

1. **† 取值的数量**：几何与字级里有约 25 个数字要等 P2 基准确认。这是本方案里唯一“还不能宣布 100%”的部分，
   处理办法是逐项核对，不猜。
2. **生成样式表**：69 个在用的 recipe `.g.dart` 里圆角、内边距、描边是编译期常量
   （`RaftRecipeTheme.elegant` 被固定写死）。这些表要么重新生成为数据，要么在 P4 逐项替换。
   我倾向**重新生成**：让 `gen-tokens` 同时输出 recipe 的数值部分，避免 69 个文件手改。
   这条会增加 P4 的成本，需要在 P1 就开始准备。
3. **rail 左上角直角**：0.7.1 要求 rail 顶角保持直角，但圆角是“容器”级的取值。
   已补进 §3.1：`radius.rail`（Raft 0 / Elegant 8 † / Brutal 0）。
4. **浮层层级里的“按钮贴边”规则**（shape.md: 内圆角 + 间距 = 外圆角）：契约给了内外两个圆角，
   组件必须用同一个公式推导，否则用户主题自定圆角后会出现“转角夹紧”。这条要写进 P4 的实现约束。
5. **对比度检查的假阳性**：半透明角色（`ink-*`、`/ a` 的阴影色）无法直接算对比度。
   校验时先按所在表面合成再算，合成表随契约版本走。
