import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_flutter/platform/raft_app_links.dart';

import 'message_presentation_test.dart' show fixture;

class _PolicyNotifications extends NativeNotificationService {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> bind(String? scope) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  bool accepts(String value) =>
      RaftAppLinks.accepts(Uri.parse(value), on: true);
  const root = 'https://app.raft.build';

  test('private App invitations are native HTTPS entry points', () {
    expect(accepts('$root/integration-invites/invite_123'), isTrue);
    expect(accepts('https://app.slock.ai/integration-invites/token'), isTrue);
  });
  test('duplicate message anchors cannot enter account-restoration queue', () {
    expect(accepts('$root/s/team/channel/c?msg=a&msg=b'), isFalse);
  });
  test('unknown query parameters cannot disguise another route', () {
    expect(accepts('$root/s/team/channel/c?invite=foreign'), isFalse);
  });
  test('a fragment is not a message or invitation anchor', () {
    expect(accepts('$root/s/team/channel/c#private'), isFalse);
    expect(accepts('$root/join/token#fragment'), isFalse);
  });
  test('encoded separators and invalid IDs are rejected before routing', () {
    expect(accepts('$root/s/team%2Fother/channel/c'), isFalse);
    expect(accepts('$root/s/team/channel/c%2Fextra'), isFalse);
    expect(accepts('$root/s/team/dm/c!'), isFalse);
  });
  test('join token is one bounded segment without a query override', () {
    expect(accepts('$root/join/a%2Fb'), isFalse);
    expect(accepts('$root/join/token?invite=other'), isFalse);
    expect(accepts('$root/join/${'a' * 257}'), isFalse);
  });
  test('unbounded message URLs cannot be retained for account restoration', () {
    expect(accepts('$root/s/${'a' * 2050}/channel/c'), isFalse);
  });
  test('ordinary channel, DM and reply anchors remain accepted', () {
    expect(accepts('$root/s/team/channel/c?thread=c:p&msg=m'), isTrue);
    expect(accepts('$root/s/team/dm/d?msg=m'), isTrue);
    expect(accepts('$root/join/valid_token'), isTrue);
    expect(accepts('https://app.raft.build.evil.test/join/token'), isFalse);
    expect(accepts('$root:8443/join/token'), isFalse);
    expect(
      accepts('$root:443/join/token'),
      isTrue,
    ); // Uri normalizes the HTTPS default port.
    expect(
      RaftAppLinks.accepts(Uri.parse('$root/join/token'), on: false),
      isFalse,
    );
  });

  test('HTTPS opt-out also blocks navigation from a signed-in workspace', () async {
    final (w, box) = await fixture('owner');
    final coordinator = NativeContentCoordinator(
      notifications: _PolicyNotifications(),
      links: const Stream.empty(),
      appLinks: false,
    );
    addTearDown(() async {
      await coordinator.dispose();
      w.dispose();
      await w.client.dispose();
    });
    await coordinator.init();
    coordinator.bindWorkspace(w);
    final before = box.calls.length;
    coordinator.receiveLink(
      Uri.parse('https://example.invalid/s/test/channel/c1?msg=parent'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      box.calls.length,
      before,
      reason:
          'an opted-out HTTPS link cannot start membership or content requests',
    );
  });
}
