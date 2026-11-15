import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/root_error_boundary.dart';

import 'flutter_test_config.dart' show leakDebt;

/// The tree from flutter/flutter#192724 (issue #195316), unchanged: a page
/// whose semantics change while a BlockSemantics barrier covers it.
class _BlockedPage {
  final blocked = ValueNotifier<bool>(false);
  final outerLabel = ValueNotifier<String>('outer');
  final offset = ValueNotifier<double>(0.0);
  final middleLabel = ValueNotifier<String>('middle');
  final innerLabel = ValueNotifier<String>('inner');

  /// The modal's own label, outside the blocked branch.
  final dialogLabel = ValueNotifier<String>('dialog');

  void dispose() {
    for (final notifier in <ChangeNotifier>[
      blocked,
      outerLabel,
      offset,
      middleLabel,
      innerLabel,
      dialogLabel,
    ]) {
      notifier.dispose();
    }
  }

  Widget build() => Directionality(
    textDirection: TextDirection.ltr,
    child: ValueListenableBuilder<bool>(
      valueListenable: blocked,
      builder: (context, isBlocked, page) => Stack(
        children: [
          page!,
          if (isBlocked)
            BlockSemantics(
              child: ValueListenableBuilder<String>(
                valueListenable: dialogLabel,
                builder: (context, label, _) => Semantics(
                  container: true,
                  label: label,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
        ],
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 200,
          height: 200,
          // "outer" is a semantics boundary and a relayout boundary.
          child: ValueListenableBuilder<String>(
            valueListenable: outerLabel,
            builder: (context, label, child) => Semantics(
              container: true,
              explicitChildNodes: true,
              label: label,
              child: child,
            ),
            // The transform does not contribute to the semantics tree, so
            // changing it clears the geometry of "middle".
            child: ValueListenableBuilder<double>(
              valueListenable: offset,
              builder: (context, dx, child) =>
                  Transform.translate(offset: Offset(dx, 0), child: child),
              child: Align(
                alignment: Alignment.topLeft,
                // "middle" forms a semantics node but is not a boundary.
                child: ValueListenableBuilder<String>(
                  valueListenable: middleLabel,
                  builder: (context, label, child) =>
                      Semantics(label: label, child: child),
                  // "inner" is a semantics boundary with an empty rect.
                  child: ValueListenableBuilder<String>(
                    valueListenable: innerLabel,
                    builder: (context, label, child) => Semantics(
                      container: true,
                      label: label,
                      child: const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// The barrier goes up, then two frames change the page beneath it; the
  /// second one makes flushSemantics read a stale ancestor geometry cache.
  Future<void> changeBeneathBarrier(WidgetTester tester) async {
    blocked.value = true;
    await tester.pump();
    offset.value = 1;
    middleLabel.value = 'middle 2';
    await tester.pump();
    outerLabel.value = 'outer 2';
    offset.value = 2;
    innerLabel.value = 'inner 2';
    dialogLabel.value = 'dialog 2';
    await tester.pump();
  }
}

void main() {
  // Leak debt (app root): see docs/development.md, Leak tracking.
  leakDebt(const ['RootErrors']);

  // Remove with the exemption in rootErrorIsFatal: this test turns red once
  // the pinned Flutter includes flutter/flutter#192724.
  testWidgets('pinned Flutter throws in flushSemantics beneath a barrier '
      '(flutter/flutter#195316)', (tester) async {
    final page = _BlockedPage();
    addTearDown(page.dispose);
    await tester.pumpWidget(page.build());

    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    try {
      await page.changeBeneathBarrier(tester);
    } finally {
      FlutterError.onError = previous;
    }

    expect(reported, hasLength(1));
    final details = reported.single;
    expect(details.exception, isA<TypeError>());
    expect(
      details.exception.toString(),
      contains('Null check operator used on a null value'),
    );
    final stack = details.stack.toString();
    expect(stack, contains('_RenderObjectSemantics.'));
    expect(stack, contains('PipelineOwner.flushSemantics'));
    expect(
      rootErrorIsFatal(
        details.exception,
        library: details.library,
        context: details.context?.toDescription(),
        stack: details.stack,
      ),
      isFalse,
    );
  });

  // testWidgets puts its own FlutterError.onError in place after setUp, so
  // the boundary is installed inside the test body to own the real path.
  testWidgets('release: the app survives the failed flush, the next frame '
      'rebuilds the semantics it dropped, and the barrier lifts cleanly', (
    tester,
  ) async {
    final page = _BlockedPage();
    addTearDown(page.dispose);
    final errors = RootErrors.instance..clear();
    addTearDown(errors.clear);
    final originalBuilder = ErrorWidget.builder;
    final logged = <String>[];
    final originalPrint = debugPrint;
    errors.install(release: true);
    debugPrint = (message, {wrapWidth}) => logged.add(message ?? '');
    try {
      await tester.pumpWidget(
        RootErrorBoundary(errors: errors, child: page.build()),
      );
      await page.changeBeneathBarrier(tester);
      expect(errors.current, isNull);
      // The failed flush stopped before the modal's own node: its new label
      // is not in the tree yet. The refresh has requested the next frame.
      expect(find.bySemanticsLabel('dialog 2'), findsNothing);
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pump();
      expect(find.bySemanticsLabel('dialog 2'), findsOneWidget);
      // One refresh, not a loop.
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    } finally {
      debugPrint = originalPrint;
      errors.uninstall();
      ErrorWidget.builder = originalBuilder;
    }

    // The failure is logged once, the app stays.
    expect(
      'Null check operator used on a null value'.allMatches(logged.join('\n')),
      hasLength(1),
    );
    expect(errors.current, isNull);
    expect(find.text('Something went wrong'), findsNothing);

    page.blocked.value = false;
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('outer 2'), findsOneWidget);
    expect(find.bySemanticsLabel('middle 2'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^(outer|middle|dialog.*)$')),
      findsNothing,
    );
  });

  test('only the null check in the semantics flush is survived', () {
    final flush = StackTrace.fromString(
      '#0 _RenderObjectSemantics._updateSemanticsNodeGeometry (package:flutter/src/rendering/object.dart:6413:53)\n'
      '#1 _RenderObjectSemantics._produceSemanticsNode (package:flutter/src/rendering/object.dart:6315:5)\n'
      '#2 _RenderObjectSemantics._buildSemantics (package:flutter/src/rendering/object.dart:6227:7)\n'
      '#3 _RenderObjectSemantics._buildSemanticsSubtree (package:flutter/src/rendering/object.dart:6263:13)\n'
      '#4 _RenderObjectSemantics.ensureSemanticsNode (package:flutter/src/rendering/object.dart:6201:7)\n'
      '#5 PipelineOwner.flushSemantics (package:flutter/src/rendering/object.dart:1636:18)\n'
      '#6 PipelineOwner.flushSemantics (package:flutter/src/rendering/object.dart:1653:15)\n'
      '#7 RendererBinding.drawFrame (package:flutter/src/rendering/binding.dart:635:25)',
    );
    Object nullCheck() {
      try {
        (null as Object?)!;
      } catch (error) {
        return error;
      }
      throw StateError('unreachable');
    }

    final error = nullCheck();
    expect(error, isA<TypeError>());
    expect(
      rootErrorIsFatal(error, library: 'scheduler library', stack: flush),
      isFalse,
    );
    // Another error from the same frames stays fatal.
    expect(
      rootErrorIsFatal(
        StateError('x'),
        library: 'scheduler library',
        stack: flush,
      ),
      isTrue,
    );
    // A null check elsewhere in rendering stays fatal.
    expect(
      rootErrorIsFatal(
        error,
        library: 'rendering library',
        stack: StackTrace.fromString(
          '#0 RenderBox.size (package:flutter/src/rendering/box.dart:2200:12)\n'
          '#1 PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1100:18)',
        ),
      ),
      isTrue,
    );
    // The flush frames below a throw from somewhere else (an app
    // describeSemanticsConfiguration) stay fatal.
    expect(
      rootErrorIsFatal(
        error,
        library: 'scheduler library',
        stack: StackTrace.fromString(
          '#0 _Row.describeSemanticsConfiguration (package:raft_flutter/features/x.dart:1:1)\n'
          '#1 _RenderObjectSemantics.ensureSemanticsNode (package:flutter/src/rendering/object.dart:6201:7)\n'
          '#2 PipelineOwner.flushSemantics (package:flutter/src/rendering/object.dart:1636:18)',
        ),
      ),
      isTrue,
    );
  });
}
