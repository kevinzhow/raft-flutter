import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final family in RaftFamily.values) {
    testWidgets(
      '$family narrow sheet selector and media controls remain usable',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var toggles = 0;
          Duration? seek;
          double? volume;
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(family),
              home: Scaffold(
                body: Column(
                  children: [
                    const Expanded(
                      child: RaftDocumentPreview(
                        data: {
                          'kind': 'xlsx',
                          'sheets': [
                            {
                              'name': '日本語',
                              'headers': ['Key', 'Value'],
                              'rows': [
                                ['first', 'one'],
                              ],
                              'rowCount': 1,
                              'columnCount': 2,
                            },
                            {
                              'name': '中文',
                              'headers': ['Key'],
                              'rows': [
                                ['second'],
                              ],
                              'rowCount': 1,
                              'columnCount': 1,
                            },
                          ],
                        },
                      ),
                    ),
                    RaftMediaControls(
                      playing: false,
                      position: Duration.zero,
                      duration: const Duration(seconds: 3),
                      onPlayPause: () => toggles++,
                      onSeek: (v) => seek = v,
                      onVolume: (v) => volume = v,
                    ),
                  ],
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.text('first'), findsOneWidget);
          await tester.tap(find.text('中文'));
          await tester.pump();
          expect(find.text('second'), findsOneWidget);
          expect(find.bySemanticsLabel('second'), findsOneWidget);
          expect(find.text('first'), findsNothing);
          await tester.tap(find.byTooltip('Play'));
          expect(toggles, 1);
          final sliders = tester
              .widgetList<Slider>(find.byType(Slider))
              .toList();
          sliders[0].onChanged!(1200);
          sliders[1].onChanged!(45);
          expect(seek, const Duration(milliseconds: 1200));
          expect(volume, 45);
          expect(
            tester.getSize(find.byTooltip('Play')).height,
            greaterThanOrEqualTo(48),
          );
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
  testWidgets('unsupported empty table and disabled playback are safe', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: RaftDocumentPreview(
                  data: {'kind': 'csv', 'headers': [], 'rows': []},
                ),
              ),
              RaftMediaControls(
                playing: false,
                position: Duration.zero,
                duration: Duration.zero,
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    expect(
      tester
          .widgetList<Slider>(find.byType(Slider))
          .every((s) => s.onChanged == null),
      true,
    );
  });
}
