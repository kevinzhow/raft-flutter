import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/keyboard_inset_guard.dart';

void main() {
  late List<double> seen;
  late List<double> seenPadding;

  Widget host(ImeVisibility? probe) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery.fromView(
      view: WidgetsBinding.instance.platformDispatcher.views.first,
      child: KeyboardInsetGuard(
        imeVisible: probe,
        child: Builder(
          builder: (context) {
            final media = MediaQuery.of(context);
            seen.add(media.viewInsets.bottom);
            seenPadding.add(media.padding.bottom);
            return const Focus(child: SizedBox());
          },
        ),
      ),
    ),
  );

  Future<void> background(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
  }

  Future<void> resume(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
  }

  setUp(() {
    seen = [];
    seenPadding = [];
  });

  /// The sequence logged on an Android 17 device (docs/keyboard-repro.md):
  /// 883 px while open, 0 on return (the IME is hidden), then 883 px again when
  /// the system's no-op IME animation ends and Flutter re-dispatches the
  /// WindowInsets it cached at the last keyboard show. `ime.isVisible` is false
  /// from the return on.
  Future<void> staleReplay(WidgetTester tester) async {
    await background(tester);
    tester.view.viewInsets = FakeViewPadding.zero;
    tester.view.padding = const FakeViewPadding(bottom: 48);
    await resume(tester);
    expect(seen.last, 0);
    tester.view.viewInsets = const FakeViewPadding(bottom: 800);
    tester.view.padding = FakeViewPadding.zero;
    await tester.pump();
    expect(seen.last, 800, reason: 'engine replay is visible until checked');
  }

  /// Keyboard open (inset 800, system bar covered => engine padding 0), the app
  /// goes to the background and returns; the engine keeps the old inset.
  Future<void> openKeyboard(WidgetTester tester, ImeVisibility? probe) async {
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    tester.view.padding = FakeViewPadding.zero;
    tester.view.viewInsets = const FakeViewPadding(bottom: 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(probe));
    expect(seen.last, 800);
  }

  testWidgets('without a platform probe the stale inset survives resume', (
    tester,
  ) async {
    await openKeyboard(tester, null);
    await background(tester);
    await resume(tester);
    expect(seen.last, 800, reason: 'documents the engine behaviour');
  });

  testWidgets('a replayed stale inset after resume is reported as 0', (
    tester,
  ) async {
    await openKeyboard(tester, () async => false);
    await staleReplay(tester);
    await tester.pump(keyboardInsetSettleDelay);
    await tester.pump();
    expect(seen.last, 0);
    expect(seenPadding.last, 48, reason: 'system bar is given back');
  });

  testWidgets('a replayed inset while the IME is visible is kept', (
    tester,
  ) async {
    await openKeyboard(tester, () async => true);
    await staleReplay(tester);
    await tester.pump(keyboardInsetSettleDelay);
    await tester.pump();
    expect(seen.last, 800);
  });

  testWidgets('a moving keyboard animation is not checked until it settles', (
    tester,
  ) async {
    var probes = 0;
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      host(() async {
        probes++;
        return false;
      }),
    );
    for (final inset in [100.0, 300.0, 600.0, 800.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(probes, 0);
    await tester.pump(keyboardInsetSettleDelay);
    expect(probes, 1);
  });

  testWidgets('resume with the IME hidden reports no keyboard inset', (
    tester,
  ) async {
    await openKeyboard(tester, () async => false);
    await background(tester);
    await resume(tester);
    expect(seen.last, 0);
    expect(seenPadding.last, 48, reason: 'system bar is given back');
  });

  testWidgets('resume with the IME still visible keeps the inset', (
    tester,
  ) async {
    await openKeyboard(tester, () async => true);
    await background(tester);
    await resume(tester);
    expect(seen.last, 800);
  });

  testWidgets('unknown IME state trusts the engine', (tester) async {
    await openKeyboard(tester, () async => null);
    await background(tester);
    await resume(tester);
    expect(seen.last, 800);
  });

  testWidgets('a new engine inset ends the stale episode', (tester) async {
    await openKeyboard(tester, () async => false);
    await background(tester);
    await resume(tester);
    expect(seen.last, 0);
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 800);
    await tester.pump();
    expect(seen.last, 800, reason: 'keyboard reopened at the same height');
  });

  testWidgets('a focus change ends the stale episode', (tester) async {
    await openKeyboard(tester, () async => false);
    await background(tester);
    await resume(tester);
    expect(seen.last, 0);
    Focus.of(tester.element(find.byType(SizedBox))).requestFocus();
    await tester.pump();
    await tester.pump();
    expect(seen.last, 800);
  });

  testWidgets('resume without a keyboard inset never probes', (tester) async {
    var probes = 0;
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    tester.view.padding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      host(() async {
        probes++;
        return false;
      }),
    );
    await background(tester);
    await resume(tester);
    expect(probes, 0);
    expect(seen.last, 0);
    expect(seenPadding.last, 48);
  });
}
