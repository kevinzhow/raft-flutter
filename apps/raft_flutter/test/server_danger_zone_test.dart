import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/server_views.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/screens/screen_fixture.dart';

/// Web v1.24 DangerZoneSection / DangerActionRow / DeleteServerConfirmDialog
/// and ProfileSection (Settings > Server).
class _Fixture {
  _Fixture(String role, {this.failExit = false}) {
    client = ScreenFixtureClient(
      (method, path, query) {
        requests.add('$method $path');
        if (failExit && (path == '/servers/s' || path == '/servers/s/leave')) {
          throw RaftApiException.response(
            'Could not leave',
            status: 500,
            body: {'error': 'Could not leave'},
          );
        }
        return <String, dynamic>{};
      },
      user: {'id': 'alice'},
      server: 's',
    );
    w = WorkspaceController(client)
      ..server = RaftRecord({
        'id': 's',
        'name': 'Moon',
        'slug': 'moon',
        'role': role,
      });
    w.servers = [w.server!];
    addTearDown(w.dispose);
  }
  final bool failExit;
  late final ScreenFixtureClient client;
  late final WorkspaceController w;
  final requests = <String>[];

  Future<void> mount(WidgetTester t, {double width = 1000}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = Size(width, 1400);
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: ServerSettingsView(controller: w)),
      ),
    );
    await t.pump();
  }
}

final _leave = find.byKey(const Key('server-danger-leave-button'));
final _delete = find.byKey(const Key('server-danger-delete-button'));

void main() {
  testWidgets('an owner sees only Delete, an admin only Leave', (t) async {
    await _Fixture('owner').mount(t);
    expect(_delete, findsOneWidget);
    expect(_leave, findsNothing);
    await _Fixture('admin').mount(t);
    expect(_leave, findsOneWidget);
    expect(_delete, findsNothing);
  });

  // DangerActionRow: a row of a ListRowGroup of its own, the button `md`.
  testWidgets('each danger action is a DangerActionRow', (t) async {
    await _Fixture('admin').mount(t);
    expect(find.byType(RaftDangerActionRow), findsOneWidget);
    expect(find.byKey(const Key('server-danger-leave-card')), findsOneWidget);
    await _Fixture('owner').mount(t);
    expect(find.byType(RaftDangerActionRow), findsOneWidget);
    expect(find.byKey(const Key('server-danger-delete-card')), findsOneWidget);
  });

  // DangerZoneSection: the Leave confirm's button reads `leaveServerConfirm`.
  testWidgets('the Leave confirm button says Leave and leaving runs at once', (
    t,
  ) async {
    final f = _Fixture('member');
    await f.mount(t);
    await t.tap(_leave);
    await t.pumpAndSettle();
    final confirm = find.byKey(const Key('server-leave-confirm-button'));
    expect(
      find.descendant(of: confirm, matching: find.text('Leave')),
      findsOneWidget,
    );
    await t.tap(confirm);
    await t.pumpAndSettle();
    expect(f.requests, contains('POST /servers/s/leave'));
  });

  // ConfirmDialog onConfirm: a failed leave keeps the dialog open with the
  // error (it was thrown from the tap handler after the dialog closed).
  testWidgets('a failed leave stays in the dialog with the error', (t) async {
    final f = _Fixture('member', failExit: true);
    await f.mount(t);
    await t.tap(_leave);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('server-leave-confirm-button')));
    await t.pumpAndSettle();
    expect(
      find.byKey(const Key('server-leave-confirm-button')),
      findsOneWidget,
    );
    expect(find.byType(RaftErrorBanner), findsOneWidget);
  });

  // ProfileSection.tsx (v1.24): the save button is `md`.
  testWidgets('the profile save button is size md', (t) async {
    await _Fixture('owner').mount(t);
    final button = t.widget<RaftSettingsRecipeButton>(
      find.byKey(const Key('server-profile-save-button')),
    );
    expect(button.size, RaftButtonRecipeSize.md);
  });

  // DeleteServerConfirmDialog: type the slug, delete runs in the dialog, a
  // failure keeps it open.
  testWidgets('a failed delete stays in the dialog with the error', (t) async {
    final f = _Fixture('owner', failExit: true);
    await f.mount(t);
    await t.tap(_delete);
    await t.pumpAndSettle();
    final confirm = find.byKey(const Key('server-delete-confirm-button'));
    await t.enterText(
      find.descendant(
        of: find.byKey(const Key('server-delete-slug-input')),
        matching: find.byType(EditableText),
      ),
      'moon',
    );
    await t.pump();
    await t.tap(confirm);
    await t.pumpAndSettle();
    expect(f.requests, contains('DELETE /servers/s'));
    expect(confirm, findsOneWidget);
    expect(find.byType(RaftErrorBanner), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
  });
}
