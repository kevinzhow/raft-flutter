import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final (id, dark) in raftThemeMatrix(
    [
      (raftThemePackId, false),
      (raftThemePackId, true),
      (elegantThemePackId, false),
      (elegantThemePackId, true),
      (brutalThemePackId, false),
    ],
    look: (v) => raftLookOf(v.$1),
    dark: (v) => v.$2,
  )) {
    for (final touch in [false, true]) {
      testWidgets(
        'server window menu $id ${dark ? 'dark' : 'light'} ${touch ? 'fold touch' : 'narrow desktop'} follows input mode and is accessible',
        (t) async {
          final menu = RaftMenuController();
          t.view.physicalSize = touch
              ? const Size(856, 944)
              : const Size(390, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          var opens = 0;
          final semantics = t.ensureSemantics();
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(pack: packForThemeId(id), dark: dark),
              builder: (context, child) => RaftInteractionScope(
                interaction: touch
                    ? RaftInteraction.touchMode
                    : RaftInteraction.pointerMode,
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(3.1)),
                  child: child!,
                ),
              ),
              home: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 64,
                  child: RaftServerSwitcher(
                    controller: menu,
                    workspaceName: 'Alpha',
                    label: 'Switch Server',
                    rows: [
                      RaftServerMenuRow(
                        id: 'a',
                        name: 'Alpha',
                        slug: 'alpha',
                        onSelected: () {},
                        onOpenWindow: () => opens++,
                      ),
                    ],
                    actions: const [],
                  ),
                ),
              ),
            ),
          );
          menu.open();
          await t.pumpAndSettle();
          final row = find.text('Alpha').last;
          final pointer = await t.startGesture(
            t.getCenter(row),
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          );
          await pointer.up();
          await t.pumpAndSettle();
          expect(
            find.text('Open in new window'),
            touch ? findsNothing : findsOneWidget,
          );
          if (!touch) {
            expect(find.bySemanticsLabel('Open in new window'), findsOneWidget);
            await t.tap(find.text('Open in new window'));
            await t.pumpAndSettle();
            expect(opens, 1);
          }
          expect(t.takeException(), isNull);
          semantics.dispose();
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          menu.dispose();
        },
      );
    }
  }
}
