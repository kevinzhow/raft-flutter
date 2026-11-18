import 'package:flutter_test/flutter_test.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

void main() {
  for (final width in [390.0, 856.0, 1280.0]) {
    testWidgets(
      'external invitation previews only its masked address at $width',
      (tester) async {
        final f = RootFixture();
        f.adapter.statuses['GET /auth/me'] = 401;
        f.overrides['GET /external-invites/invitation/preview'] = (_) => {
          'status': 'valid',
          'invitedEmailMasked': 'g•••@example.invalid',
          'channelName': 'Private channel name',
        };
        await f.mount(
          tester,
          'raft',
          width,
          uri: Uri.parse('/external-invite/invitation'),
        );
        expect(find.text("You're invited to a channel"), findsOneWidget);
        expect(find.textContaining('g•••@example.invalid'), findsOneWidget);
        expect(find.textContaining('Private channel name'), findsNothing);
        expect(
          f.adapter.calls
              .singleWhere(
                (call) => call.path == '/external-invites/invitation/preview',
              )
              .headers
              .keys
              .map((key) => key.toLowerCase()),
          isNot(contains('authorization')),
        );
        expect(
          f.adapter.calls.where(
            (call) => call.path == '/external-invites/invitation',
          ),
          isEmpty,
        );
        await f.close(tester);
      },
    );
  }

  testWidgets('connection approval submits directly and shows progress', (
    tester,
  ) async {
    final f = RootFixture();
    f.overrides['GET /server-connect-requests/approval'] = (_) => {
      'id': 'approval',
      'status': 'pending',
      'channelName': 'project',
      'hostServerName': 'Alpha',
      'targetServer': {'id': 'b', 'name': 'Beta'},
      'requester': {'id': 'guest', 'name': 'Guest'},
      'canApprove': true,
    };
    f.overrides['POST /server-connect-requests/approval/approve'] = (_) => {
      'state': 'connecting',
    };
    await f.mount(
      tester,
      'raft',
      1280,
      cachedSession: true,
      uri: Uri.parse('/server-connect-requests/approval'),
    );
    expect(find.text('Connect Beta to #project?'), findsOneWidget);
    await tester.tap(find.text('Approve'));
    await f.flush(tester);
    expect(
      f.adapter.calls.where(
        (call) =>
            call.method == 'POST' &&
            call.path == '/server-connect-requests/approval/approve',
      ),
      hasLength(1),
    );
    expect(find.text('Approve'), findsNothing);
    await f.close(tester);
  });
}
