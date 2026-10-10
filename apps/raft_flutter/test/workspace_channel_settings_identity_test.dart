import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_flutter/features/private_route_guard.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter;
import 'workspace_source_location_contract_test.dart' show pageFixture, frames;

// Source ChannelOverflowMenu.tsx:568–581 owns an explicit channelId; a
// confirmation can update/remove the selected channel before that overlay exits.
// These cases open the actual WorkspaceView handler, not a standalone sheet.
Future<(WorkspaceController, MessageAdapter)> settingsFixture(
  WidgetTester t,
) async {
  final (w, api) = await pageFixture(t, section: 'chat');
  w.channel = RaftChannel({
    ...w.channel!.json,
    'description': 'Opening channel description',
    'channelCapabilities': {
      'editChannelMetadata': true,
      'archiveChannels': true,
      'deleteChannels': true,
      'federateChannels': false,
    },
  });
  w.channels = [w.channel!];
  api.routes['GET /channels/c1/members'] = (_) => {'humans': [], 'agents': []};
  api.routes['GET /channels/c1/message-display-settings'] = (_) => {};
  api.routes['GET /servers/s1/sidebar-order'] = (_) => {'pinned': []};
  api.routes['GET /channels/dm'] = (_) => [];
  api.routes['GET /channels/unread'] = (_) => [];
  return (w, api);
}

Future<void> mountSettingsWorkspace(
  WidgetTester t,
  WorkspaceController w,
  RaftFamily family,
  bool dark,
  PrivateRouteGuard guard,
) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(1280, 800);
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(family, dark: dark),
      navigatorObservers: [guard],
      home: WorkspaceView(
        controller: w,
        appearance: RaftAppearance(light: family),
        onAppearance: (_) async {},
        onLogout: () async {},
      ),
    ),
  );
  await frames(t, () {});
  await t.pumpAndSettle();
  await t.tap(
    find.byWidgetPredicate(
      (widget) =>
          widget is RaftPanelIconButton &&
          widget.tooltip == 'Channel details and settings',
    ),
  );
  await frames(t, () {});
  await t.pumpAndSettle();
  expect(find.byType(ChannelSettings), findsOneWidget);
  expect(
    t.widget<ChannelSettings>(find.byType(ChannelSettings)).channel.id,
    'c1',
  );
  expect(find.byType(RaftChannelSettingsSheet), findsOneWidget);
  expect(t.takeException(), isNull);
}

Future<void> rebuildOverlay(WidgetTester t) async {
  // Rebuilding the real root app updates Navigator's widget; Navigator calls
  // changedExternalState on its routes, rebuilding the DialogRoute page. Keep
  // the same home widget/observer, so the existing WorkspaceView and guard live
  // through the rebuild. A metrics change alone can reuse the cached route page.
  final app = t.widget<MaterialApp>(find.byType(MaterialApp));
  t.view.physicalSize = const Size(1200, 800);
  await t.pumpWidget(
    MaterialApp(
      theme: app.theme,
      navigatorObservers: app.navigatorObservers ?? const [],
      home: app.home,
    ),
  );
  expect(t.takeException(), isNull);
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> tapSheetAction(WidgetTester t, String label) async {
  final action = find.descendant(
    of: find.byType(RaftChannelSettingsSheet),
    matching: find.text(label),
  );
  await t.ensureVisible(action);
  await t.tap(action);
  await t.pumpAndSettle();
  expect(find.byType(RaftFormDialog), findsOneWidget);
}

Future<void> submitConfirmation(WidgetTester t, String label) async {
  await t.tap(
    find.descendant(
      of: find.byType(RaftFormDialog),
      matching: find.text(label),
    ),
  );
  await frames(t, () {});
}

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark actual settings keeps opening identity and draft after selection clears or changes',
      (t) async {
        final (w, api) = await settingsFixture(t);
        final opening = w.channel!;
        await mountSettingsWorkspace(t, w, family, dark, PrivateRouteGuard());
        final sheet = t.widget<RaftChannelSettingsSheet>(
          find.byType(RaftChannelSettingsSheet),
        );
        sheet.nameController!.value = const TextEditingValue(
          text: 'Unsubmitted opening draft',
          selection: TextSelection.collapsed(offset: 12),
        );
        final sheetState = t.state(find.byType(ChannelSettings));
        w.channel = null;
        w.notifyListeners();
        await rebuildOverlay(t);
        expect(find.byType(ChannelSettings), findsOneWidget);
        expect(
          t.widget<ChannelSettings>(find.byType(ChannelSettings)).channel,
          same(opening),
        );
        expect(t.state(find.byType(ChannelSettings)), same(sheetState));
        final next = RaftChannel({'id': 'c2', 'name': 'other', 'joined': true});
        w.channels = [opening, next];
        w.channel = next;
        w.notifyListeners();
        t.view.physicalSize = const Size(1180, 800);
        await t.pumpAndSettle();
        final retained = t.widget<RaftChannelSettingsSheet>(
          find.byType(RaftChannelSettingsSheet),
        );
        expect(retained.channelName, opening.name);
        expect(retained.nameController, same(sheet.nameController));
        expect(retained.nameController!.text, 'Unsubmitted opening draft');
        expect(retained.nameController!.selection.baseOffset, 12);
        expect(
          api.calls.where((r) => r.path.startsWith('/channels/c2/')),
          isEmpty,
        );
        retained.onClose();
        await t.pumpAndSettle();
        expect(find.byType(ChannelSettings), findsNothing);
        expect(find.byType(WorkspaceView), findsOneWidget);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.linux}),
    );

    testWidgets(
      '$family/$dark actual archive refresh preserves settings identity through a Navigator rebuild',
      (t) async {
        final (w, api) = await settingsFixture(t);
        var row = w.channel!.json;
        final pending = Completer<void>();
        addTearDown(() {
          if (!pending.isCompleted) pending.complete();
        });
        api.routes['GET /channels'] = (_) => [row];
        api.routes['POST /channels/c1/archive'] = (_) async {
          await pending.future;
          row = {...row, 'archivedAt': '2026-10-10T00:00:00Z'};
          return row;
        };
        await mountSettingsWorkspace(t, w, family, dark, PrivateRouteGuard());
        final openingState = t.state(find.byType(ChannelSettings));
        await tapSheetAction(t, 'Archive Channel');
        await submitConfirmation(t, 'Confirm');
        expect(
          api.calls.where((r) => r.path == '/channels/c1/archive'),
          hasLength(1),
        );
        expect(w.channel!.archived, false);
        await t.runAsync(() async {
          pending.complete();
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await t.pumpAndSettle();
        expect(w.channel!.archived, true);
        await rebuildOverlay(t);
        expect(find.byType(ChannelSettings), findsOneWidget);
        expect(t.state(find.byType(ChannelSettings)), same(openingState));
        expect(find.text('Unarchive Channel'), findsOneWidget);
        expect(
          t.widget<ChannelSettings>(find.byType(ChannelSettings)).channel.id,
          'c1',
        );
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.linux}),
    );

    testWidgets(
      '$family/$dark actual delete clears selection and retires both overlays without route-builder crash',
      (t) async {
        final (w, api) = await settingsFixture(t);
        var deleted = false;
        final pending = Completer<void>();
        addTearDown(() {
          if (!pending.isCompleted) pending.complete();
        });
        api.routes['GET /channels'] = (_) =>
            deleted ? [] : [w.channels.first.json];
        api.routes['DELETE /channels/c1'] = (_) async {
          await pending.future;
          deleted = true;
          return {};
        };
        await mountSettingsWorkspace(t, w, family, dark, PrivateRouteGuard());
        await tapSheetAction(t, 'Delete Channel');
        await submitConfirmation(t, 'Delete');
        expect(w.channel?.id, 'c1');
        expect(find.byType(RaftFormDialog), findsOneWidget);
        await t.runAsync(() async {
          pending.complete();
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await t.pumpAndSettle();
        expect(deleted, true);
        expect(w.channel, isNull);
        await rebuildOverlay(t);
        expect(find.byType(ChannelSettings), findsNothing);
        expect(find.byType(RaftFormDialog), findsNothing);
        expect(find.byType(WorkspaceView), findsOneWidget);
        expect(
          api.calls.where((r) => r.method == 'DELETE').map((r) => r.path),
          ['/channels/c1'],
        );
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.linux}),
    );

    for (final authority in ['membership', 'principal', 'workspace']) {
      testWidgets(
        '$family/$dark actual channel settings still retires on $authority reduction',
        (t) async {
          final (w, api) = await settingsFixture(t);
          await mountSettingsWorkspace(t, w, family, dark, PrivateRouteGuard());
          switch (authority) {
            case 'membership':
              w.channel = RaftChannel({...w.channel!.json, 'joined': false});
              w.channels = [w.channel!];
            case 'principal':
              w.client.user = RaftRecord({'id': 'bob'});
            case 'workspace':
              w.client.selectServer('s2');
              w.server = RaftRecord({
                'id': 's2',
                'slug': 'next',
                'role': 'owner',
              });
          }
          w.notifyListeners();
          await rebuildOverlay(t);
          expect(find.byType(ChannelSettings), findsNothing);
          expect(find.byType(RaftFormDialog), findsNothing);
          expect(find.byType(WorkspaceView), findsOneWidget);
          expect(
            api.calls.where((r) => {'PATCH', 'DELETE'}.contains(r.method)),
            isEmpty,
          );
          expect(t.takeException(), isNull);
        },
        variant: TargetPlatformVariant({TargetPlatform.linux}),
      );
    }
  }
}
