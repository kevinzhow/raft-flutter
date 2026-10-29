import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

void main() {
  test('AgreementBody parsing (paragraphs, lists, line joins)', () {
    expect(RaftAgreementBody.parse(''), isEmpty);
    expect(
      [
        for (final (kind, lines) in RaftAgreementBody.parse(
          'a\nb\n\n- x\n* y\n1. one\n2) two\nc',
        ))
          '$kind:${lines.join('|')}',
      ],
      ['p:a|b', 'ul:x|y', 'ol:one|two', 'p:c'],
    );
  });

  testWidgets('principal picker opens, filters, picks and closes', (t) async {
    String? picked;
    await t.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => RaftAdminPrincipalPicker(
            candidates: const [
              RaftAdminPrincipal(
                key: 'human:d',
                label: 'Dana',
                agent: false,
                optionLabel: 'Dana · dana@raft.test',
              ),
              RaftAdminPrincipal(
                key: 'agent:h',
                label: '@helper',
                agent: true,
                optionLabel: '@helper · Agent',
              ),
            ],
            selectedKey: picked,
            onSelect: (key) => setState(() => picked = key),
          ),
        ),
      ),
    );
    expect(find.text('Search members...'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('admin-principal-picker')));
    await t.pumpAndSettle();
    expect(find.text('Members'), findsOneWidget);
    await t.enterText(find.byType(EditableText).last, 'help');
    await t.pumpAndSettle();
    expect(find.text('Dana · dana@raft.test'), findsNothing);
    await t.tap(find.byKey(const ValueKey('admin-candidate-agent:h')));
    await t.pumpAndSettle();
    expect(picked, 'agent:h');
    // Agents read their plain label on the trigger.
    expect(find.text('@helper'), findsOneWidget);
    // Escape closes an open picker.
    await t.tap(find.byKey(const ValueKey('admin-principal-picker')));
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('admin-principal-popover')),
      findsOneWidget,
    );
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('admin-principal-popover')), findsNothing);
  });

  testWidgets('empty picker is disabled with the no-members copy', (t) async {
    await t.pumpWidget(
      _host(
        RaftAdminPrincipalPicker(
          candidates: const [],
          selectedKey: null,
          enabled: false,
          onSelect: (_) {},
        ),
      ),
    );
    expect(find.text('No members to promote'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('admin-principal-picker')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('admin-principal-popover')), findsNothing);
  });

  testWidgets('confirm dialog runs onConfirm with the loading label', (
    t,
  ) async {
    final done = Completer<void>();
    bool? result;
    await t.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await RaftConfirmDialog.show(
                context,
                RaftConfirmDialog(
                  title: 'Revoke Invite',
                  message: 'Sure?',
                  confirmLabel: 'Revoke Invite',
                  loadingLabel: 'Revoking…',
                  confirmKey: const ValueKey('confirm'),
                  onConfirm: () => done.future,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('confirm')));
    await t.pump();
    expect(find.text('Revoking…'), findsOneWidget);
    done.complete();
    await t.pumpAndSettle();
    expect(result, isTrue);
    expect(find.text('Sure?'), findsNothing);
  });

  testWidgets('confirm dialog keeps open and shows a failure', (t) async {
    await t.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => RaftConfirmDialog.show(
              context,
              RaftConfirmDialog(
                title: 'Make public?',
                message: 'Sure?',
                confirmKey: const ValueKey('confirm'),
                onConfirm: () async => throw const RaftUserError('Nope'),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('confirm')));
    await t.pumpAndSettle();
    expect(find.text('Nope'), findsOneWidget);
    expect(find.text('Sure?'), findsOneWidget);
  });

  testWidgets('sections render in', (t) async {
    final maxUses = TextEditingController();
    final title = TextEditingController(text: 'Rules');
    final body = TextEditingController(text: 'Be kind.');
    addTearDown(maxUses.dispose);
    addTearDown(title.dispose);
    addTearDown(body.dispose);
    await t.pumpWidget(
      _host(
        Column(
          children: [
            RaftAdminCheckboxForm(
              title: 'Hide #all channel',
              description: 'd',
              checked: true,
              save: RaftAdminSaveState.saved,
              warnings: const ['Translation is enabled'],
            ),
            RaftAdminInvitesCard(
              invites: [
                RaftAdminInvite(
                  id: 'i',
                  email: 'a@b.c',
                  date: 'Jun 18',
                  onRevoke: () {},
                ),
              ],
            ),
            RaftAdminJoinLinksCard(
              maxUses: maxUses,
              expiresAt: DateTime(2026, 6, 19, 20, 24),
              onExpiresAt: (_) {},
              onCreate: () {},
              links: const [],
            ),
            RaftAdminAgreementCard(
              enabled: true,
              onEnabled: (_) {},
              title: title,
              body: body,
              save: RaftAdminSaveState.idle,
              onSave: null,
            ),
            RaftAdminOnboardingCard(
              agentId: '',
              agents: const [('a', '@a (A)')],
              onAgent: (_) {},
              greeting: true,
              onGreeting: (_) {},
              save: RaftAdminSaveState.idle,
              onSave: null,
              showSetup: true,
            ),
            const RaftPublicVisibilityCard(
              publiclyVisible: true,
              onPublic: null,
              publicUrl: 'https://raft.test/s/x',
              guestJoin: false,
              channels: [RaftPublicChannel(name: 'general')],
            ),
          ],
        ),
      ),
    );
    expect(t.takeException(), isNull);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('No active invite links.'), findsOneWidget);
    expect(find.text('06/19/2026, 08:24 PM'), findsOneWidget);
    expect(find.text('Finish setup'), findsOneWidget);
    expect(find.text('8/5000'), findsOneWidget);
  });

  testWidgets('RaftCssPixelSnap paints a fractional box on whole pixels', (
    t,
  ) async {
    final key = GlobalKey();
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 1),
          child: Padding(
            padding: const EdgeInsets.only(top: 10.5),
            child: RaftCssPixelSnap(
              child: SizedBox(key: key, width: 20, height: 10),
            ),
          ),
        ),
      ),
    );
    // Layout keeps the fraction; only the paint origin moves.
    expect(t.getTopLeft(find.byKey(key)).dy, 10.5);
    final box = find.ancestor(
      of: find.byKey(key),
      matching: find.byType(RaftCssPixelSnap),
    );
    expect(box, findsOneWidget);
  });

  testWidgets('Elegant dark settings card paints its inset highlight', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: true),
        home: const Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 100,
              height: 60,
              child: RaftSettingsCard(child: SizedBox.expand()),
            ),
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
