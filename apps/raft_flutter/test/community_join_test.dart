import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/community_join.dart';
import 'package:raft_flutter/features/global_server_selector.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

const _agreement = {
  'id': 'agreement-1',
  'title': 'Community agreement',
  'version': 3,
  'bodyMarkdown': 'Be kind.\n\n1. No spam\n2. Stay on topic',
};

final _community = {
  'id': 'new',
  'name': 'Raft Community',
  'slug': 'community',
  'role': 'member',
};

/// The community joins once a POST carried the agreement (or, without an
/// agreement, at once); the directory then lists it.
class _Community {
  _Community(this.f, {required this.needsAgreement}) {
    f.serverDirectory = () => [...f.servers, if (joined) _community];
    f.overrides['POST /servers/join-community'] = (o) {
      final data = o.data as Map;
      posts.add(Map<String, dynamic>.from(data));
      final key = 'POST /servers/join-community';
      if (needsAgreement && data['agreementId'] == null) {
        f.adapter.statuses[key] = 409;
        return {'error': 'agreement_required', 'agreement': _agreement};
      }
      f.adapter.statuses.remove(key);
      joined = true;
      return {'id': 'new', 'name': 'Raft Community'};
    };
  }
  final RootFixture f;
  final bool needsAgreement;
  bool joined = false;
  final posts = <Map<String, dynamic>>[];
}

void main() {
  testWidgets(
    '/s/community joins on arrival behind the Joining community splash',
    (t) async {
      final f = RootFixture();
      final held = Completer<dynamic>();
      final community = _Community(f, needsAgreement: false);
      f.holds['POST /servers/join-community'] = held;
      await f.mount(t, 'light', 390, uri: Uri(path: '/s/community'));
      expect(find.byKey(const ValueKey('joining-community')), findsOneWidget);
      expect(find.text('Joining community…'), findsOneWidget);
      expect(find.byType(GlobalServerSelector), findsNothing);
      held.complete(null);
      await f.flush(t);
      expect(community.posts, [
        {'slug': 'community'},
      ]);
      expect(find.byType(WorkspaceView), findsOneWidget);
      expect(f.workspace(t).server!.id, 'new');
      expect(f.router(t).currentConfiguration.path, startsWith('/s/community'));
      await f.close(t);
    },
  );

  testWidgets(
    'an agreement opens the dialog over the not-found page and Agree joins',
    (t) async {
      final f = RootFixture();
      final community = _Community(f, needsAgreement: true);
      await f.mount(t, 'light', 1280, uri: Uri(path: '/s/community'));
      expect(find.byType(RaftCommunityAgreementDialog), findsOneWidget);
      expect(find.byType(RaftServerAccessDeniedPage), findsOneWidget);
      expect(find.text('Community agreement'), findsOneWidget);
      expect(find.text('Version 3'), findsOneWidget);
      expect(
        find.textContaining('Stay on topic', findRichText: true),
        findsOneWidget,
      );
      await t.tap(find.text('Agree & Continue'));
      await f.flush(t);
      expect(community.posts, [
        {'slug': 'community'},
        {'slug': 'community', 'agreementId': 'agreement-1'},
      ]);
      expect(find.byType(RaftCommunityAgreementDialog), findsNothing);
      expect(find.byType(WorkspaceView), findsOneWidget);
      expect(f.workspace(t).server!.id, 'new');
      await f.close(t);
    },
  );

  testWidgets('declining leaves the not-found page, which still redirects', (
    t,
  ) async {
    final f = RootFixture();
    _Community(f, needsAgreement: true);
    await f.mount(t, 'light', 1280, uri: Uri(path: '/s/community'));
    await f.flush(t);
    await t.tap(find.byKey(const ValueKey('community-agreement-cancel')));
    await f.flush(t);
    expect(find.byType(RaftCommunityAgreementDialog), findsNothing);
    expect(find.byType(RaftServerAccessDeniedPage), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    await f.flush(t);
    expect(find.byType(WorkspaceView), findsOneWidget);
    expect(f.workspace(t).server!.id, 'a');
    await f.close(t);
  });

  testWidgets('the redirect closes an open agreement dialog', (t) async {
    final f = RootFixture();
    _Community(f, needsAgreement: true);
    await f.mount(t, 'light', 1280, uri: Uri(path: '/s/community'));
    await f.flush(t);
    expect(find.byType(RaftCommunityAgreementDialog), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    await f.flush(t);
    expect(find.byType(RaftCommunityAgreementDialog), findsNothing);
    expect(find.byType(WorkspaceView), findsOneWidget);
    await f.close(t);
  });

  testWidgets('a failed join shows the not-found page without a dialog', (
    t,
  ) async {
    final f = RootFixture();
    f.overrides['POST /servers/join-community'] = (_) {
      f.adapter.statuses['POST /servers/join-community'] = 403;
      return {'error': 'Server seat limit reached'};
    };
    await f.mount(t, 'light', 390, uri: Uri(path: '/s/community'));
    expect(find.byType(RaftCommunityAgreementDialog), findsNothing);
    expect(find.byType(RaftServerAccessDeniedPage), findsOneWidget);
    await f.close(t);
  });

  test('requestCommunityJoin classifies the answers', () async {
    // The agreement the server sends back survives the client's error receipt.
    final client = _StubClient((method, path, data) {
      if (data['agreementId'] == null) {
        throw RaftApiException.response(
          'agreement_changed',
          status: 409,
          body: {'error': 'agreement_changed', 'agreement': _agreement},
        );
      }
      if (data['agreementId'] == 'x') {
        throw const RaftApiException('Server seat limit reached', status: 403);
      }
      return {};
    });
    final first = await requestCommunityJoin(client, 'community');
    expect(first, isA<CommunityAgreementRequired>());
    final agreement = first as CommunityAgreementRequired;
    expect(
      (agreement.id, agreement.title, agreement.version),
      ('agreement-1', 'Community agreement', 3),
    );
    expect(
      (await requestCommunityJoin(client, 'community', agreementId: 'ok')),
      isA<CommunityJoined>(),
    );
    final failed = await requestCommunityJoin(
      client,
      'community',
      agreementId: 'x',
    );
    expect(failed, isA<CommunityJoinFailed>());
    expect(
      ((failed as CommunityJoinFailed).error as RaftApiException).message,
      'Server seat limit reached',
    );
  });

  group('RaftCommunityAgreementDialog', () {
    Future<void> host(
      WidgetTester t, {
      required Future<void> Function() onAgree,
      VoidCallback? onClose,
      Locale locale = const Locale('en'),
    }) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(600, 800);
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (context) => RaftCommunityAgreementDialog(
              title: 'Community agreement',
              version: 3,
              bodyMarkdown: _agreement['bodyMarkdown'] as String,
              onClose: onClose ?? () {},
              onAgree: onAgree,
              errorMessage: communityAgreementError,
            ),
          ),
        ),
      );
      await t.pump();
    }

    testWidgets('the buttons read Joining… and are disabled while joining', (
      t,
    ) async {
      final pending = Completer<void>();
      await host(t, onAgree: () => pending.future);
      await t.tap(find.text('Agree & Continue'));
      await t.pump();
      expect(find.text('Joining…'), findsOneWidget);
      final cancel = t.widget<RaftRecipeButton>(
        find.byKey(const ValueKey('community-agreement-cancel')),
      );
      expect(cancel.disabled, isTrue);
      pending.complete();
      await t.pump();
      expect(find.text('Agree & Continue'), findsOneWidget);
    });

    testWidgets('a changed agreement and any other failure use their own copy', (
      t,
    ) async {
      Object failure = const RaftApiException('agreement_changed');
      await host(t, onAgree: () async => throw failure);
      await t.tap(find.text('Agree & Continue'));
      await t.pump();
      expect(
        find.text(
          'The agreement was updated. Open the join action again to review the latest version.',
        ),
        findsOneWidget,
      );
      failure = const RaftApiException('boom');
      await t.tap(find.text('Agree & Continue'));
      await t.pump();
      expect(find.text('Failed to join community server'), findsOneWidget);
    });

    testWidgets(
      'close and Cancel report once; Chinese copy comes from the catalog',
      (t) async {
        var closed = 0;
        await host(
          t,
          onAgree: () async {},
          onClose: () => closed++,
          locale: const Locale('zh', 'CN'),
        );
        expect(find.text('版本 3'), findsOneWidget);
        expect(find.text('同意并继续'), findsOneWidget);
        await t.tap(find.text('取消'));
        expect(closed, 1);
      },
    );
  });
}

class _StubClient extends RaftClient {
  _StubClient(this.answer)
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final Object? Function(String method, String path, Map data) answer;
  @override
  Future<dynamic> post(String path, {dynamic data}) async =>
      answer('POST', path, data as Map);
}
