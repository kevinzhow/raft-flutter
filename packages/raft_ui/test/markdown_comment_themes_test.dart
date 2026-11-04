import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final id in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      if (id == brutalThemePackId && dark) continue;
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '$id/$dark/$scale section capture and flash keep document geometry',
          (t) async {
            t.view.physicalSize = const Size(856, 944);
            t.view.devicePixelRatio = 1;
            addTearDown(t.view.reset);
            final session = RaftAttachmentCommentState()..commentMode = true;
            addTearDown(session.dispose);
            addTearDown(() async {
              await t.pumpWidget(const SizedBox());
              await t.pump(const Duration(seconds: 3));
            });
            await t.pumpWidget(
              MaterialApp(
                theme: raftTheme(
                  pack: packForThemeId(id),
                  dark: dark,
                ).copyWith(platform: TargetPlatform.android),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: RaftAttachmentCommentScope(
                    state: session,
                    child: const RaftDocumentPreview(
                      data: {
                        'kind': 'markdown',
                        'markdown': '# Guide\n\nSection text.',
                      },
                    ),
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();
            final text = find.text('Section text.', findRichText: true);
            final before = t.getRect(text);
            await t.tap(text);
            await t.pump();
            expect(session.pendingAnchor?['data']['headingId'], 'guide');
            session.clearAnchor();
            expect(
              session.jump({
                'type': 'md-section',
                'data': {'headingId': 'guide'},
              }),
              isTrue,
            );
            for (var i = 0; i < 5; i++) {
              await t.pump(const Duration(milliseconds: 100));
            }
            expect(t.getRect(text), before);
            expect(t.takeException(), isNull);
            await t.pump(const Duration(seconds: 2));
          },
        );
      }
    }
  }
}
