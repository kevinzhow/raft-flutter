import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  const contentKey = Key('fold-dialog-content');
  const size = Size(951, 669);
  const vertical = Rect.fromLTWH(455, 0, 40, 669);
  const horizontal = Rect.fromLTWH(0, 315, 951, 40);

  Future<void> open(
    WidgetTester tester, {
    Rect? fold,
    bool dismissible = true,
    bool modal = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: false),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            displayFeatures: [
              if (fold != null)
                DisplayFeature(
                  bounds: fold,
                  type: DisplayFeatureType.fold,
                  state: DisplayFeatureState.postureHalfOpened,
                ),
            ],
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => GestureDetector(
            onTap: () => Navigator.of(context).push(
              RaftDialogRoute<void>(
                capturedThemes: InheritedTheme.capture(
                  from: context,
                  to: Navigator.of(context).context,
                ),
                dismissible: dismissible,
                modal: modal,
                builder: (_) => const Center(
                  child: SizedBox(key: contentKey, width: 100, height: 100),
                ),
              ),
            ),
            child: const SizedBox.expand(child: Text('Open')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  for (final fold in [vertical, horizontal]) {
    testWidgets('normal dialog avoids $fold', (tester) async {
      await open(tester, fold: fold);
      final bounds = tester.getRect(find.byKey(contentKey));
      expect(bounds.overlaps(fold), isFalse);
      expect(
        fold == vertical
            ? bounds.right <= fold.left
            : bounds.bottom <= fold.top,
        isTrue,
      );
    });
  }
  for (final fold in [vertical, horizontal]) {
    for (final dismissible in [true, false]) {
      for (final point in [const Offset(10, 10), const Offset(900, 600)]) {
        testWidgets('scrim $point fold=$fold dismissible=$dismissible', (
          tester,
        ) async {
          await open(tester, fold: fold, dismissible: dismissible);
          await tester.tapAt(point);
          await tester.pumpAndSettle();
          expect(
            find.byKey(contentKey),
            dismissible ? findsNothing : findsOneWidget,
          );
        });
      }
    }
  }
  testWidgets('no fold retains full viewport layout', (tester) async {
    await open(tester);
    expect(tester.getCenter(find.byKey(contentKey)), size.center(Offset.zero));
  });
  testWidgets('modal composition retains full viewport across a fold', (
    tester,
  ) async {
    await open(tester, fold: vertical, modal: true);
    expect(tester.getCenter(find.byKey(contentKey)), size.center(Offset.zero));
    expect(find.byType(DisplayFeatureSubScreen), findsNothing);
  });
}
