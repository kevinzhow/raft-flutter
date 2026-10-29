import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_channel_files_store.dart';
import 'package:raft_flutter/features/source_channel_files_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'source_channel_files_view_test.dart' show fileRow;

/// Channel Files "Load More": a tap appends the next page and the button ends
/// with the last page; a failed page keeps the files already on screen.

Future<SourceChannelFilesStore> _mount(
  WidgetTester t,
  Future<Map<String, dynamic>> Function(String? cursor) answer,
) async {
  final store = SourceChannelFilesStore(
    channelId: 'channel',
    authority: () => 'current',
    get: (_, {query}) => answer(query?['cursor'] as String?),
  );
  await store.load();
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: RaftDensityScope(
          density: RaftDensity.desktop,
          child: SizedBox(
            width: 390,
            height: 700,
            child: SourceChannelFilesProjectionView(
              store: store,
              formatCreatedAt: (_) => 'Oct 8, 10:30 AM',
              onPreview: (_) async {},
              onOpenSource: (_) async {},
              onDownload: (_) async {},
            ),
          ),
        ),
      ),
    ),
  );
  await t.pump();
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    store.dispose();
  });
  return store;
}

void main() {
  testWidgets('Load more appends the next page and ends with the last one', (
    t,
  ) async {
    await _mount(
      t,
      (cursor) async => cursor == null
          ? {
              'files': [fileRow('a')],
              'nextCursor': 'p2',
            }
          : {
              'files': [fileRow('b')],
              'nextCursor': null,
            },
    );
    expect(find.byKey(const ValueKey('channel-file-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('channel-file-b')), findsNothing);
    await t.tap(find.text('Load More'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('channel-file-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('channel-file-b')), findsOneWidget);
    expect(find.text('Load More'), findsNothing);
  });

  testWidgets('a single page never offers Load more', (t) async {
    await _mount(
      t,
      (_) async => {
        'files': [fileRow('a')],
        'nextCursor': null,
      },
    );
    expect(find.text('Load More'), findsNothing);
  });
}
