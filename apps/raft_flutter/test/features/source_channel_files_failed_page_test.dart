import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_channel_files_store.dart';
import 'package:raft_flutter/features/source_channel_files_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'source_channel_files_view_test.dart' show fileRow;

/// A failed "Load More" must not take the already loaded files off the screen,
/// and the user must be able to ask for that page again.
/// Known failing: the view shows only "Could not load files." and its Retry
/// reloads the first page (source_channel_files_view.dart, error branch).

void main() {
  testWidgets('a failed Load more keeps the loaded files and can be retried', (
    t,
  ) async {
    var fail = true;
    final store = SourceChannelFilesStore(
      channelId: 'channel',
      authority: () => 'current',
      get: (_, {query}) async {
        final cursor = query?['cursor'] as String?;
        if (cursor == null) {
          return {
            'files': [fileRow('a')],
            'nextCursor': 'p2',
          };
        }
        if (fail) {
          throw const ChannelFilesRequestFailure(ChannelFilesFailure.unavailable);
        }
        return {
          'files': [fileRow('b')],
          'nextCursor': null,
        };
      },
    );
    await store.load();
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      store.dispose();
    });
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
    await t.tap(find.text('Load More'));
    await t.pumpAndSettle();
    // The page failed; file a is still there.
    expect(find.byKey(const ValueKey('channel-file-a')), findsOneWidget);
    fail = false;
    await t.tap(find.text('Load More'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('channel-file-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('channel-file-b')), findsOneWidget);
  });
}
