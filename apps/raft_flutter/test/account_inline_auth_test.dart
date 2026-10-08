import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/account_connections_view.dart';
import 'package:raft_flutter/features/account_password_editor.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      );
  dynamic methods = {'passwordConfigured': true, 'identities': []};
  List<Map<String, dynamic>> providers = [];
  Completer<dynamic>? pendingMethods, pendingPatch;
  final mutations = <({String method, String path, dynamic data})>[];
  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    if (path == '/auth/identities' && method == 'GET') {
      return pendingMethods?.future ?? methods;
    }
    if (path == '/auth/providers') return {'providers': providers};
    mutations.add((method: method, path: path, data: data));
    return pendingPatch?.future ?? {};
  }
}

void main() {
  late _Client client;
  late WorkspaceController w;
  setUp(() {
    client = _Client()
      ..user = RaftRecord({'id': 'owner', 'email': 'fixture@example.invalid'});
    w = WorkspaceController(client);
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });
  Future<void> mount(WidgetTester t, Widget child) => t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  Finder field(String label) => find.descendant(
    of: find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label,
    ),
    matching: find.byType(TextField),
  );
  Future<void> fill(WidgetTester t) async {
    await t.tap(find.text('Change password').first);
    await t.pumpAndSettle();
    await t.enterText(field('Current password'), 'fixture-current');
    await t.enterText(field('New password'), 'fixture-updated');
    await t.enterText(field('Confirm new password'), 'fixture-updated');
  }

  testWidgets(
    'unknown methods fail closed, then verified local password expands inline',
    (t) async {
      client.pendingMethods = Completer<dynamic>();
      await mount(t, AccountConnectionsView(controller: w, inline: true));
      await t.pump();
      expect(find.text('Change password'), findsNothing);
      expect(find.text('Set password by email'), findsNothing);
      client.pendingMethods!.complete(client.methods);
      await t.pumpAndSettle();
      await fill(t);
      await t.ensureVisible(find.byType(RaftButton).last);
      await t.tap(find.byType(RaftButton).last);
      await t.pumpAndSettle();
      expect(client.mutations.single.path, '/auth/me');
      expect(client.mutations.single.method, 'PATCH');
      expect(client.mutations.single.data, {
        'currentPassword': 'fixture-current',
        'newPassword': 'fixture-updated',
      });
      expect(
        t.widget<TextField>(field('Current password')).controller!.text,
        '',
      );
      expect(t.widget<TextField>(field('New password')).controller!.text, '');
      expect(find.text('Password updated.'), findsOneWidget);
    },
  );
  testWidgets(
    'late password acknowledgement cannot leave credentials or success in next account',
    (t) async {
      client.pendingPatch = Completer<dynamic>();
      await mount(t, AccountPasswordEditor(controller: w));
      await t.pumpAndSettle();
      await fill(t);
      await t.tap(find.byType(RaftButton));
      await t.pump();
      client.user = RaftRecord({'id': 'next'});
      w.notifyListeners();
      await t.pump();
      expect(find.byType(TextField), findsNothing);
      client.pendingPatch!.complete({});
      await t.pumpAndSettle();
      expect(find.text('Password updated.'), findsNothing);
      await t.tap(find.text('Change password').first);
      await t.pumpAndSettle();
      expect(
        t.widget<TextField>(field('Current password')).controller!.text,
        '',
      );
      expect(t.widget<TextField>(field('New password')).controller!.text, '');
    },
  );
  testWidgets(
    'provider-managed password shows setup and retains linked disabled provider',
    (t) async {
      client.methods = {
        'passwordConfigured': false,
        'identities': [
          {'provider': 'google', 'providerEmail': 'fixture@example.invalid'},
        ],
      };
      client.providers = [
        {'id': 'google', 'label': 'Google', 'enabled': false},
        {'id': 'github', 'label': 'GitHub', 'enabled': false},
      ];
      await mount(t, AccountConnectionsView(controller: w, inline: true));
      await t.pumpAndSettle();
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('GitHub'), findsNothing);
      expect(find.text('Change password'), findsNothing);
      expect(find.text('Set password by email'), findsOneWidget);
      await t.tap(find.text('Disconnect'));
      await t.pumpAndSettle();
      expect(find.text('Send email'), findsOneWidget);
      expect(client.mutations, isEmpty);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(client.mutations, isEmpty);
    },
  );
  testWidgets(
    'late old identities cannot expose old provider email in next principal',
    (t) async {
      client.pendingMethods = Completer<dynamic>();
      await mount(t, AccountConnectionsView(controller: w, inline: true));
      await t.pump();
      final old = client.pendingMethods!;
      final fresh = Completer<dynamic>();
      client.pendingMethods = fresh;
      client.user = RaftRecord({'id': 'next'});
      w.notifyListeners();
      await t.pump();
      old.complete({
        'passwordConfigured': true,
        'identities': [
          {
            'provider': 'google',
            'providerEmail': 'old-private@example.invalid',
          },
        ],
      });
      await t.pump();
      expect(find.text('old-private@example.invalid'), findsNothing);
      client.pendingMethods!.complete({
        'passwordConfigured': false,
        'identities': [],
      });
      await t.pumpAndSettle();
    },
  );
  testWidgets(
    'retained password-setup action cannot open a form for the next principal',
    (t) async {
      client.methods = {'passwordConfigured': false, 'identities': []};
      await mount(t, AccountConnectionsView(controller: w, inline: true));
      await t.pumpAndSettle();
      final oldAction = t
          .widgetList<RaftButton>(find.byType(RaftButton))
          .singleWhere((button) => button.label == 'Set password by email')
          .onPressed!;
      client.user = RaftRecord({'id': 'next', 'email': 'next@example.invalid'});
      w.notifyListeners();
      await t.pumpAndSettle();
      oldAction();
      await t.pumpAndSettle();
      expect(find.byType(RaftFormDialog), findsNothing);
      expect(client.mutations, isEmpty);
    },
  );
}
