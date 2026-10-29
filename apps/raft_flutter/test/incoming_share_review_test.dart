import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/incoming_share_picker.dart';
import 'package:raft_flutter/features/incoming_share_review.dart';
import 'package:raft_ui/raft_ui.dart';

class PickerClient extends RaftClient {
  PickerClient()
    : super(origin: 'https://example.test', sessionStore: MemorySessionStore());
  final calls = <String>[];
  Completer<dynamic>? delayed;
  @override
  Future<dynamic> getForServer(
    String server,
    String path, {
    Map<String, dynamic>? query,
  }) async {
    calls.add('$server:$path');
    if (path.endsWith('/dm')) return [];
    if (server == 'a' && delayed != null) return delayed!.future;
    return [
      {'id': '$server-c', 'name': '$server-channel', 'joined': true},
    ];
  }
}

void main() {
  test(
    'credential and signed links are excluded; ordinary links remain text',
    () {
      expect(
        unsafeSharedText('https://example.test/?access_token=fixture'),
        true,
      );
      expect(unsafeSharedText('raft://oauth?code=fixture'), true);
      expect(unsafeSharedText('https://example.test/article 中文'), false);
    },
  );
  testWidgets('picker clears selection and ignores old server results', (
    t,
  ) async {
    final c = PickerClient()..delayed = Completer<dynamic>();
    final received = <String>[];
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: IncomingSharePicker(
          client: c,
          servers: [
            RaftRecord({'id': 'a', 'name': 'Server A'}),
            RaftRecord({'id': 'b', 'name': 'Server B'}),
          ],
          valid: () => true,
          onContinue: (server, target) async {
            received.add('${server.id}:${target.key}');
          },
        ),
      ),
    );
    await t.tap(find.text('Server B'));
    await t.pumpAndSettle();
    c.delayed!.complete([
      {'id': 'a-c', 'name': 'a-channel', 'joined': true},
    ]);
    await t.pumpAndSettle();
    expect(find.text('a-channel'), findsNothing);
    // Web's single-select flow: choosing a row opens the second page,
    // whose action is Continue.
    await t.tap(find.byKey(const ValueKey('incoming-target-b-c')));
    await t.pumpAndSettle();
    expect(find.text('Add shared content'), findsOneWidget);
    expect(
      t
          .widget<RaftForwardContinueAction>(
            find.byKey(const Key('incoming-share-continue')),
          )
          .onPressed,
      isNotNull,
    );
    // Back keeps the choice highlighted; switching server clears it.
    await t.tap(find.byType(RaftIconButton).first);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('incoming-share-continue')), findsNothing);
    await t.tap(find.text('Server A'));
    await t.pumpAndSettle();
    await t.tap(find.text('Server B'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('incoming-share-continue')), findsNothing);
    expect(received, isEmpty);
    expect(
      c.calls.where((s) => s.contains('upload') || s.contains('forward')),
      isEmpty,
    );
    await t.pumpWidget(const SizedBox());
    await c.dispose();
  });
}
