import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_channel_files_store.dart';
import 'package:raft_flutter/features/source_channel_files_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'source_channel_files_view_test.dart' show fileRow;

Future<void> mountFiles(
  WidgetTester tester,
  SourceChannelFilesStore store, {
  bool dark = false,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 800));
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    await tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SourceChannelFilesProjectionView(
          store: store,
          formatCreatedAt: (_) => 'Oct 8, 10:30 AM',
          onPreview: (_) async {},
          onOpenSource: (_) async {},
          onDownload: (_) async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (dark, scale) in [(false, 1.0), (true, 3.1)]) {
    testWidgets(
      '${dark ? 'dark' : 'light'} page error retries only after an explicit action',
      (tester) async {
        final cursors = <String?>[];
        final retry = Completer<dynamic>();
        final store = SourceChannelFilesStore(
          channelId: 'channel',
          authority: () => 'owner',
          get: (_, {query}) async {
            cursors.add(query?['cursor'] as String?);
            if (cursors.length == 1) {
              return {
                'files': [fileRow('a')],
                'nextCursor': 'page-two',
              };
            }
            if (cursors.length == 2) {
              throw const ChannelFilesRequestFailure(
                ChannelFilesFailure.unavailable,
              );
            }
            return retry.future;
          },
        );
        await store.load();
        await mountFiles(tester, store, dark: dark, textScale: scale);
        await tester.tap(find.text('Load More'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('channel-file-a')), findsOneWidget);
        expect(find.text('Could not load more files.'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
        final list = tester.element(find.byType(ListView));
        ScrollUpdateNotification(
          metrics: FixedScrollMetrics(
            minScrollExtent: 0,
            maxScrollExtent: 100,
            pixels: 100,
            viewportDimension: 800,
            axisDirection: AxisDirection.down,
            devicePixelRatio: 1,
          ),
          context: list,
          scrollDelta: 10,
        ).dispatch(list);
        await tester.ensureVisible(find.text('Load More'));
        await tester.pumpAndSettle();
        expect(cursors, [
          null,
          'page-two',
        ], reason: 'scroll must not retry errors');
        await tester.tap(find.text('Load More'));
        await tester.pump();
        expect(cursors, [null, 'page-two', 'page-two']);
        expect(find.byKey(const ValueKey('channel-file-a')), findsOneWidget);
        expect(find.text('Could not load more files.'), findsNothing);
        expect(find.text('Loading more files…'), findsOneWidget);
        retry.complete({
          'files': [fileRow('b')],
          'nextCursor': null,
        });
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('channel-file-a')), findsOneWidget);
        expect(find.byKey(const ValueKey('channel-file-b')), findsOneWidget);
        expect(find.text('Load More'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a malformed later page preserves accepted rows and its cursor', (
    tester,
  ) async {
    final cursors = <String?>[];
    final store = SourceChannelFilesStore(
      channelId: 'channel',
      authority: () => 'owner',
      get: (_, {query}) async {
        cursors.add(query?['cursor'] as String?);
        return {
          'files': [fileRow(cursors.length == 1 ? 'a' : 'bad')],
          'nextCursor': 'page-two',
        };
      },
    );
    await store.load();
    await mountFiles(tester, store);
    await tester.tap(find.text('Load More'));
    await tester.pumpAndSettle();
    expect(store.error, ChannelFilesFailure.malformed);
    expect(find.byKey(const ValueKey('channel-file-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('channel-file-bad')), findsNothing);
    expect(find.text('Could not load more files.'), findsOneWidget);
    await tester.tap(find.text('Load More'));
    await tester.pumpAndSettle();
    expect(cursors, [null, 'page-two', 'page-two']);
  });

  testWidgets('an unauthorized later page still removes earlier private rows', (
    tester,
  ) async {
    var calls = 0;
    final store = SourceChannelFilesStore(
      channelId: 'channel',
      authority: () => 'owner',
      get: (_, {query}) async {
        if (++calls == 1) {
          return {
            'files': [fileRow('private')],
            'nextCursor': 'page-two',
          };
        }
        throw const ChannelFilesRequestFailure(
          ChannelFilesFailure.unauthorized,
        );
      },
    );
    await store.load();
    await mountFiles(tester, store);
    await tester.tap(find.text('Load More'));
    await tester.pumpAndSettle();
    expect(find.byType(SourceChannelFileRow), findsNothing);
    expect(find.text('Could not load files.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Load More'), findsNothing);
  });
}
