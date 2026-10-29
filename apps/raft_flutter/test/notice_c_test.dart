import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/account_onboarding.dart';
import 'package:raft_flutter/features/archived_channels_section.dart';
import 'package:raft_flutter/features/invite_accept_view.dart';
import 'package:raft_flutter/features/locale_settings_page.dart';
import 'package:raft_flutter/features/member_profile_view.dart';
import 'package:raft_flutter/features/server_setup_gate.dart';
import 'package:raft_flutter/features/server_views.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;
import 'native_notifications_test.dart' show NotificationPluginFixture;
import 'parity/cases/screens/screen_fixture.dart';

/// Transient-notice audit, slice C (settings / account / auth / onboarding):
/// every notice below used to outlive its cause.
Widget _app(Widget home) => MaterialApp(
  theme: raftTheme(),
  supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(body: home),
);

RaftApiException _refused(String message, [int status = 409]) =>
    RaftApiException.response(
      message,
      status: status,
      body: {'error': message},
    );

class _AndroidFixture extends AndroidFlutterLocalNotificationsPlugin {
  @override
  Future<bool?> areNotificationsEnabled() async => true;
  @override
  Future<bool?> requestNotificationsPermission() async => true;
}

class _Preferences extends NotificationPreferenceStore {
  bool unreadable = true;
  @override
  Future<bool?> read(String key) async {
    if (unreadable) throw StateError('unreadable');
    return false;
  }
}

void main() {
  group('MembersView load error', () {
    testWidgets('a retry that succeeds ends the load error', (t) async {
      var fail = true;
      final client = ScreenFixtureClient(
        (method, path, query) {
          if (path == '/servers/s/members') {
            if (fail) throw _refused('Members are unavailable', 503);
            return [
              {'userId': 'bob', 'name': 'bob', 'role': 'member'},
            ];
          }
          return <dynamic>[];
        },
        user: {'id': 'alice'},
        server: 's',
      );
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'name': 'S', 'role': 'owner'});
      addTearDown(w.dispose);
      await t.pumpWidget(_app(MembersView(controller: w)));
      await t.pumpAndSettle();
      expect(find.text('Members are unavailable'), findsOneWidget);
      fail = false;
      await t.tap(find.text('Retry'));
      await t.pumpAndSettle();
      expect(find.text('Members are unavailable'), findsNothing);
      expect(find.textContaining('bob'), findsWidgets);
    });
  });

  group('MemberProfileView role error', () {
    testWidgets('moving to another member drops the role editor and its '
        'error, and a late failure for the old member is ignored', (t) async {
      final gate = Completer<void>();
      var hold = false;
      final w = _Directory(
        ScreenFixtureClient((_, _, _) => <dynamic>[], user: {'id': 'alice'}),
        onPatch: () async {
          if (hold) await gate.future;
          throw _refused('Role change refused');
        },
      )..server = RaftRecord({'id': 's', 'name': 'S', 'role': 'owner'});
      w.client.selectServer('s');
      addTearDown(w.dispose);
      Widget view(String id) => _app(
        MemberProfileView(
          controller: w,
          userId: id,
          onClose: () {},
          onMessage: () async {},
        ),
      );
      await t.pumpWidget(view('bob'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('member-edit-role')));
      await t.pumpAndSettle();
      final state = t.state(find.byType(MemberProfileView)) as dynamic;
      await state.saveRole();
      await t.pumpAndSettle();
      expect(find.text('Role change refused'), findsOneWidget);

      await t.pumpWidget(view('carol'));
      await t.pumpAndSettle();
      expect(find.text('Role change refused'), findsNothing);
      expect(find.byKey(const ValueKey('member-edit-role-save')), findsNothing);

      // A save started for carol that fails after the page moved on.
      hold = true;
      await t.tap(find.byKey(const ValueKey('member-edit-role')));
      await t.pumpAndSettle();
      final pending = (t.state(find.byType(MemberProfileView)) as dynamic)
          .saveRole();
      await t.pump();
      await t.pumpWidget(view('dave'));
      await t.pumpAndSettle();
      gate.complete();
      await pending;
      await t.pumpAndSettle();
      expect(find.text('Role change refused'), findsNothing);
    });
  });

  group('translation settings error', () {
    test('a failed settings read belongs to its server only', () async {
      final (w, api) = await fixture('member');
      addTearDown(w.dispose);
      api.routes['GET /agents'] = (_) => [];
      api.routes['GET /servers/s2/translation-settings'] = (_) => {
        'translationEnabled': true,
        'translationAvailable': true,
        'canManageTranslation': false,
      };
      final response = Completer<void>();
      addTearDown(() {
        if (!response.isCompleted) response.complete();
      });
      api.routes['GET /servers/s1/translation-settings'] = (_) async {
        await response.future;
        throw _refused('Translation settings are down', 503);
      };
      Future<void> settleSettings() async {
        final store = w.translations;
        final settled = Completer<void>();
        void changed() {
          if (!store.settingsLoading && !settled.isCompleted) {
            settled.complete();
          }
        }

        store.addListener(changed);
        try {
          changed();
          await settled.future;
        } finally {
          store.removeListener(changed);
        }
      }

      w.server = RaftRecord({'id': 's2', 'role': 'member'});
      w.translations.ensureSettings();
      await settleSettings();
      expect(w.translations.settings.loaded, isTrue);
      expect(w.translations.settingsError, isNull);

      w.server = RaftRecord({'id': 's1', 'role': 'member'});
      w.translations.ensureSettings();
      expect(w.translations.settingsLoading, isTrue);
      expect(w.translations.settingsError, isNull);
      final settled = settleSettings();
      // The response, rather than a wall-clock delay, ends the loading state.
      response.complete();
      await settled;
      expect(w.translations.settingsLoading, isFalse);
      expect(
        w.translations.settingsError,
        'Failed to load translation settings',
      );

      w.server = RaftRecord({'id': 's2', 'role': 'member'});
      expect(
        w.translations.settingsError,
        isNull,
        reason: 'server s2 read fine; s1 failed',
      );
      w.server = RaftRecord({'id': 's1', 'role': 'member'});
      expect(
        w.translations.settingsError,
        'Failed to load translation settings',
      );
    });
  });

  group('LocaleSettingsPage', () {
    testWidgets('a retried save that succeeds ends the previous error', (
      t,
    ) async {
      var fail = true;
      final client = ScreenFixtureClient(
        (method, path, query) {
          if (method == 'PATCH' && path == '/auth/me') {
            if (fail) throw _refused('Timezone rejected');
            return <String, dynamic>{};
          }
          if (path == '/auth/me') return {'id': 'alice'};
          if (path.endsWith('/translation-settings')) {
            return {
              'translationEnabled': true,
              'translationAvailable': true,
              'canManageTranslation': false,
            };
          }
          return <dynamic>[];
        },
        user: {'id': 'alice', 'preferredTimezone': 'UTC'},
        server: 's',
      );
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's', 'name': 'S', 'role': 'member'});
      addTearDown(w.dispose);
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(900, 3200);
      addTearDown(t.view.reset);
      await t.pumpWidget(_app(LocaleSettingsPage(controller: w)));
      await t.pumpAndSettle();
      final state = t.state(find.byType(LocaleSettingsPage)) as dynamic;
      state.edit(() => state.draftTimezone = 'Asia/Tokyo', language: false);
      await t.pump();
      await state.saveDateTime();
      await t.pumpAndSettle();
      expect(find.text('Timezone rejected'), findsOneWidget);

      fail = false;
      await state.saveDateTime();
      await t.pumpAndSettle();
      expect(find.text('Timezone rejected'), findsNothing);
    });
  });

  group('ArchivedChannelsSection', () {
    testWidgets('the unarchive failure ends when that channel is no longer '
        'archived', (t) async {
      Map<String, dynamic> channel(String id, {bool archived = true}) => {
        'id': id,
        'name': id,
        'type': 'channel',
        'serverId': 's',
        'joined': true,
        'archivedAt': ?(archived ? '2026-06-10T09:00:00.000Z' : null),
      };
      final client = ScreenFixtureClient(
        (method, path, query) {
          if (path.endsWith('/unarchive')) throw _refused('Name is taken');
          return <dynamic>[];
        },
        user: {'id': 'alice', 'preferredTimezone': 'UTC'},
        server: 's',
      );
      final w = WorkspaceController(client)
        ..server = RaftRecord({
          'id': 's',
          'name': 'S',
          'slug': 's',
          'role': 'owner',
        });
      addTearDown(w.dispose);
      w.channels = [RaftChannel(channel('one')), RaftChannel(channel('two'))];
      await t.pumpWidget(_app(ArchivedChannelsSection(controller: w)));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('archived-channel-unarchive-one')));
      await t.pumpAndSettle();
      expect(find.text('Name is taken'), findsOneWidget);

      // Restored from another device: the row is gone, so is its failure.
      w.channels = [
        RaftChannel(channel('one', archived: false)),
        RaftChannel(channel('two')),
      ];
      w.notifyListeners();
      await t.pumpAndSettle();
      expect(find.text('Name is taken'), findsNothing);
      expect(find.byKey(const ValueKey('archived-channel-row-two')), findsOne);
    });
  });

  group('AccountOnboardingView banner', () {
    testWidgets('a verification failure is gone once the account is verified', (
      t,
    ) async {
      final client = ScreenFixtureClient((method, path, query) {
        if (path == '/auth/resend-verification') {
          throw _refused('Mail is down', 503);
        }
        return <String, dynamic>{};
      }, user: {'id': 'u', 'email': 'a@b.c', 'emailVerified': false});
      addTearDown(client.dispose);
      await t.pumpWidget(
        _app(
          AccountOnboardingView(
            client: client,
            onComplete: () async {},
            onSignOut: () async {},
          ),
        ),
      );
      await t.pumpAndSettle();
      await (t.state(find.byType(AccountOnboardingView)) as dynamic).resend();
      await t.pumpAndSettle();
      expect(find.text('Mail is down'), findsOneWidget);

      client.user = RaftRecord({
        'id': 'u',
        'email': 'a@b.c',
        'emailVerified': true,
        'displayName': '',
        'name': '',
        'profileSetupRequired': true,
      });
      client.emit(const RaftEvent('account:updated', {}));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('onboarding-username')), findsOneWidget);
      expect(find.text('Mail is down'), findsNothing);
    });
  });

  group('InviteAcceptView', () {
    testWidgets('an accept failure for the previous invite is not shown for '
        'the new one', (t) async {
      InviteInfoMemory.clear();
      final reply = Completer<InviteJoined>();
      Widget view(String token) => _app(
        InviteAcceptView(
          token: token,
          signedIn: true,
          loadInfo: () async => {
            'kind': 'email',
            'serverName': 'Raft $token',
            'memberCount': 1,
            'agentCount': 0,
          },
          accept: (_) => reply.future,
          onEnter: (_) async => true,
          onSignIn: () {},
          onCreateAccount: () {},
          onGoToRaft: () {},
        ),
      );
      await t.pumpWidget(view('one'));
      await t.pumpAndSettle();
      final pending = (t.state(find.byType(InviteAcceptView)) as dynamic)
          .join();
      await t.pump();
      await t.pumpWidget(view('two'));
      await t.pumpAndSettle();
      reply.completeError(_refused('Invite one expired', 410));
      await pending;
      await t.pumpAndSettle();
      expect(find.text('Invite one expired'), findsNothing);
    });
  });

  group('ServerSetupGate', () {
    Future<(_SetupClient, WorkspaceController)> mount(WidgetTester t) async {
      final c = _SetupClient()..user = RaftRecord({'id': 'owner'});
      c.selectServer('s');
      final w = WorkspaceController(c)
        ..server = RaftRecord({'id': 's', 'slug': 'raft', 'role': 'owner'});
      addTearDown(() async {
        w.dispose();
        await c.dispose();
      });
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(390, 900);
      addTearDown(t.view.reset);
      await t.pumpWidget(
        _app(
          ServerSetupGate(
            controller: w,
            child: const Center(child: Text('Conversation')),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      return (c, w);
    }

    testWidgets('the machine-list failure goes when the step no longer needs '
        'the list', (t) async {
      final (c, w) = await mount(t);
      // (the gate started with the default projection below)
      expect(find.text('Machines are unavailable'), findsOneWidget);
      c.projection = {...c.projection, 'surface': 'verifying'};
      refreshServerSetup(w);
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Machines are unavailable'), findsNothing);
    });

    testWidgets('the survey save failure goes with the server it was for', (
      t,
    ) async {
      final (c, w) = await mount(t);
      c.projection = _survey;
      refreshServerSetup(w);
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      final state = t.state(find.byType(ServerSetupGate)) as dynamic;
      state.surveyRole = 'founder';
      state.surveySource = 'friend';
      await state.submitSurvey();
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(find.text("Couldn't save your answers. Try again."), findsOne);

      c.selectServer('t');
      w.server = RaftRecord({'id': 't', 'slug': 'other', 'role': 'owner'});
      w.notifyListeners();
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(find.byKey(const ValueKey('setup-survey')), findsOneWidget);
      expect(find.text("Couldn't save your answers. Try again."), findsNothing);
    });
  });

  group('NativeNotificationService error', () {
    test(
      'a preference failure of one principal is not the next one\'s',
      () async {
        final plugin = NotificationPluginFixture()
          ..android = _AndroidFixture()
          ..initialized.complete(true);
        final preferences = _Preferences();
        final service = NativeNotificationService(
          plugin: plugin,
          platform: TargetPlatform.android,
          preferences: preferences,
        );
        addTearDown(service.dispose);
        await service.bind('alice');
        expect(
          service.error,
          'Notification settings could not be loaded on this device.',
        );
        preferences.unreadable = false;
        await service.bind('bob');
        expect(service.error, isNull);
      },
    );
  });
}

const _survey = {
  'phase': 'complete',
  'surface': 'complete',
  'blocksChat': false,
  'allowedExits': <String>[],
  'sideEffectState': {'transitions': 'enabled', 'completion': 'enabled'},
  'postSetup': {'surveyPending': true, 'handoffPending': false},
};

class _SetupClient extends RaftClient {
  _SetupClient()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  Map<String, dynamic> projection = {
    'phase': 'in_progress',
    'surface': 'computer_runtime',
    'blocksChat': true,
    'allowedExits': <String>[],
    'sideEffectState': {'transitions': 'enabled', 'completion': 'enabled'},
  };
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/setup-projection')) return projection;
    if (path.endsWith('/machines')) {
      throw _refused('Machines are unavailable', 503);
    }
    return <dynamic>[];
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
  }) async {
    if (method == 'PATCH' && path == '/auth/me') {
      throw _refused('Survey rejected');
    }
    return <String, dynamic>{};
  }

  @override
  Stream<RaftEvent> get events => stream.stream;
}

/// A workspace whose member directory answers profile reads and whose role
/// changes follow [onPatch].
class _Directory extends WorkspaceController {
  _Directory(super.client, {required this.onPatch});
  final Future<void> Function() onPatch;
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/profile')) {
      final id = path.split('/').reversed.skip(1).first;
      return {
        'userId': id,
        'id': id,
        'name': id,
        'displayName': id,
        'role': 'member',
      };
    }
    return <dynamic>[];
  }

  @override
  Future<dynamic> command(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    if (method == 'PATCH') await onPatch();
    return path == '/feature-flags/evaluate' ? {'evaluations': []} : null;
  }
}
