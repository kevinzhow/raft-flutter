import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final spec in [
    ('elegant-light', elegantThemePackId, false),
    ('elegant-dark', elegantThemePackId, true),
    ('brutal', brutalThemePackId, false),
  ]) {
    testWidgets('public responsive frame preserves frozen ${spec.$1}', (
      t,
    ) async {
      t.view.physicalSize = const Size(780, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final old = GlobalKey(), current = GlobalKey();
      Widget frame(GlobalKey key, bool responsive) => SizedBox(
        width: 390,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: RepaintBoundary(
            key: key,
            child: RaftSettingsPanelFrame(
              header: const RaftSettingsPanelHeader(
                title: 'Language & Region',
                mobile: false,
              ),
              child: Builder(
                builder: (context) => Padding(
                  padding: responsive
                      ? RaftSettingsPanelFrame.contentInsetFor(context)
                      : RaftSettingsPanelFrame.contentInset,
                  child: const Align(
                    alignment: Alignment.topLeft,
                    child: Text('Display language'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: spec.$3, pack: packForThemeId(spec.$2)),
          home: Scaffold(
            body: Row(children: [frame(old, false), frame(current, true)]),
          ),
        ),
      );
      await t.pumpAndSettle();
      final bytes = <List<int>>[];
      await t.runAsync(() async {
        for (final entry in [('old', old), ('new', current)]) {
          final image =
              await (entry.$2.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final data = (await image.toByteData(format: ui.ImageByteFormat.png))!
              .buffer
              .asUint8List();
          bytes.add(data);
          final output = Platform.environment['PUBLIC_FRAME_OUT'];
          if (output != null) {
            Directory(output).createSync(recursive: true);
            await File('$output/${spec.$1}-${entry.$1}.png').writeAsBytes(data);
          }
          image.dispose();
        }
      });
      expect(bytes.last, orderedEquals(bytes.first));
      expect(t.takeException(), isNull);
    });
  }
}
