// The External setup block of an external agent's page (Web v1.24
// ExternalAgentConnectionCard + ExternalAgentCredentialList +
// useExternalAgentCredentials), through the real agent detail.
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/external_agent_setup_text.dart';

import 'support/external_agent_fixture.dart';

const _credentialPost = 'POST /agents/ext-1/credentials';

Map<String, dynamic> _seenNow([Duration ago = Duration.zero]) => {
  ...externalAgentRow,
  'lastSeenAt': DateTime.now().subtract(ago).toUtc().toIso8601String(),
};

void main() {
  test('the profile slug follows the handle, then the id', () {
    expect(
      externalProfileSlug('Hermes Bridge!', 'abcdef123456'),
      'Hermes-Bridge',
    );
    expect(externalProfileSlug('--', 'abcdef123456'), 'abcdef12');
  });

  testWidgets(
    'not signed in: the waiting line, the prompt and the active list',
    (tester) async {
      final (_, client) = await pumpExternal(tester);
      expect(find.text('External setup'), findsOneWidget);
      expect(
        find.text('Waiting for Hermes Bridge to connect…'),
        findsOneWidget,
      );
      expect(
        find.text('This updates by itself when Hermes Bridge signs in.'),
        findsOneWidget,
      );
      // Existing-agent steps, numbered because the credential step is there.
      expect(find.text('1. Send this prompt to your agent'), findsOneWidget);
      expect(
        find.text('2. Give it the agent credential when it asks'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'raft agent login --server https://raft.example.test --agent ext-1 --profile-slug Hermes-Bridge',
        ),
        findsOneWidget,
      );
      expect(find.text('Build it with the SDK instead'), findsOneWidget);
      // Only the active credential is listed, the unnamed one by its fallback.
      expect(find.text('Agent credential'), findsOneWidget);
      expect(find.text('Created Jun 18, 2026 · not used yet'), findsOneWidget);
      expect(find.text('Old laptop'), findsNothing);
      expect(client.count('GET /agents/ext-1/credentials'), 1);
    },
  );

  testWidgets('a status with no credential minted says where to make one', (
    tester,
  ) async {
    final client = ExternalClient()
      ..status = {'setupState': 'waiting_for_login'};
    await pumpExternal(tester, client: client);
    expect(
      find.text(
        'It has no agent credential yet. Create one below and give it to Hermes Bridge.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a failed status read shows the message and no setup block', (
    tester,
  ) async {
    final client = ExternalClient()..failStatus = true;
    await pumpExternal(tester, client: client);
    expect(find.text('Failed to load external setup status'), findsOneWidget);
    expect(find.text('Status unavailable'), findsNothing);
    expect(key('external-agent-connection'), findsNothing);
  });

  testWidgets('connected and online: steps fold behind How it connects', (
    tester,
  ) async {
    final client = ExternalClient()
      ..status = {
        'setupState': 'connected',
        'lastActivityAt': DateTime.now()
            .subtract(const Duration(minutes: 3))
            .toUtc()
            .toIso8601String(),
      };
    await pumpExternal(
      tester,
      client: client..row = _seenNow(),
      agent: _seenNow(),
    );
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Active 3 minutes ago'), findsOneWidget);
    expect(key('external-agent-switch'), findsNothing);
    expect(find.text('Send this prompt to your agent'), findsNothing);
    await tester.tap(key('external-agent-how-it-connects'));
    await tester.pumpAndSettle();
    // Open again: unnumbered, since credentials sit in their own list.
    expect(find.text('Send this prompt to your agent'), findsOneWidget);
    expect(key('external-agent-switch'), findsNothing);
    await tester.tap(key('external-agent-how-it-connects'));
    await tester.pumpAndSettle();
    expect(find.text('Send this prompt to your agent'), findsNothing);
  });

  testWidgets('connected and offline: last seen, exact date in the tooltip', (
    tester,
  ) async {
    final client = ExternalClient()..status = {'setupState': 'connected'};
    final seen = _seenNow(const Duration(hours: 3));
    await pumpExternal(tester, client: client..row = seen, agent: seen);
    expect(find.text('Offline · last seen 3 hours ago'), findsOneWidget);
    expect(
      find.text("Still connected. Messages wait until it's back."),
      findsOneWidget,
    );
  });

  testWidgets('disconnected: orange, names the way back', (tester) async {
    final client = ExternalClient()..status = {'setupState': 'disconnected'};
    await pumpExternal(tester, client: client);
    expect(find.text('Hermes Bridge is disconnected'), findsOneWidget);
    expect(
      find.text(
        'Its credentials were revoked. Create a new one and give it to Hermes Bridge to reconnect.',
      ),
      findsOneWidget,
    );
    expect(find.text('Build it with the SDK instead'), findsOneWidget);
  });

  testWidgets(
    'Create credential: named, shown once, listed and status re-read',
    (tester) async {
      final copied = captureClipboard();
      final client = ExternalClient()..credentials = const [];
      await pumpExternal(tester, client: client);
      await tester.tap(key('external-agent-create-credential'));
      await tester.pumpAndSettle();
      final (_, body) = client.bodies.singleWhere(
        (request) => request.$1 == _credentialPost,
      );
      expect(body, {'name': pageCredentialName});
      expect(
        find.text(
          "Shown once. Anyone with it can act as Hermes Bridge; revoke it on Hermes Bridge's page.",
        ),
        findsOneWidget,
      );
      expect(find.text('sk_agent_0123456789abcdefghijklmnop'), findsOneWidget);
      expect(find.text('Never put it in a command or a file.'), findsOneWidget);
      // The list re-reads and the page credential appears under its own name.
      expect(client.count('GET /agents/ext-1/credentials'), 2);
      expect(find.text('Created on this page'), findsOneWidget);
      await tester.tap(key('external-agent-new-credential-copy'));
      await tester.pump();
      expect(copied.single, 'sk_agent_0123456789abcdefghijklmnop');
      // A status read follows the change (Web: refresh after create).
      expect(client.statusReads, greaterThan(1));
    },
  );

  testWidgets('a new page credential asks first and replaces only that one', (
    tester,
  ) async {
    final client = ExternalClient();
    client.credentials = [
      ...client.credentials,
      {
        'id': 'cred-page',
        'name': 'Created on this page',
        'createdAt': '2026-06-18T09:00:00.000Z',
        'lastUsedAt': '2026-06-18T10:00:00.000Z',
        'revokedAt': null,
      },
    ];
    await pumpExternal(tester, client: client);
    expect(find.text('Create new credential'), findsOneWidget);
    expect(
      find.text(
        "The one shown when Hermes Bridge was created can't be shown again.",
      ),
      findsOneWidget,
    );
    await tester.tap(key('external-agent-create-credential'));
    await tester.pumpAndSettle();
    expect(find.text('Create a new credential?'), findsOneWidget);
    // Cancelled: nothing was made.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(client.count(_credentialPost), 0);
    await tester.tap(key('external-agent-create-credential'));
    await tester.pumpAndSettle();
    await tester.tap(key('external-agent-replace-confirm'));
    await tester.pumpAndSettle();
    final (_, body) = client.bodies.singleWhere(
      (request) => request.$1 == _credentialPost,
    );
    expect(body, {
      'name': pageCredentialName,
      'replacesCredentialId': 'cred-page',
    });
    expect(find.text('sk_agent_0123456789abcdefghijklmnop'), findsOneWidget);
  });

  testWidgets('Revoke asks first; a failure keeps the row and says so', (
    tester,
  ) async {
    final client = ExternalClient()..failRevoke = true;
    await pumpExternal(tester, client: client);
    Future<void> openRevoke() async {
      await tester.tap(key('external-credential-menu-cred-1234abcd'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revoke').last);
      await tester.pumpAndSettle();
    }

    await openRevoke();
    expect(find.text('Revoke this credential?'), findsOneWidget);
    await tester.tap(key('external-agent-revoke-confirm'));
    await tester.pumpAndSettle();
    expect(
      find.text("Raft couldn't revoke the credential. Try again."),
      findsOneWidget,
    );
    expect(key('external-credential-cred-1234abcd'), findsOneWidget);
    // Resolved: the next try goes through, the row is gone and the notice too.
    client.failRevoke = false;
    await openRevoke();
    await tester.tap(key('external-agent-revoke-confirm'));
    await tester.pumpAndSettle();
    expect(key('external-credential-cred-1234abcd'), findsNothing);
    expect(
      find.text("Raft couldn't revoke the credential. Try again."),
      findsNothing,
    );
    expect(find.text('No credentials yet.'), findsOneWidget);
  });

  testWidgets('a failed credential list says so', (tester) async {
    final client = ExternalClient()..failList = true;
    await pumpExternal(tester, client: client);
    expect(find.text("Raft couldn't load the credentials."), findsOneWidget);
    // Resolved: a create re-reads the list (Web useExternalAgentCredentials
    // `revision`), and once that read succeeds the notice is gone.
    client.failList = false;
    await tester.tap(key('external-agent-create-credential'));
    await tester.pumpAndSettle();
    expect(client.count('GET /agents/ext-1/credentials'), 2);
    expect(find.text("Raft couldn't load the credentials."), findsNothing);
  });

  testWidgets('a member may not manage the agent: no External setup block', (
    tester,
  ) async {
    final other = Map<String, dynamic>.from(externalAgentRow)
      ..['creatorId'] = 'bob';
    final (_, client) = await pumpExternal(
      tester,
      client: ExternalClient(row: other),
      role: 'member',
      agent: other,
    );
    expect(key('external-agent-connection'), findsNothing);
    expect(client.calls.where((c) => c.contains('/credentials')), isEmpty);
  });
}
