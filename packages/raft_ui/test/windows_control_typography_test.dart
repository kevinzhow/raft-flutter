import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  const base = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontFamily: 'Body',
    fontFamilyFallback: ['Microsoft YaHei'],
    fontWeight: FontWeight.w700,
    leadingDistribution: TextLeadingDistribution.even,
  );

  test(
    'Windows Chinese controls preserve the face and use measured line metrics',
    () {
      final actual = RaftControlTypography.resolve(
        baseStyle: base,
        platform: TargetPlatform.windows,
        locale: const Locale('zh', 'CN'),
      );
      expect(actual.height, 1.2);
      expect(actual.leadingDistribution, TextLeadingDistribution.proportional);
      expect(actual.fontFamily, base.fontFamily);
      expect(actual.fontFamilyFallback, base.fontFamilyFallback);
      expect(actual.fontSize, base.fontSize);
      expect(actual.fontWeight, base.fontWeight);
      expect(RaftControlTypography.isControlStyle(actual), isTrue);
    },
  );

  test(
    'Windows non-Chinese controls and body typography keep existing metrics',
    () {
      for (final locale in [
        const Locale('en'),
        const Locale('ja'),
        const Locale('ko'),
      ]) {
        expect(
          RaftControlTypography.resolve(
            baseStyle: base,
            platform: TargetPlatform.windows,
            locale: locale,
          ),
          same(base),
        );
      }
      final theme = raftTheme(
        locale: const Locale('zh', 'CN'),
        platform: TargetPlatform.windows,
      );
      expect(theme.textTheme.bodyMedium?.height, 24 / 16);
      expect(
        RaftControlTypography.isControlStyle(theme.textTheme.bodyMedium!),
        isFalse,
      );
      expect(theme.textButtonTheme.style!.textStyle!.resolve({})!.height, 1.2);
    },
  );

  testWidgets(
    'Windows control families receive the profile without changing their labels',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(
            locale: const Locale('zh', 'CN'),
            platform: TargetPlatform.windows,
          ).copyWith(platform: TargetPlatform.windows),
          home: Builder(
            builder: (context) => Localizations.override(
              context: context,
              locale: const Locale('zh', 'CN'),
              child: Scaffold(
                body: Column(
                  children: [
                    RaftButton(label: '确认', onPressed: () {}),
                    RaftRecipeButton(label: '选择', onPressed: () {}),
                    const RaftBadge(label: '未读'),
                    RaftMenuPanel(
                      width: 240,
                      onDismiss: () {},
                      children: [RaftMenuItem(label: '文件', onPressed: () {})],
                    ),
                    RaftSegmentedControl<String>(
                      label: '视图',
                      value: 'all',
                      onChanged: (_) {},
                      items: const [
                        RaftSegmentedOption(value: 'all', label: '全部'),
                        RaftSegmentedOption(value: 'read', label: '已读'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final failures = <String>[];
      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        final label = rich.text.toPlainText();
        if (label.isEmpty || rich.text.style?.fontFamily == 'MaterialIcons')
          continue;
        final style = rich.text.style!;
        if (style.height != 1.2 ||
            style.leadingDistribution != TextLeadingDistribution.proportional) {
          failures.add('$label: ${style.height}/${style.leadingDistribution}');
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(failures, isEmpty);
    },
  );
}
