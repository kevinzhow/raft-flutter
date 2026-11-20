import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/integrations_views.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/screens/screen_fixture.dart';

class _AppsClient extends ScreenFixtureClient {
  _AppsClient(super.route)
    : super(user: const {'id': 'owner'}, server: 'server');

  final posts = <String, List<Object?>>{};
  final puts = <String, List<Object?>>{};

  @override
  Future<dynamic> post(String path, {dynamic data}) {
    (posts[path] ??= []).add(data);
    return super.post(path, data: data);
  }

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
  }) {
    if (method == 'PUT') (puts[path] ??= []).add(data);
    return super.request(
      method,
      path,
      data: data,
      query: query,
      authorized: authorized,
      retried: retried,
      cancellation: cancellation,
      onSendProgress: onSendProgress,
      headers: headers,
      acceptServerExit: acceptServerExit,
      receiveTimeout: receiveTimeout,
    );
  }
}

Future<void> _mount(
  WidgetTester tester,
  _AppsClient client, {
  TargetPlatform platform = TargetPlatform.android,
  Size size = const Size(856, 944),
}) async {
  final workspace = WorkspaceController(client)
    ..server = RaftRecord({'id': 'server', 'name': 'Garden', 'role': 'owner'});
  addTearDown(workspace.dispose);
  addTearDown(client.dispose);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: platform),
      home: Scaffold(body: IntegrationsView(controller: workspace)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder, warnIfMissed: true);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('installed apps includes server-local MCP apps', (tester) async {
    final client = _AppsClient((method, route, _) {
      if (route == '/mcp/apps') {
        return {
          'apps': [
            {
              'id': 'calendar-mcp',
              'name': 'Garden Calendar',
              'category': 'Productivity & Collaboration',
              'description': 'Plans garden work',
              'source': {'kind': 'official', 'maintainedByRaft': true},
            },
          ],
        };
      }
      return const <Object>[];
    });
    await _mount(tester, client);
    expect(find.text('Garden Calendar'), findsOneWidget);
    expect(find.textContaining('Maintained by Raft'), findsOneWidget);
    expect(find.text('MCP'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an app built here appears in Installed after installation', (
    tester,
  ) async {
    final client = _AppsClient((method, path, _) {
      if (path == '/integrations/clients') {
        return [
          _sourceApp,
          {
            ..._sourceApp,
            'id': 'irrigation',
            'name': 'Garden Irrigation',
            'installationId': 'installation',
          },
        ];
      }
      return const <Object>[];
    });
    await _mount(tester, client);
    expect(find.text('Garden Irrigation'), findsOneWidget);
    expect(find.text('Garden Notes'), findsNothing);
    await _tap(
      tester,
      find.byKey(const ValueKey('connected-apps-tab-my-apps')),
    );
    expect(find.text('Garden Notes'), findsOneWidget);
    expect(find.text('Garden Irrigation'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'review submits the visible text revision and a rejection reason',
    (tester) async {
      const path = '/integrations/clients/garden/prompt-text';
      var rejected = false;
      final client = _AppsClient((method, route, _) {
        if (route == '/feature-flags/evaluate') return _textConsent;
        if (route == '$path/review') {
          rejected = true;
          return const <String, Object>{};
        }
        if (route == path) {
          return {
            'can_review': true,
            'current': _revision('live', 'Garden Notes'),
            if (!rejected) 'pending': _revision('submitted', 'Garden Planner'),
          };
        }
        if (route == '/integrations/marketplace') {
          return [_promptApp];
        }
        if (route == '/integrations/marketplace/listings') {
          return {
            'items': [
              {'id': 'app:garden', 'kind': 'app', 'app': _promptApp},
            ],
            'total': 1,
          };
        }
        return const <Object>[];
      });
      await _mount(tester, client);
      await _tap(
        tester,
        find.byKey(const ValueKey('connected-apps-tab-marketplace')),
      );
      await _tap(tester, find.text('Garden Notes'));
      await _tap(tester, find.text('Reject text update'));
      expect(client.posts[path], isNull);
      await tester.enterText(
        find.byKey(const ValueKey('app-prompt-text-reject-reason')),
        '  Clarify the description  ',
      );
      await _tap(
        tester,
        find.byKey(const ValueKey('app-prompt-text-reject-confirm')),
      );
      expect(client.posts['$path/review'], [
        {
          'decision': 'reject',
          'expected_revision_id': 'submitted',
          'reason': 'Clarify the description',
        },
      ]);
      expect(find.text('Reject text update'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('listing opens while it checks whether text needs approval', (
    tester,
  ) async {
    final flag = Completer<Map<String, dynamic>>();
    final client = _AppsClient((method, path, _) {
      if (path == '/feature-flags/evaluate') return flag.future;
      if (path == '/integrations/marketplace') return [_promptApp];
      if (path == '/integrations/marketplace/listings') {
        return {
          'items': [
            {'id': 'app:garden', 'kind': 'app', 'app': _promptApp},
          ],
          'total': 1,
        };
      }
      return const <Object>[];
    });
    await _mount(tester, client);
    await _tap(
      tester,
      find.byKey(const ValueKey('connected-apps-tab-marketplace')),
    );
    await _tap(tester, find.text('Garden Notes'));
    expect(find.byKey(const ValueKey('connected-app-detail')), findsOneWidget);
    final install = find.byKey(const ValueKey('connected-app-install'));
    expect(tester.widget<RaftConnectedAppButton>(install).onPressed, isNull);
    flag.complete(_textConsent);
    await tester.pumpAndSettle();
    expect(tester.widget<RaftConnectedAppButton>(install).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('installed app adds and removes its bot with explicit consent', (
    tester,
  ) async {
    const path = '/integrations/clients/irrigation/install/bot';
    var grant = 'pending';
    final client = _AppsClient((method, route, _) {
      if (route == path) {
        grant = grant == 'pending' ? 'granted' : 'revoked';
        return {
          'botGrant': grant,
          'bot': grant == 'granted'
              ? {'handle': 'sprinkler', 'agentId': 'bot-1'}
              : null,
        };
      }
      if (route == '/integrations/marketplace') {
        return [
          {
            'id': 'irrigation',
            'name': 'Irrigation',
            'installedAt': '2026-11-01T00:00:00Z',
            'bot': {'offered': true, 'grant': grant, 'handle': 'sprinkler'},
          },
        ];
      }
      return const <Object>[];
    });
    await _mount(tester, client);
    await _tap(tester, find.text('Irrigation'));
    await _tap(tester, find.text('Add @sprinkler to Garden'));
    expect(client.posts[path], [
      {'action': 'grant'},
    ]);
    expect(find.text('Added to server'), findsOneWidget);
    await _tap(tester, find.text('Remove'));
    expect(find.text('Remove @sprinkler?'), findsOneWidget);
    expect(client.posts[path], hasLength(1));
    final confirmRemove = find.descendant(
      of: find.byKey(const ValueKey('connected-app-bot-remove-dialog')),
      matching: find.text('Remove'),
    );
    await _tap(tester, confirmRemove);
    expect(client.posts[path], [
      {'action': 'grant'},
      {'action': 'revoke'},
    ]);
    expect(find.text('Remove @sprinkler?'), findsNothing);
    expect(find.text('Added to server'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a late prompt text review preserves edits already entered', (
    tester,
  ) async {
    const path = '/integrations/clients/garden/prompt-text';
    final pending = Completer<Map<String, dynamic>>();
    final client = _AppsClient((method, route, _) {
      if (route == '/feature-flags/evaluate') return _textConsent;
      if (route == '/integrations/clients') return [_sourceApp];
      if (route == path) return pending.future;
      if (route == '/integrations/clients/garden/app-notifications') {
        return {'current_groups': [], 'current_events': []};
      }
      return const <Object>[];
    });
    await _mount(tester, client);
    await _tap(
      tester,
      find.byKey(const ValueKey('connected-apps-tab-my-apps')),
    );
    await _tap(
      tester,
      find.byKey(const ValueKey('connected-app-action-garden')),
    );
    final input = find.descendant(
      of: find.byKey(const ValueKey('connected-app-name')),
      matching: find.byType(EditableText),
    );
    await tester.ensureVisible(input);
    expect(tester.widget<EditableText>(input).controller.text, 'Garden Notes');
    await tester.enterText(input, 'Unsaved garden notes');
    pending.complete({
      'current': _revision('live', 'Garden Notes'),
      'pending': _revision('submitted', 'Garden Planner'),
      'local_confirmed_revision_id': 'live',
    });
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(input).controller.text,
      'Unsaved garden notes',
    );
    expect(find.textContaining('Garden Planner'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('confirm text reviews the replacement revision before retry', (
    tester,
  ) async {
    const path = '/integrations/clients/garden/prompt-text';
    var confirmations = 0;
    final client = _AppsClient((method, route, _) {
      if (route == '/feature-flags/evaluate') return _textConsent;
      if (route == '/integrations/clients') return [_sourceApp];
      if (route == path) return {'current': _revision('live', 'Garden Notes')};
      if (route == '$path/confirm' && confirmations++ == 0) {
        throw RaftApiException.response(
          'Changed',
          status: 409,
          body: {
            'error': 'Changed',
            'code': 'APP_PERMISSIONS_CHANGED',
            'current_text_revision_id': 'replacement',
            'current_text': _revision('replacement', 'New Garden Notes'),
          },
        );
      }
      if (route == '/integrations/clients/garden/app-notifications') {
        return {'current_groups': [], 'current_events': []};
      }
      return const <Object>[];
    });
    await _mount(tester, client);
    await _tap(
      tester,
      find.byKey(const ValueKey('connected-apps-tab-my-apps')),
    );
    await _tap(
      tester,
      find.byKey(const ValueKey('connected-app-action-garden')),
    );
    await _tap(tester, find.text('Confirm text'));
    expect(find.textContaining('New Garden Notes'), findsWidgets);
    expect(confirmations, 1);
    await _tap(tester, find.text('Confirm text'));
    expect(client.puts['$path/confirm'], [
      {'expected_revision_id': 'live'},
      {'expected_revision_id': 'replacement'},
    ]);
    expect(find.text('Confirm text'), findsNothing);
    expect(find.byKey(const ValueKey('connected-app-editor')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('withdrawing a publish request keeps the editor and app', (
    tester,
  ) async {
    const path = '/integrations/clients/garden/withdraw-publish';
    var withdrawn = false;
    Map<String, dynamic> app() => {
      'id': 'garden',
      'clientId': 'garden',
      'name': 'Garden Notes',
      'appType': 'third_party_global',
      'publishStatus': withdrawn ? 'private' : 'publish_requested',
    };
    final client = _AppsClient((method, route, _) {
      if (route == path) {
        withdrawn = true;
        return app();
      }
      if (route == '/integrations/clients') return [app()];
      if (route == '/integrations/clients/garden/app-notifications') {
        return {'current_groups': [], 'current_events': []};
      }
      return const <Object>[];
    });
    await _mount(
      tester,
      client,
      platform: TargetPlatform.linux,
      size: const Size(390, 844),
    );
    final scope = find.byKey(const ValueKey('connected-apps-scope-select'));
    if (scope.evaluate().isNotEmpty) {
      await _tap(tester, scope);
      await _tap(tester, find.text('Developer'));
    } else {
      await _tap(
        tester,
        find.byKey(const ValueKey('connected-apps-tab-my-apps')),
      );
    }
    await _tap(
      tester,
      find.byKey(const ValueKey('connected-app-action-garden')),
    );
    await _tap(tester, find.text('Withdraw request'));
    expect(client.posts[path], [null]);
    expect(find.byKey(const ValueKey('connected-app-editor')), findsOneWidget);
    expect(find.text('Withdraw request'), findsNothing);
    expect(find.text('Private share link'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('link previews can be revoked and allowed from Applications', (
    tester,
  ) async {
    var allowed = true;
    final client = _AppsClient((method, route, _) {
      const path = '/integrations/clients/irrigation/link-preview-';
      const choice = {
        'app': {'id': 'irrigation', 'name': 'Irrigation', 'icon': null},
        'declined_at': '2026-11-03T08:00:00Z',
        'granted_at': '2026-11-03T08:00:00Z',
      };
      if (route == '/integrations/link-preview-consents') {
        return {
          'allowed': [if (allowed) choice],
          'declined': [if (!allowed) choice],
        };
      }
      if (route == '${path}consent' || route == '${path}decline') {
        allowed = route.endsWith('consent');
        return choice;
      }
      return const <Object>[];
    });
    await _mount(tester, client, size: const Size(944, 856));
    await _tap(
      tester,
      find.byKey(const ValueKey('link-preview-consents-manage')),
    );
    expect(find.text('Search apps'), findsNothing);
    await _tap(tester, find.text('Revoke'));
    expect(
      client.posts['/integrations/clients/irrigation/link-preview-decline'],
      isNull,
    );
    await _tap(
      tester,
      find.byKey(const ValueKey('link-preview-consents-revoke-confirm')),
    );
    expect(
      client.posts.keys,
      contains('/integrations/clients/irrigation/link-preview-decline'),
    );
    expect(find.text('Revoke'), findsNothing);
    await _tap(tester, find.text('Allow'));
    expect(
      client.posts.keys,
      contains('/integrations/clients/irrigation/link-preview-consent'),
    );
    expect(find.text('Allow'), findsNothing);
    expect(find.text('Revoke'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

const _textConsent = {
  'evaluations': [
    {'key': 'app_prompt_text_consent', 'enabled': true},
  ],
};

const _promptApp = {
  'id': 'garden',
  'clientId': 'garden',
  'name': 'Garden Notes',
  'promptTextRevisionId': 'live',
  'whenToUse': 'Garden planning',
};

const _sourceApp = {
  ..._promptApp,
  'appType': 'server_local',
  'publishStatus': 'private',
};

Map<String, Object?> _revision(String id, String name) => {
  'id': id,
  'name': name,
  'when_to_use': 'Garden planning',
};
