// Debug/profile-only entrypoint: opens the real HtmlAttachmentPreviewDialog
// (the route every chat/Activity/Search/Files HTML attachment uses) against a
// local fake server that serves /api/attachments/:id/html-preview-url and the
// sandboxed /html-preview document with the real server's headers. No login
// data, no app shell. See docs/html-preview-evidence.md.
//
//   python3 <fake_server.py> 18951 file.html server.log
//   tool/flutter run -d linux -t integration_test/html_preview_probe_main.dart \
//     --dart-define=HTML_PROBE_ORIGIN=http://127.0.0.1:18951
//   (Android emulator: --dart-define=HTML_PROBE_ORIGIN=http://10.0.2.2:18951)
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_html_preview.dart';
import 'package:raft_ui/raft_ui.dart';

const probeId = String.fromEnvironment('HTML_PROBE_ID', defaultValue: 'a');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const origin = String.fromEnvironment(
    'HTML_PROBE_ORIGIN',
    defaultValue: 'http://127.0.0.1:18951',
  );
  final client = RaftClient(origin: origin, sessionStore: MemorySessionStore());
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({'id': 's1', 'role': 'owner'});
  w.channel = RaftChannel({'id': 'c1', 'name': 'test', 'joined': true});
  w.channels = [w.channel!];
  runApp(
    MaterialApp(
      theme: raftTheme(),
      debugShowCheckedModeBanner: false,
      home: _Probe(w),
    ),
  );
}

/// Opens the preview on start and again from the button, so a second preview
/// (cookie / storage carry-over) can be observed in the server log.
class _Probe extends StatefulWidget {
  const _Probe(this.w);
  final WorkspaceController w;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => open());
  }

  void open() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (route) => HtmlAttachmentPreviewDialog(
        page: MediaQuery.sizeOf(route).width < 600,
        controller: widget.w,
        metadata: const {'id': probeId, 'filename': 'npc-motion-analysis.html'},
        authorized: () => true,
        onClose: () => Navigator.of(route).pop(),
        onDownload: () async {},
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(onPressed: open, child: const Text('Open Preview')),
    ),
  );
}
