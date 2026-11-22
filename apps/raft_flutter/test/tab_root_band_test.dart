import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'mounted_message_navigation_test.dart' show pageFixture, mountPage;
import 'parity/parity_harness.dart' show loadParityFonts;

/// Web v1.24 TabRootBar on the phone tab roots: the frame band (56 tall, the
/// seam below, 20px sides) with Home's WorkspaceButton and Search's field as
/// its `content`, and the one-line Search filter strip.
class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/messages/search') return {'results': [], 'hasMore': false};
    if (path.endsWith('/members') || path == '/agents') return [];
    if (path.endsWith('/machines')) return [];
    return {};
  }
}

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('Home band $mode: workspace button, avatar and name, menu', (
      t,
    ) async {
      final (w, _) = await pageFixture(t);
      w.server = RaftRecord({'id': 's1', 'role': 'owner', 'name': 'Alpha'});
      w.setSection('home');
      await mountPage(t, w, dark, width: 390, height: 844, browserHost: true);
      final tokens = RaftTokens.of(
        t.element(find.byKey(const Key('mobile-server-selector'))),
      );
      final button = find.byType(RaftWorkspaceButton);
      expect(button, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('mobile-server-selector')),
          matching: find.byType(RaftWorkspaceButton),
        ),
        findsOneWidget,
      );
      final avatar = find.descendant(
        of: button,
        matching: find.byType(RaftAvatarSlot),
      );
      expect(avatar, findsOneWidget);
      expect(t.getRect(avatar).left, 20, reason: '-ml-[11px] on the 20 edge');
      expect(
        find.descendant(of: button, matching: find.text('Alpha')),
        findsOneWidget,
      );
      final band = t.getRect(find.byType(RaftMobileRootHeader));
      expect(band.height, 56);
      final bell = find.byType(RaftMobileNotificationButton);
      expect(t.getRect(bell).right, 381, reason: 'Web: 9px from the edge');
      expect(
        tokens.colors['layer-section-header-mobile'],
        tokens.colors['layer-frame'],
      );
      await t.tap(button);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('server-switcher-menu')), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  group('Search tab root', () {
    const captureKey = Key('search-band-paint');
    late RaftClient client;
    late _Workspace w;
    late int backCalls;
    setUp(() {
      backCalls = 0;
      client = RaftClient(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      )..user = RaftRecord({'id': 'owner', 'name': 'Owner'});
      client.selectServer('s');
      w = _Workspace(client)..server = RaftRecord({'id': 's', 'role': 'owner'});
    });
    tearDown(() async {
      w.dispose();
      await client.dispose();
    });

    Future<void> mount(
      WidgetTester t, {
      required bool dark,
      bool root = true,
      TargetPlatform platform = TargetPlatform.android,
    }) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          supportedLocales: const [Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: raftTheme(dark: dark).copyWith(platform: platform),
          home: Scaffold(
            body: RepaintBoundary(
              key: captureKey,
              child: ResourceView(
                controller: w,
                section: 'search',
                mobileRoot: root,
                restoreSearchState: false,
                onBack: () => backCalls++,
                onMessage: (_, _) async {},
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets('band $mode: frame fill, seam, field inset 20, no Back', (
        t,
      ) async {
        await t.runAsync(loadParityFonts);
        await mount(t, dark: dark);
        final head = find.byKey(const Key('search-tab-head'));
        expect(head, findsOneWidget);
        final tokens = RaftTokens.of(t.element(head));
        expect(t.getRect(head), const Rect.fromLTWH(0, 0, 390, 56));
        final box = t
            .widgetList<Container>(
              find.descendant(of: head, matching: find.byType(Container)),
            )
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((d) => d.border != null);
        expect(box.color, tokens.colors['layer-frame']);
        expect(
          (box.border! as Border).bottom.color,
          tokens.colors['line-seam'],
        );
        final field = find.descendant(
          of: head,
          matching: find.byType(RaftSearchInput),
        );
        expect(t.getRect(field), const Rect.fromLTWH(20, 5.5, 350, 44));
        final glyph = find.descendant(
          of: field,
          matching: find.byWidgetPredicate(
            (widget) => widget is RaftIcon && widget.glyph == RaftGlyph.search,
          ),
        );
        expect(t.getRect(glyph), const Rect.fromLTWH(33, 18.5, 18, 18));
        final input = find.descendant(
          of: field,
          matching: find.byType(RaftInputGroup),
        );
        final surface = t
            .widgetList<DecoratedBox>(
              find.descendant(of: input, matching: find.byType(DecoratedBox)),
            )
            .map((widget) => widget.decoration)
            .whereType<BoxDecoration>()
            .first;
        expect(surface.borderRadius, BorderRadius.circular(10));
        final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byKey(captureKey),
        );
        final paint = (await t.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          try {
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            int pixel(int x, int y) =>
                bytes.getUint32((y * image.width + x) * 4);
            final fill = pixel(690, 50) >> 24;
            final hintStart = [
              for (var y = 34; y < 82; y++)
                if (Iterable<int>.generate(
                  576,
                  (i) => i + 115,
                ).any((x) => ((pixel(x, y) >> 24) - fill).abs() > 8))
                  y,
            ].first;
            return (
              above: pixel(390, 8),
              before: pixel(390, 10),
              border: pixel(390, 12),
              hintStart: hintStart,
            );
          } finally {
            image.dispose();
          }
        }))!;
        expect(paint.before, paint.above, reason: 'paint starts at y=6');
        final outline = tokens.colors['line-strong']!;
        expect(paint.border >> 8, outline.toARGB32() & 0xffffff);
        // Blink @2× starts the hint at physical row 43. Allow one AA row.
        expect(paint.hintStart, closeTo(43, 1));
        expect(find.byType(RaftMobileBackButton), findsNothing);
        expect(find.byTooltip('Back'), findsNothing);
      });
    }

    for (final (dark, platform) in [
      (false, TargetPlatform.android),
      (true, TargetPlatform.android),
      (false, TargetPlatform.linux),
    ]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets(
        'phone Search focuses at both vertical field edges ($mode, ${platform.name})',
        (t) async {
          await mount(t, dark: dark, platform: platform);
          final group = find.descendant(
            of: find.byKey(const Key('search-tab-head')),
            matching: find.byType(RaftInputGroup),
          );
          final editable = find.descendant(
            of: group,
            matching: find.byType(EditableText),
          );
          final focus = t.widget<EditableText>(editable).focusNode;
          final box = t.getRect(group);
          final text = t.getRect(editable);
          final kind = platform == TargetPlatform.linux
              ? ui.PointerDeviceKind.mouse
              : ui.PointerDeviceKind.touch;
          for (final y in [box.top + 3, box.bottom - 3]) {
            await t.tapAt(Offset(text.left + 80, y), kind: kind);
            await t.pumpAndSettle();
            expect(focus.hasFocus, isTrue, reason: 'InputGroup field at y=$y');
            focus.unfocus();
            await t.pumpAndSettle();
          }
          for (final x in [box.left + 22, box.right - 10]) {
            await t.tapAt(Offset(x, box.center.dy), kind: kind);
            await t.pumpAndSettle();
            expect(focus.hasFocus, isFalse, reason: 'Search addon at x=$x');
          }
        },
      );
    }

    testWidgets('native Search field keeps pointer and keyboard focus', (
      t,
    ) async {
      await mount(t, dark: false);
      final field = find.descendant(
        of: find.byKey(const Key('search-tab-head')),
        matching: find.byType(EditableText),
      );
      final text = t.widget<EditableText>(field);
      expect(text.focusNode.hasFocus, isFalse);
      await t.tap(field.hitTestable());
      await t.pumpAndSettle();
      expect(text.focusNode.hasFocus, isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
      expect(text.focusNode.hasFocus, isFalse);
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await t.pumpAndSettle();
      expect(text.focusNode.hasFocus, isTrue);
      t.testTextInput.enterText('roadmap');
      await t.pumpAndSettle();
      expect(text.controller.text, 'roadmap');
    });

    testWidgets('a pushed Search (not a tab root) keeps its Back', (t) async {
      await mount(t, dark: false, root: false);
      expect(find.byKey(const Key('search-tab-head')), findsNothing);
      final back = find.byTooltip('Back').hitTestable();
      expect(back, findsOneWidget);
      await t.tap(back);
      await t.pump();
      expect(backCalls, 1);
    });

    testWidgets('filter strip is one line and the chips scroll sideways', (
      t,
    ) async {
      await mount(t, dark: false);
      double top(String text) => t.getRect(find.text(text)).center.dy;
      final line = top('From');
      for (final text in ['Scope', 'Channel', 'Any time', 'Relevant']) {
        expect(top(text), moreOrNear(line), reason: text);
      }
      final scroller = find.descendant(
        of: find.byType(RaftFitToolbar),
        matching: find.byType(SingleChildScrollView),
      );
      expect(scroller, findsOneWidget);
      final position = t
          .state<ScrollableState>(
            find.descendant(of: scroller, matching: find.byType(Scrollable)),
          )
          .position;
      expect(position.axis, Axis.horizontal);
      expect(position.maxScrollExtent, greaterThan(0));
      await t.drag(scroller, const Offset(-120, 0));
      await t.pump();
      expect(position.pixels, greaterThan(0));
      // The strip: 8 air, 32 controls, 8 air, the seam (49 by touch).
      final strip = t.getRect(find.byType(RaftFitToolbar));
      expect(strip.height, 32 + 0);
    });
  });
}

Matcher moreOrNear(double v) => closeTo(v, 1);
