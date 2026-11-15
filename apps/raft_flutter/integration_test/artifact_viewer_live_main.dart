// WP-ART1 live acceptance entry (debug only): signs in to a local Raft v1.24 stack and shows each
// listed Artifact in the real viewer, one every ART1_SECONDS, so a screenshot loop can capture
// every kind on a device.
//
//   tool/flutter build apk --debug -t integration_test/artifact_viewer_live_main.dart \
//     --dart-define=RAFT_ORIGIN=http://localhost:13022 \
//     --dart-define=RAFT_FRONTEND_ORIGIN=http://localhost:15194 \
//     --dart-define=RAFT_ARTIFACTS_CONTENT_DOMAIN=artifacts.localhost:18787 \
//     --dart-define=ART1_ARTIFACTS=pt_a,pt_b --dart-define=ART1_SERVER=<server uuid> \
//     --dart-define=ART1_LOGIN=<fixture email> --dart-define=ART1_PASSWORD=<fixture password>
//   (Android emulator: `adb reverse` the API and content ports.)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/artifacts/artifact_session.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:raft_ui/raft_ui.dart';

const _api = String.fromEnvironment('RAFT_ORIGIN');
const _ids = String.fromEnvironment('ART1_ARTIFACTS');
const _server = String.fromEnvironment('ART1_SERVER');
const _login = String.fromEnvironment('ART1_LOGIN');
const _password = String.fromEnvironment('ART1_PASSWORD');
const _seconds = int.fromEnvironment('ART1_SECONDS', defaultValue: 14);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final client = RaftClient(origin: _api, sessionStore: MemorySessionStore());
  await client.login(_login, _password);
  client.selectServer(_server);
  final w = WorkspaceController(client)
    ..server = RaftRecord({'id': _server, 'role': 'owner', 'name': 'Dev'});
  runApp(_Cycle(w: w, ids: _ids.split(',')));
}

class _Cycle extends StatefulWidget {
  const _Cycle({required this.w, required this.ids});
  final WorkspaceController w;
  final List<String> ids;
  @override
  State<_Cycle> createState() => _CycleState();
}

class _CycleState extends State<_Cycle> {
  var index = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: _seconds), (_) {
      setState(() => index = (index + 1) % widget.ids.length);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: raftTheme(),
    home: RaftToastHost(
      child: Scaffold(
        body: ArtifactWorkspaceViewer(
          key: ValueKey(widget.ids[index]),
          session: ArtifactSession.of(widget.w),
          target: ArtifactLinkTarget(widget.ids[index]),
          page: true,
          onClose: () {},
        ),
      ),
    ),
  );
}
