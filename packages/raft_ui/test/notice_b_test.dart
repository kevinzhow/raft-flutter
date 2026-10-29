import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Slice B of the transient-notice audit: a notice must end with its cause.
/// Each test fails on the code before the fix.
Widget _app(Widget child) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(body: child),
);

RaftComputerDetailData _computer(String id, {List<String> agents = const []}) =>
    RaftComputerDetailData(
      id: id,
      name: 'Computer $id',
      online: true,
      isComputer: true,
      slug: id,
      runtimes: const [],
      createdLabel: 'today',
      canManage: true,
      agents: [
        for (final a in agents)
          RaftComputerAgent(
            id: a,
            name: 'Agent $a',
            subtitle: '',
            activity: 'offline',
            activityText: '',
          ),
      ],
    );

RaftComputerDetailActions _actions({
  Future<int> Function(RaftComputerBulk, List<String>)? bulk,
  Future<void> Function(String)? rename,
  Future<void> Function(String?)? describe,
}) => RaftComputerDetailActions(
  rename: rename ?? (_) async {},
  describe: describe ?? (_) async {},
  scanWorkspaces: () async => const [],
  deleteWorkspace: (_) async {},
  restart: () async {},
  deleteComputer: () async {},
  bulk: bulk ?? (_, _) async => 0,
);

void main() {
  testWidgets('secret view copy confirmation dismisses itself', (tester) async {
    await tester.pumpWidget(
      _app(RaftSecretView(value: 'secret', onCopy: (_) async {})),
    );
    await tester.tap(find.text('Copy Credential'));
    await tester.pump();
    expect(find.text('Copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Copied'), findsNothing);
  });

  testWidgets('form dialog drops the last rejection when a new submit starts', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => RaftFormDialog(
                title: 'Create',
                fields: const [RaftFormField('title', 'Title', required: true)],
                onSubmit: (_) async => throw const RaftUserError('Name taken'),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'abc');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Name taken'), findsOneWidget);
    // The user empties the field and submits again: validation stops the
    // submit, and the rejection of the earlier value no longer applies.
    await tester.enterText(find.byType(TextFormField), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Name taken'), findsNothing);
  });

  testWidgets('invite dialog email prompt ends once an email is typed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(RaftInviteHumanDialog(onClose: () {}, onSend: (_) async {})),
    );
    await tester.tap(find.text('Send Invites'));
    await tester.pump();
    const prompt = 'Enter at least one email, or copy the invite link above.';
    expect(find.text(prompt), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'a@b.co');
    await tester.pump();
    expect(find.text(prompt), findsNothing);
  });

  group('computer detail', () {
    Future<void> mount(
      WidgetTester tester,
      RaftComputerDetailData data,
      RaftComputerDetailActions actions,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(RaftComputerDetailView(data: data, actions: actions)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('name error ends when the name is edited', (tester) async {
      await mount(tester, _computer('a'), _actions());
      await tester.tap(find.byKey(const ValueKey('computer-edit-name')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('computer-name-field')),
        '',
      );
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Computer name is required'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('computer-name-field')),
        'Studio',
      );
      await tester.pump();
      expect(find.text('Computer name is required'), findsNothing);
    });

    testWidgets('description error ends when the text is edited', (
      tester,
    ) async {
      await mount(
        tester,
        _computer('a'),
        _actions(describe: (_) async => throw StateError('no')),
      );
      await tester.tap(find.byKey(const ValueKey('computer-edit-description')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('computer-description-field')),
        'first',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Failed to update description'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('computer-description-field')),
        'second',
      );
      await tester.pump();
      expect(find.text('Failed to update description'), findsNothing);
    });

    testWidgets('a bulk failure of computer A never shows on computer B', (
      tester,
    ) async {
      final pending = Completer<int>();
      await mount(
        tester,
        _computer('a', agents: ['a1']),
        _actions(bulk: (_, _) => pending.future),
      );
      await tester.tap(find.byKey(const ValueKey('computer-agents-select')));
      await tester.pump();
      await tester.tap(find.text('Agent a1'));
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pump();
      // The view moves to another computer while the request is in flight.
      await tester.pumpWidget(
        _app(
          RaftComputerDetailView(
            data: _computer('b', agents: ['b1']),
            actions: _actions(),
          ),
        ),
      );
      pending.complete(1);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('computer-agents-select')));
      await tester.pump();
      await tester.tap(find.text('Agent b1'));
      await tester.pump();
      expect(find.textContaining('agent action failed'), findsNothing);
      expect(find.textContaining('Start'), findsOneWidget);
    });

    testWidgets('a bulk error is dropped when another computer is shown', (
      tester,
    ) async {
      await mount(
        tester,
        _computer('a', agents: ['a1']),
        _actions(bulk: (_, _) async => 1),
      );
      await tester.tap(find.byKey(const ValueKey('computer-agents-select')));
      await tester.pump();
      await tester.tap(find.text('Agent a1'));
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(find.textContaining('agent action failed'), findsOneWidget);
      await tester.pumpWidget(
        _app(
          RaftComputerDetailView(
            data: _computer('b', agents: ['a1']),
            actions: _actions(),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('computer-agents-select')));
      await tester.pump();
      await tester.tap(find.text('Agent a1'));
      await tester.pump();
      expect(find.textContaining('agent action failed'), findsNothing);
    });
  });
}
