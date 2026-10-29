import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/invite_accept_view.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_flutter/platform/raft_app_links.dart';

class _Notifications extends NativeNotificationService {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> bind(String? scope) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = 'https://app.raft.build/s/acme/channel/c1?msg=m1';

  group('which https links are Raft links (RaftAppLinks)', () {
    test('the switch is off in every build until the domain is ready', () {
      expect(RaftAppLinks.enabled, isFalse);
      expect(RaftAppLinks.accepts(Uri.parse(channel)), isFalse);
      expect(
        RaftAppLinks.accepts(Uri.parse('https://app.raft.build/join/t')),
        isFalse,
      );
    });

    test('on: message links and invites of the production hosts only', () {
      bool ok(String url) => RaftAppLinks.accepts(Uri.parse(url), on: true);
      expect(ok(channel), isTrue);
      expect(ok('https://app.raft.build/s/acme/dm/d1'), isTrue);
      expect(
        ok('https://app.raft.build/s/acme/channel/c1?thread=c1:p&msg=m'),
        isTrue,
      );
      expect(ok('https://app.slock.ai/s/acme/channel/c1'), isTrue);
      expect(ok('https://app.raft.build/join/token123'), isTrue);
      // Not Raft's hosts, not https, not a claimed path.
      expect(ok('https://staging.slock.ai/s/acme/channel/c1'), isFalse);
      expect(ok('https://example.com/s/acme/channel/c1'), isFalse);
      expect(ok('http://app.raft.build/s/acme/channel/c1'), isFalse);
      expect(ok('https://app.raft.build:8443/s/acme/channel/c1'), isFalse);
      expect(ok('https://user@app.raft.build/s/acme/channel/c1'), isFalse);
      expect(ok('https://app.raft.build/'), isFalse);
      expect(ok('https://app.raft.build/s/acme/settings/account'), isFalse);
      expect(ok('https://app.raft.build/s/acme/channel'), isFalse);
      expect(ok('https://app.raft.build/s/acme/channel/c1/extra'), isFalse);
      expect(ok('https://app.raft.build/join'), isFalse);
      expect(ok('https://app.raft.build.evil.test/join/t'), isFalse);
      expect(ok('raft://v1/join/t'), isFalse);
    });
  });

  group('the coordinator', () {
    late NativeContentCoordinator Function(bool) make;
    final made = <NativeContentCoordinator>[];
    setUp(() {
      make = (appLinks) {
        final c = NativeContentCoordinator(
          notifications: _Notifications(),
          links: const Stream.empty(),
          appLinks: appLinks,
        );
        made.add(c);
        return c;
      };
      InviteRequests.instance.take();
    });
    tearDown(() async {
      for (final c in made) {
        await c.dispose();
      }
      made.clear();
      InviteRequests.instance.take();
    });

    test('off: an https Raft link never reaches the app', () async {
      final links = make(false);
      await links.init();
      links.receiveLink(Uri.parse('https://app.raft.build/join/token123'));
      links.receiveLink(Uri.parse(channel));
      expect(InviteRequests.instance.take(), isNull);
      expect(links.pendingLink, isNull);
    });

    test('on: an invite opens the invite page, signed in or not', () async {
      final links = make(true);
      await links.init();
      links.receiveLink(Uri.parse('https://app.raft.build/join/token123'));
      final invite = InviteRequests.instance.take();
      expect(invite?.token, 'token123');
      // A link of another host is no Raft link.
      links.receiveLink(Uri.parse('https://example.com/join/token123'));
      expect(InviteRequests.instance.take(), isNull);
    });

    test('on: a message link waits for the account to be restored', () async {
      final links = make(true);
      await links.init();
      final uri = Uri.parse(channel);
      links.receiveLink(uri);
      expect(links.pendingLink, uri);
      // Only Raft links wait; nothing else is kept for later.
      final other = make(true);
      await other.init();
      other.receiveLink(Uri.parse('https://example.com/s/acme/channel/c1'));
      expect(other.pendingLink, isNull);
    });
  });
}
