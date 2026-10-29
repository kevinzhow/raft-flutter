import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Edge-to-edge helpers: bottom controls paint to the screen edge and pad by
/// the system inset, lists clear the bar, and the tab bar never follows the
/// keyboard.
void main() {
  const screen = Size(400, 800);

  void insets(WidgetTester t, {double nav = 24, double keyboard = 0}) {
    t.view.physicalSize = screen;
    t.view.devicePixelRatio = 1;
    t.view.viewPadding = FakeViewPadding(bottom: nav);
    // Android: the IME replaces the nav bar in `padding`, not in viewPadding.
    t.view.padding = FakeViewPadding(bottom: keyboard > 0 ? 0 : nav);
    t.view.viewInsets = FakeViewPadding(bottom: keyboard);
  }

  Future<void> pump(WidgetTester t, Widget child) =>
      t.pumpWidget(MaterialApp(theme: raftTheme(), home: child));

  tearDown(() {});

  testWidgets(
    'raftBottomInset follows padding, system inset follows viewPadding',
    (t) async {
      addTearDown(t.view.reset);
      late BuildContext inner;
      insets(t);
      await pump(
        t,
        Builder(
          builder: (c) {
            inner = c;
            return const SizedBox();
          },
        ),
      );
      expect(raftBottomInset(inner), 24);
      expect(raftSystemBottomInset(inner), 24);
      insets(t, keyboard: 300);
      await t.pump();
      expect(raftBottomInset(inner), 0, reason: 'keyboard covers the nav bar');
      expect(raftSystemBottomInset(inner), 24, reason: 'bar height is stable');
    },
  );

  testWidgets('raftScrollPadding adds clearance and the inset', (t) async {
    addTearDown(t.view.reset);
    insets(t);
    late EdgeInsets padding;
    await pump(
      t,
      Builder(
        builder: (c) {
          padding = raftScrollPadding(
            c,
            const EdgeInsets.all(16),
            raftTabBarClearance(),
          );
          return const SizedBox();
        },
      ),
    );
    expect(padding, const EdgeInsets.fromLTRB(16, 16, 16, 16 + 68 + 24));
  });

  testWidgets('RaftBottomInsetSurface reaches the edge and pads by the inset', (
    t,
  ) async {
    addTearDown(t.view.reset);
    insets(t);
    await pump(
      t,
      const Align(
        alignment: Alignment.bottomCenter,
        child: RaftBottomInsetSurface(
          color: Colors.white,
          padding: EdgeInsets.all(12),
          child: SizedBox(key: Key('inner'), height: 40, width: 100),
        ),
      ),
    );
    final surface = t.getRect(find.byType(RaftBottomInsetSurface));
    expect(surface.bottom, screen.height);
    expect(surface.height, 12 + 40 + 12 + 24);
    expect(t.getRect(find.byKey(const Key('inner'))).bottom, 800 - 12 - 24);
    // Keyboard up: inset is spent, no double padding.
    insets(t, keyboard: 300);
    await t.pump();
    expect(t.getRect(find.byType(RaftBottomInsetSurface)).height, 12 + 40 + 12);
  });

  testWidgets('RaftNavigationBarStyle picks icon contrast from the surface', (
    t,
  ) async {
    for (final (color, expected) in [
      (Colors.white, Brightness.dark),
      (const Color(0xFF111111), Brightness.light),
    ]) {
      await pump(
        t,
        RaftNavigationBarStyle(background: color, child: const SizedBox()),
      );
      final region = t.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).last,
      );
      expect(region.value.systemNavigationBarIconBrightness, expected);
      expect(region.value.systemNavigationBarColor, Colors.transparent);
    }
  });

  for (final floating in [true, false]) {
    testWidgets('adaptive workspace keeps the bar put under the keyboard '
        '(floating=$floating)', (t) async {
      addTearDown(t.view.reset);
      insets(t);
      late EdgeInsets contentPadding;
      await pump(
        t,
        RaftAdaptiveWorkspace(
          mobileNavigationFloating: floating,
          mobileNavigationClearance: floating ? 68 : 0,
          mobileNavigation: const SizedBox(
            key: Key('bar'),
            height: 60,
            width: double.infinity,
          ),
          sidebar: const SizedBox(),
          rail: const SizedBox(),
          content: Builder(
            builder: (c) {
              contentPadding = MediaQuery.paddingOf(c);
              return const SizedBox.expand(key: Key('content'));
            },
          ),
        ),
      );
      final restBar = t.getRect(find.byKey(const Key('bar')));
      expect(restBar.bottom, screen.height);
      final restContent = t.getRect(find.byKey(const Key('content')));
      expect(restContent.bottom, floating ? screen.height : screen.height - 60);
      expect(
        contentPadding.bottom,
        floating ? 68 + 24 : 0,
        reason: floating ? 'capsule clearance' : 'in-flow bar consumes it',
      );
      insets(t, keyboard: 300);
      await t.pump();
      expect(t.getRect(find.byKey(const Key('bar'))), restBar);
      expect(
        t.getRect(find.byKey(const Key('content'))).bottom,
        screen.height - 300,
        reason: 'content sits on the keyboard, the bar stays under it',
      );
      expect(contentPadding.bottom, 0);
      insets(t);
      await t.pump();
      expect(t.getRect(find.byKey(const Key('bar'))), restBar);
      expect(t.getRect(find.byKey(const Key('content'))), restContent);
    });
  }

  testWidgets('adaptive workspace without a bar: content on the keyboard, '
      'inset only at rest', (t) async {
    addTearDown(t.view.reset);
    insets(t);
    late EdgeInsets contentPadding;
    await pump(
      t,
      RaftAdaptiveWorkspace(
        sidebar: const SizedBox(),
        rail: const SizedBox(),
        content: Builder(
          builder: (c) {
            contentPadding = MediaQuery.paddingOf(c);
            return const SizedBox.expand(key: Key('content'));
          },
        ),
      ),
    );
    expect(contentPadding.bottom, 24);
    insets(t, keyboard: 300);
    await t.pump();
    expect(t.getRect(find.byKey(const Key('content'))).bottom, 500);
    expect(contentPadding.bottom, 0);
  });

  testWidgets('forward preview footer paints to the bottom with the inset', (
    t,
  ) async {
    addTearDown(t.view.reset);
    insets(t);
    await pump(
      t,
      const RaftForwardPage(
        child: RaftForwardPreviewStep(
          previewLabel: 'Preview',
          preview: SizedBox(height: 20),
          noteLabel: 'Note',
          note: SizedBox(height: 32),
          send: SizedBox(height: 32, width: 32),
        ),
      ),
    );
    final footer = t.getRect(find.byType(RaftBottomInsetSurface));
    expect(footer.bottom, screen.height);
    insets(t, keyboard: 300);
    await t.pump();
    expect(
      t.getRect(find.byType(RaftBottomInsetSurface)).bottom,
      screen.height - 300,
      reason: 'forward page sits above the keyboard',
    );
  });

  testWidgets('RaftComposer defaults its host padding to the inset', (t) async {
    addTearDown(t.view.reset);
    insets(t);
    await pump(
      t,
      Scaffold(
        resizeToAvoidBottomInset: false,
        body: Align(
          alignment: Alignment.bottomCenter,
          child: RaftComposer(onSend: (_) async => false),
        ),
      ),
    );
    final host = find.byKey(const ValueKey('composer-host-slot'));
    final shell = find.byKey(const ValueKey('composer-shell-slot'));
    expect(t.getRect(host).bottom, screen.height);
    final rest = t.getRect(host).bottom - t.getRect(shell).bottom;
    insets(t, keyboard: 300);
    await t.pump();
    final up = t.getRect(host).bottom - t.getRect(shell).bottom;
    expect(rest - up, 24, reason: 'inset dropped while the keyboard is up');
  });
}
