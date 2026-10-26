import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Web Modal.tsx owns the scrollport. DialogCard.tsx places the header, form
// and actions in one natural-height surface; desktop actions are not pinned.
void main() {
  for (final size in const [Size(390, 844), Size(856, 944), Size(944, 856)]) {
    for (final dark in [false, true]) {
      testWidgets('product card scrolls as a whole: $size dark=$dark', (
        t,
      ) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        addTearDown(() => t.pumpWidget(const SizedBox()));
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(
              dark: dark,
              platform: size.width == 390
                  ? TargetPlatform.linux
                  : TargetPlatform.android,
            ),
            home: Scaffold(
              body: RaftModalBackdrop(
                child: RaftDialog.card(
                  title: 'Review changes',
                  onClose: () {},
                  footer: RaftButton(label: 'Finish', onPressed: () {}),
                  child: const SizedBox(height: 1300),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Review changes').hitTestable(), findsOneWidget);
        expect(find.text('Finish').hitTestable(), findsNothing);
        final viewport = find.byType(Scrollable).first;
        await t.scrollUntilVisible(
          find.text('Finish'),
          350,
          scrollable: viewport,
        );
        expect(find.text('Finish').hitTestable(), findsOneWidget);
        expect(find.text('Review changes').hitTestable(), findsNothing);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('framed card uses the space provided by its parent', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
    var submitted = false;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(platform: TargetPlatform.linux),
        // A host can constrain its route independently of the display metrics.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(size: const Size(800, 600)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showRaftForm<void>(
                context,
                builder: (_) => RaftDialog.card(
                  title: 'Review changes',
                  onClose: () {},
                  child: const SizedBox(height: 700),
                  footer: RaftButton(
                    label: 'Finish',
                    onPressed: () => submitted = true,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(find.text('Finish').hitTestable(), findsOneWidget);
    await t.tap(find.text('Finish'));
    expect(submitted, isTrue);
    expect(t.takeException(), isNull);
  });

  for (final backdrop in [false, true]) {
    for (final actualWidth in [390.0, 1280.0]) {
      testWidgets(
        'card width follows parent $actualWidth: backdrop=$backdrop',
        (t) async {
          t.view.physicalSize = Size(actualWidth, 800);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(platform: TargetPlatform.linux),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(size: Size(actualWidth == 390 ? 1280 : 390, 600)),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    final card = RaftDialog.card(
                      title: 'Review',
                      onClose: () {},
                      child: const SizedBox(height: 80),
                    );
                    return backdrop ? RaftModalBackdrop(child: card) : card;
                  },
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(
            t.getSize(find.byType(RaftDialogSurface)).width,
            actualWidth == 390 ? 358 : 448,
          );
          expect(t.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('framed card keeps its scrollport above the keyboard', (t) async {
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(t.view.reset);
    addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
    var submitted = false;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(platform: TargetPlatform.linux),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showRaftForm<void>(
                context,
                builder: (_) => RaftDialog.card(
                  title: 'Review changes',
                  onClose: () {},
                  child: const SizedBox(height: 700),
                  footer: RaftButton(
                    label: 'Finish',
                    onPressed: () => submitted = true,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Finish'));
    await t.pumpAndSettle();
    expect(find.text('Finish').hitTestable(), findsOneWidget);
    expect(t.getRect(find.text('Finish')).bottom, lessThanOrEqualTo(500));
    await t.tap(find.text('Finish'));
    expect(submitted, isTrue);
    expect(t.takeException(), isNull);
  });
}
