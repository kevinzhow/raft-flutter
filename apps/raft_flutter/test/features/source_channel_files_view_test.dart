import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_channel_files_store.dart';
import 'package:raft_flutter/features/source_channel_files_view.dart';
import 'package:raft_ui/raft_ui.dart';

Map<String, dynamic> fileRow(String id) => {'id': id, 'messageId': 'message', 'channelId': 'channel',
  'filename': 'Public 中文.txt', 'mimeType': 'text/plain', 'sizeBytes': 1024,
  'createdAt': '2026-10-08T01:30:00Z', 'source': {'type': 'channel', 'channelId': 'channel', 'parentMessageId': null}};
void main() {
  test('source channelFiles classification and1024 rounding thresholds', () {
    expect(sourceChannelFileSize(0), '0 B'); expect(sourceChannelFileSize(1024), '1.0 KB');
    expect(sourceChannelFileSize(10 * 1024), '10 KB'); expect(sourceChannelFileSize(1024 * 1024 * 1024), '1.0 GB');
  });
  for (final (family, dark) in [(RaftFamily.brutal, false), (RaftFamily.elegant, false), (RaftFamily.elegant, true)]) {
    testWidgets('$family/$dark real row/overflow actions and stale callback admission', (tester) async {
      var owner = 'current', previews = 0, jumps = 0, downloads = 0;
      final store = SourceChannelFilesStore(channelId: 'channel', authority: () => owner,
        get: (_, {query}) async => {'files': [fileRow('a')], 'nextCursor': null});
      await store.load();
      await tester.pumpWidget(MaterialApp(theme: raftTheme(family, dark: dark), home: Scaffold(
        body: RaftDensityScope(density: RaftDensity.desktop, child: SizedBox(width: 390,
          child: SourceChannelFilesProjectionView(store: store, formatCreatedAt: (_) => 'Oct 8, 10:30 AM',
            onPreview: (_) async { previews++; }, onOpenSource: (_) async { jumps++; },
            onDownload: (_) async { downloads++; }))))));
      await tester.pump();
      expect(find.text('Public 中文.txt'), findsOneWidget);
      expect(find.text('Oct 8, 10:30 AM'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('channel-file-preview-a'))); await tester.pump();
      expect((previews, jumps, downloads), (1, 0, 0));
      await tester.tap(find.byKey(const ValueKey('channel-file-overflow-a'))); await tester.pumpAndSettle();
      await tester.tap(find.text('Jump to original message')); await tester.pumpAndSettle();
      expect((previews, jumps, downloads), (1, 1, 0));
      final stale = tester.widget<SourceChannelFileRow>(find.byType(SourceChannelFileRow));
      owner = 'revoked'; stale.onPreview(); stale.onDownload();
      await tester.pump(); expect((previews, jumps, downloads), (1, 1, 0));
      store.syncAuthority(); await tester.pump(); expect(find.text('Public 中文.txt'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink()); store.dispose();
      expect(tester.takeException(), isNull);
    });
    testWidgets('$family/$dark wide row keeps preview and actions distinct and uses content-box breakpoint', (tester) async {
      var previews = 0, jumps = 0, downloads = 0;
      await tester.pumpWidget(MaterialApp(theme: raftTheme(family, dark: dark), home: Scaffold(
        body: RaftDensityScope(density: RaftDensity.desktop, child: Align(alignment: Alignment.topLeft,
          child: SizedBox(width: 620, child: SourceChannelFileRow(file: SourceChannelFileEntry.parse(fileRow('a')),
            formattedDate: 'Oct 8, 10:30 AM', onPreview: () => previews++,
            onOpenSource: () => jumps++, onDownload: () => downloads++)))))));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('channel-file-download-a'))); await tester.pump();
      await tester.tap(find.byKey(const ValueKey('channel-file-jump-a'))); await tester.pump();
      expect((previews, jumps, downloads), (0, 1, 1));
      final t = raftTheme(family, dark: dark).extension<RaftTokens>()!;
      final recipe = SourceChannelFilesRecipe(t);
      final boundary = 560 + 24 + recipe.border(false).width * 2;
      expect(recipe.collapsedActions(boundary), true);
      expect(recipe.collapsedActions(boundary + .1), false);
      expect(tester.takeException(), isNull);
    });
    testWidgets('$family/$dark wrapped metadata grows naturally and keyboard preview stays independent', (tester) async {
      var previews = 0, downloads = 0;
      await tester.pumpWidget(MaterialApp(theme: raftTheme(family, dark: dark), home: Scaffold(
        body: RaftDensityScope(density: RaftDensity.desktop, child: Align(alignment: Alignment.topLeft,
          child: SizedBox(width: 230, child: SourceChannelFileRow(file: SourceChannelFileEntry.parse(fileRow('a')),
            formattedDate: '30 sept., 11:59 PM', onPreview: () => previews++,
            onOpenSource: () {}, onDownload: () => downloads++)))))));
      await tester.pump();
      final preview = find.byKey(const ValueKey('channel-file-preview-a'));
      expect(tester.getSize(preview).height, greaterThan(56));
      final overflow = find.byKey(const ValueKey('channel-file-overflow-a'));
      expect(tester.getCenter(overflow).dy, closeTo(tester.getCenter(preview).dy, .1));
      final focus = tester.widget<FocusableActionDetector>(find.descendant(
        of: preview, matching: find.byType(FocusableActionDetector)).first).focusNode!;
      focus.requestFocus(); await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter); await tester.pump();
      expect((previews, downloads), (1, 0));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
    testWidgets('$family/$dark loading-error-retry does not fabricate empty list', (tester) async {
      final pending = Completer<dynamic>(); var calls = 0;
      final store = SourceChannelFilesStore(channelId: 'channel', authority: () => 'owner',
        get: (_, {query}) => ++calls == 1 ? pending.future : Future.value({'files': [], 'nextCursor': null}));
      final request = store.load();
      await tester.pumpWidget(MaterialApp(theme: raftTheme(family, dark: dark), home: Scaffold(
        body: SourceChannelFilesProjectionView(store: store, formatCreatedAt: (value) => value,
          onPreview: (_) async {}, onOpenSource: (_) async {}, onDownload: (_) async {}))));
      expect(find.text('Loading files…'), findsOneWidget); expect(find.text('No files yet'), findsNothing);
      pending.completeError(const ChannelFilesRequestFailure(ChannelFilesFailure.unavailable));
      await request; await tester.pump();
      expect(find.text('Could not load files.'), findsOneWidget); expect(find.text('No files yet'), findsNothing);
      await tester.tap(find.text('Retry')); await tester.pumpAndSettle();
      expect(find.text('No files yet'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink()); store.dispose();
    });
  }
}
