import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Web v1.24 ThreadsInbox toolbar as RaftActivityFilterBar: 49 tall (44 with a
// mouse from 768), Filter radio menu, the chip with its x, Mark all read.
const _labels = RaftActivityFilterLabels(
  filter: 'Filter',
  menu: 'Filter inbox',
  clear: 'Clear filter',
  markAllRead: 'Mark all read',
  markAllReadTooltip: 'Mark all as read',
  choices: {
    RaftActivityFilterChoice.all: 'All',
    RaftActivityFilterChoice.unread: 'Unread',
    RaftActivityFilterChoice.mentions: 'Mentions',
    RaftActivityFilterChoice.pinned: 'Pinned',
    RaftActivityFilterChoice.saved: 'Saved',
    RaftActivityFilterChoice.artifacts: 'Artifacts',
  },
);

typedef _Env = (String, Size, TargetPlatform, double);

const _envs = <_Env>[
  ('linux 1440x900', Size(1440, 900), TargetPlatform.linux, 44),
  ('linux 390x844', Size(390, 844), TargetPlatform.linux, 49),
  ('android 856x944', Size(856, 944), TargetPlatform.android, 49),
  ('android 944x856', Size(944, 856), TargetPlatform.android, 49),
];

class _Host extends StatefulWidget {
  const _Host({
    this.initial = RaftActivityFilterChoice.all,
    this.unread = true,
    this.onRead,
    this.width,
    this.choices,
  });
  final RaftActivityFilterChoice initial;
  final bool unread;
  final VoidCallback? onRead;
  final double? width;
  final List<RaftActivityFilterChoice>? choices;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late RaftActivityFilterChoice choice = widget.initial;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    child: RaftActivityFilterBar(
      choice: choice,
      onChoice: (c) {
        widget.choices?.add(c);
        setState(() => choice = c);
      },
      labels: _labels,
      showMarkAllRead: widget.unread,
      onMarkAllRead: widget.onRead,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  _Env env,
  Widget child, {
  bool dark = false,
  double scale = 1,
}) async {
  tester.view.physicalSize = env.$2;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: raftTheme(dark: dark).copyWith(platform: env.$3),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _bar => find.byKey(const ValueKey('activity-filter-bar'));
Finder get _filter => find.byKey(const ValueKey('inbox-filter-button'));
Finder get _chip => find.byKey(const ValueKey('inbox-filter-chip'));
Finder get _clear => find.byKey(const ValueKey('inbox-filter-clear'));
Finder get _mark => find.byKey(const ValueKey('inbox-mark-all-read'));

void main() {
  for (final env in _envs) {
    final (name, size, platform, height) = env;
    final touch = platform == TargetPlatform.android;
    group(name, () {
      testWidgets('bar is $height tall, column margin, seamed', (tester) async {
        await _pump(tester, env, const _Host());
        expect(tester.getSize(_bar).height, height);
        expect(tester.getSize(_bar).width, size.width);
        expect(
          tester.getTopLeft(_filter).dx,
          size.width >= 768 && !touch ? 16 : 20,
          reason: 'column margin: 16 desktop mouse, 20 otherwise',
        );
        final box = tester.widget<Container>(_bar).decoration! as BoxDecoration;
        expect((box.border! as Border).bottom.width, greaterThan(0));
        // Mark all read ends on the margin (its padding hangs outward).
        if (size.width > 480) {
          expect(
            tester.getRect(find.text('Mark all read')).right,
            closeTo(size.width - (size.width >= 768 && !touch ? 16 : 20), 2),
          );
        }
      });

      testWidgets('menu: radios, separator, check, choose', (tester) async {
        final handle = tester.ensureSemantics();
        final chosen = <RaftActivityFilterChoice>[];
        await _pump(tester, env, _Host(choices: chosen));
        await tester.tap(_filter);
        await tester.pumpAndSettle();
        for (final c in RaftActivityFilterChoice.values) {
          expect(find.text(_labels.choices[c]!), findsWidgets);
        }
        final all = tester.getSemantics(find.text('All').last);
        expect(all.getSemanticsData().flagsCollection.isChecked, isNotNull);
        expect(
          tester
              .getSemantics(find.text('Unread').last)
              .getSemanticsData()
              .flagsCollection
              .isChecked,
          CheckedState.isFalse,
        );
        expect(
          all.getSemanticsData().flagsCollection.isChecked,
          CheckedState.isTrue,
        );
        await tester.tap(find.text('Saved').last);
        await tester.pumpAndSettle();
        expect(chosen, [RaftActivityFilterChoice.saved]);
        expect(find.text('Pinned'), findsNothing, reason: 'menu closed');
        expect(_chip, findsOneWidget);
        handle.dispose();
      });

      testWidgets('open Filter takes the fill; Escape closes and keeps focus', (
        tester,
      ) async {
        await _pump(tester, env, const _Host());
        await tester.tap(_filter);
        await tester.pumpAndSettle();
        expect(find.text('Artifacts'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Artifacts'), findsNothing);
        expect(Focus.of(tester.element(_filter)).hasFocus, isTrue);
      });

      testWidgets('chip shows for a filter; x clears and refocuses Filter', (
        tester,
      ) async {
        final chosen = <RaftActivityFilterChoice>[];
        await _pump(
          tester,
          env,
          _Host(initial: RaftActivityFilterChoice.mentions, choices: chosen),
        );
        expect(_chip, findsOneWidget);
        expect(
          find.descendant(of: _chip, matching: find.text('Mentions')),
          findsOneWidget,
        );
        await tester.tap(_clear);
        await tester.pumpAndSettle();
        expect(chosen, [RaftActivityFilterChoice.all]);
        expect(_chip, findsNothing);
        final node = Focus.of(tester.element(_filter));
        expect(node.hasPrimaryFocus || node.hasFocus, isTrue);
      });

      testWidgets('no chip on All; Mark all read only while unread', (
        tester,
      ) async {
        await _pump(tester, env, const _Host(unread: false));
        expect(_chip, findsNothing);
        expect(_mark, findsNothing);
      });

      testWidgets('Mark all read acts, labelled, tooltip mouse only', (
        tester,
      ) async {
        var read = 0;
        await _pump(tester, env, _Host(onRead: () => read++));
        expect(_mark, findsOneWidget);
        final tip = tester.widget<RaftTooltip>(
          find.ancestor(of: _mark, matching: find.byType(RaftTooltip)).first,
        );
        expect(tip.message, 'Mark all as read');
        expect(tip.enabled, !touch);
        await tester.tap(_mark);
        expect(read, 1);
      });

      testWidgets('icon-only at 480 and under, words above', (tester) async {
        for (final (width, iconOnly) in [(481.0, false), (480.0, true)]) {
          if (width > size.width) continue;
          await _pump(tester, env, _Host(width: width));
          expect(
            find.text('Mark all read'),
            iconOnly ? findsNothing : findsOneWidget,
            reason: 'bar width $width',
          );
          expect(_mark, findsOneWidget);
        }
      });

      for (final dark in [false, true]) {
        testWidgets('${dark ? 'dark' : 'light'}: paints with the chip', (
          tester,
        ) async {
          await _pump(
            tester,
            env,
            const _Host(initial: RaftActivityFilterChoice.artifacts),
            dark: dark,
          );
          expect(_chip, findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('text 2.0x grows the bar without clipping', (tester) async {
        await _pump(
          tester,
          env,
          const _Host(initial: RaftActivityFilterChoice.mentions),
          scale: 2,
        );
        expect(tester.getSize(_bar).height, greaterThan(height));
        expect(tester.takeException(), isNull);
        // Controls stay inside the bar.
        final bar = tester.getRect(_bar);
        expect(bar.contains(tester.getRect(_filter).topLeft), isTrue);
        expect(bar.contains(tester.getRect(_filter).bottomRight), isTrue);
      });
    });
  }
}
