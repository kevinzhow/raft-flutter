import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/features/workspace_grid_view.dart';
import 'package:raft_flutter/features/source_feedback_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'workspace_source_location_contract_test.dart' show pageFixture, frames;

// Source 26f77ef LeftRail649–771 + Sidebar922–1019/3840–3848/4554–4561.
// Every test mounts WorkspaceView and activates real product handlers.
Future<void> mountShell(
  WidgetTester t,
  WorkspaceController w,
  RaftFamily family,
  bool dark, {
  double width = 1280,
  PersonalPresentationStore? presentation,
}) async {
  t.view.physicalSize = Size(width, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(family, dark: dark),
      home: WorkspaceView(
        controller: w,
        appearance: RaftAppearance(light: family),
        onAppearance: (_) async {},
        onLogout: () async {},
        presentation: presentation,
      ),
    ),
  );
  await frames(t, () {});
  await t.pumpAndSettle();
}

Future<void> openHelp(WidgetTester t) async {
  await t.tap(find.byKey(const Key('rail-help')));
  await t.pumpAndSettle();
  expect(find.byType(RaftMenuPanel), findsOneWidget);
}

Future<void> retire(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '[K08a] $family/$dark classic owner keeps six entries, guest hides directory, and one sidebar heading',
      (t) async {
        final (w, api) = await pageFixture(t, section: 'chat');
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [];
        await mountShell(t, w, family, dark);
        for (final id in [
          'search',
          'chat',
          'activity',
          'tasks',
          'members',
          'computers',
        ]) {
          expect(find.byKey(ValueKey('rail-$id')), findsOneWidget);
        }
        expect(find.byType(RaftChatSidebarHeading), findsOneWidget);
        expect(
          t.getSize(find.byType(RaftChatSidebarHeading)).height,
          family == RaftFamily.brutal ? 62 : 56,
        );
        expect(find.byKey(const Key('rail-workspace')), findsOneWidget);
        expect(find.byKey(const Key('account-navigation')), findsNothing);
        expect(find.byType(PopupMenuButton<String>), findsNothing);
        final search = t.getRect(find.byKey(const ValueKey('rail-search'))),
            chat = t.getRect(find.byKey(const ValueKey('rail-chat')));
        expect(chat.top - search.top, 46);
        expect(search.top, family == RaftFamily.brutal ? 70 : 72);
        w.server = RaftRecord({...w.server!.json, 'role': 'guest'});
        w.notifyListeners();
        await frames(t, () {});
        expect(find.byKey(const ValueKey('rail-members')), findsNothing);
        expect(find.byKey(const ValueKey('rail-computers')), findsNothing);
        for (final id in ['search', 'chat', 'activity', 'tasks']) {
          expect(find.byKey(ValueKey('rail-$id')), findsOneWidget);
        }
        await retire(t);
      },
      variant: TargetPlatformVariant({TargetPlatform.linux}),
    );
    testWidgets(
      '[K08b] $family/$dark real Help opens resources and Feedback/About publish scoped settings paths',
      (t) async {
        final (w, api) = await pageFixture(t, section: 'chat');
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [];
        await mountShell(t, w, family, dark);
        final before = w.navigation.entries.length;
        final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(1200, 20));
        await mouse.moveTo(t.getCenter(find.byKey(const Key('rail-help'))));
        await t.pumpAndSettle();
        for (final label in [
          'Raft Documentation',
          'Mobile App',
          'Feedback',
          'Join Community',
        ]) {
          expect(
            find.descendant(
              of: find.byType(RaftMenuPanel),
              matching: find.text(label),
            ),
            findsOneWidget,
          );
        }
        expect(w.navigation.entries.length, before);
        final menu = t.getRect(find.byType(RaftMenuPanel)),
            help = t.getRect(find.byKey(const Key('rail-help')));
        expect(menu.width, 320);
        expect(menu.left, help.right + 8);
        await mouse.moveTo(t.getCenter(find.text('Feedback').last));
        await t.tap(
          find.descendant(
            of: find.byType(RaftMenuPanel),
            matching: find.text('Feedback'),
          ),
        );
        await t.pumpAndSettle();
        expect(w.location.toString(), '/s/demo/settings/feedback');
        expect(find.byType(SourceFeedbackView), findsOneWidget);
        expect(w.navigation.entries.length, before + 1);
        await mouse.moveTo(const Offset(1200, 20));
        await mouse.removePointer();
        await openHelp(t);
        await t.tap(
          find.descendant(
            of: find.byType(RaftMenuPanel),
            matching: find.text('Mobile App'),
          ),
        );
        await t.pumpAndSettle();
        expect(w.location.toString(), '/s/demo/settings/about');
        expect(find.byType(RaftMenuPanel), findsNothing);
        expect(w.navigation.entries.length, before + 2);
        await retire(t);
      },
      variant: TargetPlatformVariant({TargetPlatform.linux}),
    );
    testWidgets(
      '[K08f] $family/$dark Help in already joined Community pushes Home without joining or clearing its draft',
      (t) async {
        final (w, api) = await pageFixture(
          t,
          section: 'chat',
          serverSlug: 'community',
        );
        w.servers = [w.server!];
        w.drafts['c1'] = 'Retain joined community editor';
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [];
        await mountShell(t, w, family, dark);
        final before = w.navigation.entries.length;
        await openHelp(t);
        await t.tap(
          find.descendant(
            of: find.byType(RaftMenuPanel),
            matching: find.text('Join Community'),
          ),
        );
        await frames(t, () {});
        await t.pumpAndSettle();
        expect(w.location.toString(), '/s/community');
        expect(w.navigation.entries.length, before + 1);
        expect(w.drafts['c1'], 'Retain joined community editor');
        expect(
          api.calls.where((r) => r.path == '/servers/join-community'),
          isEmpty,
        );
        await retire(t);
      },
      variant: TargetPlatformVariant({TargetPlatform.linux}),
    );
    testWidgets(
      '[K08c] $family/$dark actual available workspace toggle is lg gated and retains location/draft',
      (t) async {
        final (w, api) = await pageFixture(t, section: 'chat');
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [];
        w.drafts['c1'] = 'Keep this editor';
        await mountShell(t, w, family, dark, width: 1023);
        expect(find.byKey(const Key('workspace-mode-toggle')), findsNothing);
        t.view.physicalSize = const Size(1024, 800);
        await t.pumpAndSettle();
        final uri = w.location.toString(), count = w.navigation.entries.length;
        expect(find.byKey(const Key('workspace-mode-toggle')), findsOneWidget);
        await t.tap(find.byKey(const Key('workspace-mode-toggle')));
        await frames(t, () {});
        await t.pumpAndSettle();
        expect(find.byType(WorkspaceGridView), findsOneWidget);
        expect(w.location.toString(), uri);
        expect(w.navigation.entries.length, count);
        expect(w.drafts['c1'], 'Keep this editor');
        await t.tap(find.byKey(const Key('workspace-mode-toggle')));
        await frames(t, () {});
        await t.pumpAndSettle();
        expect(find.byType(WorkspaceGridView), findsNothing);
        expect(w.location.toString(), uri);
        expect(w.drafts['c1'], 'Keep this editor');
        await retire(t);
      },
      variant: TargetPlatformVariant({TargetPlatform.linux}),
    );
    testWidgets(
      '[K08d] $family/$dark browser/native empty-section defaults and persisted choice are separate',
      (t) async {
        final (w, api) = await pageFixture(t, section: 'chat');
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [];
        final presentation = PersonalPresentationStore(desktop: false);
        addTearDown(presentation.dispose);
        await mountShell(t, w, family, dark, presentation: presentation);
        expect(presentation.value.hideEmptySections, isFalse);
        expect(find.text('Drag channels or DMs here to pin'), findsOneWidget);
        expect(find.text('No joint channels yet'), findsOneWidget);
        presentation.update(presentation.key, hideEmptySections: true);
        await t.pumpAndSettle();
        expect(find.text('Drag channels or DMs here to pin'), findsNothing);
        expect(find.text('No joint channels yet'), findsNothing);
        final key = presentation.key;
        presentation.update(key, hideEmptySections: false);
        await presentation.writes;
        final native = PersonalPresentationStore(desktop: true);
        addTearDown(native.dispose);
        expect(native.value.hideEmptySections, isTrue);
        await native.bind(w.client.origin, w.client.user!.id);
        expect(
          native.value.hideEmptySections,
          isFalse,
          reason: 'the same persisted user choice overrides native default',
        );
        await retire(t);
      },
      variant: TargetPlatformVariant({TargetPlatform.linux}),
    );
    testWidgets(
      '[K08e] $family/$dark actual DM row has Source avatar, description, typography and input route',
      (t) async {
        final (w, api) = await pageFixture(t, section: 'chat');
        final dm = RaftChannel({
          'id': 'dm1',
          'name': 'Snapshot',
          'type': 'dm',
          'joined': true,
          'peerType': 'agent',
          'peerId': 'agent1',
          'peerName': 'Cindy',
          'peerDisplayName': 'Cindy',
          'peerDescription': 'Keeps release notes aligned.',
          'peerAvatarUrl': 'pixel:robot',
        });
        w.dms = [dm];
        w.unread['dm1'] = 5;
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [];
        api.routes['GET /messages/channel/dm1'] = (_) => {
          'messages': [],
          'hasMore': false,
        };
        api.routes['POST /channels/dm1/read'] = (_) => {};
        await mountShell(t, w, family, dark);
        final row = find.byKey(const ValueKey('sidebar-channel-dm1'));
        final avatar = find.descendant(
          of: row,
          matching: find.byType(RaftAvatar),
        );
        expect(avatar, findsOneWidget);
        expect(t.getSize(avatar), const Size(18, 18));
        final content = t.widget<RaftAvatarContent>(
          find.descendant(of: row, matching: find.byType(RaftAvatarContent)),
        );
        expect(content.pixelKey, 'robot');
        expect(t.getSize(row).height, family == RaftFamily.brutal ? 32 : 34);
        final title = t.widget<Text>(
          find.descendant(of: row, matching: find.text('Cindy')),
        );
        expect(title.style!.fontSize, 14);
        expect(title.style!.fontWeight, FontWeight.w700);
        expect(
          title.style!.color,
          family == RaftFamily.brutal
              ? Colors.black
              : RaftTokens.of(t.element(row)).colors['foreground-muted'],
        );
        final desc = t.widget<Text>(
          find.descendant(
            of: row,
            matching: find.text('Keeps release notes aligned.'),
          ),
        );
        expect(desc.style!.fontSize, 12);
        expect(desc.style!.height, 16 / 12);
        expect(desc.style!.fontWeight, FontWeight.w500);
        api.routes['GET /agents'] = (_) => [
          {
            'id': 'agent1',
            'name': 'current-name',
            'displayName': 'Live Cindy',
            'description': 'Live description',
            'avatarUrl': null,
            'status': 'active',
            'runtime': 'fixture',
            'model': 'fixture',
          },
        ];
        await t.runAsync(
          () => w.entityDirectory.refresh(WorkspaceEntityKind.agents),
        );
        await frames(t, () {});
        await t.pumpAndSettle();
        expect(
          find.descendant(of: row, matching: find.text('Live Cindy')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: find.text('Live description')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: row,
            matching: find.text('Keeps release notes aligned.'),
          ),
          findsNothing,
        );
        expect(
          t
              .widget<RaftAvatarContent>(
                find.descendant(
                  of: row,
                  matching: find.byType(RaftAvatarContent),
                ),
              )
              .pixelKey,
          'robot',
          reason: 'live null avatar retains Source DM discovery fallback',
        );
        await t.tap(row);
        await frames(t, () {});
        await t.pumpAndSettle();
        expect(w.location.route, RaftRoute.dm);
        expect(w.location.entityId, 'dm1');
        expect(w.channel!.id, 'dm1');
        await retire(t);
      },
      variant: TargetPlatformVariant({TargetPlatform.linux}),
    );
  }
}
