// Exact text input from the initial frozen P01 native performance harness.
// This fixture changes no benchmark thresholds or performance inputs.
String p01LongMessage(int i) => '''## 第 $i 条固定性能消息

这是用于复现真实频道滚动卡顿的中文长消息。我们必须保留同一份输入和原始测量结果，不能用短消息或空列表替代用户正在阅读的内容。一次完整的回归应覆盖长段落、内联格式、链接、列表、代码以及附件，检查真实构建和布局成本。

这里继续说明产品的实现约束。界面显示的资料来自当前工作区，频道和线程分别保留自己的滚动位置，长内容在需要的时候折叠。**同样的文字**应该在不同主题下保持可读，*文字选择*和鼠标菜单应当持续可用，不能为了测量而关闭产品原本的功能。查看 [来源资料](https://example.invalid/reference/$i) 了解固定输入。

- 第一项：这是一段包含中文、English、日本語和多个标点的长列表内容，用于测量换行、内联解析、选择区域和约束变化时的实际布局。
- 第二项：固定消息的内容不随版本更改，页面结构和绘制成本才能进行比较；任何测量失败都必须保留，不能仅汇总成功的最后一次运行。
- 第三项：当前频道含有几百条不同类型的消息，我们连续滚动十秒，再在消息上下文内重复滚动，最后调整真实桌面窗口大小。

> 引用的一段讨论：外观对齐需要保留交互和滚动流畅度，真实平台的证据必须覆盖显示、绘制、输入和状态变化。

```dart
Future<String> processMessage(int value) async {
  final values = List.generate(8, (index) => index + value);
  final total = values.fold<int>(0, (a, b) => a + b);
  return "fixed message $i: \$total";
}
```

''';

