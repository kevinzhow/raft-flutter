import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'support/server_tab.dart';

void main() {
  testWidgets('hidden permission changes are read once when shown', (
    tester,
  ) async {
    const path = '/integrations/permission-updates';
    final fixture = RootFixture();
    fixture.overrides['GET $path'] = (_) => {'count': 0};
    await fixture.mount(tester, 'light', 390, uri: Uri.parse('/s/alpha/tasks'));
    final reads = fixture.adapter.calls.where(
      (request) => request.path == path,
    );
    final setLifecycle = tester.binding.handleAppLifecycleStateChanged;
    expect(reads, hasLength(1));
    setLifecycle(AppLifecycleState.inactive);
    setLifecycle(AppLifecycleState.hidden);
    final serverId = fixture.workspace(tester).server!.id;
    fixture.client.event('permission-updates:changed', {'serverId': serverId});
    fixture.client.event('permission-updates:changed', {'serverId': serverId});
    await tester.pump();
    expect(reads, hasLength(1));
    setLifecycle(AppLifecycleState.inactive);
    setLifecycle(AppLifecycleState.resumed);
    await fixture.flush(tester);
    expect(reads, hasLength(2));
    setLifecycle(AppLifecycleState.inactive);
    setLifecycle(AppLifecycleState.hidden);
    setLifecycle(AppLifecycleState.inactive);
    setLifecycle(AppLifecycleState.resumed);
    await fixture.flush(tester);
    expect(reads, hasLength(2));
    await fixture.close(tester);
  });

  testWidgets('a cold Tasks route loads the server popover Apps dot', (
    tester,
  ) async {
    const path = '/integrations/permission-updates';
    final fixture = RootFixture();
    fixture.overrides['GET $path'] = (_) => {
      'count': 1,
      'needsAdminReview': true,
    };
    await fixture.mount(tester, 'light', 390, uri: Uri.parse('/s/alpha/tasks'));
    final summaryReads = fixture.adapter.calls.where(
      (request) => request.path == path,
    );
    expect(summaryReads, hasLength(1));
    await openServerPopover(tester, flush: fixture.flush);
    expect(find.byKey(const Key('apps-attention-dot')), findsOneWidget);
    expect(summaryReads, hasLength(1));
    await fixture.close(tester);
  });

  testWidgets('reviewing an app clears the bell notice and the Apps dot', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const notificationPath = '/integrations/permission-updates';
    const permissionPath =
        '/integrations/marketplace/garden/install/app-notifications';
    var pending = true;
    final fixture = RootFixture();
    fixture.overrides.addAll({
      'GET $notificationPath': (_) => {
        'count': pending ? 1 : 0,
        'needsAdminReview': pending,
      },
      'GET /integrations/clients': (_) => [],
      'GET /integrations/overview': (_) => [],
      'GET /mcp/apps': (_) => {'apps': []},
      'GET /integrations/link-preview-consents': (_) => {
        'allowed': [],
        'declined': [],
      },
      'GET /integrations/marketplace': (_) => [
        {
          'id': 'garden',
          'clientId': 'garden',
          'name': 'Garden',
          'installedAt': '2026-11-20T00:00:00Z',
          'permissionApprovalRequired': pending,
          'needsAdminReview': pending,
        },
      ],
      'GET $permissionPath': (_) => {
        'requested_scopes': ['openid'],
        'requested_groups': ['server', 'agent'],
        'approved_groups': ['server', if (!pending) 'agent'],
        'approval_required': pending,
      },
      'PUT $permissionPath/grant': (_) {
        pending = false;
        return {};
      },
    });
    await fixture.mount(tester, 'light', 390, uri: Uri.parse('/s/alpha'));
    Future<void> tap(Finder target) async {
      await tester.ensureVisible(target);
      await tester.tap(target);
      await fixture.flush(tester);
      await tester.pumpAndSettle();
    }

    const dot = Key('apps-attention-dot');
    final bell = find.byKey(const Key('mobile-home-notifications'));
    await openServerPopover(tester, flush: fixture.flush);
    expect(find.byKey(dot), findsOneWidget);
    await tap(find.byKey(serverTabKey));
    await tap(bell);
    await tap(find.text('View updates'));
    expect(fixture.workspace(tester).location.uri.path, '/s/alpha/apps');
    expect(
      find.byKey(const Key('connected-app-installed-detail')),
      findsOneWidget,
    );
    await tap(find.text('Close').last);
    final appDot = find.bySemanticsLabel(RegExp('Needs your review'));
    expect(appDot, findsOneWidget);
    await tap(find.byKey(const Key('connected-app-review-permissions-garden')));
    expect(
      find.byKey(const Key('connected-app-installed-detail')),
      findsOneWidget,
    );
    await tap(find.text('Approve update'));
    expect(pending, isFalse);
    expect(find.text('Approve update'), findsNothing);
    expect(
      fixture.adapter.calls
          .where((request) => request.path == '$permissionPath/grant')
          .single
          .data,
      {
        'expected_scopes': ['openid'],
        'expected_groups': ['server', 'agent'],
      },
    );
    await tap(find.text('Close').last);
    expect(appDot, findsNothing);
    expect(
      find.byKey(const Key('connected-app-review-permissions-garden')),
      findsNothing,
    );
    await tap(find.byKey(const Key('apps-mobile-back')));
    await openServerPopover(tester, flush: fixture.flush);
    expect(find.byKey(dot), findsNothing);
    await tap(find.byKey(serverTabKey));
    await tap(bell);
    expect(find.text('View updates'), findsNothing);
    await fixture.close(tester);
    semantics.dispose();
  });
}
