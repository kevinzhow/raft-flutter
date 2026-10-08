import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/incoming_share_review.dart';
import 'package:raft_flutter/platform/native_sharing.dart';

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://example.test', sessionStore: MemorySessionStore());
  bool denied = false;
  @override
  Future<List<RaftRecord>> servers() async => [
    RaftRecord({'id': 's'}),
  ];
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (denied) throw const RaftApiException('Forbidden');
    return {'id': 'c', 'serverId': 's'};
  }
}

void main() {
  Future<(_Client, WorkspaceController)> mount(WidgetTester t) async {
    final c = _Client()..user = RaftRecord({'id': 'alice'});
    c.selectServer('s');
    final w = WorkspaceController(c)
      ..channel = RaftChannel({'id': 'c', 'joined': true, 'name': 'general'});
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => reviewIncomingShare(
                context,
                w,
                const IncomingShare(text: 'shared text'),
                NativeSharing(supported: false),
              ),
              child: const Text('Review'),
            ),
          ),
        ),
      ),
    );
    return (c, w);
  }

  testWidgets('share review appends existing draft; cancel stages nothing', (
    t,
  ) async {
    final (c, w) = await mount(t);
    w.saveDraft('existing draft');
    await t.tap(find.text('Review'));
    await t.pumpAndSettle();
    expect(find.text('Add shared content'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(w.drafts[w.draftScope()], 'existing draft');
    await t.tap(find.text('Review'));
    await t.pumpAndSettle();
    await t.tap(find.text('Add to conversation'));
    await t.pumpAndSettle();
    expect(w.drafts[w.draftScope()], 'existing draft\nshared text');
    expect(w.uploads(), isEmpty);
    await t.pumpWidget(const SizedBox());
    w.dispose();
    await c.dispose();
  });
  testWidgets(
    'account scope change removes review; denied fresh authority cannot open it',
    (t) async {
      final (c, w) = await mount(t);
      await t.tap(find.text('Review'));
      await t.pumpAndSettle();
      w.revokeServer('s');
      await t.pumpAndSettle();
      expect(find.text('Add shared content'), findsNothing);
      expect(w.drafts, isEmpty);
      await t.pumpWidget(const SizedBox());
      w.dispose();
      await c.dispose();
      final (c2, w2) = await mount(t);
      c2.denied = true;
      await t.tap(find.text('Review'));
      await t.pumpAndSettle();
      expect(find.text('Add shared content'), findsNothing);
      expect(w2.drafts, isEmpty);
      await t.pumpWidget(const SizedBox());
      w2.dispose();
      await c2.dispose();
    },
  );
}
