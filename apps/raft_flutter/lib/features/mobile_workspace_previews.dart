import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/previews.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/personal_presentation.dart';
import '../data/search_memory.dart';
import '../data/workspace_controller.dart';
import 'page_alignment_fixtures.dart';
import 'workspace_view.dart';

@RaftPreviews('Page mobile Home root', size: Size(390, 844))
Widget mobileHomeRootPreview() => const _MobileWorkspacePreview();
@RaftPreviews('Page mobile Home compact', size: Size(390, 568))
Widget mobileHomeCompactPreview() => const _MobileWorkspacePreview();
@RaftPreviews('Page mobile guest Home root', size: Size(390, 844))
Widget mobileGuestHomeRootPreview() =>
    const _MobileWorkspacePreview(guest: true);

@RaftPreviews('Page mobile Settings root', size: Size(390, 844))
Widget mobileSettingsRootPreview() =>
    const _MobileWorkspacePreview(section: 'settings');
@RaftPreviews('Page mobile Tasks root', size: Size(390, 844))
Widget mobileTasksRootPreview() =>
    const _MobileWorkspacePreview(section: 'tasks');

class _MobileWorkspacePreview extends StatefulWidget {
  const _MobileWorkspacePreview({this.guest = false, this.section = 'home'});
  final bool guest;
  final String section;
  @override
  State<_MobileWorkspacePreview> createState() =>
      _MobileWorkspacePreviewState();
}

class _MobileWorkspacePreviewState extends State<_MobileWorkspacePreview> {
  late final client = _PublicMobileClient();
  late final presentation = PersonalPresentationStore(
    storage: _VisualStorage(),
  );
  late final workspace = WorkspaceController(client, mobileNavigation: true)
    ..server = RaftRecord({
      'id': 'server-visual',
      'name': 'Visual workspace',
      'role': widget.guest ? 'guest' : 'owner',
    })
    ..servers = [
      RaftRecord({
        'id': 'server-visual',
        'name': 'Visual workspace',
        'role': widget.guest ? 'guest' : 'owner',
      }),
    ]
    ..channels = [
      RaftChannel({
        'id': 'channel-design',
        'name': 'design',
        'joined': true,
        'visibility': 'public',
      }),
    ]
    ..dms = [
      RaftChannel({
        'id': 'dm-artin',
        'name': 'artin',
        'type': 'dm',
        'peerName': 'artin',
        'peerType': 'user',
        'peerId': 'visual-other',
        'joined': true,
      }),
    ]
    ..section = widget.section;
  @override
  void dispose() {
    workspace.dispose();
    presentation.dispose();
    client.stream.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RaftDensityScope(
    density: RaftDensity.touch,
    child: WorkspaceView(
      controller: workspace,
      presentation: presentation,
      appearance: const RaftAppearance(),
      onAppearance: (_) async {},
      onLogout: () async {},
    ),
  );
}

class _VisualStorage implements SearchMemoryStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

class _PublicMobileClient extends RaftClient {
  _PublicMobileClient()
    : super(
        origin: 'https://public-visual-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'visual-user', 'displayName': 'artin'});
    selectServer('server-visual');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/tasks') return pageTasksFixture;
    if (path == '/channels/unread') return {'channels': {}};
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    }
    if (path.endsWith('/sidebar-order')) {
      return {'pinned': [], 'customSections': [], 'sectionPlacements': []};
    }
    if (path == '/auth/identities') {
      return {'passwordConfigured': true, 'identities': []};
    }
    if (path == '/auth/providers') return {'providers': []};
    return [];
  }

  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    BigInt? before,
    BigInt? after,
    int limit = 50,
  }) async => {
    'messages': [
      {
        'id': 'public-mobile-message',
        'channelId': id,
        'seq': '1',
        'senderId': 'visual-user',
        'senderName': 'artin',
        'senderType': 'user',
        'content': 'Public mobile fixture. Back returns to Home.',
        'createdAt': '2026-10-08T00:00:00Z',
      },
    ],
    'threadSummariesByParentMessageId': {},
  };
  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    if (path == '/feature-flags/evaluate') return {'evaluations': []};
    if (path.endsWith('/read')) {
      return {'maxReadSeq': '1', 'readStateVersion': '1'};
    }
    throw const RaftApiException(
      'Public visual fixture does not send or modify server data.',
    );
  }
}
