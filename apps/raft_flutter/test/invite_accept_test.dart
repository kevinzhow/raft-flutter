import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/features/global_server_selector.dart';
import 'package:raft_flutter/features/invite_accept_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

const _agreement = {
  'id': 'agreement-1',
  'title': 'Community agreement',
  'version': 3,
  'bodyMarkdown': 'Be kind.\n\n1. No spam',
};

Map<String, dynamic> _info({
  String kind = 'email',
  Map<String, dynamic>? agreement,
  bool seatLimit = false,
  bool hidden = false,
  int humans = 12,
  int agents = 5,
}) => {
  'kind': kind,
  'serverName': 'Raft Design',
  'inviterName': kind == 'email' ? 'Wenyi' : null,
  'memberCount': humans,
  'agentCount': agents,
  'insideCountsHidden': hidden,
  'humanSeatLimitReached': seatLimit,
  'agreement': agreement,
};

void main() {
  // Every host uses the same synthetic token. Keep the process-wide invite
  // cache within one test; warm-cache behavior is exercised explicitly below.
  setUp(InviteInfoMemory.clear);
  tearDown(InviteInfoMemory.clear);

  group('InviteLink', () {
    test('reads Web invite links, deep links and bare codes', () {
      expect(
        InviteLink.fromLocation(Uri.parse('/join/abc123'))?.token,
        'abc123',
      );
      expect(
        InviteLink.fromLocation(Uri.parse('/?invite=abc123'))?.token,
        'abc123',
      );
      expect(
        InviteLink.fromLocation(Uri.parse('raft://v1/join/abc123'))?.token,
        'abc123',
      );
      final full = InviteLink.fromLocation(
        Uri.parse('https://raft.example.com:8443/join/abc123'),
      );
      expect(full?.token, 'abc123');
      expect(full?.origin, 'https://raft.example.com:8443');
      expect(
        InviteLink.fromLocation(Uri.parse('/s/design/channel/c1')),
        isNull,
      );
      expect(InviteLink.fromLocation(Uri.parse('/join')), isNull);
      expect(InviteLink.fromInput('  abc123  ')?.token, 'abc123');
      expect(
        InviteLink.fromInput('https://raft.example.com/?invite=zzz')?.token,
        'zzz',
      );
      expect(
        InviteLink.fromInput('https://raft.example.com/x?token=ttt')?.token,
        'ttt',
      );
      expect(InviteLink.fromInput('   '), isNull);
      expect(InviteLink.fromInput('https://raft.example.com/nothing'), isNull);
    });
  });

  group('InviteAcceptView', () {
    Future<void> host(
      WidgetTester t, {
      required Future<Map<String, dynamic>> Function() loadInfo,
      Future<InviteJoined> Function(String?)? accept,
      Future<bool> Function(String)? onEnter,
      bool signedIn = true,
      VoidCallback? onSignIn,
      VoidCallback? onCreateAccount,
      VoidCallback? onGoToRaft,
      Locale locale = const Locale('en'),
    }) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(390, 900);
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: InviteAcceptView(
            key: UniqueKey(),
            token: 'tok',
            signedIn: signedIn,
            loadInfo: loadInfo,
            accept:
                accept ?? (_) async => const InviteJoined('s', 'Raft Design'),
            onEnter: onEnter ?? (_) async => true,
            onSignIn: onSignIn ?? () {},
            onCreateAccount: onCreateAccount ?? () {},
            onGoToRaft: onGoToRaft ?? () {},
          ),
        ),
      );
      await t.pump();
      await t.pump();
    }

    testWidgets('shows Loading invite… until the invite arrives', (t) async {
      final pending = Completer<Map<String, dynamic>>();
      await host(t, loadInfo: () => pending.future);
      expect(find.text('Loading invite…'), findsOneWidget);
      pending.complete(_info());
      await t.pump();
      await t.pump();
      expect(find.text("You're invited"), findsOneWidget);
      expect(find.text('Loading invite…'), findsNothing);
    });

    testWidgets('a cached invite paints while its revalidation is pending', (
      t,
    ) async {
      await host(t, loadInfo: () async => _info());
      expect(find.text("You're invited"), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());

      final pending = Completer<Map<String, dynamic>>();
      var loads = 0;
      await host(
        t,
        loadInfo: () {
          loads++;
          return pending.future;
        },
      );
      expect(loads, 1);
      expect(find.text("You're invited"), findsOneWidget);
      expect(find.text('Loading invite…'), findsNothing);
      expect(
        find.textContaining('Raft Design', findRichText: true),
        findsWidgets,
      );

      pending.complete({..._info(), 'serverName': 'Updated workspace'});
      await t.pump();
      await t.pump();
      expect(
        find.textContaining('Updated workspace', findRichText: true),
        findsWidgets,
      );
      expect(
        find.textContaining('Raft Design', findRichText: true),
        findsNothing,
      );
    });

    testWidgets(
      'an email invite names the inviter, the server and who is inside',
      (t) async {
        await host(t, loadInfo: () async => _info());
        expect(
          find.textContaining(
            'Wenyi invited you to join Raft Design on Raft.',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Meet 12 humans and 5 agents inside.',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(find.text('Join Server'), findsOneWidget);
      },
    );

    testWidgets('inside sentences: one count, singular, hidden and none', (
      t,
    ) async {
      await host(t, loadInfo: () async => _info(humans: 1, agents: 0));
      expect(
        find.textContaining('Meet 1 human inside.', findRichText: true),
        findsOneWidget,
      );
      await host(t, loadInfo: () async => _info(humans: 0, agents: 1));
      expect(
        find.textContaining('Meet 1 agent inside.', findRichText: true),
        findsOneWidget,
      );
      await host(t, loadInfo: () async => _info(hidden: true));
      expect(
        find.textContaining('Meet everyone inside.', findRichText: true),
        findsOneWidget,
      );
      await host(t, loadInfo: () async => _info(humans: 0, agents: 0));
      expect(find.textContaining('Meet', findRichText: true), findsNothing);
    });

    testWidgets('a join link has no inviter', (t) async {
      await host(t, loadInfo: () async => _info(kind: 'join_link'));
      expect(find.text('Join this server'), findsOneWidget);
      expect(
        find.textContaining(
          'Use this link to join Raft Design on Raft.',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('signed out offers Sign In and Create Account, never Join', (
      t,
    ) async {
      var signIn = 0, create = 0;
      await host(
        t,
        signedIn: false,
        loadInfo: () async => _info(),
        onSignIn: () => signIn++,
        onCreateAccount: () => create++,
      );
      expect(
        find.text('Sign in or create an account to accept this invite.'),
        findsOneWidget,
      );
      expect(find.text('Join Server'), findsNothing);
      await t.tap(find.byKey(const ValueKey('invite-sign-in')));
      await t.tap(find.byKey(const ValueKey('invite-create-account')));
      expect((signIn, create), (1, 1));
    });

    testWidgets(
      'expired, throttled and failed loads each show their own message',
      (t) async {
        var goes = 0;
        for (final (status, message) in [
          (404, 'This invite link is invalid or has expired.'),
          (429, 'Too many attempts. Wait a minute and try again.'),
          (500, 'Failed to load invite link. Try again.'),
        ]) {
          await host(
            t,
            loadInfo: () async => throw RaftApiException('x', status: status),
            onGoToRaft: () => goes++,
          );
          expect(find.text('Invite error'), findsOneWidget);
          expect(find.text(message), findsOneWidget);
          expect(find.text('Join Server'), findsNothing);
        }
        await t.tap(find.byKey(const ValueKey('invite-go-to-raft')));
        expect(goes, 1);
      },
    );

    testWidgets('no human seat: the notice and Go to Raft replace Join', (
      t,
    ) async {
      await host(t, loadInfo: () async => _info(seatLimit: true));
      expect(
        find.textContaining('no available human seats', findRichText: true),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('invite-join')), findsNothing);
      expect(find.byKey(const ValueKey('invite-go-to-raft')), findsOneWidget);
    });

    testWidgets('Join accepts, then opens the joined server', (t) async {
      final accepted = <String?>[];
      final entered = <String>[];
      await host(
        t,
        loadInfo: () async => _info(),
        accept: (agreement) async {
          accepted.add(agreement);
          return const InviteJoined('srv-9', 'Raft Design');
        },
        onEnter: (id) async {
          entered.add(id);
          return true;
        },
      );
      await t.tap(find.byKey(const ValueKey('invite-join')));
      await t.pump();
      await t.pump();
      expect(accepted, [null]);
      expect(entered, ['srv-9']);
    });

    testWidgets('an invite with an agreement shows it and joins with its id', (
      t,
    ) async {
      final accepted = <String?>[];
      await host(
        t,
        loadInfo: () async => _info(agreement: _agreement),
        accept: (agreement) async {
          accepted.add(agreement);
          return const InviteJoined('s', 'Raft Design');
        },
      );
      expect(find.text('Community agreement'), findsOneWidget);
      expect(find.text('Version 3'), findsOneWidget);
      expect(find.text('Join Server'), findsNothing);
      await t.tap(find.text('Agree & Join'));
      await t.pump();
      expect(accepted, ['agreement-1']);
    });

    testWidgets(
      'a rejected accept shows the server message and can be retried',
      (t) async {
        var attempts = 0;
        await host(
          t,
          loadInfo: () async => _info(),
          accept: (_) async {
            attempts++;
            throw RaftApiException.response(
              'This invite has already been used.',
              status: 400,
              body: {'error': 'This invite has already been used.'},
            );
          },
        );
        await t.tap(find.byKey(const ValueKey('invite-join')));
        await t.pump();
        await t.pump();
        expect(find.text('Invite error'), findsOneWidget);
        expect(find.text('This invite has already been used.'), findsOneWidget);
        expect(attempts, 1);
      },
    );

    testWidgets('a changed agreement replaces the shown one without an error', (
      t,
    ) async {
      var first = true;
      await host(
        t,
        loadInfo: () async => _info(agreement: _agreement),
        accept: (_) async {
          if (first) {
            first = false;
            throw RaftApiException.response(
              'agreement_changed',
              status: 409,
              body: {
                'error': 'agreement_changed',
                'agreement': {
                  ..._agreement,
                  'version': 4,
                  'title': 'Updated rules',
                },
              },
            );
          }
          return const InviteJoined('s', 'Raft Design');
        },
      );
      await t.tap(find.text('Agree & Join'));
      await t.pump();
      await t.pump();
      expect(find.text('Updated rules'), findsOneWidget);
      expect(find.text('Version 4'), findsOneWidget);
      expect(find.text('Invite error'), findsNothing);
    });

    testWidgets(
      'while the server list lacks the joined server, Continue retries then leaves',
      (t) async {
        final entered = <String>[];
        var goes = 0;
        await host(
          t,
          loadInfo: () async => _info(),
          onEnter: (id) async {
            entered.add(id);
            return false;
          },
          onGoToRaft: () => goes++,
        );
        await t.tap(find.byKey(const ValueKey('invite-join')));
        await t.pump();
        await t.pump();
        expect(find.text("You're in"), findsOneWidget);
        expect(
          find.textContaining("You've joined Raft Design.", findRichText: true),
          findsOneWidget,
        );
        await t.tap(find.text('Continue to Raft'));
        await t.pump();
        await t.pump();
        expect(entered, ['s', 's']);
        expect(goes, 1);
      },
    );

    testWidgets('Chinese copy comes from the Web catalog', (t) async {
      await host(
        t,
        loadInfo: () async => _info(),
        locale: const Locale('zh', 'CN'),
      );
      expect(find.text('你收到了邀请'), findsOneWidget);
      expect(
        find.textContaining(
          'Wenyi 邀请你加入 Raft 上的 Raft Design。',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('认识里面的 12 位人类 和 5 个 Agent。', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('加入服务器'), findsOneWidget);
    });
  });

  group('app root', () {
    void routes(RootFixture f, {Map<String, dynamic>? info}) {
      f.overrides['GET /auth/invite-info'] = (_) => info ?? _info();
      f.overrides['POST /auth/accept-invite'] = (o) {
        accepts.add(Map<String, dynamic>.from(o.data as Map));
        joined = true;
        return {'serverId': 'new', 'serverName': 'Raft Design'};
      };
      f.serverDirectory = () => [
        ...f.servers,
        if (joined)
          {
            'id': 'new',
            'name': 'Raft Design',
            'slug': 'raft-design',
            'role': 'member',
          },
      ];
    }

    setUp(() {
      accepts.clear();
      joined = false;
    });

    testWidgets(
      'a signed-in /join/<token> link opens the invite page and joining opens the server',
      (t) async {
        final f = RootFixture();
        routes(f);
        await f.mount(t, 'light', 390, uri: Uri(path: '/join/tok-1'));
        expect(find.byType(RaftInviteAcceptPage), findsOneWidget);
        expect(find.byType(WorkspaceView), findsNothing);
        expect(
          f.adapter.calls
              .where((c) => c.path == '/auth/invite-info')
              .single
              .queryParameters['token'],
          'tok-1',
        );
        // The link is consumed: the app is at the root, not at /join/…
        expect(f.router(t).currentConfiguration.path, '/');
        await t.tap(find.byKey(const ValueKey('invite-join')));
        await f.flush(t);
        expect(accepts, [
          {'token': 'tok-1'},
        ]);
        expect(find.byType(RaftInviteAcceptPage), findsNothing);
        expect(find.byType(WorkspaceView), findsOneWidget);
        expect(f.workspace(t).server!.id, 'new');
        expect(
          f.router(t).currentConfiguration.path,
          startsWith('/s/raft-design'),
        );
        await f.close(t);
      },
    );

    testWidgets('a rejected invite offers Go to Raft, which shows the app', (
      t,
    ) async {
      final f = RootFixture();
      routes(f);
      f.adapter.statuses['GET /auth/invite-info'] = 404;
      f.overrides['GET /auth/invite-info'] = (_) => {'error': 'Not found'};
      await f.mount(t, 'light', 390, uri: Uri(path: '/join/dead'));
      expect(
        find.text('This invite link is invalid or has expired.'),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('invite-go-to-raft')));
      await f.flush(t);
      expect(find.byType(RaftInviteAcceptPage), findsNothing);
      expect(find.byType(GlobalServerSelector), findsOneWidget);
      await f.close(t);
    });

    testWidgets('the Join workspace dialog opens the same page', (t) async {
      final f = RootFixture();
      routes(f);
      await f.mount(t, 'light', 1280);
      await t.tap(find.byKey(const ValueKey('global-server-a')));
      await f.flush(t);
      expect(find.byType(WorkspaceView), findsOneWidget);
      InviteRequests.instance.open(
        InviteLink.fromInput('https://fixture.invalid/join/from-dialog')!,
      );
      await f.flush(t);
      expect(find.byType(RaftInviteAcceptPage), findsOneWidget);
      expect(
        f.adapter.calls
            .where((c) => c.path == '/auth/invite-info')
            .last
            .queryParameters['token'],
        'from-dialog',
      );
      // Back leaves the page for the workspace that was open.
      expect(await f.router(t).popRoute(), isTrue);
      await f.flush(t);
      expect(find.byType(RaftInviteAcceptPage), findsNothing);
      expect(find.byType(WorkspaceView), findsOneWidget);
      await f.close(t);
    });

    testWidgets(
      'signed out: Sign In remembers the invite and resumes it after login',
      (t) async {
        final f = RootFixture();
        routes(f);
        f.adapter.statuses['GET /auth/me'] = 401;
        f.overrides['GET /auth/me'] = (_) => {'error': 'Unauthorized'};
        f.overrides['POST /auth/login'] = (_) => {
          'accessToken': 'fixture-only',
          'refreshToken': 'fixture-only',
          'user': {
            'id': 'alice',
            'name': 'alice',
            'email': 'alice@example.invalid',
            'emailVerified': true,
          },
        };
        await f.mount(t, 'light', 390, uri: Uri(path: '/join/tok-2'));
        expect(find.byType(RaftInviteAcceptPage), findsOneWidget);
        expect(find.byKey(const ValueKey('invite-join')), findsNothing);
        await t.tap(find.byKey(const ValueKey('invite-sign-in')));
        await f.flush(t);
        expect(find.byType(AuthView), findsOneWidget);
        expect(
          (await SharedPreferences.getInstance()).getString(
            'raft.pending-invite',
          ),
          'tok-2',
        );
        await t.enterText(
          find.byKey(const Key('login-email')),
          'alice@example.invalid',
        );
        await t.enterText(
          find.byKey(const Key('login-password')),
          'secret-password',
        );
        await t.tap(find.byKey(const Key('login-submit')));
        await f.flush(t);
        await f.flush(t);
        // The stored invite is resumed through the invite page, not joined silently.
        expect(find.byType(RaftInviteAcceptPage), findsOneWidget);
        expect(accepts, isEmpty);
        expect(find.byKey(const ValueKey('invite-join')), findsOneWidget);
        expect(
          (await SharedPreferences.getInstance()).getString(
            'raft.pending-invite',
          ),
          isNull,
        );
        await f.close(t);
      },
    );

    testWidgets('signed out: Create Account opens the register form', (
      t,
    ) async {
      final f = RootFixture();
      routes(f);
      f.adapter.statuses['GET /auth/me'] = 401;
      f.overrides['GET /auth/me'] = (_) => {'error': 'Unauthorized'};
      await f.mount(t, 'light', 390, uri: Uri(path: '/join/tok-3'));
      await t.tap(find.byKey(const ValueKey('invite-create-account')));
      await f.flush(t);
      expect(find.byType(AuthView), findsOneWidget);
      expect(find.byKey(const Key('register-legal')), findsOneWidget);
      await f.close(t);
    });
  });
}

final accepts = <Map<String, dynamic>>[];
bool joined = false;
