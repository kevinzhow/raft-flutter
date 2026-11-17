// RaftMeter (raft-ui `Meter`) and the inline RaftDescriptionList under it:
// theme (light and dark), the filled share, the warning axis, semantics and
// text scaling. A meter is read-only, so it has no keyboard behavior: nothing
// in it takes focus.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _host(Widget child, {bool dark = false, double scale = 1}) =>
    MaterialApp(
      theme: raftTheme(dark: dark),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: Center(child: SizedBox(width: 320, child: child)),
        ),
      ),
    );

void main() {
  final track = find.byKey(const ValueKey('meter-track'));
  final fill = find.byKey(const ValueKey('meter-indicator'));

  for (final dark in [false, true]) {
    testWidgets('fills to the share used (${dark ? 'dark' : 'light'})', (
      t,
    ) async {
      await t.pumpWidget(
        _host(
          const RaftMeter(
            label: 'Seats',
            used: 1.5,
            max: 3,
            valueText: '1.5 of 3 used',
          ),
          dark: dark,
        ),
      );
      expect(find.text('Seats'), findsOneWidget);
      expect(find.text('1.5 of 3 used'), findsOneWidget);
      expect(t.getSize(fill).width, closeTo(t.getSize(track).width / 2, .01));
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('the share is held to the track', (t) async {
    Future<double> share(num used, num max) async {
      await t.pumpWidget(
        _host(RaftMeter(label: 'L', used: used, max: max, valueText: 'v')),
      );
      return t.getSize(fill).width / t.getSize(track).width;
    }

    expect(await share(0, 5), 0);
    expect(await share(9, 5), 1);
    expect(await share(-3, 5), 0);
    expect(await share(2, 0), 0);
  });

  testWidgets('warning uses the warning colour, otherwise info', (t) async {
    Color color() => t.widget<ColoredBox>(fill).color;
    await t.pumpWidget(
      _host(const RaftMeter(label: 'L', used: 1, max: 2, valueText: 'v')),
    );
    final normal = color();
    await t.pumpWidget(
      _host(
        const RaftMeter(
          label: 'L',
          used: 1,
          max: 2,
          valueText: 'v',
          warning: true,
        ),
      ),
    );
    expect(color(), isNot(normal));
  });

  testWidgets('reads as one labelled value', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      _host(
        const RaftMeter(
          label: 'Seats',
          used: 1,
          max: 3,
          valueText: '1 of 3 used',
        ),
      ),
    );
    final node = t.getSemantics(find.bySemanticsLabel('Seats'));
    expect(node.label, 'Seats');
    expect(node.value, '1 of 3 used');
    handle.dispose();
  });

  testWidgets('a long label truncates, the value stays whole, at 3.1x', (
    t,
  ) async {
    await t.pumpWidget(
      _host(
        const RaftMeter(
          label: 'A very long meter label that cannot possibly fit the row',
          used: 1,
          max: 2,
          valueText: '1 of 2 used',
        ),
        scale: 3.1,
      ),
    );
    expect(t.takeException(), isNull);
    expect(find.text('1 of 2 used'), findsOneWidget);
  });

  testWidgets('inline description list wraps and takes widgets', (t) async {
    await t.pumpWidget(
      _host(
        const RaftDescriptionList(
          inline: true,
          entries: [
            RaftDescriptionEntry('People', '1 · 1 seat'),
            RaftDescriptionEntry(
              'Agents',
              '',
              detailsChild: SizedBox(key: ValueKey('custom'), width: 10),
            ),
            RaftDescriptionEntry('Members', '2 people · 2 agents'),
          ],
        ),
      ),
    );
    expect(find.text('People'), findsOneWidget);
    expect(find.text('1 · 1 seat'), findsOneWidget);
    expect(find.byKey(const ValueKey('custom')), findsOneWidget);
    // 320px cannot hold all three side by side: they wrap to a second line.
    final first = t.getTopLeft(find.text('People')).dy;
    final last = t.getTopLeft(find.text('Members')).dy;
    expect(last, greaterThan(first));
  });
}
