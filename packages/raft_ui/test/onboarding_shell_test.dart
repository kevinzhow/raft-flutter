import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _host(Size size, {Widget? preview}) => MediaQuery(
  data: MediaQueryData(size: size),
  child: MaterialApp(
    theme: raftTheme(),
    home: RaftOnboardingShell(
      preview: preview,
      child: const SizedBox(
        key: Key('form'),
        width: double.infinity,
        height: 200,
      ),
    ),
  ),
);

void main() {
  for (final (id, light) in [
    (raftThemePackId, const Color(0xffffd440)),
    (elegantThemePackId, const Color(0xffffffff)),
    (brutalThemePackId, const Color(0xffffd440)),
  ]) {
    testWidgets(
      '$id auth header keeps its source fill at phone and desktop widths',
      (t) async {
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        for (final dark in [false, true]) {
          for (final width in [390.0, 1280.0]) {
            t.view.physicalSize = Size(width, 844);
            await t.pumpWidget(
              MaterialApp(
                theme: raftTheme(pack: packForThemeId(id), dark: dark),
                home: const Scaffold(body: RaftAuthTopBar()),
              ),
            );
            await t.pumpAndSettle();
            final surface = t.widget<Container>(
              find
                  .descendant(
                    of: find.byType(RaftAuthTopBar),
                    matching: find.byWidgetPredicate(
                      (w) => w is Container && w.decoration is BoxDecoration,
                    ),
                  )
                  .first,
            );
            final expected = dark
                ? (id == raftThemePackId
                      ? const Color(0xff0d0d0b)
                      : const Color(0xff242422))
                : light;
            expect((surface.decoration! as BoxDecoration).color, expected);
            // Raft look: the 56px panel header (`h-panel-header`); the pre-theme
            // looks kept the 62px fallback of a page outside the app shell.
            expect(
              t.getSize(find.byType(RaftAuthTopBar)).height,
              id == raftThemePackId ? 56 : 62,
            );
            expect(t.takeException(), isNull);
          }
        }
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('lg width with a preview splits form panel and dot pane', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(const Size(1280, 800), preview: const SizedBox(key: Key('pv'))),
    );
    // grid-cols-[minmax(320px,2fr)_3fr]: 512 | 768; form panel px-10 (+ 1px hairline border-r) leaves 431.
    expect(tester.getSize(find.byKey(const Key('form'))).width, 431);
    expect(tester.getTopLeft(find.byKey(const Key('form'))).dx, 40);
    expect(tester.getTopLeft(find.byKey(const Key('pv'))).dx, 512 + 32);
    expect(tester.getSize(find.byKey(const Key('pv'))).width, 704);
    expect(tester.takeException(), isNull);
  });

  testWidgets('below lg the shell is the narrow form page without preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(const Size(390, 844), preview: const SizedBox(key: Key('pv'))),
    );
    expect(find.byKey(const Key('pv')), findsNothing);
    expect(find.byKey(const Key('form')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('splash body shows its label centred on the cream canvas', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: const RaftServerResolutionBody(label: 'Restoring session…'),
      ),
    );
    expect(find.text('Restoring session…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
