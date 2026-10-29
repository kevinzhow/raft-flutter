// Login / server-selection tap targets (docs/login-acceptance.md): every row,
// button and link shows pressed feedback from the design system (pressing
// changes what is painted) and can be hit 24dp from its centre (a 48dp target)
// even when its visual box is smaller.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/global_server_selector.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

class _Taps {
  final log = <String>[];
}

Widget _selector(_Taps taps, {int servers = 2}) => GlobalServerSelector(
  servers: [
    for (var i = 0; i < servers; i++)
      RaftRecord({'id': 's$i', 'name': 'Server $i', 'slug': 'server-$i'}),
  ],
  user: RaftRecord({'id': 'u', 'email': 'alice@example.invalid'}),
  loading: false,
  onSelect: (s) async => taps.log.add('select ${s.id}'),
  onCreate: (_, _) async => taps.log.add('create'),
  onLogout: () async => taps.log.add('logout'),
  onRetry: () async => taps.log.add('retry'),
);

/// The painted look of [target]: decorations, opacity and text colours below it.
List<Object?> _look(WidgetTester t, Finder target) {
  final out = <Object?>[];
  void visit(Element e) {
    final w = e.widget;
    if (w is DecoratedBox) out.add(w.decoration);
    if (w is Opacity) out.add(w.opacity);
    if (w is Text) out.add(w.style?.color);
    if (w is Transform) out.add(w.transform);
    e.visitChildren(visit);
  }

  visit(t.element(target));
  return out;
}

void main() {
  for (final theme in raftThemeMatrix(['light', 'dark'], full: true)) {
    final dark = theme == 'dark';
    Future<_Taps> pump(WidgetTester t) async {
      final taps = _Taps();
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: RaftDensityScope(
            density: RaftDensity.touch,
            child: _selector(taps),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 400));
      return taps;
    }

    final targets = <String, Finder Function()>{
      'server row': () => find.byKey(const ValueKey('global-server-s0')),
      '+ Create New Server': () =>
          find.byKey(const ValueKey('global-server-create-new')),
      'Log out': () => find.ancestor(
        of: find.text('Log out'),
        matching: find.byType(RaftInteractive),
      ),
    };
    final expected = {'server row': 'select s0', 'Log out': 'logout'};

    for (final MapEntry(key: what, value: find_) in targets.entries) {
      testWidgets('$what shows pressed feedback ($theme)', (t) async {
        await pump(t);
        final target = find_();
        final idle = _look(t, target);
        final g = await t.startGesture(t.getCenter(target));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        final pressed = _look(t, target);
        await g.up();
        await t.pump(const Duration(milliseconds: 400));
        expect(pressed, isNot(idle), reason: '$what has no pressed feedback');
      });

      testWidgets('$what has a 48dp tap target ($theme)', (t) async {
        final taps = await pump(t);
        final target = find_();
        final centre = t.getCenter(target);
        // 23dp above the centre: inside a 48dp box centred on the control,
        // outside the 24..36dp visual box. (Below, the next sibling or the
        // parent's own edge bounds the hit area, so that side is not claimed.)
        for (final dy in [-23.0]) {
          taps.log.clear();
          await t.tapAt(centre + Offset(0, dy));
          await t.pump(const Duration(milliseconds: 400));
          if (what == '+ Create New Server') {
            expect(find.text('Create Server'), findsWidgets, reason: 'dy=$dy');
            await t.pumpWidget(const SizedBox());
            await pump(t);
          } else {
            expect(taps.log, [expected[what]], reason: 'dy=$dy');
          }
        }
      });
    }
  }
}
