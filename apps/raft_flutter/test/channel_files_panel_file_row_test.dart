import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_channel_files_store.dart';
import 'package:raft_flutter/features/channel_side_files_rows.dart';
import 'package:raft_flutter/features/source_channel_files_view.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets(
    'ChannelFilesPanelFileRow never loads original HEIC as a thumbnail',
    (tester) async {
      final requested = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Column(
              children: [
                for (final (id, url) in [
                  ('original', null),
                  ('raster', 'https://storage.example.com/thumb.webp'),
                ])
                  SourceChannelFileThumbnail(
                    file: SourceChannelFileEntry(
                      {
                        'id': id,
                        'filename': '$id.heic',
                        'mimeType': 'image/heic',
                        'thumbnailUrl': url,
                      },
                      'message',
                      'channel',
                      'channel',
                      null,
                      'channel',
                      '',
                    ),
                    authorized: () => true,
                    acquireImage: (file, _, _) async {
                      requested.add(file.id);
                      return null;
                    },
                  ),
              ],
            ),
          ),
        ),
      );
      expect(requested, ['raster']);
    },
  );

  testWidgets('ChannelFilesPanelFileRow sizes actions to the row', (
    tester,
  ) async {
    final file = SourceChannelFileEntry(
      {
        'id': 'file',
        'filename': 'design.heic',
        'mimeType': 'image/heic',
        'sizeBytes': 4096,
      },
      'message',
      'channel',
      'channel',
      null,
      'channel',
      '',
    );
    var jumps = 0;
    var downloads = 0;
    Future<void> mount(double width) => tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: ChannelFilesCompactRow(
                width: width,
                file: file,
                formattedDate: 'Oct 12',
                onPreview: () {},
                onOpenSource: () => jumps++,
                onDownload: () => downloads++,
              ),
            ),
          ),
        ),
      ),
    );
    final overflow = find.byKey(const ValueKey('channel-file-overflow-file'));
    final jump = find.byKey(const ValueKey('channel-file-jump-file'));
    final download = find.byKey(const ValueKey('channel-file-download-file'));
    await mount(320);
    expect(overflow, findsOneWidget);
    expect(jump, findsNothing);
    expect(
      tester.getCenter(overflow).dy,
      closeTo(tester.getCenter(find.text('design.heic')).dy, 2),
    );
    await mount(640);
    expect(overflow, findsNothing);
    await tester.tap(jump);
    await tester.tap(download);
    expect((jumps, downloads), (1, 1));
  });
}
