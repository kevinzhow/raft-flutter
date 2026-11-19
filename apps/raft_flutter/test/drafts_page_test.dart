import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/desktop_drafts_page.dart';
import 'package:raft_ui/raft_ui.dart';

class _Client extends RaftClient {
  _Client(this.enabled)
    : super(
        origin: 'https://example.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'reader'});
    selectServer('workspace');
  }

  final bool enabled;
  int evaluations = 0;

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    if (path != '/feature-flags/evaluate') throw StateError(path);
    expect((data as Map)['keys'], ['drafts_section_v0']);
    evaluations++;
    return {
      'evaluations': [
        {'key': 'drafts_section_v0', 'enabled': enabled},
      ],
    };
  }
}

void main() {
  for (final (width, enabled, hasDraft) in [
    (390.0, true, true),
    (1100.0, true, true),
    (390.0, false, true),
    (390.0, true, false),
  ]) {
    final label = 'drafts at $width, enabled=$enabled, draft=$hasDraft';
    testWidgets(label, (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final client = _Client(enabled);
      final w = WorkspaceController(client, ownsClient: false)
        ..server = RaftRecord({
          'id': 'workspace',
          'role': 'owner',
          'slug': 'workspace',
        })
        ..channels = [
          RaftChannel({
            'id': 'c1',
            'name': 'general',
            'type': 'channel',
            'joined': true,
          }),
        ];
      if (hasDraft) w.drafts['c1'] = 'unsent package update';
      addTearDown(w.dispose);
      addTearDown(client.dispose);
      var returned = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: false),
          home: Scaffold(
            body: Column(
              children: [
                DraftsSidebarEntry(controller: w, onOpen: () {}),
                Expanded(
                  child: DraftsPage(
                    controller: w,
                    onBack: () => returned++,
                    onUnavailable: () => returned++,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(client.evaluations, 1);
      expect(
        find.byKey(const ValueKey('nav-drafts')),
        enabled ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('unsent package update'),
        enabled && hasDraft ? findsOneWidget : findsNothing,
      );
      if (enabled && hasDraft) {
        expect(find.text('general'), findsOneWidget);
      } else if (enabled) {
        expect(find.text('No drafts'), findsOneWidget);
        expect(
          tester.widget<RaftEmptyState>(find.byType(RaftEmptyState)).glyph,
          RaftGlyph.pencil,
        );
      }
      expect(returned, enabled ? 0 : 1);
    });
  }
}
