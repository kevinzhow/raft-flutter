import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:raft_flutter/data/source_channel_files_store.dart';
import 'package:raft_flutter/features/source_channel_file_glyph.dart';
import 'package:raft_flutter/features/source_channel_files_view.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final theme in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'inline SVG actually paints and retires on authority loss $theme',
      (tester) async {
        var authorized = true, acquired = 0;
        // Exact browser-supported encoding spelling used by Source's files
        // fixture. Dart Uri.data alone rejects the `;utf8` shorthand.
        final svgSource =
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">'
            '<rect width="32" height="32" fill="#FDE047"/></svg>';
        final thumbnail =
            'data:image/svg+xml;utf8,${Uri.encodeComponent(svgSource)}';
        final file = SourceChannelFileEntry.parse({
          'id': 'inline',
          'messageId': 'message',
          'channelId': 'channel',
          'filename': 'thumbnail.png',
          'mimeType': 'image/png',
          'sizeBytes': 128,
          'width': 32,
          'height': 32,
          'thumbnailUrl': thumbnail,
          'createdAt': '2026-10-09T00:00:00Z',
          'source': {'type': 'channel', 'channelId': 'channel'},
        });
        Widget host() => MaterialApp(
          theme: raftTheme(theme.$1, dark: theme.$2),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: const Key('thumbnail-pixels'),
                child: SizedBox.square(
                  dimension: 32,
                  child: SourceChannelFileThumbnail(
                    file: file,
                    authorized: () => authorized,
                    acquireImage: (_, _, _) async {
                      acquired++;
                      return null;
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(host());
        // Allow the real SVG compiler's asynchronous decode to finish.
        await tester.runAsync(vg.waitForPendingDecodes);
        await tester.pumpAndSettle();
        expect(find.byType(SvgPicture), findsOneWidget);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('thumbnail-pixels')),
        );
        final image = await tester.runAsync(() => boundary.toImage());
        final rgba = await tester.runAsync(
          () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        final center = (16 * image!.width + 16) * 4;
        expect(rgba!.buffer.asUint8List().sublist(center, center + 4), [
          253,
          224,
          71,
          255,
        ]);
        image.dispose();
        expect(acquired, 0);
        authorized = false;
        await tester.pumpWidget(host());
        await tester.pumpAndSettle();
        expect(find.byType(SvgPicture), findsNothing);
        expect(find.byType(ChannelFileGlyph), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );
  }
}
