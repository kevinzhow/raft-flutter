import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/history_capacity.dart';
import 'package:raft_flutter/features/message_history_settings.dart';
import 'package:raft_ui/raft_ui.dart';

const account = HistoryAccount('https://history.invalid', 'alice');

class _Capacity implements HistoryCapacity {
  @override
  Future<void> opened(
    HistoryAccount account,
    String server,
    String channel,
  ) async {}
  int budget = 1 << 30;
  bool kept = false, full = false, pending = false, fail = false;
  int cleanups = 0;
  bool fullAllowed = false;
  HistoryCompactionPlan plan = const HistoryCompactionPlan(fullVacuum: false);
  Completer<void>? gate;
  @override
  Future<HistoryDiskUsage> usage(HistoryAccount account) async {
    await gate?.future;
    if (fail) throw StateError('synthetic');
    return HistoryDiskUsage(
      budget: budget,
      accountBytes: 80 << 20,
      databaseBytes: 100 << 20,
      walBytes: 2 << 20,
      indexBytes: 2 << 20,
      freeBytes: 0,
      rows: 1000,
      pendingCompaction: pending,
      protectedFull: full,
    );
  }

  @override
  Future<void> setBudget(HistoryAccount account, int bytes) async {
    if (fail) throw StateError('synthetic');
    budget = bytes;
  }

  @override
  Future<bool> isKept(
    HistoryAccount account,
    String server,
    String channel,
  ) async => kept;
  @override
  Future<void> keep(
    HistoryAccount account,
    String server,
    String channel,
    bool value,
  ) async => kept = value;
  @override
  Future<HistoryDiskUsage> maintain(
    HistoryAccount account, {
    bool compact = false,
    bool allowFullVacuum = false,
  }) async {
    if (fail) throw StateError('synthetic');
    if (compact) {
      cleanups++;
      fullAllowed = allowFullVacuum;
    }
    pending = false;
    return usage(account);
  }

  @override
  Future<HistoryCompactionPlan> compactionPlan(HistoryAccount account) async =>
      plan;

  @override
  void protect(
    Object owner,
    Iterable<HistoryProtectedRows> Function() current,
  ) {}
  @override
  void release(Object owner) {}
}

Future<void> _pump(
  WidgetTester t,
  _Capacity cap, {
  bool dark = false,
  double scale = 1,
  Locale locale = const Locale('en'),
}) async {
  t.view.physicalSize = const Size(360, 1500);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark),
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(RaftSpace.x4),
              child: MessageHistorySettings(capacity: cap, account: account),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'automatic history exposes only capacity in ${dark ? 'dark' : 'light'}, including reopen',
      (t) async {
        addTearDown(() async {
          await t.pumpWidget(const SizedBox.shrink());
          await t.pumpAndSettle();
        });
        final cap = _Capacity()
          ..full = true
          ..pending = true;
        for (var visit = 0; visit < 2; visit++) {
          await _pump(t, cap, dark: dark, scale: 3.1);
          await t.pumpAndSettle();
          expect(find.byKey(const Key('history-budget')), findsOneWidget);
          for (final action in ['keep', 'refresh', 'clean', 'measure']) {
            expect(find.byKey(Key('history-$action')), findsNothing);
          }
          expect(find.textContaining('stop keeping'), findsNothing);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
          await t.pumpAndSettle();
        }
      },
    );
  }
}
