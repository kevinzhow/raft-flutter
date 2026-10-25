# 主题包与配方引擎

`raft_theme` 只依赖 Flutter，不依赖 `raft_ui` 或 Raft 应用。它提供主题包解析、继承与校验，以及生成配方的 CSS 层叠、槽位、状态、缓存和基础绘制类型。

```dart
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_theme/recipes.dart';

final values = userPack.resolve(dark: false, base: builtInRaftTheme);
final tokens = RaftThemeRecipeTokens(values);
final input = RaftInputRecipe.resolve(
  theme: RaftRecipeTheme.elegant,
  tokens: tokens,
).root;
final radius = input.borderRadius;
```

`theme` 参数是冻结源配方的兼容轴。组件属性通过生成的绑定读取包数据；它不应成为应用按主题名称选择绘制器的开关。当前已绑定 Input 的四个圆角到 `radius.control`；其他尚未迁移的声明保留源值，不表示所有组件都已经完成主题化。绑定规则在 `tool/recipes/pack-bindings.json`，按 recipe、slot、属性、变体和状态限定，不能全局替换相同数字。

`RaftThemeRecipeTokens(values, bindComponents: false)` 读取冻结配方声明，基础颜色和字体仍由传入的包解析，供已经按包绘制的组件借用源配方的 ring／sheen。应用适配器可覆写基础颜色别名和平台字体名称。`RaftSlotStyle.copyWith` 保留 `context` 中的配方、槽位、参数与状态，便于诊断实际绘制来源。

在仓库中，从此包目录运行 `../../tool/flutter test test -j 2`。独立使用时，可以只复制此目录，在它的父目录创建仅包含此包的 Dart workspace，再从包目录运行同版本 SDK 的 `flutter pub get` 和 `flutter test test -j 2`。测试资产和完整 JS 槽位对照数据随包携带，不需要 Raft 应用或主仓库的 build 目录。

生成配方保留原 raft-ui 0.5.52 的来源，用于兼容已冻结的配方；Raft 当前外观的权威来源仍是 Web v1.21.23，Elegant／Brutal 是 a57b9dab。移动配方表不等于修复其中尚未绑定的常量。生成器、来源与再生成步骤见仓库的 `tool/recipes/run` 和 `docs/component-recipes.md`。
