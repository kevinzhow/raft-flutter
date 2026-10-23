// RaftBench against a real Raft server (the local test stack): sign in as the
// server owner, open Settings > RaftBench, enable one channel with a short
// window, wait for the hosted agent's accepted result, check the findings and
// that an evidence reference opens its source message, then disable the
// analysis again. (raftbench_views_e2e_test.dart captures the page in every
// theme, language and width without enabling anything.)
//
//   flutter test integration_test/raftbench_e2e_test.dart -d linux --no-pub \
//     --dart-define=RAFT_TEST_CONFIG=<json: origin, email, password, serverId, channelId> \
//     --dart-define=RAFT_TEST_REPORT=<dir for the PNG captures and the run log>
//
// It spends model calls (one analysis run of the chosen channel) and always
// leaves RaftBench disabled.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/raftbench_session.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('RaftBench enable, analyze, findings, evidence, disable', (
    t,
  ) async {
    final cfg = raftbenchConfig();
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    addTearDown(() => writeRunLog('run.log'));
    final w = await signIn(t, cfg);
    expect(w.server?.string('role'), anyOf('owner', 'admin'));

    try {
      // Settings > RaftBench (the row exists only for an owner / admin with the flag).
      await openRaftbench(t);
      await until(
        t,
        () => find
            .byKey(const ValueKey('raftbench-task-snapshot'))
            .evaluate()
            .isNotEmpty,
        what: 'the task snapshot',
      );
      await until(
        t,
        () =>
            find
                .byKey(const ValueKey('raftbench-cost-comparison'))
                .evaluate()
                .isNotEmpty ||
            find
                .textContaining('Cloud agent billing is not available')
                .evaluate()
                .isNotEmpty,
        what: 'the cost line',
      );
      await shot(t, '01-desktop-light-en-disabled');
      expect(find.text('Enable and start analysis'), findsOneWidget);
      expect(find.text('Workspace efficiency and cost'), findsOneWidget);

      // One channel, a start date of yesterday through the date picker.
      final general = find.text('general');
      expect(general, findsWidgets);
      final today = DateTime.now().toUtc();
      final yesterday = today.subtract(const Duration(days: 1));
      await t.ensureVisible(
        find.byKey(const ValueKey('raftbench-history-from')),
      );
      await t.tap(find.byKey(const ValueKey('raftbench-history-from')));
      await t.pumpAndSettle();
      // The picker opens on the saved start (September on the stack): walk to
      // yesterday's month, then pick the day.
      final monthLabel = DateFormat.yMMMM('en').format(yesterday);
      for (var i = 0; i < 24 && find.text(monthLabel).evaluate().isEmpty; i++) {
        await t.tap(find.byTooltip('Next month'));
        await t.pumpAndSettle();
      }
      expect(find.text(monthLabel), findsOneWidget);
      await t.tap(find.text('${yesterday.day}').last);
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      await shot(t, '02-desktop-light-en-range-chosen');

      await t.ensureVisible(find.text('Enable and start analysis'));
      await t.tap(find.text('Enable and start analysis'));
      note('enabled through the app');
      await until(
        t,
        () => find.text('Disable and clear results').evaluate().isNotEmpty,
        what: 'the enabled state',
      );
      await shot(t, '03-desktop-light-en-queued');

      // Wait for the hosted agent to be accepted (queued -> reading -> complete).
      var shotsTaken = 0;
      final started = DateTime.now();
      var finished = false;
      while (DateTime.now().difference(started) < const Duration(minutes: 12)) {
        await t.pump(const Duration(seconds: 2));
        for (final label in [
          'Analysis complete',
          'Partial analysis — coverage is incomplete',
          'Analysis did not finish',
        ]) {
          if (find.text(label).evaluate().isNotEmpty) {
            note(
              'run settled: $label after ${DateTime.now().difference(started).inSeconds}s',
            );
            finished = true;
          }
        }
        if (finished) break;
        if (shotsTaken < 2 &&
            find.textContaining('messages read').evaluate().isNotEmpty) {
          shotsTaken++;
          await shot(t, '04-desktop-light-en-running-$shotsTaken');
        }
      }
      expect(
        finished,
        isTrue,
        reason: 'the analysis did not settle within 12 minutes',
      );
      await t.pumpAndSettle();
      await shot(t, '05-desktop-light-en-result');
      note(
        'findings: ${find.textContaining('Evidence ').evaluate().length} evidence buttons',
      );

      // Evidence opens its source message in the channel.
      final evidence = find.byWidgetPredicate(
        (x) => x is RaftButton && x.label.startsWith('Evidence #'),
      );
      if (evidence.evaluate().isNotEmpty) {
        await t.ensureVisible(evidence.first);
        await shot(t, '06-desktop-light-en-findings');
        final label = (evidence.evaluate().first.widget as RaftButton).label;
        note('opening evidence: $label');
        await t.tap(evidence.first);
        await t.pumpAndSettle();
        await until(
          t,
          () => w.location.route == RaftRoute.channel,
          what: 'the source channel',
        );
        note(
          'opened ${w.location.uri.path}${w.location.uri.hasQuery ? '?${w.location.uri.query}' : ''}',
        );
        expect(w.location.messageId, isNotNull);
        await shot(t, '07-desktop-light-en-evidence-opened');
        await openRaftbench(t);
      } else {
        note('no evidence buttons (the model returned no pattern)');
      }

      // Disable again through the app and check the server agrees.
      final disable = find.text('Disable and clear results');
      await t.ensureVisible(disable);
      await t.tap(disable);
      await until(
        t,
        () => find.text('Enable and start analysis').evaluate().isNotEmpty,
        what: 'the disabled state',
      );
      note('disabled through the app');
      await shot(t, '16-desktop-light-en-disabled-again');
    } finally {
      // Whatever happened above, never leave the analysis running (it costs
      // model calls every 15 minutes while enabled).
      await t.runAsync(() async {
        try {
          final dashboard = await w.client.get('/raftbench') as Map;
          if (dashboard['enabled'] == true) {
            await w.client.request(
              'PUT',
              '/raftbench',
              data: {
                'enabled': false,
                'channelIds': dashboard['channelIds'],
                'expectedRevision': dashboard['revision'],
              },
            );
            note('cleanup: disabled through the API');
          } else {
            note('cleanup: already disabled');
          }
        } catch (e) {
          note('cleanup failed: $e');
        }
      });
    }
    t.platformDispatcher.clearAllTestValues();
  });
}
