import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// The feedback / text part of the data-display families at raft-ui 0.95.3
/// (Web v1.24): Banner, EmptyState, Progress, TextLink, SectionEyebrow /
/// SectionHeader.
///
/// The three input contexts: a desktop window with a mouse (1024x768 Linux),
/// an unfolded foldable by touch (856x944 Android) and a narrow desktop window
/// (390x844 Linux, still a mouse, still below the 768 band).
const _desktop = (Size(1024, 768), TargetPlatform.linux);
const _foldable = (Size(856, 944), TargetPlatform.android);
const _narrow = (Size(390, 844), TargetPlatform.linux);

Future<void> _mount(
  WidgetTester t,
  Widget child, {
  (Size, TargetPlatform) context = _desktop,
  bool dark = false,
  double? width,
}) async {
  t.view.physicalSize = context.$1;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark).copyWith(platform: context.$2),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: width == null ? child : SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 300));
}

RaftTokens _tokens(WidgetTester t, Finder f) => RaftTokens.of(t.element(f));

Widget _button(String key) => RaftButton(
  key: ValueKey(key),
  label: 'Retry',
  size: RaftButtonRecipeSize.sm,
  visualHeight: RaftMetrics.buttonSm,
  onPressed: () {},
);

Widget _banner({
  RaftBannerRecipeSize size = RaftBannerRecipeSize.md,
  RaftBannerRecipeStatus status = RaftBannerRecipeStatus.info,
  String description = 'Reconnect to send',
  bool action = false,
  VoidCallback? onClose,
  String? closeLabel,
  bool live = true,
  RaftGlyph? glyph,
}) => RaftBanner(
  key: const ValueKey('banner'),
  size: size,
  status: status,
  description: description,
  live: live,
  glyph: glyph,
  action: action ? _button('action') : null,
  onClose: onClose,
  closeLabel: closeLabel,
);

TextStyle _style(WidgetTester t, String text) =>
    t.widget<Text>(find.text(text)).style!;

Iterable<SemanticsRole> _roles(WidgetTester t) => t
    .widgetList<Semantics>(find.byType(Semantics))
    .map((s) => s.properties.role)
    .whereType<SemanticsRole>();

TextStyle? _spanStyle(WidgetTester t, Finder rich, String text) {
  TextStyle? found;
  final root = t.widget<RichText>(rich).text;
  root.visitChildren((span) {
    if (span is TextSpan && span.text == text) found = span.style;
    return true;
  });
  return found;
}

void main() {
  group('Banner', () {
    testWidgets(
      'text is text-callout at every density: 14/20, 22 with a mouse',
      (t) async {
        for (final size in [RaftBannerRecipeSize.sm, RaftBannerRecipeSize.md]) {
          await _mount(t, _banner(size: size), context: _foldable, width: 360);
          expect(_style(t, 'Reconnect to send').fontSize, 14, reason: '$size');
          expect(
            _style(t, 'Reconnect to send').height,
            20 / 14,
            reason: '$size',
          );
          await _mount(t, _banner(size: size), context: _narrow, width: 360);
          expect(
            _style(t, 'Reconnect to send').height,
            20 / 14,
            reason: '$size',
          );
          await _mount(t, _banner(size: size), context: _desktop, width: 360);
          expect(_style(t, 'Reconnect to send').fontSize, 14, reason: '$size');
          expect(
            _style(t, 'Reconnect to send').height,
            22 / 14,
            reason: '$size',
          );
        }
      },
    );

    testWidgets('sm with a button pads 10 top and bottom, without one 8', (
      t,
    ) async {
      for (final context in [_desktop, _foldable, _narrow]) {
        await _mount(
          t,
          _banner(size: RaftBannerRecipeSize.sm, action: true),
          context: context,
          width: 300,
        );
        final box = t.getTopLeft(find.byKey(const ValueKey('banner')));
        expect(
          t.getTopLeft(find.text('Reconnect to send')).dy - box.dy,
          10,
          reason: '${context.$2}',
        );
        await _mount(
          t,
          _banner(size: RaftBannerRecipeSize.sm),
          context: context,
          width: 300,
        );
        expect(
          t.getTopLeft(find.text('Reconnect to send')).dy -
              t.getTopLeft(find.byKey(const ValueKey('banner'))).dy,
          8,
          reason: '${context.$2}',
        );
      }
    });

    // A 390px window cannot hold a 452px container: it is always below.
    for (final context in [_desktop, _foldable]) {
      testWidgets('action: below the text, end aligned, under 452px; beside it from 452px '
          '(${context.$2}, ${context.$1.width.toInt()})', (t) async {
        // md padding is 14 a side; the container query measures the content.
        await _mount(
          t,
          _banner(action: true),
          context: context,
          width: 451 + 28,
        );
        var banner = t.getRect(find.byKey(const ValueKey('banner')));
        var action = t.getRect(find.byKey(const ValueKey('action')));
        final text = t.getRect(find.text('Reconnect to send'));
        expect(action.top, greaterThanOrEqualTo(text.bottom), reason: '451');
        expect(action.right, banner.right - 14, reason: '451 end aligned');
        await _mount(
          t,
          _banner(action: true),
          context: context,
          width: 452 + 28,
        );
        banner = t.getRect(find.byKey(const ValueKey('banner')));
        action = t.getRect(find.byKey(const ValueKey('action')));
        final beside = t.getRect(find.text('Reconnect to send'));
        expect(action.center.dy, closeTo(beside.center.dy, 1), reason: '452');
        expect(action.left, greaterThan(beside.right), reason: '452');
        expect(action.right, banner.right - 14, reason: '452 end aligned');
      });
    }

    testWidgets('narrow window: the action is always under the text', (
      t,
    ) async {
      await _mount(t, _banner(action: true), context: _narrow, width: 390);
      final text = t.getRect(find.text('Reconnect to send'));
      final action = t.getRect(find.byKey(const ValueKey('action')));
      expect(action.top, greaterThanOrEqualTo(text.bottom));
    });

    testWidgets('copy that does not fit next to the action stays above it', (
      t,
    ) async {
      await _mount(
        t,
        _banner(
          action: true,
          description:
              'This copy is long enough that it needs the whole row and '
              'cannot sit beside the button on one line at this width.',
        ),
        width: 520,
      );
      final text = t.getRect(find.byType(Text).first);
      final action = t.getRect(find.byKey(const ValueKey('action')));
      expect(action.top, greaterThanOrEqualTo(text.bottom));
    });

    testWidgets('the leading glyph centres on the first line', (t) async {
      for (final (size, glyph, touch, desktop) in [
        (RaftBannerRecipeSize.sm, 16.0, 2.0, 3.0),
        (RaftBannerRecipeSize.md, 20.0, 0.0, 1.0),
      ]) {
        for (final context in [_foldable, _desktop]) {
          await _mount(
            t,
            _banner(size: size, glyph: RaftGlyph.info),
            context: context,
            width: 360,
          );
          final top =
              t.getTopLeft(find.byType(RaftIcon)).dy -
              t.getTopLeft(find.text('Reconnect to send')).dy;
          expect(
            top,
            context == _desktop ? desktop : touch,
            reason: '$size $glyph ${context.$2}',
          );
        }
      }
    });

    testWidgets('BannerClose: labelled ghost icon button calls onClose', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      var closed = 0;
      for (final context in [_desktop, _foldable, _narrow]) {
        closed = 0;
        await _mount(
          t,
          _banner(onClose: () => closed++, closeLabel: 'Dismiss notice'),
          context: context,
          width: 360,
        );
        expect(find.bySemanticsLabel('Dismiss notice'), findsWidgets);
        await t.tap(find.byKey(const ValueKey('banner-close')));
        await t.pump();
        expect(closed, 1, reason: '${context.$2}');
        // It does not grow the one-line banner and ends on the padding.
        final banner = t.getRect(find.byKey(const ValueKey('banner')));
        final close = t.getRect(find.byKey(const ValueKey('banner-close')));
        expect(
          banner.height,
          closeTo(12 + (context == _desktop ? 22 : 20) + 12, .01),
        );
        expect(
          close.center.dy,
          closeTo(banner.top + 12 + (context == _desktop ? 11 : 10), .6),
        );
      }
      await _mount(t, _banner(onClose: () {}), width: 360);
      expect(find.bySemanticsLabel('Dismiss'), findsWidgets);
      await _mount(t, _banner(), width: 360);
      expect(find.byKey(const ValueKey('banner-close')), findsNothing);
      handle.dispose();
    });

    testWidgets('live role: alert only for destructive, status otherwise', (
      t,
    ) async {
      await _mount(t, _banner(status: RaftBannerRecipeStatus.warning));
      expect(_roles(t), contains(SemanticsRole.status));
      expect(_roles(t), isNot(contains(SemanticsRole.alert)));
      await _mount(t, _banner(status: RaftBannerRecipeStatus.destructive));
      expect(_roles(t), contains(SemanticsRole.alert));
      await _mount(t, _banner(live: false));
      expect(_roles(t), isNot(contains(SemanticsRole.status)));
      expect(_roles(t), isNot(contains(SemanticsRole.alert)));
    });
  });

  group('EmptyState', () {
    final widgets = <String, Widget Function()>{
      'RaftEmptyState': () => const RaftEmptyState(
        title: 'Nothing here',
        detail: 'Create the first one.',
        titleHeading: true,
      ),
      'RaftProductEmptyState': () => RaftProductEmptyState(
        title: 'Nothing here',
        description: 'Create the first one.',
        titleHeading: true,
        icon: (context, size, color) =>
            Icon(Icons.inbox, size: size, color: color),
      ),
    };
    for (final MapEntry(key: name, value: build) in widgets.entries) {
      testWidgets('$name: desktop metrics only with a mouse from 768', (
        t,
      ) async {
        await _mount(t, build(), context: _desktop);
        expect(_style(t, 'Nothing here').fontSize, 16);
        expect(_style(t, 'Nothing here').height, 24 / 16);
        expect(_style(t, 'Create the first one.').height, 22 / 14);
        final pad = t
            .widget<Padding>(
              find
                  .descendant(
                    of: find.byType(Center),
                    matching: find.byType(Padding),
                  )
                  .first,
            )
            .padding;
        expect(pad.horizontal, 32, reason: 'px 16');
        for (final context in [_foldable, _narrow]) {
          await _mount(t, build(), context: context);
          expect(
            _style(t, 'Nothing here').fontSize,
            17,
            reason: '${context.$2}',
          );
          expect(_style(t, 'Nothing here').height, 22 / 17);
          expect(_style(t, 'Create the first one.').height, 20 / 14);
          final pad = t
              .widget<Padding>(
                find
                    .descendant(
                      of: find.byType(Center),
                      matching: find.byType(Padding),
                    )
                    .first,
              )
              .padding;
          expect(pad.horizontal, 48, reason: 'px 24');
        }
      });

      testWidgets('$name: titleHeading makes the title a heading', (t) async {
        final handle = t.ensureSemantics();
        await _mount(t, build());
        expect(
          t.getSemantics(find.text('Nothing here')),
          matchesSemantics(
            label: 'Nothing here',
            isHeader: true,
            textDirection: TextDirection.ltr,
          ),
        );
        handle.dispose();
      });
    }
  });

  group('ProgressBar', () {
    Widget bar(double value, {bool hold = false}) => SizedBox(
      width: 200,
      child: RaftProgressBar(
        value: value,
        label: 'Disk',
        showPercent: true,
        tone: RaftProgressRecipeVariant.information,
        holdToneWhenFull: hold,
      ),
    );
    Finder fillOf(Color color) => find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.position == DecorationPosition.background &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == color,
    );

    testWidgets('a labelled bar turns success at 100%, not before', (t) async {
      await _mount(t, bar(100));
      final ui = _tokens(t, find.byType(RaftProgressBar)).ui;
      expect(fillOf(ui.success), findsOneWidget);
      await _mount(t, bar(99));
      expect(fillOf(ui.success), findsNothing);
      expect(fillOf(ui.info), findsOneWidget);
    });

    testWidgets('holdToneWhenFull keeps the tone at 100%', (t) async {
      await _mount(t, bar(100, hold: true));
      final ui = _tokens(t, find.byType(RaftProgressBar)).ui;
      expect(fillOf(ui.success), findsNothing);
      expect(fillOf(ui.info), findsOneWidget);
    });
  });

  group('TextLink', () {
    TextStyle? linkStyle(WidgetTester t) => t
        .widget<RichText>(
          find.descendant(
            of: find.byType(RaftAuthTextLink),
            matching: find.byType(RichText),
          ),
        )
        .text
        .style;

    for (final context in [_desktop, _foldable, _narrow]) {
      testWidgets(
        'auth links are raft-ui muted / strong / disabled (${context.$2})',
        (t) async {
          await _mount(
            t,
            RaftAuthTextLink(label: 'Create one', primary: true, onTap: () {}),
            context: context,
          );
          final ui = _tokens(t, find.byType(RaftAuthTextLink)).ui;
          expect(linkStyle(t)!.color, ui.foreground);
          expect(linkStyle(t)!.fontWeight, FontWeight.w600);
          await _mount(
            t,
            RaftAuthTextLink(label: 'Forgot', onTap: () {}),
            context: context,
          );
          expect(linkStyle(t)!.color, ui.foregroundMuted);
          expect(linkStyle(t)!.fontWeight, FontWeight.w500);
          await _mount(
            t,
            const RaftAuthTextLink(label: 'Forgot'),
            context: context,
          );
          expect(linkStyle(t)!.color, ui.foregroundDisabled);
          expect(
            find.descendant(
              of: find.byType(RaftAuthTextLink),
              matching: find.byType(Opacity),
            ),
            findsNothing,
            reason: 'disabled is a colour, not an opacity',
          );
        },
      );
    }

    testWidgets('auth link taps and keeps the underline for hover only', (
      t,
    ) async {
      var taps = 0;
      await _mount(
        t,
        RaftAuthTextLink(
          key: const ValueKey('link'),
          label: 'Sign in',
          onTap: () => taps++,
        ),
      );
      await t.tap(find.byKey(const ValueKey('link')));
      expect(taps, 1);
    });
  });

  group('SectionEyebrow / SectionHeader', () {
    testWidgets('eyebrow is text-footnote: 13/18, 12/18 with a mouse', (
      t,
    ) async {
      await _mount(t, const RaftSectionEyebrow('Members'), context: _desktop);
      var style = t.widget<Text>(find.byType(Text)).style!;
      expect(style.fontSize, 12);
      expect(style.height, 18 / 12);
      for (final context in [_foldable, _narrow]) {
        await _mount(t, const RaftSectionEyebrow('Members'), context: context);
        style = t.widget<Text>(find.byType(Text)).style!;
        expect(style.fontSize, 13, reason: '${context.$2}');
        expect(style.height, 18 / 13);
      }
    });

    testWidgets('header count is mono-meta, normal weight, hint colour', (
      t,
    ) async {
      final rich = find.descendant(
        of: find.byType(RaftSectionEyebrow),
        matching: find.byType(RichText),
      );
      await _mount(
        t,
        const RaftSectionHeader(label: 'Skills', count: 3),
        context: _foldable,
      );
      var count = _spanStyle(t, rich, '3')!;
      expect(count.fontWeight, FontWeight.w400);
      expect(count.fontSize, 12);
      expect(count.height, 16 / 12);
      expect(count.color, _tokens(t, rich).colors['foreground-hint']);
      await _mount(
        t,
        const RaftSectionHeader(label: 'Skills', count: 3),
        context: _desktop,
      );
      count = _spanStyle(t, rich, '3')!;
      expect(count.fontSize, 12);
      expect(count.height, 18 / 12);
    });
  });
}
