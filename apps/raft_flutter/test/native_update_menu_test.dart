import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/app_window.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_updater/raft_updater.dart';

const _window = MethodChannel('app.raft/window');
const _updater = MethodChannel('task183/updater');

Future<Object?> _request(WidgetTester t) async {
  final reply = Completer<Object?>();
  await t.binding.defaultBinaryMessenger.handlePlatformMessage(
    _window.name,
    const StandardMethodCodec().encodeMethodCall(
      const MethodCall('checkForUpdatesRequested'),
    ),
    (data) {
      try {
        reply.complete(
          data == null
              ? null
              : const StandardMethodCodec().decodeEnvelope(data),
        );
      } catch (error, stack) {
        reply.completeError(error, stack);
      }
    },
  );
  return reply.future;
}

void main() {
  for (final scenario in ['native', 'busy', 'fallback', 'retry']) {
    testWidgets('application update menu: $scenario', (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final navigator = GlobalKey<NavigatorState>();
      final states = <Map>[];
      final calls = <String>[];
      final urls = <Uri>[];
      final pending = Completer<bool>();
      var checks = 0;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(_window, (
        call,
      ) async {
        if (call.method == 'setWindowCommandsState') {
          states.add(call.arguments as Map);
        }
        return null;
      });
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(_updater, (
        call,
      ) async {
        calls.add(call.method);
        if (call.method == 'configure') {
          return {'available': scenario != 'fallback'};
        }
        if (call.method == 'checkForUpdates') {
          checks++;
          if (scenario == 'busy') return pending.future;
          return scenario != 'retry' || checks > 1;
        }
        return null;
      });
      final updater = AppUpdater(
        channel: _updater,
        config: const AppUpdaterConfig(enabled: true),
        platform: TargetPlatform.macOS,
        openUrl: (url) async {
          urls.add(url);
          return scenario != 'retry';
        },
      );
      try {
        await t.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            theme: raftTheme(),
            builder: (context, child) => AppWindowCommands(
              navigatorKey: navigator,
              updater: updater,
              child: child!,
            ),
            home: const Scaffold(body: Text('Signed out')),
          ),
        );
        await t.pump();
        expect(states.last['updates'], isTrue);
        expect(states.last['preferences'], isFalse);
        final response = _request(t);
        await t.pumpAndSettle();
        if (scenario == 'busy') {
          expect(states.last['updates'], isFalse);
          expect(await _request(t), isFalse);
          expect(checks, 1);
          pending.complete(true);
          await t.pumpAndSettle();
        }
        if (scenario == 'retry') {
          for (
            var frame = 0;
            frame < 60 && find.byType(RaftAlertDialog).evaluate().isEmpty;
            frame++
          ) {
            await t.pump(const Duration(milliseconds: 16));
          }
          expect(checks, 1, reason: 'calls=$calls; urls=$urls; states=$states');
          expect(
            t.widget<RaftAlertDialog>(find.byType(RaftAlertDialog)).title,
            "Couldn't check for updates",
          );
          expect(states.last['updates'], isFalse);
          await t.tap(
            find.byWidgetPredicate(
              (widget) => widget is RaftButton && widget.label == 'Try Again',
            ),
          );
          await t.pumpAndSettle();
          expect(checks, 2);
          expect(find.byType(RaftAlertDialog), findsNothing);
        }
        expect(await response, isTrue);
        expect(states.last['updates'], isTrue);
        expect(find.text('Signed out'), findsOneWidget);
        expect(calls.first, 'configure');
        if (scenario == 'fallback') {
          expect(checks, 0);
          expect(urls, [AppUpdater.releasePage]);
        } else if (scenario != 'retry') {
          expect(urls, isEmpty);
        }
      } finally {
        if (!pending.isCompleted) pending.complete(false);
        navigator.currentState?.popUntil((route) => route.isFirst);
        await t.pumpAndSettle();
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
        (updater.availability as ChangeNotifier).dispose();
        debugDefaultTargetPlatformOverride = null;
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _window,
          null,
        );
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _updater,
          null,
        );
      }
    });
  }
}
