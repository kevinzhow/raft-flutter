// Settings > Account > Delete Account (Web DeleteAccountPage.tsx,
// AccountDeletionChecklist.tsx and their rows, v1.24.0): the list, what holds
// the deletion up and how each blocker is resolved, the request with the
// proof the server names, the refusals, and the confirmation.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/account_deletion_page.dart';
import 'package:raft_flutter/features/account_deletion_section.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/account_deletion_server.dart';

const _soleOwner = {
  'id': 'srv1',
  'name': 'Studio',
  'slug': 'studio',
  'memberCount': 3,
};

Map<String, Object?> _agent(
  String id,
  String name, {
  String outcome = 'transfer_to_owner',
  String server = 'srv1',
  Map<String, String>? toUser,
}) => {
  'id': id,
  'name': name,
  'outcome': outcome,
  'server': deletionServer(server, server == 'srv1' ? 'Studio' : 'Lab'),
  'toUser': toUser,
};

Map<String, Object?> _computer(
  String id,
  String name,
  List<Map<String, Object?>> agents, {
  String server = 'srv1',
}) => {
  'id': id,
  'name': name,
  'server': deletionServer(server, server == 'srv1' ? 'Studio' : 'Lab'),
  'agents': agents,
};

Map<String, Object?> _others(String id, String name, {Object? owner}) => {
  'id': id,
  'name': name,
  'ownedByMe': false,
  'owner': owner ?? {'id': 'u9', 'name': 'Bo'},
  'personalAssistant': false,
};

void main() {
  late AccountDeletionServerClient client;
  late WorkspaceController w;
  setUp(() {
    client = AccountDeletionServerClient();
    w = WorkspaceController(client);
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Future<void> mount(
    WidgetTester t, {
    String? moveAgentId,
    void Function(AccountDeletionServer server)? openSettings,
  }) async {
    t.view
      ..physicalSize = const Size(900, 2600)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AccountDeletionPage(
              controller: w,
              moveAgentId: moveAgentId,
              onOpenServerSettings: openSettings,
              onSignOut: () => client.logout(),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, String key) async {
    await t.ensureVisible(find.byKey(ValueKey(key)));
    await t.tap(find.byKey(ValueKey(key)));
    await t.pumpAndSettle();
  }

  bool deleteEnabled(WidgetTester t) {
    final button = t.widget<RaftButton>(
      find.byKey(const ValueKey('account-deletion-confirm')),
    );
    return button.onPressed != null;
  }

  void scheduled() => client.postAnswers.add({
    'status': 'scheduled',
    'requestedAt': '2026-11-18T10:00:00.000Z',
    'scheduledFor': '2026-12-18T10:00:00.000Z',
  });

  testWidgets('the list reads the deletion on open and shows each thing', (
    t,
  ) async {
    client.checklist = {
      ...client.checklist,
      'soleMemberServers': [deletionServer('srv2', 'Notes')],
      'paidServersEndingAtPeriodEnd': [
        {
          ...deletionServer('srv3', 'Team'),
          'periodEnd': '2026-12-01T00:00:00.000Z',
        },
      ],
      'agents': [
        _agent('a1', 'Scout', toUser: {'id': 'u2', 'name': 'Ana'}),
        _agent('a2', 'Helper', outcome: 'archive_personal_assistant'),
      ],
      'computers': [
        _computer('c1', 'Laptop', [
          {'id': 'a1', 'name': 'Scout', 'ownedByMe': true},
          {'id': 'a2', 'name': 'Helper', 'ownedByMe': true},
        ]),
      ],
    };
    await mount(t);
    expect(client.reads(), 1);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Only you'), findsOneWidget);
    expect(find.text('Billing for Team'), findsOneWidget);
    expect(find.text('2 agents on Laptop'), findsOneWidget);
    expect(find.text('Helper and Scout'), findsOneWidget);
    expect(find.textContaining('Goes to Ana'), findsOneWidget);
    expect(find.text('Billing stops on December 1'), findsOneWidget);
    // v7: the date a request made now takes effect, from the server's grace.
    expect(find.textContaining('Delete account · Effective'), findsOneWidget);
    expect(find.text('Sign in within 30 days to cancel'), findsOneWidget);
    expect(deleteEnabled(t), isTrue);
    expect(find.byKey(const ValueKey('account-deletion-why')), findsNothing);
  });

  testWidgets('a failed read keeps the general agents line and Delete waits', (
    t,
  ) async {
    client.readFailure = 500;
    await mount(t);
    expect(find.text('Your agents'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
    // Read once; settled either way, Delete is allowed (the 409 still guards).
    expect(deleteEnabled(t), isTrue);
  });

  testWidgets('a server only you own holds Delete up until Make owner', (
    t,
  ) async {
    client.checklist = {
      ...client.checklist,
      'soleOwnerServers': [_soleOwner],
    };
    client.members['srv1'] = [
      {'userId': 'me', 'name': 'me', 'role': 'owner'},
      {'userId': 'u2', 'name': 'ana', 'displayName': 'Ana', 'role': 'member'},
      {'userId': 'u3', 'name': 'gus', 'role': 'guest'},
    ];
    await mount(t);
    expect(deleteEnabled(t), isFalse);
    expect(find.text('Needs action (1)'), findsOneWidget);
    expect(find.text('First choose a new Owner for Studio'), findsOneWidget);
    expect(
      find.text('2 other members, and you\'re the only Owner'),
      findsOneWidget,
    );

    // Make owner stays off until a member is chosen.
    expect(
      t
          .widget<RaftButton>(
            find.byKey(
              const ValueKey('account-deletion-transfer-confirm-srv1'),
            ),
          )
          .onPressed,
      isNull,
    );
    await tap(t, 'account-deletion-transfer-select-srv1');
    // Not the person, no guests.
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('gus'), findsNothing);
    await t.tap(find.text('Ana'));
    await t.pumpAndSettle();
    // The server's list gets read again once the owner is made.
    client.checklist = {...client.checklist, 'soleOwnerServers': <Object?>[]};
    final reads = client.reads();
    await tap(t, 'account-deletion-transfer-confirm-srv1');
    final patch = client.to('PATCH', '/servers/srv1/members/u2');
    expect(patch, hasLength(1));
    expect(patch.single.data, {'role': 'owner'});
    expect(patch.single.server, 'srv1');
    expect(client.reads(), reads + 1);
    // The row stays, handled; Delete is allowed.
    expect(find.text('Handled'), findsOneWidget);
    expect(
      find.text('Goes to Ana, who manages it from now on'),
      findsOneWidget,
    );
    expect(deleteEnabled(t), isTrue);
    expect(find.byKey(const ValueKey('account-deletion-why')), findsNothing);
  });

  testWidgets('no one to hand over to: say so and link to the server', (
    t,
  ) async {
    client.checklist = {
      ...client.checklist,
      'soleOwnerServers': [_soleOwner],
    };
    client.members['srv1'] = [
      {'userId': 'me', 'name': 'me', 'role': 'owner'},
    ];
    AccountDeletionServer? opened;
    await mount(t, openSettings: (server) => opened = server);
    expect(
      find.text('No one here can become an Owner. Delete the server instead.'),
      findsOneWidget,
    );
    await tap(t, 'account-deletion-open-settings-srv1');
    expect(opened?.id, 'srv1');
  });

  testWidgets('a failed Make owner says so and keeps the row', (t) async {
    client.checklist = {
      ...client.checklist,
      'soleOwnerServers': [_soleOwner],
    };
    client.members['srv1'] = [
      {'userId': 'u2', 'name': 'Ana', 'role': 'member'},
    ];
    client.failures['PATCH /servers/srv1/members/u2'] = deletionRefusal(
      500,
      'boom',
    );
    await mount(t);
    await tap(t, 'account-deletion-transfer-select-srv1');
    await t.tap(find.text('Ana'));
    await t.pumpAndSettle();
    await tap(t, 'account-deletion-transfer-confirm-srv1');
    expect(
      find.text("Couldn't make them an Owner. Try again."),
      findsOneWidget,
    );
    expect(deleteEnabled(t), isFalse);
  });

  testWidgets("other people's agents: notify, Notify all, and Force unbind", (
    t,
  ) async {
    client.checklist = {
      ...client.checklist,
      'computers': [
        _computer('c1', 'Laptop', [
          _others('b1', 'Rex'),
          _others('b2', 'Pip', owner: {'id': 'u8', 'name': 'Cy'}),
        ]),
      ],
    };
    await mount(t);
    expect(deleteEnabled(t), isFalse);
    expect(find.text('Needs action (2)'), findsOneWidget);
    expect(
      find.text(
        "First wait for 2 other people's agents to leave your computers",
      ),
      findsOneWidget,
    );
    expect(find.text('Owner: Bo · Studio · Laptop'), findsOneWidget);

    // Per agent, once; the list is read again when it settles.
    final reads = client.reads();
    await tap(t, 'account-deletion-notify-b1');
    final notify = client.to(
      'POST',
      '/me/account/deletion/notify-agent-owners',
    );
    expect(notify.single.data, {
      'agentIds': ['b1'],
    });
    expect(client.reads(), reads + 1);

    // Notify all: the ones that can be reminded now (b2 only).
    await tap(t, 'account-deletion-notify-all');
    expect(
      client.to('POST', '/me/account/deletion/notify-agent-owners').last.data,
      {
        'agentIds': ['b2'],
      },
    );
  });

  Finder field() => find.descendant(
    of: find.byKey(const ValueKey('second-factor-answer-password')),
    matching: find.byType(EditableText),
  );

  List<dynamic> posts() => [
    for (final c in client.to('POST', '/me/account/deletion')) c.data,
  ];

  testWidgets('a recent sign-in schedules at once: the shell goes', (t) async {
    scheduled();
    await mount(t);
    await tap(t, 'account-deletion-confirm');
    // The first request carries no proof; the server decides.
    expect(posts(), [<String, Object?>{}]);
    expect(client.accountDeletion.requested, isTrue);
    expect(
      client.accountDeletion.requestedScheduledFor,
      '2026-12-18T10:00:00.000Z',
    );
  });

  testWidgets('a password is asked for, a wrong one stays under its field', (
    t,
  ) async {
    client.postAnswers.addAll([
      deletionRefusal(
        403,
        'reauth_required',
        extra: {
          'methods': ['password'],
        },
      ),
      deletionRefusal(401, 'password_incorrect'),
      {
        'status': 'scheduled',
        'requestedAt': '2026-11-18T10:00:00.000Z',
        'scheduledFor': '2026-12-18T10:00:00.000Z',
      },
    ]);
    await mount(t);
    await tap(t, 'account-deletion-confirm');
    expect(
      find.byKey(const ValueKey('account-deletion-password')),
      findsOneWidget,
    );
    expect(find.text("Verify it's you"), findsOneWidget);
    // Delete account waits for a password.
    expect(
      t
          .widget<RaftButton>(
            find.byKey(const ValueKey('second-factor-step-commit')),
          )
          .onPressed,
      isNull,
    );
    await t.enterText(field(), 'wrong');
    await t.pump();
    await tap(t, 'second-factor-step-commit');
    expect(find.text('That password is incorrect. Try again.'), findsOneWidget);
    expect(client.accountDeletion.requested, isFalse);
    await t.enterText(field(), 'right');
    await t.pump();
    await tap(t, 'second-factor-step-commit');
    expect(posts().last, {'password': 'right'});
    expect(client.accountDeletion.requested, isTrue);
    // The dialog is gone with the shell.
    expect(
      find.byKey(const ValueKey('account-deletion-password')),
      findsNothing,
    );
  });

  testWidgets('two-step verification: the code goes in the request itself', (
    t,
  ) async {
    client.postAnswers.addAll([
      deletionRefusal(
        403,
        'reauth_required',
        extra: {
          'methods': ['totp', 'backup_code'],
        },
      ),
      {
        'status': 'scheduled',
        'requestedAt': '2026-11-18T10:00:00.000Z',
        'scheduledFor': '2026-12-18T10:00:00.000Z',
      },
    ]);
    await mount(t);
    await tap(t, 'account-deletion-confirm');
    expect(find.text("Verify it's you"), findsWidgets);
    expect(
      find.text("Confirm it's you to delete your account."),
      findsOneWidget,
    );
    await t.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('step-up-totp')),
        matching: find.byType(EditableText),
      ),
      '123 456',
    );
    await t.pump();
    await t.tap(find.text('Verify'));
    await t.pumpAndSettle();
    expect(posts().last, {
      'secondFactor': {'code': '123456'},
    });
    expect(client.accountDeletion.requested, isTrue);
  });

  testWidgets(
    'no password and no two-step: an emailed code, then the request',
    (t) async {
      client.postAnswers.addAll([
        deletionRefusal(
          403,
          'reauth_required',
          extra: {
            'methods': ['email_code'],
          },
        ),
        {
          'status': 'scheduled',
          'requestedAt': '2026-11-18T10:00:00.000Z',
          'scheduledFor': '2026-12-18T10:00:00.000Z',
        },
      ]);
      await mount(t);
      await tap(t, 'account-deletion-confirm');
      expect(
        find.text("We'll email a code to me@example.invalid."),
        findsOneWidget,
      );
      // Sending the code is not the deletion.
      await tap(t, 'second-factor-step-commit');
      expect(
        client.to('POST', '/me/account/deletion/email-code'),
        hasLength(1),
      );
      expect(posts(), [<String, Object?>{}]);
      expect(find.text('Code sent to me@example.invalid'), findsWidgets);
      await t.enterText(
        find.byKey(const ValueKey('account-deletion-email-code-field')),
        '123456',
      );
      await t.pump();
      await tap(t, 'second-factor-step-commit');
      expect(posts().last, {'emailCode': '123456'});
      expect(client.accountDeletion.requested, isTrue);
    },
  );

  testWidgets('a server only you own, found at request time, joins the list', (
    t,
  ) async {
    client.postAnswers.add(
      deletionRefusal(
        409,
        'sole_owner_servers',
        extra: {
          'servers': [_soleOwner],
        },
      ),
    );
    client.members['srv1'] = [
      {'userId': 'u2', 'name': 'Ana', 'role': 'member'},
    ];
    await mount(t);
    final reads = client.reads();
    await tap(t, 'account-deletion-confirm');
    expect(
      find.byKey(const ValueKey('account-deletion-transfer-srv1')),
      findsOneWidget,
    );
    expect(client.reads(), reads + 1);
    expect(deleteEnabled(t), isFalse);
  });

  testWidgets('403 session_family_required offers Sign in again', (t) async {
    client.postAnswers.add(deletionRefusal(403, 'session_family_required'));
    await mount(t);
    await tap(t, 'account-deletion-confirm');
    expect(
      find.byKey(const ValueKey('account-deletion-sign-in-again')),
      findsOneWidget,
    );
    await tap(t, 'account-deletion-sign-in-again-button');
    expect(client.logouts, 1);
  });

  testWidgets('any other failure says so under the button', (t) async {
    client.postAnswers.add(deletionRefusal(500, 'boom'));
    await mount(t);
    await tap(t, 'account-deletion-confirm');
    expect(
      find.text("Couldn't delete your account. Try again."),
      findsOneWidget,
    );
    expect(deleteEnabled(t), isTrue);
  });

  testWidgets("Force unbind asks to confirm the list, then sends exactly it", (
    t,
  ) async {
    client.checklist = {
      ...client.checklist,
      'computers': [
        _computer('c1', 'Laptop', [_others('b1', 'Rex'), _others('b2', 'Pip')]),
      ],
    };
    // More arrives between the dialog and the request: nothing is unbound.
    client.postAnswers.addAll([
      deletionRefusal(
        409,
        'others_agents_on_computers',
        extra: {
          'agents': [
            {
              ..._others('b1', 'Rex'),
              'server': deletionServer('srv1', 'Studio'),
              'computer': {'id': 'c1', 'name': 'Laptop'},
            },
            {
              ..._others('b2', 'Pip'),
              'server': deletionServer('srv1', 'Studio'),
              'computer': {'id': 'c1', 'name': 'Laptop'},
            },
            {
              ..._others('b3', 'Max'),
              'server': deletionServer('srv1', 'Studio'),
              'computer': {'id': 'c1', 'name': 'Laptop'},
            },
          ],
        },
      ),
    ]);
    await mount(t);
    await tap(t, 'account-deletion-force-unbind');
    expect(find.text('Force unbind 2 agents?'), findsOneWidget);
    expect(find.text('Owner: Bo · Laptop'), findsNWidgets(2));
    // The server now lists the new one too (the read after the 409).
    client.checklist = {
      ...client.checklist,
      'computers': [
        _computer('c1', 'Laptop', [
          _others('b1', 'Rex'),
          _others('b2', 'Pip'),
          _others('b3', 'Max'),
        ]),
      ],
    };
    await tap(t, 'force-unbind-confirm');
    expect(posts(), [
      {
        'forceAgentIds': ['b2', 'b1'],
      },
    ]);
    expect(
      find.byKey(const ValueKey('account-deletion-force-conflict')),
      findsOneWidget,
    );
    // The list is redrawn from the 409: the new agent is a row.
    expect(
      find.byKey(const ValueKey('account-deletion-others-agent-b3')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Archive confirms, sends the DELETE for its server, and reads again',
    (t) async {
      client.checklist = {
        ...client.checklist,
        'agents': [
          _agent('a1', 'Scout', toUser: {'id': 'u2', 'name': 'Ana'}),
        ],
        'computers': [
          _computer('c1', 'Laptop', [
            {'id': 'a1', 'name': 'Scout', 'ownedByMe': true},
          ]),
        ],
      };
      await mount(t);
      final reads = client.reads();
      await tap(t, 'account-deletion-archive-c1');
      expect(find.text('Archive Scout?'), findsOneWidget);
      await tap(t, 'account-deletion-archive-confirm-button');
      final archived = client.to('DELETE', '/agents/a1');
      expect(archived.single.data, {'workspace': 'keep'});
      expect(archived.single.server, 'srv1');
      expect(client.reads(), reads + 1);
    },
  );

  testWidgets('a failed Archive stays in its dialog with the reason', (
    t,
  ) async {
    client.checklist = {
      ...client.checklist,
      'agents': [_agent('a1', 'Scout')],
      'computers': [
        _computer('c1', 'Laptop', [
          {'id': 'a1', 'name': 'Scout', 'ownedByMe': true},
        ]),
      ],
    };
    client.failures['DELETE /agents/a1'] = deletionRefusal(500, 'boom');
    await mount(t);
    await tap(t, 'account-deletion-archive-c1');
    await tap(t, 'account-deletion-archive-confirm-button');
    expect(find.text('Archive Scout?'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('account-deletion-archive-confirm')),
      findsOneWidget,
    );
  });

  testWidgets('coming back to the app reads the list again', (t) async {
    await mount(t);
    final reads = client.reads();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(client.reads(), reads + 1);
  });

  testWidgets('the Danger zone row opens the page', (t) async {
    var opened = 0;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: AccountDeleteSection(onOpen: () => opened++)),
      ),
    );
    expect(find.text('Danger zone'), findsOneWidget);
    expect(find.text('Delete account'), findsNWidgets(2));
    await t.tap(find.byKey(const ValueKey('account-deletion-open')));
    expect(opened, 1);
  });
}
