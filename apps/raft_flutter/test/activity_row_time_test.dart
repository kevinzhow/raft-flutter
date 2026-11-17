import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/features/activity_inbox_row.dart';
import 'package:raft_flutter/features/activity_row_time.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/activity_row_harness.dart';

// Web v1.24 `formatRowTime` / `rowTimeKey` (C41): "now", "3m", "2h" at rest
// while the row is from today; an older row shows its clock on hover only; the
// time in words is the tooltip and part of the row's name.
const _copy = RowTimeCopy(
  now: 'now',
  minutes: _m,
  hours: _h,
  minutesAgo: _mAgo,
  hoursAgo: _hAgo,
  yesterdayAt: _yesterday,
  dayAt: _dayAt,
);
String _m(int n) => '${n}m';
String _h(int n) => '${n}h';
String _mAgo(int n) => n == 1 ? '1 minute ago' : '$n minutes ago';
String _hAgo(int n) => n == 1 ? '1 hour ago' : '$n hours ago';
String _yesterday(String time) => 'yesterday at $time';
String _dayAt(String day, String time) => '$day at $time';

SourceTimeFormatter _fmt({bool twentyFour = false}) => SourceTimeFormatter(
  locale: 'en',
  preferredTimeFormat: twentyFour
      ? SourceTimeFormat.twentyFourHour
      : SourceTimeFormat.twelveHour,
);

RowTime? _at(DateTime at, {DateTime? now, bool twentyFour = false}) =>
    formatRowTime(
      at,
      now: now ?? fixedNow,
      formatter: _fmt(twentyFour: twentyFour),
      copy: _copy,
    );

void main() {
  group('row time rule', () {
    test('under a minute is now, never hidden', () {
      final t = _at(fixedNow.subtract(const Duration(seconds: 30)))!;
      expect((t.shown, t.older, t.words), ('now', false, 'now'));
    });
    test('a time a little ahead of the clock reads as now', () {
      final t = _at(fixedNow.add(const Duration(minutes: 2)))!;
      expect((t.shown, t.older), ('now', false));
    });
    test('whole minutes under an hour, on any day', () {
      var t = _at(fixedNow.subtract(const Duration(minutes: 1)))!;
      expect((t.shown, t.words, t.older), ('1m', '1 minute ago', false));
      t = _at(fixedNow.subtract(const Duration(minutes: 59, seconds: 59)))!;
      expect((t.shown, t.words), ('59m', '59 minutes ago'));
      // 00:20, 40 minutes after yesterday's 23:40: still minutes, not older.
      t = _at(
        DateTime(2026, 11, 16, 23, 40),
        now: DateTime(2026, 11, 17, 0, 20),
      )!;
      expect((t.shown, t.older), ('40m', false));
    });
    test('whole hours while it is still today (1h 59m is 1h)', () {
      var t = _at(fixedNow.subtract(const Duration(hours: 1, minutes: 59)))!;
      expect((t.shown, t.words, t.older), ('1h', '1 hour ago', false));
      t = _at(DateTime(2026, 11, 17, 7, 5))!;
      expect((t.shown, t.words), ('8h', '8 hours ago'));
    });
    test('another calendar day shows the clock, on hover only', () {
      var t = _at(DateTime(2026, 11, 16, 17, 20))!;
      expect((t.shown, t.older), ('5:20 PM', true));
      expect(t.words, 'yesterday at 5:20 PM');
      t = _at(DateTime(2026, 11, 16, 17, 20), twentyFour: true)!;
      expect(t.shown, '17:20');
      expect(t.words, 'yesterday at 17:20');
      // The rule is the calendar day, not 24 hours: 15:31 yesterday is older.
      t = _at(DateTime(2026, 11, 16, 15, 31))!;
      expect(t.older, isTrue);
    });
    test('words: weekday within a week, then the long day', () {
      expect(_at(DateTime(2026, 11, 14, 9, 5))!.words, 'Saturday at 9:05 AM');
      expect(_at(DateTime(2026, 11, 7, 9, 5))!.words, 'November 7 at 9:05 AM');
      expect(
        _at(DateTime(2025, 12, 3, 9, 5))!.words,
        'December 3, 2025 at 9:05 AM',
      );
      expect(
        _at(DateTime(2026, 11, 14, 9, 5), twentyFour: true)!.shown,
        '9:05',
      );
    });
    test('not a time reads as none', () {
      expect(
        formatRowTime('soon', now: fixedNow, formatter: _fmt(), copy: _copy),
        isNull,
      );
    });
    test('the key changes exactly when the words do', () {
      String key(Duration ago, [DateTime? now]) =>
          rowTimeKey((now ?? fixedNow).subtract(ago), now ?? fixedNow, _fmt());
      expect(key(const Duration(seconds: 5)), key(const Duration(seconds: 59)));
      expect(
        key(const Duration(seconds: 59)),
        isNot(key(const Duration(seconds: 60))),
      );
      expect(
        key(const Duration(minutes: 3)),
        key(const Duration(minutes: 3, seconds: 40)),
      );
      expect(
        key(const Duration(hours: 2)),
        key(const Duration(hours: 2, minutes: 59)),
      );
      // An older row says "yesterday at", then "Saturday at": its key has today.
      final old = DateTime(2026, 11, 10, 9);
      expect(
        rowTimeKey(old, fixedNow, _fmt()),
        isNot(rowTimeKey(old, fixedNow.add(const Duration(days: 1)), _fmt())),
      );
      expect(
        rowTimeKey(old, fixedNow, _fmt()),
        rowTimeKey(old, fixedNow.add(const Duration(minutes: 5)), _fmt()),
      );
    });
  });

  group('row time in the row', () {
    for (final (name, size, platform) in rowEnvs) {
      final touch = platform == TargetPlatform.android;
      testWidgets('$name: short time rests visible, words in the name', (
        tester,
      ) async {
        useFixedClock();
        final f = RowFixture();
        addTearDown(f.dispose);
        final handle = tester.ensureSemantics();
        await pumpRowApp(
          tester,
          ActivityInboxRow(
            row: channelRow(at: fixedNow.subtract(const Duration(minutes: 3))),
            host: f.host(),
          ),
          size: size,
          platform: platform,
        );
        expect(find.text('3m'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('conversation-card-timestamp')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp(r'3 minutes ago$')),
          findsOneWidget,
        );
        handle.dispose();
      });

      testWidgets(
        '$name: an older row hides its clock until hover (never on touch)',
        (tester) async {
          useFixedClock();
          final f = RowFixture();
          addTearDown(f.dispose);
          final handle = tester.ensureSemantics();
          await pumpRowApp(
            tester,
            ActivityInboxRow(
              row: channelRow(at: DateTime(2026, 11, 16, 17, 20)),
              host: f.host(),
            ),
            size: size,
            platform: platform,
          );
          final clock = find.byKey(
            const ValueKey('conversation-card-timestamp'),
          );
          expect(clock, findsNothing);
          // The words are the row's name, shown or not.
          expect(
            find.bySemanticsLabel(RegExp(r'yesterday at 5:20 PM$')),
            findsOneWidget,
          );
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          addTearDown(mouse.removePointer);
          await mouse.moveTo(
            tester.getCenter(find.byKey(const ValueKey('inbox-item-open'))),
          );
          await tester.pump();
          expect(clock, touch ? findsNothing : findsOneWidget);
          if (!touch) expect(find.text('5:20 PM'), findsOneWidget);
          handle.dispose();
        },
      );
    }

    testWidgets('mouse: the long words are the time\'s tooltip', (
      tester,
    ) async {
      useFixedClock();
      final f = RowFixture();
      addTearDown(f.dispose);
      await pumpRowApp(
        tester,
        ActivityInboxRow(
          row: channelRow(at: fixedNow.subtract(const Duration(hours: 2))),
          host: f.host(),
        ),
      );
      final tip = find.ancestor(
        of: find.byKey(const ValueKey('inbox-item-timestamp')),
        matching: find.byType(RaftTooltip),
      );
      expect(tip, findsOneWidget);
      expect(tester.widget<RaftTooltip>(tip).message, '2 hours ago');
    });

    testWidgets(
      'one shared clock: a minute turns the text, rows share one timer',
      (tester) async {
        var now = fixedNow;
        useFixedClock();
        sourceTimeNow = () => now;
        final f = RowFixture();
        addTearDown(f.dispose);
        await pumpRowApp(
          tester,
          Column(
            children: [
              for (final id in ['a', 'b', 'c'])
                ActivityInboxRow(
                  key: ValueKey(id),
                  row: channelRow(
                    id: id,
                    name: 'room-$id',
                    at: fixedNow.subtract(const Duration(seconds: 50)),
                  ),
                  host: f.host(),
                ),
            ],
          ),
        );
        expect(find.text('now'), findsNWidgets(3));
        expect(ActivityRowClock.instance.listenerCount, 3);
        expect(ActivityRowClock.instance.running, isTrue);
        // The clock ticks every 15 s; a row rebuilds only when its words changed.
        now = fixedNow.add(const Duration(seconds: 20));
        await tester.pump(const Duration(seconds: 15));
        expect(find.text('1m'), findsNWidgets(3));
        now = fixedNow.add(const Duration(minutes: 5, seconds: 20));
        await tester.pump(const Duration(seconds: 15));
        expect(find.text('6m'), findsNWidgets(3));
        await tester.pumpWidget(const SizedBox.shrink());
        expect(ActivityRowClock.instance.listenerCount, 0);
        expect(ActivityRowClock.instance.running, isFalse);
      },
    );
  });
}
