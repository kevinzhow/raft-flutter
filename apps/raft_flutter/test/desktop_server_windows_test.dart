import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_cache.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/platform/desktop_windows.dart';
import 'package:raft_ui/raft_ui.dart';

import 'workspace_source_location_contract_test.dart' show pageFixture;

class WindowsFixture implements DesktopWindows {
  final opened = <String>[];
  @override
  WorkspaceCache? get draftCache => null;
  @override
  Future<void> retireDrafts() async {}
  @override
  Future<void> selectServer(String serverId) async {}
  @override
  Future<bool> prepareExit() async => true;
  @override
  void cancelClose() {}
  @override
  bool get isChild => false;
  @override
  String? get origin => null;
  @override
  Uri? get initialLocation => null;
  @override
  String? get navigationNamespace => null;
  @override
  String? get startupServerId => null;
  @override
  SharedSessionAuthority? get sessionAuthority => null;
  @override
  void bind(
    RaftClient? client,
    String? serverId, {
    Future<void> Function()? onLogout,
    WorkspaceCache? cache,
    Future<bool> Function()? prepareClose,
    void Function()? cancelClose,
  }) {}
  @override
  Future<void> openServer(RaftRecord server) async {
    opened.add(server.id);
  }

  @override
  Future<void> frameReady() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  for (final menu in [false, true]) {
    testWidgets(
      'production server switcher ${menu ? 'native menu' : 'middle click'} opens a window without navigating this workspace',
      (t) async {
        final (workspace, api) = await pageFixture(t, section: 'chat');
        final originalServer = workspace.server!.id;
        final originalChannel = workspace.channel!.id;
        workspace.servers = [
          workspace.server!,
          RaftRecord({'id': 's2', 'name': 'Beta', 'slug': 'beta'}),
        ];
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [];
        api.routes['GET /servers/unread-summary'] = (_) => [];
        t.view.physicalSize = const Size(1280, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final windows = WindowsFixture();
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: TargetPlatform.linux),
            home: AppServicesScope(
              services: AppServices.updatesDisabledForTestOrPreview(
                desktopWindows: windows,
              ),
              child: WorkspaceView(
                controller: workspace,
                appearance: RaftAppearance(),
                onAppearance: (_) async {},
                onLogout: () async {},
                onChooseServer: () {},
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('topbar-workspace')));
        await t.pumpAndSettle();
        final gesture = await t.startGesture(
          t.getCenter(find.text('Beta').last),
          kind: PointerDeviceKind.mouse,
          buttons: menu ? kSecondaryMouseButton : kMiddleMouseButton,
        );
        await gesture.up();
        await t.pumpAndSettle();
        if (menu) {
          expect(find.text('Open in new window'), findsOneWidget);
          await t.tap(find.text('Open in new window'));
          await t.pumpAndSettle();
        }
        expect(windows.opened, ['s2']);
        expect(workspace.server!.id, originalServer);
        expect(workspace.channel!.id, originalChannel);
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      },
    );
  }
}
