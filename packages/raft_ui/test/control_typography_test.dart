import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

const zh = Locale('zh', 'CN');
final profileHeight = RaftControlTypographyTokens.androidChineseLineHeight;

bool isProfile(TextStyle? style) =>
    style != null &&
    style.height == profileHeight &&
    style.leadingDistribution == TextLeadingDistribution.proportional;

/// Every label paragraph (not icon-font glyphs) under [root].
List<InlineSpan> labelSpans(WidgetTester tester, Finder root) => [
  for (final p in tester.widgetList<RichText>(
    find.descendant(of: root, matching: find.byType(RichText)),
  ))
    if (p.text.style?.fontFamily != 'MaterialIcons' &&
        p.text.toPlainText().trim().isNotEmpty)
      p.text,
];

Widget host(Widget child, {Locale locale = zh, TargetPlatform? platform}) {
  final theme = raftTheme(locale: locale, platform: platform);
  return MaterialApp(
    theme: theme.copyWith(platform: platform),
    home: Builder(
      builder: (context) => Localizations.override(
        context: context,
        locale: locale,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

void main() {
  group('policy', () {
    const base = TextStyle(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w700,
      color: Color(0xFF123456),
      fontFamily: 'Family',
      fontFamilyFallback: ['Fallback'],
      leadingDistribution: TextLeadingDistribution.even,
    );

    test('the line height comes from the generated token', () {
      expect(RaftControlTypography.androidChineseLineHeight, profileHeight);
      expect(profileHeight, 1.3);
    });

    test('Android + Chinese changes only height and leading distribution', () {
      for (final locale in const [
        Locale('zh'),
        Locale('zh', 'CN'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      ]) {
        final resolved = RaftControlTypography.resolve(
          baseStyle: base,
          platform: TargetPlatform.android,
          locale: locale,
        );
        expect(isProfile(resolved), isTrue, reason: '$locale');
        expect(resolved.fontSize, base.fontSize);
        expect(resolved.fontWeight, base.fontWeight);
        expect(resolved.color, base.color);
        expect(resolved.fontFamily, base.fontFamily);
        expect(resolved.fontFamilyFallback, base.fontFamilyFallback);
      }
    });

    test('other platforms and locales keep the style instance', () {
      for (final platform in [
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        expect(
          RaftControlTypography.resolve(
            baseStyle: base,
            platform: platform,
            locale: zh,
          ),
          same(base),
          reason: '$platform',
        );
      }
      for (final locale in const [Locale('en'), Locale('ja'), Locale('ko')]) {
        expect(
          RaftControlTypography.resolve(
            baseStyle: base,
            platform: TargetPlatform.android,
            locale: locale,
          ),
          same(base),
          reason: '$locale',
        );
      }
    });
  });

  group('Material theme', () {
    TextStyle? buttonText(ThemeData theme) =>
        theme.textButtonTheme.style?.textStyle?.resolve(const {});

    test('control families take the profile on Android Chinese only', () {
      final theme = raftTheme(locale: zh, platform: TargetPlatform.android);
      for (final style in [
        buttonText(theme),
        theme.outlinedButtonTheme.style?.textStyle?.resolve(const {}),
        theme.filledButtonTheme.style?.textStyle?.resolve(const {}),
        theme.segmentedButtonTheme.style?.textStyle?.resolve(const {}),
        theme.chipTheme.labelStyle,
        theme.popupMenuTheme.textStyle,
        theme.navigationBarTheme.labelTextStyle?.resolve(const {}),
      ]) {
        expect(isProfile(style), isTrue);
      }
      // Body and multi-line typography keep their metrics.
      expect(theme.textTheme.bodyMedium?.height, 24 / 16);
      expect(isProfile(theme.textTheme.bodyMedium), isFalse);
      expect(isProfile(theme.textTheme.labelLarge), isFalse);
      for (final other in [
        raftTheme(),
        raftTheme(locale: zh, platform: TargetPlatform.iOS),
        raftTheme(locale: const Locale('en'), platform: TargetPlatform.android),
      ]) {
        expect(isProfile(buttonText(other)), isFalse);
        expect(isProfile(other.chipTheme.labelStyle), isFalse);
      }
    });
  });

  group('components (no style leak)', () {
    // Every single-line control label must reach its paragraph with the
    // profile: a local TextStyle that restates height/leading leaks.
    final samples = <String, Widget Function()>{
      'RaftBadge': () => const RaftBadge(label: '新消息'),
      'RaftResourceBadge': () => const RaftResourceBadge(label: '5 条回复'),
      'RaftResourceBadge glyph': () => const RaftResourceBadge(
        label: '你',
        glyph: RaftGlyph.atSign,
        variant: RaftBadgeRecipeVariant.primary,
      ),
      'RaftThreadRepliesBadge': () =>
          const RaftThreadRepliesBadge(replyCount: 5, unreadCount: 2),
      'RaftRecipeButton': () => RaftRecipeButton(label: '选择', onPressed: () {}),
      'RaftTextButton': () => RaftTextButton(label: '全部已读', onPressed: () {}),
      'RaftSegmentedControl buttons': () => RaftSegmentedControl<String>(
        label: '筛选',
        value: 'all',
        onChanged: (_) {},
        items: const [
          RaftSegmentedOption(value: 'all', label: '全部', count: '3'),
          RaftSegmentedOption(value: 'unread', label: '未读'),
        ],
      ),
      'RaftSegmentedControl tabs': () => RaftSegmentedControl<String>(
        label: '筛选',
        legacyStyle: RaftSegmentedStyle.tabs,
        value: 'all',
        onChanged: (_) {},
        items: const [
          RaftSegmentedOption(value: 'all', label: '全部'),
          RaftSegmentedOption(value: 'mentions', label: '提及'),
        ],
      ),
      'RaftSegmentedControl taskViews': () => RaftSegmentedControl<String>(
        label: '视图',
        legacyStyle: RaftSegmentedStyle.taskViews,
        value: 'list',
        onChanged: (_) {},
        items: const [
          RaftSegmentedOption(value: 'list', label: '列表'),
          RaftSegmentedOption(value: 'board', label: '看板'),
        ],
      ),
      'RaftMenuItem': () => RaftMenuPanel(
        width: 240,
        onDismiss: () {},
        children: [RaftMenuItem(label: '标记为已读', onPressed: () {})],
      ),
      'RaftRuntimeChip': () =>
          const RaftRuntimeChip(label: '运行时', detected: true),
      'RaftRecipeBadge': () => const RaftRecipeBadge('中文'),
      'RaftTaskStatus': () => const RaftTaskStatus(status: 'in_progress'),
      'RaftActorTypeBadge': () => const RaftActorTypeBadge(label: '智能体'),
      'RaftArchivedBadge': () => const RaftArchivedBadge(label: '已归档'),
      'RaftFeedbackKindChip': () => const RaftFeedbackKindChip(problem: true),
    };

    for (final entry in samples.entries) {
      testWidgets('${entry.key} takes the profile on Android Chinese', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(entry.value(), platform: TargetPlatform.android),
        );
        final spans = labelSpans(tester, find.byWidgetPredicate((w) => true));
        // The scaffold and overlay hold no text of their own: every label
        // paragraph on screen belongs to the sample.
        expect(spans, isNotEmpty);
        for (final span in spans) {
          expect(
            isProfile(span.style),
            isTrue,
            reason: '"${span.toPlainText()}" ${span.style}',
          );
        }
      });

      testWidgets('${entry.key} is unchanged on iOS and in English', (
        tester,
      ) async {
        for (final (platform, locale) in [
          (TargetPlatform.iOS, zh),
          (TargetPlatform.android, const Locale('en')),
        ]) {
          await tester.pumpWidget(
            host(entry.value(), locale: locale, platform: platform),
          );
          for (final span in labelSpans(
            tester,
            find.byWidgetPredicate((w) => true),
          )) {
            expect(
              isProfile(span.style),
              isFalse,
              reason: '$platform $locale "${span.toPlainText()}"',
            );
          }
        }
      });
    }
  });

  group('CSS line box', () {
    Future<(RenderBox, RenderParagraph)> mount(
      WidgetTester tester,
      TargetPlatform platform,
      Locale locale,
    ) async {
      await tester.pumpWidget(
        host(
          const SizedBox(
            height: 24,
            child: DefaultTextStyle(
              style: TextStyle(fontSize: 12, height: 16 / 12),
              child: RaftCssText('全部已读', controlLabel: true),
            ),
          ),
          locale: locale,
          platform: platform,
        ),
      );
      final lineBox = tester.renderObject<RenderBox>(
        find.byType(RaftCssLineBox),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(RaftCssLineBox),
          matching: find.byType(RichText),
        ),
      );
      return (lineBox, paragraph);
    }

    testWidgets(
      'control labels keep Flutter\'s own baseline on Android Chinese',
      (tester) async {
        final (box, paragraph) = await mount(
          tester,
          TargetPlatform.android,
          zh,
        );
        const loose = BoxConstraints(maxWidth: 200, maxHeight: 100);
        expect(
          box.getDryBaseline(loose, TextBaseline.alphabetic),
          paragraph.getDryBaseline(loose, TextBaseline.alphabetic),
        );
        // No paint shift: the paragraph paints at the line box origin.
        expect(
          paragraph.localToGlobal(Offset.zero),
          box.localToGlobal(Offset.zero),
        );
        expect(isProfile(paragraph.text.style), isTrue);
      },
    );

    testWidgets('elsewhere the Blink baseline model is untouched', (
      tester,
    ) async {
      final (_, paragraph) = await mount(
        tester,
        TargetPlatform.android,
        const Locale('en'),
      );
      expect(isProfile(paragraph.text.style), isFalse);
      expect(paragraph.text.style?.height, 16 / 12);
    });
  });
}
