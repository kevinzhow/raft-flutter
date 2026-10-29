import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/local_error_diagnostics.dart';
import 'package:raft_flutter/features/local_error_diagnostics.dart';
import 'package:raft_flutter/features/storage_settings.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';
import 'package:raft_ui/raft_ui.dart';

final _trace = StackTrace.fromString(
  '#0 write (package:raft_flutter/data/workspace_device_store.dart:211:5)\n'
  '#1 privateName (/private/user/secret.dart:12:5)\n'
  '#2 execute (package:drift/src/runtime/executor/helpers/engines.dart:92:9)',
);

LocalErrorSample _record(LocalErrorDiagnostics log, [Object? error]) =>
    log.record(
      error ?? StateError('private payload'),
      _trace,
      operation: LocalErrorOperation.resumeCursor,
      notice: LocalErrorNotice.saveFailed,
    );

void main() {
  testWidgets(
    'storage settings always offers diagnostic copy without an error',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(child: StorageSettingsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Local error diagnostics'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
    },
  );

  test(
    'captures SQLite codes across the real background database isolate',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'raft-diagnostic-isolate-',
      );
      final db = DriftWorkspaceCache(
        NativeDatabase.createInBackground(File('${dir.path}/history.sqlite')),
      );
      try {
        Object? error;
        StackTrace? stack;
        try {
          await db.customSelect('SELECT * FROM private_missing_table').get();
        } catch (cause, trace) {
          error = cause;
          stack = trace;
        }
        expect(error, isNotNull);
        final log = LocalErrorDiagnostics();
        log.record(
          error!,
          stack!,
          operation: LocalErrorOperation.resumeCursor,
          notice: LocalErrorNotice.saveFailed,
        );
        final sample = log.samples.single.fields;
        expect(sample['sqliteResultCode'], 1);
        expect(sample['sqliteExtendedCode'], 1);
        expect(sample['type'], 'SqliteException');
        expect(log.export(), isNot(contains('private_missing_table')));
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );

  testWidgets('service host captures actual binding lifecycle transitions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AppServicesHost(
        services: AppServices.updatesDisabledForTestOrPreview(),
        child: SizedBox(),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final sample = _record(LocalErrorDiagnostics.shared);
    final states = (sample.fields['lifecycle'] as List).map((e) => e['state']);
    expect(states, contains('paused'));
    expect(states.last, 'resumed');
    expect(LocalErrorDiagnostics.shared.platform, isNot('unknown'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a delayed clipboard completion preserves a newer error', (
    tester,
  ) async {
    final clipboard = Completer<void>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) => call.method == 'Clipboard.setData'
          ? clipboard.future
          : Future.value(),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final log = LocalErrorDiagnostics();
    _record(log);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        builder: (context, child) => RaftToastHost(child: child!),
        home: Builder(
          builder: (held) {
            context = held;
            return Scaffold(
              body: TextButton(
                onPressed: () => copyLocalErrorDiagnostics(held, log: log),
                child: const Text('Copy'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Copy'));
    await tester.pump();
    showRaftToast(context, 'A newer error');
    clipboard.complete();
    await tester.pumpAndSettle();
    expect(find.text('A newer error'), findsOneWidget);
    expect(find.text('Diagnostics copied'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  test(
    'copies numeric SQLite codes and source frames, never raw error data',
    () {
      final log = LocalErrorDiagnostics()..platform = 'android';
      log.lifecycle('paused');
      log.lifecycle('resumed');
      _record(
        log,
        SqliteException(
          extendedResultCode: 1032,
          message: 'secret-message https://private.invalid?token=secret-token',
          causingStatement: 'INSERT secret-sql',
          parametersToStatement: ['secret-argument'],
        ),
      );
      final text = log.export();
      final json = jsonDecode(text) as Map;
      final sample = (json['samples'] as List).single as Map;
      expect(sample['sqliteResultCode'], 8);
      expect(sample['sqliteExtendedCode'], 1032);
      expect(sample['operation'], 'resumeCursor');
      expect(sample['frames'], hasLength(2));
      expect((sample['lifecycle'] as List).last['state'], 'resumed');
      for (final private in [
        'secret-message',
        'private.invalid',
        'secret-token',
        'secret-sql',
        'secret-argument',
        '/private/user',
        'privateName',
      ]) {
        expect(text, isNot(contains(private)));
      }
    },
  );

  test(
    'coalesces repeated failures and bounds samples and lifecycle history',
    () {
      var time = DateTime.utc(2026, 10, 19);
      final log = LocalErrorDiagnostics(capacity: 2, clock: () => time);
      final first = _record(log);
      time = time.add(const Duration(seconds: 4));
      expect(_record(log), same(first));
      expect(log.samples, hasLength(1));
      expect(first.fields['count'], 2);
      expect(first.fields['lastAt'], time.toIso8601String());
      for (var i = 0; i < 12; i++) {
        log.lifecycle(i.isEven ? 'paused' : 'resumed');
      }
      _record(log);
      _record(log, const FormatException('secret-json'));
      expect(log.samples, hasLength(2));
      expect(log.samples, isNot(contains(first)));
      expect(log.samples.last.fields['lifecycle'], hasLength(8));
      // A toast holds its own sample even after later failures evict it.
      expect(
        (jsonDecode(log.export(sample: first))['samples'] as List).single['id'],
        first.fields['id'],
      );
      expect(log.forNotice('Unrelated network error'), isNull);
      expect(LocalErrorDiagnostics().samples, isEmpty);
    },
  );

  testWidgets(
    'storage copy retries, reopening keeps samples, a fresh run still copies metadata',
    (tester) async {
      final log = LocalErrorDiagnostics();
      _record(log);
      var fail = true;
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            if (fail) throw PlatformException(code: 'clipboard-unavailable');
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      var page = 0;
      Widget app(LocalErrorDiagnostics current) => MaterialApp(
        theme: raftTheme(),
        builder: (context, child) => RaftToastHost(child: child!),
        home: Scaffold(
          body: LocalErrorDiagnosticsCard(key: ValueKey(page++), log: current),
        ),
      );
      await tester.pumpWidget(app(log));
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(clipboard, isNull);
      expect(
        find.text('Could not copy diagnostics. Try again.'),
        findsOneWidget,
      );
      fail = false;
      await tester.tap(
        find.descendant(
          of: find.byType(RaftToast),
          matching: find.text('Copy'),
        ),
      );
      await tester.pumpAndSettle();
      expect(clipboard, contains('resumeCursor'));
      expect(find.text('Could not copy diagnostics. Try again.'), findsNothing);
      expect(find.text('Diagnostics copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Diagnostics copied'), findsNothing);
      await tester.pumpWidget(app(log));
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsOneWidget);
      final fresh = LocalErrorDiagnostics()..lifecycle('resumed');
      await tester.pumpWidget(app(fresh));
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Local error diagnostics'), findsOneWidget);
      expect(find.textContaining('Copy app version'), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      final copied = jsonDecode(clipboard!) as Map;
      expect(copied['samples'], isEmpty);
      expect((copied['lifecycle'] as List).single['state'], 'resumed');
      expect(find.text('Diagnostics copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    },
  );
}
