# 主题契约（P0 定稿草案）

Raft 外观的最终对照基准是 **Web v1.21.23 实际渲染**（source tag
`v1.21.23-source.1`，提交 `db5e399f017d584e49597e3a28757645d6807893`），
不是独立组件的官方样例。该版本 `packages/web/package.json:46` 与
`pnpm-lock.yaml` 固定 `raft-ui` 为 `npm:@botiverse/raft-ui@0.7.0`。
仓库中保留的 0.7.1 token 数据与 0.7.0 的 `tokens.json` 字节一致
（SHA-256 `47e5ed2d0c4867db61f054940189db56010787b9353cbc1babfc048f6efd53fd`）；
Badge、Card、Button（含 ghost）实现亦相同，因此不能通过更换 token 数据版本
修复应用布局。官方样例只验证组件输入；页面的排列、变体和文案以该 Web 版本
实际调用及渲染为准。Elegant／Brutal 的外观基准仍为 `a57b9dab`。

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
3. **结构差异收敛成 22 个枚举选项**，每个选项的实现只写一次，主题只选值。清单见 §4。
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
| ③ 结构选项 | “这一处用哪种画法” | 枚举 | 22 个（§4） |

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
| `layer-panel-header` | Flutter 新增（Cindy be3134a7） | 共享面板页头：Raft 同 `layer-canvas`；旧两套沿用 a57b9dab 的原页头绘制，保留手机底色和桌面透明层。 |
| `foreground-message` | Flutter 新增（Cindy 4e2f12b0） | 正文和发送者共用；Raft 同 foreground；Elegant 明暗同 foreground-muted；Brutal 浅色同现有 ink（原黑色），深色沿Elegant。 |
| `layer-section-header-mobile` | Flutter 新增（Cindy b1ba932f） | 窄布局的分节页头：Raft 同 `layer-frame`；Elegant 同 `layer-panel`；Brutal 浅色同 a57b9dab 的 `color-soft-signal`，深色沿用 Elegant。桌面不读此角色。 |
| `foreground-select` / `foreground-select-placeholder` | Flutter 新增（Cindy 50cb5231） | Raft：foreground / foreground-hint；Elegant 明暗：均 foreground-muted；Brutal 浅色：均 foreground-strong，深色沿 Elegant。 |
| `foreground-select-disabled` | Flutter 新增（Cindy 50cb5231） | Raft：foreground-disabled；Elegant 明暗：foreground-muted；Brutal 浅色：foreground-strong，深色沿 Elegant。 |
| `layer-select` / `layer-select-disabled` | Flutter 新增（Cindy 50cb5231） | Raft：layer-card / fill-muted；Elegant 浅色：均 layer-panel，深色：均 fill-muted；Brutal 浅色：均 layer-panel，深色沿 Elegant。 |
| `line-select` / `line-select-disabled` | Flutter 新增（Cindy 50cb5231） | Raft：line-strong / line-hairline；Elegant 明暗：均 line-muted（原环/阴影）；Brutal 浅色：均 foreground-strong，深色沿 Elegant。 |


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
| `radius.settingsCard` | 10 | 0 | 0 |
| `type.settingsCardTitle.size/line` | 17 / 22 | 18 / 22.5 | 18 / 22.5 |
| `type.settingsCardMeta.size/line` | 13 / 18 | 14 / 20 | 14 / 20 |
| `size.avatar.profileHero` | 99 | 64 | 64 |
| `size.avatar.profileTile` | 51 | 64 | 64 |
| `size.avatar.panelHeader` | 35 | 36 | 36 |
| `size.panelHeader` | 56 | 56 | 62 |
| `size.rail` / `railShort`（矮屏 ≤ 600） | 56 / 56 | 56 / 56 | 64 / 50 |
| `size.railGlyph` | 16 | 16 | 18 |
| `size.navRow` / `navRowCompact` | 34 / — | 34 / 30 | 40 / 32 |
| `size.navRowWide`（桌面宽 ≥ 768，非矮屏） | 34 | 34 | 32 |
| `size.menuRow` / `menuRowCompact` | 32 / — | 31.5 / 27.5 | 36 / 28 |
| `size.menuActionRow` / `menuActionRowCompact`（视口高 ≤ 600） | 36 / 32 | 28 / 28 | 28 / 28 |
| `size.menuPopupMin` | 240 | 192 | 192 |
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
Raft 包把它填成 none，旧的两套各自保留自己的写法。基础三档分开，因为旧版只对大写一部分；组件专用映射可在实测后单独批准：

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
| Raft | Web v1.21.23 实际渲染；以该版本应用的调用参数、文案和布局为准，组件为 `@botiverse/raft-ui` 0.7.0。0.7.1 官方样例仅作组件诊断，不能替代页面验收。 |
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

### 3.8 触控最小布局尺寸

`size.touchLayoutMin` 经 Cindy 于 2026-10-23 批准：Raft 为 **0**，
Elegant / Brutal 为 **48**，Brutal 深色仍使用 Elegant 深色。
它只在触控密度下生效，显式 `minimumTargetSize` 优先。

**0 表示不扩大布局，只扩大命中区和语义区**，沿用 `RaftTouchTarget`；
48 表示布局至少 48×48，视觉控件在其中居中。
这不是所有控件的全局布局规则：`a57b9dab` 实测开关、小图标按钮采用48布局，
复选框仍是14/16、单选标记仍是14/16。开关及24px（`RaftMetrics.buttonXs`）小图标按钮读取此共用数值；
较大图标按钮保持原有布局规则。小图标按钮的48px命中区与语义区独立于布局，
窄工具栏外的触点由现有 `RaftTapSlopHost` 路由。
其他控件只在其原实现确有最小布局规则时复用，不将它套到每个命中区上。
官方0.7.1默认图标按钮是32px，伪元素扩大命中区而不占布局；
产品显式24px尺寸保持不变，不将它当成官方默认尺寸的像素对照。

24px图标外观读取 `iconButton.surface`（Cindy4bee37ed批准）：`generic` 沿用
通用表面，`raised` 的
描边还受 `control.edge` 控制；圆角和硬阴影等数据分别取 `stroke.control`、`radius.controlSmall`、`xs/sm/md`；
普通、悬停、按下的阴影对应 `sm/md/xs`。位移沿用 a57b9dab
`_RaftControlState.build`：悬停上移1px、按下右下各移1px；减弱动画时不移动。
此1px经 Cindy4430babb 确认为该结构内部常量，不新增数值令牌。
这些是 a57b9dab 的原有行为，
不影响其他尺寸；`press.effect` 独立控制位移，不选择颜色、边框或其他表面。
深色 `ink-4` 沿用 a57b9dab 的浮点RGBA（alpha0.039203，
RGB0.954685/0.954685/0.969524）；展示表中的0.04和整数RGB不作为绘制精度。

## 4. 结构选项

下表是契约的第 ③ 层。`实现点` 指每一份实现要改写的位置（`a57b9dab` 行号，便于从 git 恢复）。

| # | 选项 | 取值 | Raft | Elegant | Brutal | 实现点 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `control.edge` | `inkBorder` / `ring` / `none` | inkBorder | ring | inkBorder | `design_primitives.dart:722-806` |
| 2 | `sticker.ring` | `none` / `dieCut` | dieCut（仅深色） | none | none | `raft/button.dart`、`mounted_avatar_recipe.dart` |
| 3 | `emphasis.fill` | `solid` / `soft` | solid | soft | solid | `design_primitives.dart:216,531-536` |
| 4a | `iconButton.surface` | `generic` / `raised` | generic | generic | raised（深色 generic） | `small_icon_recipe.dart`；仅24px图标，表面与按压结构独立 |
| 4 | `press.effect` | `overlay` / `scale` / `offsetShadow` | overlay | scale | offsetShadow | `design_primitives.dart:1002-1135` |
| 5 | `control.sheen` | `none` / `gradient` | none | gradient | none | `design_primitives.dart:615-657` |
| 6 | `avatar.shape` | `square` / `circle` | square | circle | square | `components.dart:478`、`mounted_avatar_recipe.dart:94` |
| 7 | `indicator.border` | `none` / `ink` | none | none | ink | `indicators.dart:228-273` |
| 8 | `switch.shape` | `pill` / `square` | pill | pill | square | `switch.dart:22-80` |
| 9 | `checkbox.mark` | `fillCheck` / `strokeCheck` / `thickStroke` | fillCheck | strokeCheck | thickStroke | `raft/checkbox.dart`、`indicators.dart:419-470` |
| 10 | `field.style` | `border` / `inset` | border | inset | border | `theme.dart:255-315`、`RaftFieldRecipe` |
| 11 | `tabs.selected` | `sticker` / `tint` / `underline` | sticker | tint | sticker | `design_primitives.dart:578-592` |
| 12 | `segmented.selected` | `sticker` / `tint` | sticker | tint | sticker | `design_primitives.dart:780-806` |
| 13 | `mobileNav.style` | `floatingCapsule` / `docked` | docked | floatingCapsule | docked | `mobile_navigation.dart`, `mobile_navigation_docked.dart` |
| 14 | `mobileNav.labels` | `iconsOnly` / `withLabels` | withLabels | iconsOnly | withLabels | 同上 |
| 15 | `header.layout` | `overlay` / `inFlow` | overlay | overlay | inFlow | `design_primitives.dart:138-186` |
| 16 | `panel.edge` | `seam` / `border` | seam | seam | border | `adaptive_workspace.dart:658-670` |
| 17 | `nav.selection` | `sticker` / `softFill` / `outline` | sticker | softFill | sticker | `components.dart:524,735` |
| 18 | `tooltip.arrow` | `yes` / `no` | yes | yes | no | `tooltip.dart:28,550` |
| 19 | `code.innerBorder` | `dashed` / `solid` | dashed | dashed | solid | `copyable_code.dart:78-122` |
| 20 | `spinner.style` | `pixel` / `ring` | pixel | ring | ring | `design_primitives.dart:1580-1690` |

新增表面选项（Cindy 2026-10-23 批准；只选择已有颜色角色，不增加颜色词汇）：

| 选项 | 取值 | Raft | Elegant | Brutal | 来源与适用范围 |
| --- | --- | --- | --- | --- | --- |
| `sidebar.mobileSurface` | `canvas` / `sidebar` | canvas | sidebar（明暗相同选择） | 浅色 canvas；深色 sidebar | Web v1.21.23 `packages/web/src/components/layout/Sidebar.tsx:3806`；a57b9dab `packages/raft_ui/lib/src/design_primitives.dart:141-145`。手机侧栏；桌面读取已有 `layer-sidebar`。 |
| `resource.surface` | `canvas` / `sidebar` | canvas | sidebar（手机／桌面相同） | 浅色 canvas；深色 sidebar | Web v1.21.23 `packages/web/src/components/thread/ThreadsInbox.tsx:1038,1079`；a57b9dab `apps/raft_flutter/lib/features/resource_view.dart:2385,2393`。Activity／Saved 的页表面，不改变 Search／Tasks。 |
| `resource.rows` | `flat` / `cards` | flat | cards | cards | Web v1.21.23 `ThreadsInbox.tsx:103-108`、`SavedPanel.tsx:269` 的实际排列；a57b9dab 的资源卡片排列。 |
| `resource.badge` | `sticker` / `pill` | sticker | pill | pill | Web v1.21.23 的 `Badge` 实际调用；a57b9dab `resource_rows.dart` 的胶囊 recipe。 |
| `resource.markRead` | `ghost` / `outline` | ghost | outline | outline | Web v1.21.23 `ThreadsInbox.tsx:1059-1069` 的 Button sm ghost；a57b9dab 的 outline 操作。 |
| `panelAction.surface` | `ghost` / `outline` | ghost | outline | outline | 面板返回与操作按钮；独立于24px小图标的 `iconButton.surface`（Cindy be3134a7）。 |
| `listGroup.frame` | `plain` / `framed` | plain | framed | framed | 共用列表分组容器；Web v1.21.23 taskListSection、search 分组实际无框，a57b9dab 保留旧分组。 |
| `task.status` | `square` / `symbol` | square | symbol | symbol | Web v1.21.23 TaskStatusPixel，9px状态色方块；a57b9dab 状态符号。 |
| `searchResult.selection` | `flat` / `card` | flat | card | card | Web v1.21.23 SearchEntityResult／SearchMessageResult，整行 brand-soft；a57b9dab 选中卡片。 |

原版实测值（390／1280宽，字体与其他内容不决定取色）：Elegant浅色侧栏与资源页均为 `#f8f8f7`，深色均为 `#0d0d0b`，不按宽度区分。Brutal浅色手机侧栏为 `#ffffff`、桌面为 `#fffaef`；资源页在两种宽度均为 `#ffffff`。Brutal深色按 a57b9dab `theme.dart:100-102` 沿用Elegant深色。桌面的 `layer-sidebar` 家族包投影只复原该专用角色，旧 `layer-canvas-muted` 值不改。

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
| 组件 | 15 个 raft-ui specimen（工具已在，`tool/parity-ui`）：Raft 对官方 React；Elegant/Brutal 对 `a57b9dab` 旧版渲染 | 官方通过线（96%；以工具的 basic-pass / pass / same 判定为准） |
| App 框架 | 手机、平板、桌面的框架截图；每套主题与明暗模式分别对照其冻结基准 | 同上；必须保留未覆盖和未通过项 |
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

资源列表的两种结构各自采用常量（Cindy 2026-10-23 批准），不增加间距令牌：
flat 的外侧左右0、顶部4、底部16，行内左右16／上下12，行间0，元数据前8；
cards 的外侧16、行内12、行间8、元数据前4。前者来自上述 Web 版本的 DOM
计算样式与源码，后者来自 a57b9dab。两套旧外观在 cards 结构下数值相同；
以后同一种结构内出现外观差异时再提取令牌。Raft 行的字级复用已有
subhead／callout／caption；徽标与按钮复用 RaftBadge／RaftButton。
“Mark all read”来自应用的 `thread.markAllRead.label` 翻译键，不属于主题数据。

头像的三个上下文尺寸经当前 Web DOM 实测（Cindy 826b64bb 批准名称）：
`HumanDetailPanel` 资料头图99、`AccountSettingsSection` 设置头像51、
`AppPanelHeader` 内的 AvatarSlot35；a57b9dab 对应64／64／36。
`profileHero` 与 `profileTile` 分开，形状和贴纸继续读已有选项，
不会用尺寸判断主题。页头的无框按钮复用现有 ghost Button；
现有24px小图标的 generic／raised 不足以表达旧32px有框 PanelAction。

设置卡圆角及标题／副标题数值经 Cindy 318b1d17 批准；来源为当前 Web
`SettingsProfileCard.tsx` 的 Card、text-headline、text-mono-code，
旧两套取 a57b9dab 的 `RaftSettingsCard.decoration` 和 `RaftSettingsProfileRecipe`。

共享 Composer 数值（Cindy 27a5a99c）：`space.composerHostInline` Raft20、旧两套12；
`space.composerHostTop` 8／12；`type.composerInput.line` 24／20；
`type.composerInputDesktop.size` 16／14。手机字号均16，底部安全区的16加系统值保持不变。
出处为当前 Web MessageInput 的 ComposerRoot px-5／pt-2、ComposerInput text-body
（实际 DOM16/24），a57b9dab `composer_recipe.dart` 的原值。
主聊天、线程、转发共享这些数值，捕获须一同检查。

Select 数值（Cindy 511917e6）：`size.selectTrigger` 的 Raft 值由生成器引用
`size.control.lg`（geometry 格式只存数字，生成时展开同一 h-11 档位）；旧两套32。
`type.selectValue.size` Raft15／旧14，`type.selectValue.weight` 600／500；
行高20为常量；占位字重按下述原版配对更正。当前 Web select.trigger 的 h-11、text-subhead
和 font-semibold，以及旧版实际触发框／继承文字探测，是数值来源。
调用方的显式高度继续优先。

菜单操作行数值由 Cindy 4e51e70c 批准：当前 Web MenuItem 的常规／矮屏行高与
消息 ContextMenu 最小宽度。它们与选择菜单的 menuRow 分开；矮屏同 navRowCompact
使用视口高度 ≤ 600，行为、权限和调用方显式尺寸保持原样。

Select 后续数值（Cindy 5c5b2a85）：`opacity.selectDisabled` Raft1／旧0.4（a57 原控件实测更正）；
`space.selectTriggerStart` 14／旧12；`size.selectChevron` 16／旧14；
`stroke.selectChevron` 2／旧1.5。末端12三套相同，作常量。
七个 Select 颜色角色均有至少一套与 field 对应角色不同；旧禁用态保留原颜色再乘0.4，
Raft禁用态读独立的淡底、淡边和禁用文字，整体不降低透明度。

Select 原版配对更正（Cindy 91d3ac48）：`type.selectValue.weight` 的 Brutal 浅色为700；
`type.selectPlaceholder.weight` Raft／Elegant500、Brutal浅色700，深色沿Elegant500。
原a57实际recipe证明先前统一500错误，不能据已经丢失主题分支的当前组件反推原版。
Elegant暗色xs阴影保留a57源alpha0.045，避免导出表显示精度0.04改变边缘像素。

消息字号按当前 Web `src/store/appearanceStore.ts` 的 MESSAGE_*_SIZE_CLASSES/VALUES
（Cindy 5eef1cad、4e2f12b0 批准），原三档偏好值 sm/md/lg 与存储逻辑不变。
展示层使用如下数值；调用方显式物理字号及行高优先，文档字级独立：

| 令牌 | Raft | Elegant | Brutal 浅色 |
| --- | --- | --- | --- |
| `type.messageBody.sm.size/line` | 14/20 | 12/16 | 12/16 |
| `type.messageBody.md.size/line` | 16/24 | 14/20 | 14/20 |
| `type.messageBody.lg.size/line` | 18/28 | 16/24 | 16/24 |
| `type.messageSender.sm.size/line` | 13/20 | 12/12 | 12/20 |
| `type.messageSender.md.size/line` | 15/20 | 14/14 | 14/20 |
| `type.messageSender.lg.size/line` | 17/20 | 16/16 | 16/20 |
| `type.messageSender.weight` | 700 | 500 | 700 |
| `type.messageBody.tracking`（em） | 0 | -0.01 | 0 |
| `type.messageMeta.lg.size` | 13 | 14 | 14 |
| `type.messagePreview.sm.size` | 12 | 11 | 11 |
| `type.messagePreview.md.size` | 13 | 12.5 | 12.5 |
| `type.messagePreviewTime.md.size` | 12 | 11.5 | 11.5 |

Meta sm11/md12、preview lg14、previewTime sm11/lg13 三套相同，保持常量。
Brutal 深色整套沿 Elegant。消息发送者控件的物理最小行高跟随上述 line，
大字号允许自然增高；不能只放大文字却保留14px裁切盒。

### 消息引用标签结构（Cindy 972c9666）

`messageReference.chipLayout = fixed | intrinsic`：Raft 为 fixed，Elegant／Brutal 为 intrinsic。fixed 沿用实际 Web 0.7.0 的 22px 最小高度、20px 行高、0.875em 字号、2px 图文间距和 6px 水平内边距（有图标时左侧 3px）；系统大字下随内容增高。自我提及与消息引用文字复用 `sticker.ring`／`radius.sticker`，绘制 1.5px 内外圈，不增加布局尺寸。

### 登录页头与快捷反应分隔线（Cindy dbb08097）

`layer-auth-header`：Raft 引用 layer-frame，Elegant 保持 panel，Brutal 浅色保持原 soft-signal，深色沿 Elegant；登录页所有宽度共用此角色。`messageMenu.reactionDivider = shown | hidden`：Raft shown、旧两套 hidden，仅在有快捷反应且下面有菜单项时显示原有分隔线。

### 输入框外壳、操作行和通知条（Cindy 16e23df0）

外壳复用 `control.edge`，不新增 composer.frame。数值来自当前 Web 0.7.0 的真实 DOM 与 a57 原版四组组件探测；通知条原内边距按左／上／右／下为 Elegant 10／10／8／10、Brutal 8／8／8／8。原版 recipe 的既有填充色和文字色通过角色引用保存；需要原样保留的数值仅进入已批准的专用调色板项。

| 数值 | Raft | Elegant | Brutal 浅色 |
| --- | ---: | ---: | ---: |
| `space.composerShellInline` | 12 | 0 | 8 |
| `space.composerShellTop` | 12 | 0 | 8 |
| `space.composerShellBottom` | 8 | 0 | 8 |
| `space.composerEditorInline` | 2 | 12 | 0 |
| `space.composerEditorTop` | 0 | 12 | 0 |
| `space.composerToolbarInline` | 0 | 10 | 0 |
| `space.composerToolbarTop` | 0 | 4 | 0 |
| `space.composerToolbarBottom` | 0 | 10 | 0 |
| `space.composerToolbarShiftY` | 0 | 4 | 0 |
| `space.composerFirstActionOffset` | -5 | 0 | 0 |
| `space.composerActionGap` | 8 | 6 | 8 |
| `space.composerMetaGap` | 8 | 12 | 12 |
| `size.composerEditorMinimumDesktop` | 24 | 40 | 40 |
| `size.composerAction` | 32 | 28 | 26 |
| `size.composerSubmit` | 32 | 28 | 28 |
| `size.composerGlyph` | 18 | 14 | 14 |
| `type.composerNotice.size` | 13 | 12 | 12 |
| `type.composerNotice.line` | 18 | 16 | 16 |
| `type.composerNotice.weight` | 400 | 700 | 700 |
| `radius.composerNotice` | 10 | 4 | 0 |
| `stroke.composerNotice` | 1 | 0 | 2 |
| `space.composerNoticeTop` | 8 | 10 | 8 |
| `space.composerNoticeEnd` | 12 | 8 | 8 |
| `space.composerNoticeBottom` | 8 | 10 | 8 |
| `space.composerNoticeStart` | 12 | 10 | 8 |

`size.composerAction` 和 `size.composerSubmit` 在 Raft 生成器中引用已有 size.control.sm。深色 Brutal 沿用 Elegant。颜色角色 line-composer、layer-composer-notice、foreground-composer-notice、line-composer-notice 复用相应源码既有颜色。

Cindy fc426a64 批准任务勾选数值：

| 数值 | Raft | Elegant | Brutal 浅色 |
| --- | ---: | ---: | ---: |
| `size.composerTaskToggle` | 32 | 16 | 16 |
| `size.composerTaskCheckbox` | 20 | 14 | 14 |
| `space.composerTaskGap` | 8 | 6 | 6 |
| `type.composerTaskLabel.size` | 14 | 12 | 12 |
| `type.composerTaskLabel.line` | 20 | 16 | 16 |
| `type.composerTaskLabel.weight` | 600 | 700 | 700 |

调色板（Cindy c3468770、ab2343bd、fd3328fd）：`palette.elegantNotice.light` 为 #ffeadc；深色项保留 a57 `recipe_utilities.g.dart` 的 `_v609` 实际绘制值：`Color.from(alpha: 0.180368, red: 0.534161, green: 0.321382, blue: 0.207110)`。源码同时保存的 CSS 字面值 `oklch(0.5 0.08 50 / 0.18)` 经当前包解析器转换后并不等于这组浮点值，因此不使用 CSS 字面值或四舍五入后的 ARGB。两项只用于保留旧 Elegant 的像素，没有对应的 Web 值；只出现在 Elegant 源模式（Brutal 深色完整继承），Raft 包不加。`layer-composer-notice` 引用这些项；Brutal 浅色引用现有 palette-orange-100。

任务勾选颜色（Cindy ab2343bd）：`foreground-composer-task` 为 Raft foreground／Elegant foreground-strong／Brutal ink 的 60%；`layer-composer-task-checked` 为 foreground／foreground-strong／ink；`line-composer-task` 为 line-strong／line-strong／ink。包格式不支持在引用上加透明度，Brutal 的标签值保存在专用调色板项 `composerTaskLabel`，组件不再乘透明度。旧两套共同的勾号尺寸 10、描边 4 保持常量。共享指示器仍由原来的单个交互控件承载，不增添焦点或勾选权威。

### 消息行几何、头部与字体引用

数值由 Cindy 53e94688 批准，a732e624 补充 `size.messageRowAvatarLarge`。
Raft 取当前 Web v1.21.23 的 raft-ui 0.7.0 MessageItem 与挂载覆盖；Elegant／Brutal
取 a57b9dab 原实现，不以当前共用的 0.5.52 数值代替原版。Brutal 深色完整沿 Elegant。
紧凑宽度仍为 <768，thread 的原有内边距覆盖仍在 <1024 生效。

| Name | Raft | Elegant | Brutal |
|---|---:|---:|---:|
| size.messageRowMin | 0 | 48 | 48 |
| stroke.messageRow | 0 | 1 | 2 |
| space.messageRowInline | 8 | 28 | 6 |
| space.messageRowInlineCompact | 8 | 16 | 6 |
| space.messageRowInlineThread | 8 | 12 | 6 |
| space.messageRowTop | 8 | 14 | 4 |
| space.messageRowTopCompact | 8 | 8 | 4 |
| space.messageRowContinuationTop | 0 | 6 | 4 |
| space.messageRowBottom | 8 | 12 | 4 |
| space.messageRowBottomCompact | 8 | 6 | 4 |
| space.messageRowFollowedCompactBottom | 8 | 2 | 4 |
| space.messageRowFollowedCompactBottomCompact | 8 | 0 | 4 |
| space.messageRowMarginInline | 0 | 0 | 12 |
| space.messageRowMarginTop | 0 | 0 | 6 |
| space.messageRowMarginBottom | 0 | 0 | 4 |
| size.messageRowGutter | 35 | 36 | 36 |
| size.messageRowGutterCompact | 35 | 32 | 36 |
| size.messageRowAvatar | 35 | 36 | 36 |
| size.messageRowAvatarLarge | 34 | 36 | 36 |
| space.messageRowGapCompact | 12 | 8 | 12 |
| space.messageHeaderReserve | 0 | 96 | 96 |
| size.messageHeaderLine | 20 | 21 | 20 |
| space.messageHeaderGap | 6 | 6 | 8 |
| space.messageHeaderAfter | 1 | 6 | 0 |
| space.messageHeaderAfterCompact | 1 | 4 | 0 |
| space.messageBodyBottom | 0 | 6 | 0 |
| space.messageBodyBottomCompact | 0 | 4 | 0 |
| space.messageAttachmentsTop | 8 | 4 | 4 |
| type.messageMeta.sm.line | 16 | 11 | 16 |
| type.messageMeta.md.line | 16 | 12 | 16 |
| type.messageMeta.lg.line | 16 | 14 | 16 |
| type.messageMeta.tracking | 0 | -0.14 | 0 |

桌面间距12、连续行最小高度0、页脚上间距6、Brutal 连续行上外边距0三套相同，保留常量。
Raft lg 头像34来自 MessageItem.tsx 的 `[--mi-avatar:2.125rem]`，其余档35；原版头像均36。
Raft 外壳底内边距8不因下一条消息分组改变；原有 followedBy、followsSystem 数据语义保留，
已跟随其他消息且正文以代码块结束时的 1px 尾距也保留，不另造旧版几何。

头部结构选项：

- `messageHeader.timePosition = trailing | inline`（53e94688）：Raft trailing，旧两套 inline。
  trailing 将时间放在末端，inline 保留名字、模型、说明、时间的顺序；大字均可换行。
- `messageHeader.align = baseline | center`（626bac7e）：Raft／Brutal 浅色 center，Elegant baseline。

颜色 `foreground-message-meta`（53e94688）：Raft 引用 foreground-hint，Elegant 保留原 muted 的
0.7倍透明度，Brutal 浅色保留黑色0.4。后两者放进各自原模式专用调色板，不在组件叠乘透明度。

`RaftTypeStyleSpec` 没有字体家族字段，因此不新增 messageTime.font 枚举。
模式新增可选 `font` 映射，只接受以下已批准组件角色，值必须引用既有字体定义：

```jsonc
"font": {
  "font.messageTime": "{fonts.mono}",
  "font.messageSubtitle": "{fonts.sans}"
}
```

`font.messageTime`（53e94688）为 Raft／Brutal 浅色 mono、Elegant sans；
`font.messageSubtitle`（a52f5728）为 Raft／Elegant sans、Brutal 浅色 mono；深色 Brutal 沿 Elegant。
只允许 `{fonts.sans}`、`{fonts.heading}`、`{fonts.mono}`，未知角色、裸字符串和未知家族拒绝并报 JSON 路径。
引用随模式继承，也遵循原有系统字体偏好；不新增字体资产或第二套字体来源。

原版三套的 mono 字体均为 Geist Mono（a57 metrics.g.dart），Brutal 的既有字体定义据此更正。


按模式覆盖字体（Cindy 1d128e06）：`modes.light.fonts` / `modes.dark.fonts` 使用与顶层
`fonts` 相同的 sans、heading、mono 角色与 `{family, stack, asset}` 格式。每个家族的优先级
为模式内定义 > 当前包顶层 > 继承基准包；未写的家族继续继承。用户主动选择的系统字体仍优先
于所有主题定义。模式与顶层共用名称、stack 和 asset 字段校验；本次没有新增字体导入器，
JSON 解析不读取资产字节，文件大小与文件存在性仍须在未来导入阶段验证。
Brutal 深色明确覆盖为 Elegant 的三组字体，避免只继承颜色、几何却保留浅色字体。

头像上间距三套均为2：Raft 的挂载 MessageItem.tsx 内的 MessageSenderAvatar（2290、2338行）
两条路径都是 `mt-0.5`，与 a57 原版一致。因此撤掉 `space.messageRowAvatarTop`，使用共同常量。


### 加载动画的数值与结构（Cindy 63f52c81 / 3fd7a4e6）

数值类别新增 `duration.*`（正整数毫秒）和 `ratio.*`（有限的 0 到 1，包含端点）。
校验器拒绝零／负／小数时长及范围外比例，不将它们当作像素长度。

| 数值 | Raft | Elegant | Brutal 浅色 |
| --- | --- | --- | --- |
| `size.spinnerDefault` | 12 | 14 | 16 |
| `duration.spinnerTurn` | 1000 | 1600 | 1000 |
| `stroke.spinnerRing` | 0 | 0 | 2 |
| `ratio.spinnerRingRadius` | 10/24 | 10/24 | 0.5 |
| `space.spinnerRingInset` | 0 | 0 | 1 |
| `opacity.spinnerArc` | 0.8 | 0.8 | 1 |

`spinner.style` 沿用已有 pixel／ring；Raft 真正绘制像素网格，圆环字段在包内保留但不参与绘制。
`spinner.ringShape = sweep | quarter` 为 sweep／sweep／quarter；
`spinner.foreground = inherited | fixed` 为 inherited／inherited／fixed。
颜色角色 `foreground-spinner` 引用现有 foreground／foreground／ink；仅 fixed 使用。
Brutal 深色完整沿 Elegant。描边为 0 时保留原比例 2.5/24；半径按尺寸乘 ratio 后减 inset。

Raft 的来源为 Web v1.21.23 实际安装的 raft-ui 0.7.0：xs／sm／md／lg 像素边长
4／5／6／8，间隙 1.5／2／2／3。原版圆环取 a57b9dab。
共用夹具传来源尺寸档，不按主题改写。调用方显式物理尺寸优先；未传尺寸档时读取默认大小，
inverse 在每套外观均保持白色。减弱动画时像素首格点亮，圆环静止；隐藏与卸载受 State vsync 生命周期约束。


### Dialog 与确认说明（Cindy 046ef0f7 / 76ef3df8 / e02a1edc / fe0074f6）

来源为当前 Web v1.21.23 实际安装的 raft-ui 0.7.0 Dialog / ConfirmDialog / Banner，
与 a57b9dab 实际运行的同名组件。这里按部位投影既有 Dialog recipe，不增加“新旧渲染器”选项。
Brutal 深色整套沿 Elegant 深色；模式内 geometry 覆盖沿用包的统一合并路径。

| 数值 | Raft | Elegant | Brutal 浅色 |
| --- | --- | --- | --- |
| `space.dialogContentInline` / `space.dialogContentBlock` | 0 / 0 | 0 / 0 | 24 / 16 |
| `space.dialogPartGap` | 0 | 0 | 16 |
| `space.dialogHeaderInline` / `space.dialogHeaderTop` / `space.dialogHeaderBottom` | 20 / 20 / 0 | 24 / 12 / 12 | 0 / 0 / 0 |
| `space.dialogHeaderGap` | 8 | 12 | 12 |
| `space.dialogBodyInline` / `space.dialogBodyTop` / `space.dialogBodyBottom` | 20 / 6 / 20 | 24 / 20 / 20 | 0 / 8 / 8 |
| `space.dialogFooterInline` / `space.dialogFooterTop` / `space.dialogFooterBottom` | 20 / 0 / 20 | 24 / 12 / 12 | 0 / 0 / 0 |
| `space.dialogFooterGap` | 8 | 12 | 12 |
| `type.dialogTitle.size` / `type.dialogTitle.line` | 17 / 22 | 16 / 24 | 18 / 18 |
| `size.dialogClose` / `size.dialogCloseGlyph` | 32 / 18 | 28 / 16 | 32 / 20 |
| `space.dialogCloseOutset` | 6 | 0 | 0 |
| `blur.dialogBackdrop` | 0 | 2 | 0 |
| `stroke.dialog` / `stroke.dialogRing` | 0 / 1 | 0 / 0 | 2 / 0 |
| `size.confirmAction` | 44 | 28 | 28 |

Elegant 深色的 `space.dialogBodyTop` 为10。`blur.*` 为有限、非负的像素值，负值须拒绝。
关闭按钮的 outset 对应来源的负上下及右 margin，只缩小布局槽位；绘制与可点击范围必须保留。
实体边会占布局空间，外圈不占；Elegant 原圈已在 xl 阴影里，不能重复描边。
`line-dialog` 引用现有 line-seam／line-muted（未使用）／ink。
`foreground-dialog-close` 引用 foreground／foreground-placeholder／ink（outline 自带颜色）。

`dialog.close = ghost | outline` 为 ghost／ghost／outline，调用方显式 outlineClose 优先。
现有 case 映射新增 `dialogShellTitle`：Raft none，旧两套 uppercase，仅供 RaftDialogShell 使用；
普通 RaftDialogTitle 不因此改变。标题700是共同值。
`confirm.explanation = dangerBanner | plain` 为 dangerBanner／plain／plain，仅选择说明的组合方式；
显式 plainMessage 优先。`dialog.cancelSurface = ghost | outline` 为 ghost／outline／outline。
三套确认操作均走共享 RaftButton，显式 actionSize 优先于默认高度，不通过无关主题选项选择按钮实现。

#### Banner 的 md 档

| 数值 | Raft | Elegant | Brutal 浅色 |
| --- | --- | --- | --- |
| `space.bannerInline` | 14 | 12 | 12 |
| `space.bannerGap` | 10 | 8 | 12 |
| `type.bannerBody.size` / `type.bannerBody.line` / `type.bannerBody.tracking` | 14 / 20 / 0 | 13 / 16 / -0.065 | 14 / 20 / 0 |
| `size.bannerGlyph` | 20 | 16 | 18 |
| `radius.banner` | 10 | 4 | 0 |
| `stroke.bannerBorder` / `stroke.bannerRing` | 0 / 1 | 0 / 0 | 2 / 0 |

上下内边距12、根继承行高20为共同值；description 的实际行高读取 type.bannerBody.line。
sm／lg 密度仍沿各自来源，不从 md 反推。
`line-banner` 引用现有 line-hairline／line-strong（未使用）／line-strong。
`banner.iconAlignment = start | center` 为 start／center／center；带标题的原有顶对齐保留，
调用方显式 centerAction 覆盖默认对齐。`banner.iconColor = foreground | intent` 为
foreground／intent／foreground；背景与意图色仍引用已有状态角色，不增加调色板值。
确认解释是静态说明，调用方使用 live=false；普通 Banner 的默认可访问性不变。

#### 确认文案与 slug 提示

| 数值 | Raft | Elegant | Brutal 浅色 |
| --- | --- | --- | --- |
| `type.confirmBody.size` / `type.confirmBody.line` | 15 / 20 | 14 / 22.75 | 14 / 22.75 |
| `type.confirmName.weight` | 600 | 700 | 700 |
| `type.confirmPrompt.size` / `type.confirmPrompt.line` / `type.confirmPrompt.weight` | 13 / 18 / 600 | 14 / 20 / 400 | 14 / 20 / 400 |
| `type.confirmSlug.size` / `type.confirmSlug.weight` | 13 / 600 | 14 / 700 | 14 / 700 |
| `space.confirmSlugInline` | 4 | 0 | 0 |

slug 行高20为共同值。`confirm.slug = chip | text` 为 chip／text／text，chip 使用既有
radius.sticker。foreground-confirm-name／foreground-confirm-prompt／foreground-confirm-input
引用 foreground／foreground-muted／foreground-muted；foreground-confirm-slug 引用
foreground／foreground-strong／foreground-strong，layer-confirm-slug 引用 fill-muted（旧两套不使用）。
删除服务器的输入框自动聚焦是三套共有的产品行为，不是主题字段；精确 slug 校验与删除权限逻辑不变。


Banner 文案颜色与深色精度补充（Cindy fca42af8 / cc2cdd85）：
foreground-banner-body 为 foreground／foreground-muted／foreground。
layer-banner-destructive、layer-banner-warning、layer-banner-info、layer-banner-success
在 Raft 与 Brutal 浅色引用既有对应 soft 背景；Elegant 深色的 warning 复用
palette.elegantNotice.dark，其余保存在 Elegant 专用的 palette.elegantBanner.destructive.dark、
palette.elegantBanner.info.dark、palette.elegantBanner.success.dark。
这些项只保存原编译样式的浮点绘制精度，不修改通用 danger-soft 等角色，也不新增配色。

### 共享 Button：尺寸、状态和绘制角色

此处的 Raft 参照为 Web v1.21.23（`db5e399f`）安装的 `raft-ui` **0.7.0**，
入口是 `dist/dialog-CY6S-Xqf.mjs` 的 Button；前面的 0.7.1 说明属于早期参照记录。
Elegant／Brutal 仍以 `a57b9dab` 为准。数值由尺寸轴决定，调用方的 `physicalHeight`
只覆盖物理高度，不把 sm 字体切成 md。Brutal 深色完整继承 Elegant 深色。

经 Cindy a0741fbf、c1ec691c 批准的差异如下；三列顺序是 Raft／Elegant／Brutal 浅色。

| 名称 | Raft | Elegant | Brutal 浅色 |
| --- | ---: | ---: | ---: |
| `size.control.xs` | 32 | 24 | 24 |
| `type.button.xs.size` | 13 | 11 | 11 |
| `type.button.sm.size` | 13 | 12 | 12 |
| `type.button.md.size` | 13 | 14 | 14 |
| `type.button.lg.size` | 15 | 16 | 14 |
| `type.button.sm.line` | 18 | 16 | 16 |
| `type.button.md.line` | 18 | 20 | 20 |
| `type.button.lg.line` | 20 | 24 | 20 |
| `type.button.weight` | 700 | 500 | 700 |
| `space.buttonInline.xs` | 12 | 8 | 8 |
| `space.buttonInline.sm` | 12 | 10 | 10 |
| `space.buttonInline.lg` | 16 | 14 | 16 |
| `space.buttonGap.xs` | 8 | 4 | 4 |
| `space.buttonGap.sm` | 8 | 5 | 5 |
| `space.buttonGap.md` | 8 | 5.5 | 5.5 |
| `space.buttonGap.lg` | 8 | 6 | 6 |
| `size.buttonGlyph.xs` | 16 | 12 | 12 |
| `size.buttonGlyph.sm` | 16 | 14 | 14 |
| `size.buttonGlyph.lg` | 18 | 16 | 16 |
| `size.buttonGlyph.iconXs` | 18 | 12 | 12 |
| `size.buttonGlyph.iconSm` | 18 | 14 | 14 |
| `size.buttonGlyph.iconMd` | 18 | 16 | 16 |
| `size.buttonGlyph.iconLg` | 22 | 16 | 16 |
| `opacity.buttonDisabled` | 1 | 0.4 | 0.4 |

md 水平内边距 12、带前置／后置图标时相应侧减少 2、md 普通图标 16 是共同值。
`inline` 继承环境字号和行高；旧外观的 xs 继承环境行高，Raft xs 的 18 为固定值。
现有 sm／md／lg 控制高度继续生效；xl 保持当前 Web 的 52，不从旧 lg 推导新值。

| 结构选项 | 取值 | Raft | Elegant／Brutal |
| --- | --- | --- | --- |
| `button.disabledSurface` | `muted` / `opacity` | muted | opacity |
| `button.xsLine` | `fixed` / `inherited` | fixed | inherited |
| `button.hoverSurface` | `overlay` / `variant` | overlay | variant |
| `button.linkDecoration` | `underline` / `none` | underline | none |
| `button.linkPadding` | `none` / `size` | none | size |

后两项分别经 Cindy a7ff13b3、95bf2f18 批准。加载状态固定为全不透明并阻止激活；
禁用状态的组透明度与加载状态分开。调用方的 `opacityCompositing` 继续选择普通透明层
或 alpha 过滤，不能丢失已存在的合成边界。

经 Cindy 29efd8b3 批准的 40 个颜色角色及各包取值存于
`tool/theme-adapters/button_contract.json`，包括各 variant 的底色、悬停底色、前景色、
强调按钮边线和 ghost 悬停边线。`emphasis.fill` 仅选择 primary／accent 的 solid／soft 底色。
旧 `button-*` 别名保留；不能把它们全局重定向到新角色。无法引用既有角色的原版常量，
只存入 Elegant 专用的 `palette.elegantButton.*.{light,dark}` 或 Brutal 专用的
`palette.brutalButton.dangerSecondary.ink`，不扩展 Raft 调色板。

Cindy 72a99839 批准的 `layer-button-danger-high-contrast`、
`foreground-button-danger-high-contrast` 由系统高对比度偏好选择：Elegant 使用现有
`button-danger-high-contrast(-foreground)`；Raft／Brutal 浅色引用普通 danger 组件颜色。
Brutal 深色仍继承 Elegant。调用方显式前景色保持最高优先级。

阴影与运动、环边独立（Cindy 362a0c7b、a7ff13b3）：

| 阴影角色 | Raft | Elegant 浅色 | Elegant 深色 | Brutal 浅色 |
| --- | --- | --- | --- | --- |
| `shadow.control` | none | none | xs | sm |
| `shadow.buttonHover` | none | none | xs | md |
| `shadow.buttonPressed` | none | none | xs | xs |
| `shadow.buttonDangerOutline` | none | none | xs | none |
| `shadow.buttonSuccess` | none | none | none | sm |

ghost／link 无实体阴影，success 保持其静态阴影；边环由 `control.edge` 单独决定。
`press.effect` 只决定叠色以外的位移／缩放，不能选择整套渲染器或颜色。
`control.sheen` 只决定渐变和内高光，`sticker.ring` 只决定实际贴纸外环。
所有外观共用一个绘制投影，原版 recipe 仅作为环和高光的属性参照。

`values.json` 是便于阅读的数据导出，会舍掉浮点精度。五档原版阴影的完整层数据和源文件 SHA
保存在 `tool/theme-adapters/original_shadows.json`；适配器同时保留 Elegant primary-edge、
深色 line-muted 等既有颜色项的原始浮点通道。不要用显示用的四舍五入值替换绘制值。

### StableField 与字段控件

`StableField` 保留消息行，标签上的小动作按负外边距占据标签行，
不靠放大整行来容纳按钮。字段形态的 Select（`chrome=field`）与普通
Select 共用实现，但文字读取 `type.field.size/line/weight`，不读取普通
Select 的半粗字重；弹出菜单也保留同一形态。

| 名字 | Raft | Elegant | Brutal 浅色 |
| --- | ---: | ---: | ---: |
| `type.fieldLabel.size` | 13 | 14 | 14 |
| `type.fieldLabel.line` | 18 | 20 | 20 |
| `type.fieldLabel.weight` | 600 | 700 | 700 |
| `space.fieldGap` | 6 | 6 | 4 |
| `space.fieldLabelAccessoryOutset` | 7 | 0 | 0 |
| `size.fieldInput` | 44 | 38 | 44 |
| `size.fieldSelect` | 44 | 36 | 44 |

Brutal 深色完整沿用 Elegant 深色，包括 6px 间距。`size.fieldInput`
与 `size.fieldSelect` 是组合控件实测外高；原有 `size.field` 保持通用旧字段的含义。

`foreground-field-label`：Raft 引用 foreground-muted；Elegant 浅色与
Brutal 浅色引用 foreground-strong，Elegant 深色引用 foreground-hint。
`foreground-field-required`：Raft 引用 foreground-muted，原两套引用 danger-strong。
取消动作统一读取 `dialog.cancelSurface = ghost | outline`：Raft ghost，
原两套 outline；确认框和表单对话框使用同一选项。原名称 `confirm.cancelSurface` 已撤销。

依据：Web v1.21.23 的 `StableField.tsx` 与 raft-ui 字段 Select 的 `chrome=field`
覆盖；原两套标签包装与输入／下拉外高取自 a57b9dab 实际控件。手机表单的
sheet 展示策略由产品决定，不属于主题选项，仍遵守 `close-affordances.md`。

命名流程（2026-10-24 更新）：实现者按契约自行确定令牌、颜色角色及结构选项名，
在 PR 描述集中列出新增项；负责人在完整检查前统一审查。无需逐个等待名称批准。
取值差异用数据，排布差异才用枚举；不按主题名判断，不借无关选项推断，
旧外观的字面色存入对应包的专用调色板。

### Select 阴影独立数据

`shadow.select`、`shadow.selectHover`、`shadow.selectPressed`、
`shadow.selectFocus` 分别表示默认、悬停、按下和键盘焦点的额外阴影。
默认 Raft 前三者为空，焦点引用已有 focusRing；Elegant 及 Brutal 深色
默认／悬停／按下引用原 xs，浅色 Elegant 为空，焦点由原 ring 负责；
Brutal 浅色依次引用原 sm／md／xs／sm。
边缘 ring 与 sheen 各读自己的选项，阴影不从 `press.effect` 推断。
当 hover 和 active 同时成立时保留原 Select CSS 的 hover 层优先顺序。
原 recipe 只提供其固定布局、ring、sheen 和对应运动属性，不选择整个绘制实现。

`type.selectValue.tracking`（em 比例）：Raft／Elegant 及 Brutal 深色 −0.005，
Brutal 浅色 0；保留原来的字距，不能借运动选项选择字号配方。

`layer-select-hover`：Raft 仍用 layer-card，Elegant／Brutal 深色引用原 ink-2，
Brutal 浅色保持 layer-panel。该颜色角色与运动选项无关。

### MobileNav source restoration (2026-10-24)

`mobileNav.style` selects arrangement and `mobileNav.labels` selects label visibility.
`mobileNav.selection = iconSticker | cell` selects whether the selected surface
wraps only the icon or the entire item; it does not select geometry or typography.
Raft uses iconSticker, legacy packs use cell (floating Elegant keeps its pill).
The `space.mobileNav*`, `size.mobileNav*`, `stroke.mobileNav*`,
`radius.mobileNavSticker`, `type.mobileNavLabel*` entries come from the locked
Web MainLayout MobileTabBar and raft-ui 0.7.0 mobile-nav recipe, or frozen
`a57b9dab:mobile_navigation.dart` for legacy appearances. Color roles
`layer-mobile-nav`, `line-mobile-nav`, `line-mobile-nav-divider`, `foreground-mobile-nav`,
`foreground-mobile-nav-selected`, `foreground-mobile-nav-glyph-selected`,
`layer-mobile-nav-selected`, `line-mobile-nav-selected`,
`line-mobile-nav-selected-ring`, `layer-mobile-nav-pressed` reference existing
source colors. MainLayout overrides the generic minimum 8px safe padding with
`min(env(safe-area-inset-bottom),34px)`; native shell owns the physical system inset.
Measured Chromium used CSS border width rounds positive fractions down at normal zoom
(1.5px is 1px at DPR3 too); the specified value remains in pack data.

`mobileNav.boxLayout = css | natural` controls source box/glyph pixel snapping;
`mobileNav.textLayout = css | natural` controls source text line boxes. Raft
uses the existing Blink box and CSS text primitives; legacy packs keep natural
Flutter painting independently of selection surface, colors and typography.

`layer-mobile-nav-system` paints the native shell's stable bottom system inset
(Raft layer-card, legacy transparent). It adds no inset and does not follow the
keyboard. `line-mobile-nav-divider` preserves the legacy line-strong separators
separately from the pure-black outer borders.
