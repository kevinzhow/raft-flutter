// Delete Account › an agent row's "You can also" actions (Web
// AccountDeletionAgentRow.tsx AgentAction): the Pro tag sits inside the Move
// button after its label, and the actions wrap within a phone's width.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/account_deletion_page.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/parity_harness.dart' show loadParityFonts;
import 'support/account_deletion_server.dart';

void main() {
  late AccountDeletionServerClient client;
  late WorkspaceController w;
  setUp(() {
    client = AccountDeletionServerClient();
    w = WorkspaceController(client);
    client.checklist = {
      ...client.checklist,
      'agents': [
        for (final (id, name) in [('a1', 'Scout'), ('a2', 'Helper')])
          {
            'id': id,
            'name': name,
            'outcome': 'transfer_to_owner',
            'server': deletionServer('srv1', 'Studio'),
            'toUser': {'id': 'u2', 'name': 'Ana'},
          },
      ],
      'computers': [
        {
          'id': 'c1',
          'name': 'Laptop',
          'server': deletionServer('srv1', 'Studio'),
          'agents': [
            {'id': 'a1', 'name': 'Scout', 'ownedByMe': true},
            {'id': 'a2', 'name': 'Helper', 'ownedByMe': true},
          ],
        },
      ],
    };
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  testWidgets('phone width: Move with its Pro tag fits, the tag is inside', (
    t,
  ) async {
    t.view
      ..physicalSize = const Size(390, 1400)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AccountDeletionPage(
              controller: w,
              // Studio is not the open server: Move leads there.
              onMoveElsewhere: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: 'no overflow');
    final move = find.byKey(const ValueKey('account-deletion-move-c1'));
    expect(move, findsOneWidget);
    final button = find.descendant(of: move, matching: find.byType(RaftButton));
    expect(
      find.descendant(of: button, matching: find.text('Pro')),
      findsOneWidget,
      reason: 'the tag is part of the button (Web: {icon}{label}{badge})',
    );
    final row = t.getRect(find.byType(AccountDeletionPage));
    expect(t.getRect(button).right, lessThanOrEqualTo(row.right));
  });

  testWidgets('a hairline separates Needs action from the automatic rows', (
    t,
  ) async {
    client.checklist = {
      ...client.checklist,
      'soleOwnerServers': [
        {...deletionServer('srv9', 'Lab'), 'memberCount': 3},
      ],
    };
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AccountDeletionPage(
              controller: w,
              onMoveElsewhere: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final line = find.byKey(
      const ValueKey('account-deletion-groups-separator'),
    );
    expect(line, findsOneWidget);
    expect(
      t.getRect(line).bottom,
      lessThan(
        t.getTopLeft(find.text('The rest happens automatically (1)')).dy,
      ),
    );
  });

  testWidgets('phone width: the outcome arrow sits in the icon column', (
    t,
  ) async {
    // Web AccountDeletionChecklistRow below `sm`: grid-cols-[20px_1fr], the
    // arrow under the icon, so the outcome and its actions get the width.
    t.view
      ..physicalSize = const Size(390, 1400)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    // Real fonts: the test font's em-square glyphs would cut any label.
    await t.runAsync(loadParityFonts);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AccountDeletionPage(
              controller: w,
              onMoveElsewhere: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final icon = t.getRect(
      find
          .byWidgetPredicate(
            (w) => w is RaftIcon && w.glyph == RaftGlyph.monitor,
          )
          .first,
    );
    final arrow = t.getRect(
      find
          .byWidgetPredicate(
            (w) => w is RaftIcon && w.glyph == RaftGlyph.arrowRight,
          )
          .first,
    );
    expect(arrow.center.dx, closeTo(icon.center.dx, 2));
    final label = t.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byKey(const ValueKey('account-deletion-move-c1')),
        matching: find.text('Move to another computer'),
      ),
    );
    expect(label.didExceedMaxLines, isFalse, reason: 'the label is not cut');
  });
}
