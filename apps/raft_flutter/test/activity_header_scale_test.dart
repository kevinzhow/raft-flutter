import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/page_layout.dart';
import 'package:raft_ui/raft_ui.dart';

/// Activity column header at a 768×900 window.
///
/// The recorded failure is this bar, not the search toolbar under it.
/// [RaftTextScaling] over a platform scale of 2 makes the title and
/// subtitle column overflow a fixed-height bar. Default scale stays on the
/// 56px shell header (the Brutal 62px bar no longer exists).
void main() {
  testWidgets('Activity header stays 56px at the default text size', (
    tester,
  ) async {
    await pumpActivityHeader(tester, scale: 1);
    expect(headerHeight(tester), 56);
    expect(find.text('3 active'), findsOneWidget);
  });

  testWidgets(
    'Activity header shows its subtitle at 2x text without overflow',
    (tester) async {
      await pumpActivityHeader(tester, scale: 2);
      final height = headerHeight(tester);
      expect(height, greaterThan(56));
      final header = tester.getRect(
        find.byKey(const Key('page-header-surface')),
      );
      final subtitle = tester.getRect(find.text('3 active'));
      expect(header.contains(subtitle.topLeft), isTrue);
      expect(header.contains(subtitle.bottomRight), isTrue);
    },
  );
}

Future<void> pumpActivityHeader(
  WidgetTester tester, {
  required double scale,
}) async {
  tester.view.physicalSize = const Size(768, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: RaftTextScaling(child: child!),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            final mobile =
                MediaQuery.sizeOf(context).width <
                RaftLayoutMetrics.desktopBreakpoint;
            return Column(
              children: [
                RaftPageHeader(
                  title: 'Activity',
                  subtitle: '3 active',
                  height: raftPageHeaderHeight(context),
                  mobile: mobile,
                  leftInset: 12,
                  bottomRule: true,
                  icon: const RaftIcon(RaftGlyph.activity),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

double headerHeight(WidgetTester tester) =>
    tester.getSize(find.byKey(const Key('page-header-surface'))).height;
