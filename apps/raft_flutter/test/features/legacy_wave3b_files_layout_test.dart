import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_channel_files_store.dart';
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/channel_side_files_rows.dart';
import 'package:raft_flutter/features/source_channel_file_glyph.dart';
import 'package:raft_flutter/features/source_channel_files_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

Map<String, dynamic> _fileJson(String id, String name, String mime) => {
  'id': id,
  'messageId': 'm-$id',
  'channelId': 'c1',
  'filename': name,
  'mimeType': mime,
  'sizeBytes': 4096,
  'createdAt': '2026-10-12T08:00:00Z',
  'source': {'type': 'channel', 'channelId': 'c1', 'parentMessageId': null},
};

void main() {
  const sizes = [Size(841, 701), Size(1180, 820), Size(390, 844)];

  for (final size in sizes) {
    final platform = size.width >= 1000
        ? TargetPlatform.linux
        : TargetPlatform.android;
    for (final dark in raftThemeMatrix([false, true])) {
      final mode = dark ? 'dark' : 'light';
      testWidgets(
        'D6 channel files and artifacts render cleanly at ${size.width.toInt()}x${size.height.toInt()} ($mode)',
        (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1.0;
          addTearDown(() {
            t.view.resetPhysicalSize();
            t.view.resetDevicePixelRatio();
          });

          final store = SourceChannelFilesStore(
            channelId: 'c1',
            authority: () => 'auth',
            get: (_, {query}) async => {
              'files': [
                _fileJson('f1', 'design-spec.pdf', 'application/pdf'),
                _fileJson('f2', 'demo-recording.mp4', 'video/mp4'),
                _fileJson('f3', 'bundle.zip', 'application/zip'),
              ],
              'nextCursor': null,
            },
          );
          addTearDown(store.dispose);
          await store.load();

          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark).copyWith(platform: platform),
              home: Scaffold(
                body: SizedBox.fromSize(
                  size: size,
                  child: SourceChannelFilesProjectionView(
                    store: store,
                    formatCreatedAt: (_) => 'Oct 12, 8:00 AM',
                    onPreview: (_) async {},
                    onDownload: (_) async {},
                    onOpenSource: (_) async {},
                  ),
                ),
              ),
            ),
          );
          await t.pump();
          expect(find.text('design-spec.pdf'), findsOneWidget);
          expect(t.takeException(), isNull);

          final card = ArtifactCard(
            id: 'art-1',
            url: 'https://raft.test/art-1',
            title: 'Architecture Diagram',
            kind: ArtifactKind.markdown,
            version: 3,
            latestVersion: 3,
            author: const ArtifactActor(
              type: 'human',
              name: 'alex',
              displayName: 'Alex',
            ),
            createdAt: DateTime.utc(2026, 10, 12, 8),
            updatedAt: DateTime.utc(2026, 10, 12, 8),
          );
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark).copyWith(platform: platform),
              home: Scaffold(
                body: SizedBox.fromSize(
                  size: size,
                  child: Column(
                    children: [
                      const Wrap(
                        spacing: 8,
                        children: [
                          ChannelFileGlyph(SourceChannelFileGlyph.image),
                          ChannelFileGlyph(SourceChannelFileGlyph.video),
                          ChannelFileGlyph(SourceChannelFileGlyph.pdf),
                          ChannelFileGlyph(SourceChannelFileGlyph.archive),
                          ChannelFileGlyph(SourceChannelFileGlyph.other),
                          ChannelFileGlyph(SourceChannelFileGlyph.jump),
                          ChannelFileGlyph(SourceChannelFileGlyph.more),
                        ],
                      ),
                      ConversationArtifactRow(
                        card: card,
                        compact: size.width < 500,
                        formattedDate: 'Oct 12',
                        onOpen: () {},
                      ),
                      ChannelFilesCompactRow(
                        file: SourceChannelFileEntry.parse(
                          _fileJson('f4', 'compact.txt', 'text/plain'),
                        ),
                        width: size.width,
                        formattedDate: 'Oct 12',
                        onPreview: () {},
                        onOpenSource: () {},
                        onDownload: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await t.pump();
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets('D6 row inline/overflow and preview buttons do not steal taps', (
    t,
  ) async {
    var previews = 0, jumps = 0, downloads = 0;
    final file = SourceChannelFileEntry.parse(
      _fileJson('f-hit', 'quarterly-report.pdf', 'application/pdf'),
    );
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.android),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 720,
              child: SourceChannelFileRow(
                file: file,
                formattedDate: 'Oct 12, 8:00 AM',
                onPreview: () => previews++,
                onOpenSource: () => jumps++,
                onDownload: () => downloads++,
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.tap(find.byKey(const ValueKey('channel-file-preview-f-hit')));
    await t.pump();
    expect((previews, jumps, downloads), (1, 0, 0));

    await t.tap(find.byKey(const ValueKey('channel-file-jump-f-hit')));
    await t.pump();
    expect((previews, jumps, downloads), (1, 1, 0));

    await t.tap(find.byKey(const ValueKey('channel-file-download-f-hit')));
    await t.pump();
    expect((previews, jumps, downloads), (1, 1, 1));
  });
}
