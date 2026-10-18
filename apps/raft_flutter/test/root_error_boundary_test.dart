import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/root_error_boundary.dart';
import 'package:raft_ui/raft_ui.dart';
import 'flutter_test_config.dart' show leakDebt;

class _Bomb extends StatelessWidget {
  const _Bomb();
  @override
  Widget build(BuildContext context) => throw StateError('channel header broke');
}

int _builds = 0;

// The tail of the Android release report (v0.1.0+24).
final _selectionSortStack = StackTrace.fromString(
  '#0 RenderObject.constraints (package:flutter/src/rendering/object.dart:2596)\n'
  '#2 RenderParagraph.getBoxesForSelection (package:flutter/src/rendering/paragraph.dart:1135)\n'
  '#4 _SelectableTextContainerDelegate._compareScreenOrder (package:flutter/src/widgets/text.dart:1229)\n'
  '#9 MultiSelectableSelectionContainerDelegate._flushAdditions (package:flutter/src/widgets/selectable_region.dart:2476)\n'
  '#12 SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430)',
);

class _Counter extends StatelessWidget {
  const _Counter();
  @override
  Widget build(BuildContext context) {
    _builds++;
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: Text('app'),
    );
  }
}

void main() {
  // Leak debt (app root): see docs/development.md, Leak tracking.
  leakDebt(const ['RootErrors']);
  test('which errors end the app on the fallback', () {
    expect(rootErrorIsFatal(StateError('x')), isTrue);
    expect(rootErrorIsFatal(StateError('x'), library: 'widgets library'), isTrue);
    expect(rootErrorIsFatal(const RaftApiException('offline')), isFalse);
    expect(rootErrorIsFatal(const SocketException('lost')), isFalse);
    expect(rootErrorIsFatal(TimeoutException('slow')), isFalse);
    expect(
      rootErrorIsFatal(StateError('x'), library: 'image resource service'),
      isFalse,
    );
    expect(
      rootErrorIsFatal(
        StateError('x'),
        library: 'widgets library',
        context: 'while handling a gesture',
      ),
      isFalse,
    );
  });

  group('release path', () {
    late RootErrors errors;
    final originalBuilder = ErrorWidget.builder;
    final originalOnError = FlutterError.onError;

    setUp(() {
      errors = RootErrors.instance..clear();
      errors.install(release: true);
      _builds = 0;
    });
    tearDown(() {
      errors.uninstall();
      errors.clear();
      ErrorWidget.builder = originalBuilder;
      FlutterError.onError = originalOnError;
    });

    testWidgets('a build error replaces the app with the fallback and reload remounts it', (
      tester,
    ) async {
      var broken = true;
      await tester.pumpWidget(
        RootErrorBoundary(
          errors: errors,
          child: Builder(
            builder: (_) => broken ? const _Bomb() : const _Counter(),
          ),
        ),
      );
      // The framework reports the build error; the boundary swaps in the page.
      tester.takeException();
      await tester.pump();
      await tester.pump();
      expect(find.text('Something went wrong'), findsOneWidget);
      // The raw exception is not printed on the page: it sits in the closed
      // "Stack trace" disclosure.
      expect(find.textContaining('channel header broke'), findsNothing);
      expect(find.byKey(const ValueKey('root-error-message')), findsNothing);
      expect(find.text('Reload app'), findsOneWidget);
      expect(find.byType(_Bomb), findsNothing);

      broken = false;
      await tester.tap(find.text('Reload app'));
      await tester.pump();
      expect(find.text('Something went wrong'), findsNothing);
      expect(find.text('app'), findsOneWidget);
      expect(_builds, greaterThan(0));
    });

    testWidgets('an uncaught async error shows the fallback, a network error does not', (
      tester,
    ) async {
      await tester.pumpWidget(
        RootErrorBoundary(errors: errors, child: const _Counter()),
      );
      final handler = tester.binding.platformDispatcher.onError!;
      handler(const RaftApiException('offline'), StackTrace.current);
      await tester.pump();
      expect(find.text('app'), findsOneWidget);
      expect(errors.current, isNull);

      handler(StateError('lost state'), StackTrace.current);
      await tester.pump();
      await tester.pump();
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(errors.current?.message, contains('lost state'));
    });

    // Pages built beneath an opaque route are not laid out, yet their
    // Text.rich-with-WidgetSpan paragraphs register selectables; Flutter's
    // post-frame sort then throws on the unlaid paragraph (Android release,
    // reported from a scheduler callback). Only selection on that page is
    // affected, so the app keeps running.
    testWidgets('a selection sort on unlaid text does not end the app', (
      tester,
    ) async {
      await tester.pumpWidget(
        RootErrorBoundary(errors: errors, child: const _Counter()),
      );
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError(
            'A RenderObject does not have any constraints before it has been '
            'laid out.',
          ),
          stack: _selectionSortStack,
          library: 'scheduler library',
          context: ErrorDescription('during a scheduler callback'),
        ),
      );
      tester.binding.platformDispatcher.onError!(
        StateError('unlaid'),
        _selectionSortStack,
      );
      // The report is still logged.
      expect(tester.takeException(), isA<StateError>());
      await tester.pump();
      await tester.pump();
      expect(errors.current, isNull);
      expect(find.text('app'), findsOneWidget);
    });

    test('only the selection sort failure is survived', () {
      final sort = _selectionSortStack;
      expect(
        rootErrorIsFatal(
          StateError('A RenderObject does not have any constraints'),
          library: 'scheduler library',
          stack: sort,
        ),
        isFalse,
      );
      expect(
        rootErrorIsFatal(
          StateError('x'),
          library: 'scheduler library',
          stack: StackTrace.fromString(
            '#0 Other.thing (package:raft_flutter/features/x.dart:1)',
          ),
        ),
        isTrue,
      );
    });

    testWidgets('the first error stays on screen', (tester) async {
      await tester.pumpWidget(
        RootErrorBoundary(errors: errors, child: const _Counter()),
      );
      final handler = tester.binding.platformDispatcher.onError!;
      handler(StateError('first'), StackTrace.current);
      handler(StateError('second'), StackTrace.current);
      await tester.pump();
      await tester.pump();
      expect(errors.current?.message, contains('first'));
    });

    testWidgets('the fallback shows Chinese for a Chinese device', (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('zh', 'CN');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      errors.report(StateError('boom'), null);
      await tester.pumpWidget(
        RootErrorBoundary(errors: errors, child: const _Counter()),
      );
      await tester.pump();
      expect(find.text('出了点问题'), findsOneWidget);
      expect(find.text('重新加载应用'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      await tester.tap(find.text('错误堆栈'));
      await tester.pump();
      expect(find.textContaining('boom'), findsOneWidget);
    });
  });

  test('debug and profile builds keep the framework handlers', () {
    final before = FlutterError.onError, builder = ErrorWidget.builder;
    final errors = RootErrors.instance;
    errors.install(release: false);
    expect(errors.installed, isFalse);
    expect(identical(FlutterError.onError, before), isTrue);
    expect(identical(ErrorWidget.builder, builder), isTrue);
  });

  testWidgets('the fallback page lists the error, disclosures and reload', (
    tester,
  ) async {
    var reloaded = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: RaftRootErrorFallback(
            message: 'Cannot read properties',
            stack: 'TypeError: x\n  at a',
            componentStack: '\n  at ChannelHeader',
            onReload: () => reloaded++,
          ),
        ),
      ),
    );
    expect(find.text('Cannot read properties'), findsOneWidget);
    expect(find.text('Stack trace'), findsOneWidget);
    // Component stack opens by default, stack trace starts closed.
    expect(find.textContaining('at ChannelHeader'), findsOneWidget);
    expect(find.textContaining('TypeError: x'), findsNothing);
    await tester.tap(find.text('Stack trace'));
    await tester.pump();
    expect(find.textContaining('TypeError: x'), findsOneWidget);
    await tester.tap(find.text('Reload app'));
    expect(reloaded, 1);
  });
}
