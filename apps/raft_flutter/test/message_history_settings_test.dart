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
  bool kept = false, full = false, hard = false, pending = false, fail = false;
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
      hardFull: hard,
    );
  }

  @override
  Future<void> setBudget(HistoryAccount account, int bytes) async {
    if (fail) throw StateError('synthetic');
    if (bytes > budget) hard = false;
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
  testWidgets(
    'usage does not delay the first frame or block capacity choices',
    (t) async {
      final cap = _Capacity()..gate = Completer<void>();
      await _pump(t, cap);
      expect(
        t.widget<Text>(find.byKey(const Key('history-size'))).data,
        'Calculating…',
      );
      expect(
        t
            .widget<RaftSelectField<int>>(
              find.byKey(const Key('history-budget')),
            )
            .onChanged,
        isNotNull,
      );
      cap.gate!.complete();
      await t.pumpAndSettle();
      expect(find.text('Estimated message storage: 80.0 MB'), findsOneWidget);
      expect(
        find.text('Shared database and pending writes: 102.0 MB'),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'lower capacity confirms once; cancel and reopen keep the saved choice',
    (t) async {
      final cap = _Capacity();
      await _pump(t, cap);
      await t.pumpAndSettle();
      Future<void> lower() async {
        await t.ensureVisible(find.byKey(const Key('history-budget')));
        await t.tap(find.byKey(const Key('history-budget')));
        await t.pumpAndSettle();
        await t.tap(find.text('512 MiB').last);
        await t.pumpAndSettle();
      }

      await lower();
      expect(cap.budget, 1 << 30);
      await t.tap(find.text('Keep Limit'));
      await t.pumpAndSettle();
      expect(cap.budget, 1 << 30);
      await lower();
      await t.tap(find.byKey(const Key('history-lower-confirm')));
      await t.pumpAndSettle();
      expect(cap.budget, 512 << 20);
      expect(find.byKey(const Key('history-lower-dialog')), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
      await _pump(t, cap);
      await t.pumpAndSettle();
      expect(
        t
            .widget<RaftSelectField<int>>(
              find.byKey(const Key('history-budget')),
            )
            .value,
        512 << 20,
      );
      expect(find.byKey(const Key('history-lower-dialog')), findsNothing);
      expect(cap.cleanups, 0);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'failed meter is advisory and a reopen automatically measures again in Chinese',
    (t) async {
      final cap = _Capacity()..fail = true;
      await _pump(t, cap, locale: const Locale('zh', 'CN'));
      await t.pumpAndSettle();
      expect(find.text('暂时无法估算存储占用'), findsOneWidget);
      expect(find.text('重新计算'), findsNothing);
      expect(
        t
            .widget<RaftSelectField<int>>(
              find.byKey(const Key('history-budget')),
            )
            .onChanged,
        isNotNull,
      );
      await t.pumpWidget(const SizedBox.shrink());
      cap.fail = false;
      await _pump(t, cap, locale: const Locale('zh', 'CN'));
      await t.pumpAndSettle();
      expect(find.text('消息占用估算：80.0 MB'), findsOneWidget);
      expect(find.text('暂时无法估算存储占用'), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'hard capacity status clears after increasing capacity and stays clear on reopen',
    (t) async {
      final cap = _Capacity()..hard = true;
      await _pump(t, cap);
      await t.pumpAndSettle();
      expect(
        find.textContaining('New messages are not being saved offline'),
        findsOneWidget,
      );
      await t.ensureVisible(find.byKey(const Key('history-budget')));
      await t.tap(find.byKey(const Key('history-budget')));
      await t.pumpAndSettle();
      await t.tap(find.text('2 GiB').last);
      await t.pumpAndSettle();
      expect(cap.budget, 2 << 30);
      expect(
        find.textContaining('New messages are not being saved offline'),
        findsNothing,
      );
      await t.pumpWidget(const SizedBox.shrink());
      await _pump(t, cap);
      await t.pumpAndSettle();
      expect(
        find.textContaining('New messages are not being saved offline'),
        findsNothing,
      );
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('retired measurement cannot publish into the new account scope', (
    t,
  ) async {
    final first = _Capacity()..gate = Completer<void>();
    await _pump(t, first);
    final next = _Capacity()..budget = 5 << 30;
    await _pump(t, next);
    await t.pumpAndSettle();
    first.gate!.complete();
    await t.pumpAndSettle();
    expect(
      t
          .widget<RaftSelectField<int>>(find.byKey(const Key('history-budget')))
          .value,
      5 << 30,
    );
    await t.pumpWidget(const SizedBox.shrink());
  });
}
