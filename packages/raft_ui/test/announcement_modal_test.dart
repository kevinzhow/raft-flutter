import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

const body = '''
Intro paragraph with `inline code`, **bold** and a [link](https://raft.build).

# Heading one

## Heading two

### Heading three

- First item
- Second item

1. One
2. Two
''';

Widget frame(
  RaftFamily family,
  bool dark, {
  String text = body,
  String? label,
  String? ctaLabel,
  RaftAnnouncementImage? image,
  VoidCallback? onDismiss,
  VoidCallback? onCta,
  ValueChanged<String>? onLink,
  Locale? locale,
  Size? size,
}) => MaterialApp(
  theme: raftTheme(family, dark: dark),
  home: MediaQuery(
    data: MediaQueryData(size: size ?? const Size(800, 600)),
    child: Scaffold(
      body: Builder(
        builder: (context) => Localizations.override(
          context: context,
          locale: locale,
          child: RaftAnnouncementModal(
            title: 'What is new',
            body: text,
            label: label,
            ctaLabel: ctaLabel,
            image: image,
            onDismiss: onDismiss ?? () {},
            onCta: onCta ?? (ctaLabel == null ? null : () {}),
            onLink: onLink,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  for (final (family, dark) in raftThemeMatrix([
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ])) {
    testWidgets('renders every block in ${family.name}${dark ? ' dark' : ''}', (
      t,
    ) async {
      await t.pumpWidget(frame(family, dark));
      expect(t.takeException(), isNull);
      // Web v1.21.12: the title is no longer uppercased, the label is the
      // default "Latest updates", headings keep their case.
      expect(find.text('What is new'), findsOneWidget);
      expect(find.text('Latest updates'), findsOneWidget);
      expect(find.text('inline code'), findsOneWidget);
      expect(find.text('Heading one'), findsOneWidget);
      expect(find.text('First item'), findsOneWidget);
      expect(find.text('2. '), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
      // max-w-xl
      expect(
        t.getSize(find.byKey(const ValueKey('announcement-modal'))).width,
        RaftAnnouncementCard.maxWidth,
      );
    });
  }

  testWidgets('heading sizes: text-xl, text-lg, text-base; paragraphs mt-3', (
    t,
  ) async {
    await t.pumpWidget(
      frame(RaftFamily.elegant, false, text: '# One\n\n## Two\n\n### Three'),
    );
    double sizeOf(String text) => t
        .widget<RaftCssText>(find.widgetWithText(RaftCssText, text))
        .style!
        .fontSize!;
    expect(sizeOf('One'), 20);
    expect(sizeOf('Two'), 18);
    expect(sizeOf('Three'), 16);
    await t.pumpWidget(frame(RaftFamily.elegant, false, text: 'A\n\nB\n\nC'));
    final a = t.getBottomLeft(find.text('A')).dy;
    final b = t.getTopLeft(find.text('B')).dy;
    final bBottom = t.getBottomLeft(find.text('B')).dy;
    final c = t.getTopLeft(find.text('C')).dy;
    // 22.75 px lines with a 12 px gap between paragraphs.
    expect(b - a, closeTo(12, 1));
    expect(c - bBottom, closeTo(12, 1));
  });

  testWidgets('Enter, Escape and the actions', (t) async {
    var dismiss = 0, cta = 0;
    final links = <String>[];
    await t.pumpWidget(
      frame(
        RaftFamily.elegant,
        false,
        onDismiss: () => dismiss++,
        onCta: () => cta++,
        onLink: links.add,
      ),
    );
    await t.pump();
    // No CTA: the primary action is Got it, and Enter acts like it.
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    expect((dismiss, cta), (1, 0));
    await t.tap(find.byKey(const ValueKey('announcement-ok')));
    expect((dismiss, cta), (2, 0));
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(dismiss, 3);
    await t.tap(find.byType(RaftDialogClose));
    expect(dismiss, 4);
    await t.tapOnText(find.textRange.ofSubstring('link'));
    expect(links, ['https://raft.build']);
  });

  testWidgets('a CTA is the primary action beside a Got it link', (t) async {
    var dismiss = 0, cta = 0;
    await t.pumpWidget(
      frame(
        RaftFamily.brutal,
        false,
        label: 'Release',
        ctaLabel: 'Read more',
        onDismiss: () => dismiss++,
        onCta: () => cta++,
      ),
    );
    await t.pump();
    expect(find.text('Release'), findsOneWidget);
    expect(find.text('Latest updates'), findsNothing);
    final gotIt = t.getRect(find.byKey(const ValueKey('announcement-dismiss')));
    final primary = t.getRect(find.byKey(const ValueKey('announcement-ok')));
    // One row: the link at the start, the CTA at the end (`ml-auto`).
    expect(gotIt.top, closeTo(primary.top, 0.5));
    expect(gotIt.left, lessThan(primary.left));
    final card = t.getRect(find.byKey(const ValueKey('announcement-modal')));
    expect(primary.right, closeTo(card.right - 2 - 28, 0.5));
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    expect((dismiss, cta), (0, 1));
    await t.tap(find.byKey(const ValueKey('announcement-dismiss')));
    expect((dismiss, cta), (1, 1));
    await t.tap(find.byKey(const ValueKey('announcement-ok')));
    expect((dismiss, cta), (1, 2));
  });

  testWidgets('narrow dialogs stack the actions at full width', (t) async {
    await t.pumpWidget(
      frame(
        RaftFamily.elegant,
        false,
        ctaLabel: 'Read more',
        size: const Size(390, 800),
      ),
    );
    await t.pump();
    final gotIt = t.getRect(find.byKey(const ValueKey('announcement-dismiss')));
    final primary = t.getRect(find.byKey(const ValueKey('announcement-ok')));
    expect(gotIt.width, primary.width);
    expect(primary.top - gotIt.bottom, 12);
    expect(primary.width, 390 - 32 - 56);
  });

  testWidgets('a long CTA label wraps and the footer wraps with it', (t) async {
    await t.pumpWidget(
      frame(
        RaftFamily.elegant,
        false,
        ctaLabel: 'Read the full migration guide and the list of changes for every runtime',
      ),
    );
    await t.pump();
    final gotIt = t.getRect(find.byKey(const ValueKey('announcement-dismiss')));
    final primary = t.getRect(find.byKey(const ValueKey('announcement-ok')));
    // Too wide for one row: the link keeps the first line, the CTA the next,
    // pushed to the end.
    expect(primary.top, greaterThan(gotIt.bottom));
    expect(primary.right, closeTo(576 - 28 + (800 - 576) / 2, 0.5));
  });

  testWidgets('the picture box is h-44 inside the body', (t) async {
    await t.pumpWidget(
      frame(
        RaftFamily.brutal,
        false,
        image: const RaftAnnouncementImage(
          url: 'https://fixture.invalid/api/announcements/images/x',
          alt: 'Diagram',
        ),
      ),
    );
    await t.pump();
    final picture = t.getRect(
      find.byKey(const ValueKey('announcement-picture')),
    );
    expect(picture.height, 176);
    expect(picture.width, 576 - 4 - 56);
  });

  testWidgets('zh copy', (t) async {
    await t.pumpWidget(
      frame(RaftFamily.brutal, false, locale: const Locale('zh', 'CN')),
    );
    expect(find.text('知道了'), findsOneWidget);
    expect(find.text('最新动态'), findsOneWidget);
  });
}
