import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (dark) in [(false), (true)]) {
    Widget host(Widget child, {bool touch = false}) => MaterialApp(
      theme: raftTheme(dark: dark),
      home: Scaffold(
        body: RaftDensityScope(
          density: touch ? RaftDensity.touch : RaftDensity.desktop,
          child: Padding(
            padding: const EdgeInsets.all(60),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 500, child: child),
            ),
          ),
        ),
      ),
    );
    void retire(WidgetTester t) => addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    });

    for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
      testWidgets(
        'DM avatar opens profile using Tab and ${key == LogicalKeyboardKey.space ? 'Space' : 'Enter'} ${dark ? 'dark' : 'light'}',
        (t) async {
          retire(t);
          var opened = 0;
          await t.pumpWidget(
            host(
              RaftDmHeader(
                name: 'Taylor',
                avatar: const SizedBox.square(dimension: 36),
                onAvatarTap: () => opened++,
              ),
            ),
          );
          await t.sendKeyEvent(LogicalKeyboardKey.tab);
          await t.pump();
          await t.sendKeyEvent(key);
          await t.pumpAndSettle();
          expect(
            opened,
            1,
            reason:
                'the new profile button must be reachable without a pointer',
          );
        },
      );
    }

    testWidgets(
      'disclosure retains its auxiliary action in the semantics tree ${dark ? 'dark' : 'light'}',
      (t) async {
        retire(t);
        final semantics = t.ensureSemantics();
        try {
          var actions = 0, changes = 0;
          Widget action() => RaftControl(
            semanticLabel: 'Add skill',
            visualWidth: 32,
            onPressed: () => actions++,
            child: const Icon(Icons.add),
          );
          await t.pumpWidget(
            host(
              RaftSectionHeader(label: 'Skills', count: 3, action: action()),
            ),
          );
          expect(
            find.bySemanticsLabel('Add skill'),
            findsOneWidget,
            reason: 'control: the original header exposes the action',
          );
          await t.pumpWidget(
            host(
              RaftCollapsibleSectionHeader(
                label: 'Skills',
                count: 3,
                expanded: false,
                onExpandedChanged: (_) => changes++,
                action: action(),
                children: const [],
              ),
            ),
          );
          expect(
            find.bySemanticsLabel('Add skill'),
            findsOneWidget,
            reason: 'turning the header into a disclosure must not hide the separate action from assistive technology',
          );
          final node = t.getSemantics(find.bySemanticsLabel('Add skill'));
          t.binding.performSemanticsAction(
            SemanticsActionEvent(
              viewId: t.view.viewId,
              nodeId: node.id,
              type: SemanticsAction.tap,
            ),
          );
          await t.pumpAndSettle();
          expect(actions, 1);
          expect(changes, 0);
          await t.tap(find.bySemanticsLabel('Add skill'));
          await t.sendKeyEvent(LogicalKeyboardKey.enter);
          await t.sendKeyEvent(LogicalKeyboardKey.space);
          await t.pumpAndSettle();
          expect(actions, 4);
          expect(changes, 0);
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      'touch can activate the disclosure inside the 48px target ${dark ? 'dark' : 'light'}',
      (t) async {
        retire(t);
        var changes = 0;
        await t.pumpWidget(
          host(
            RaftCollapsibleSectionHeader(
              disclosureKey: const ValueKey('disclosure'),
              label: 'Skills',
              count: 3,
              expanded: false,
              onExpandedChanged: (_) => changes++,
              children: const [],
            ),
            touch: true,
          ),
        );
        final rect = t.getRect(find.byKey(const ValueKey('disclosure')));
        await t.tapAt(rect.center + const Offset(0, 18));
        await t.pumpAndSettle();
        expect(
          changes,
          1,
          reason: 'a touch 18px from the visual centre is within a 48px target',
        );
      },
    );

    testWidgets(
      'the disclosure label keeps the neighbouring section alignment ${dark ? 'dark' : 'light'}',
      (t) async {
        retire(t);
        await t.pumpWidget(
          host(
            Column(
              children: [
                RaftCollapsibleSectionHeader(
                  label: 'Skills',
                  count: 3,
                  expanded: false,
                  onExpandedChanged: (_) {},
                  children: const [],
                ),
                const RaftSectionHeader(label: 'Actions', count: 2),
              ],
            ),
          ),
        );
        Finder title(String text) => find.byWidgetPredicate(
          (w) => w is RaftSectionEyebrow && w.label == text,
        );
        expect(
          t.getTopLeft(title('Skills')).dx,
          t.getTopLeft(title('Actions')).dx,
        );
        expect(
          t.getCenter(find.byType(AnimatedRotation)).dx,
          greaterThan(t.getCenter(title('Skills')).dx),
        );
      },
    );

    testWidgets(
      'Skills remains keyboard-operable for Enter and Space ${dark ? 'dark' : 'light'}',
      (t) async {
        retire(t);
        await t.pumpWidget(
          host(
            const RaftSkillsSection(
              global: [
                RaftSkillItem(
                  name: 'deploy',
                  displayName: 'Deploy',
                  description: 'Ship it',
                  sourcePath: '/skills',
                  userInvocable: true,
                ),
              ],
              workspace: [],
            ),
          ),
        );
        expect(find.text('Deploy'), findsNothing);
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        expect(find.text('Deploy'), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pumpAndSettle();
        expect(find.text('Deploy'), findsNothing);
      },
    );
  }
}
