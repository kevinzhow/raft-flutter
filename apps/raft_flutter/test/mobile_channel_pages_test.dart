@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/channel_members.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_flutter/features/mobile_workspace_pages.dart';
import 'package:raft_flutter/features/private_route_guard.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'workspace_channel_settings_identity_test.dart' show settingsFixture;
import 'task_surface_test.dart' show flush;
import 'support/app_services_fixture.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'Mobile channel pages share current settings content, preserve history and keyboard focus ${dark ? 'dark' : 'light'}',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final semantics = t.ensureSemantics();
        final (w, api) = await settingsFixture(t);
        w.channel = RaftChannel({
          ...w.channel!.json,
          'channelCapabilities': {
            ...w.channel!.json['channelCapabilities'] as Map,
            'addChannelMembers': true,
          },
        });
        w.channels = [w.channel!];
        var channel = w.channel!.json;
        api.routes['GET /channels'] = (_) => [channel];
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [
          {'userId': 'alice', 'name': 'Alice'},
          {'userId': 'bob', 'name': 'Bob'},
        ];
        api.routes['PATCH /channels/c1'] = (r) {
          channel = {...channel, ...Map<String, dynamic>.from(r.data as Map)};
          return channel;
        };
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            navigatorObservers: [PrivateRouteGuard()],
            home: withAppServices(
              WorkspaceView(
                controller: w,
                appearance: RaftAppearance(),
                onAppearance: (_) async {},
                onLogout: () async {},
              ),
            ),
          ),
        );
        await flush(t);
        await t.pumpAndSettle();
        final base = w.location;
        final pages = mobilePageEntries(w.navigation).length;
        for (var cycle = 0; cycle < 3; cycle++) {
          await t.tap(find.byTooltip('Channel Details and Settings'));
          await t.pump();
          final context = t.element(find.byType(ChannelSettings));
          expect(ModalRoute.of(context)?.animation?.value, lessThan(1));
          await flush(t);
          await t.pumpAndSettle();
          expect(w.location.channelPage?.kind, RaftChannelPage.settings);
          expect(mobilePageEntries(w.navigation), hasLength(pages + 1));
          expect(find.byType(RaftOverflowSheet), findsOneWidget);
          expect(find.byType(RaftChannelSettingsSheet), findsNothing);
          expect(find.byType(RaftChannelInfoForm), findsOneWidget);
          expect(t.testTextInput.isVisible, isFalse);
          // Web's Drawer header below md: px-4 and the shared Button
          // `icon-sm` Back (raft-ui 0.7.0 `iconMd`: `size-8`, 32px in the Raft
          // look; 28px in the a57b9dab looks). Owner decision 2026-10-12: no
          // left edge line on the phone.
          expect(find.byType(RaftMobilePageHeader), findsNothing);
          expect(
            t.getCenter(find.byKey(const ValueKey('channel-overflow-back'))).dx,
            16 + 16,
          );
          expect(
            t.getSemantics(find.text('#test')).flagsCollection.isHeader,
            isTrue,
          );
          expect(
            find.byKey(const ValueKey('channel-overflow-identity-desc')),
            findsOneWidget,
          );

          await t.tap(
            find.byKey(const ValueKey('channel-overflow-members-entry')),
          );
          await flush(t);
          await t.pumpAndSettle();
          expect(w.location.channelPage?.kind, RaftChannelPage.members);
          expect(find.byType(ChannelMembers), findsOneWidget);
          expect(find.byType(RaftModalBackdrop), findsNothing);
          expect(mobilePageEntries(w.navigation), hasLength(pages + 2));
          expect(t.testTextInput.isVisible, isFalse);
          await t.tap(find.byKey(const ValueKey('add-member-open')));
          await t.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('add-member-confirm')),
            findsOneWidget,
          );
          expect(t.testTextInput.isVisible, isFalse);
          await t.binding.handlePopRoute();
          await t.pumpAndSettle();
          expect(find.byType(ChannelMembers), findsOneWidget);
          expect(
            find.byKey(const ValueKey('add-member-confirm')),
            findsNothing,
          );
          await t.binding.handlePopRoute();
          await flush(t);
          await t.pumpAndSettle();
          expect(w.location.channelPage?.kind, RaftChannelPage.settings);
          expect(find.byType(ChannelSettings), findsOneWidget);
          expect(t.testTextInput.isVisible, isFalse);
          await t.tap(find.byKey(const ValueKey('channel-overflow-back')));
          await t.pumpAndSettle();
          expect(w.location.uri, base.uri);
          expect(find.byType(ChannelSettings), findsNothing);
          expect(t.takeException(), isNull);
        }
        await t.tap(find.byTooltip('Channel Details and Settings'));
        await flush(t);
        await t.pumpAndSettle();
        await t.enterText(
          find.byKey(const ValueKey('channel-settings-name')),
          'renamed',
        );
        await t.pump();
        expect(
          t
              .widget<RaftSettingsRecipeButton>(
                find.byKey(const ValueKey('channel-settings-save-inline')),
              )
              .onPressed,
          isNotNull,
        );
        await t.ensureVisible(
          find.byKey(const ValueKey('channel-settings-save-inline')),
        );
        await t.tap(find.byKey(const ValueKey('channel-settings-save-inline')));
        await flush(t);
        await t.pumpAndSettle();
        expect(find.byType(ChannelSettings), findsOneWidget);
        expect(find.text('#renamed'), findsOneWidget);
        expect(
          api.calls.where(
            (r) => r.method == 'PATCH' && r.path == '/channels/c1',
          ),
          hasLength(1),
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pumpAndSettle();
        // Both the button and Android system back guard an unsaved draft.
        await t.enterText(
          find.byKey(const ValueKey('channel-settings-name')),
          'draft',
        );
        await t.pump();
        await t.binding.handlePopRoute();
        await t.pumpAndSettle();
        expect(find.byType(RaftUnsavedChangesPrompt), findsOneWidget);
        await t.tap(
          find.byKey(const ValueKey('channel-overflow-unsaved-keep')),
        );
        await t.pumpAndSettle();
        expect(find.byType(RaftUnsavedChangesPrompt), findsNothing);
        expect(w.location.channelPage?.kind, RaftChannelPage.settings);
        await t.tap(find.byKey(const ValueKey('channel-overflow-back')));
        await t.pumpAndSettle();
        expect(find.byType(RaftUnsavedChangesPrompt), findsOneWidget);
        await t.tap(
          find.byKey(const ValueKey('channel-overflow-unsaved-discard')),
        );
        await t.pumpAndSettle();
        expect(w.location.uri, base.uri);
        await t.tap(find.byTooltip('Channel Details and Settings'));
        await flush(t);
        await t.pumpAndSettle();
        // A lost membership retires the settings route.
        w.channel = RaftChannel({...w.channel!.json, 'joined': false});
        w.channels = [w.channel!];
        w.notifyListeners();
        await t.pumpAndSettle();
        expect(w.location.channelPage, isNull);
        expect(find.byType(ChannelSettings), findsNothing);
        expect(find.byType(RaftFormDialog), findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      }),
    );
  }
}
