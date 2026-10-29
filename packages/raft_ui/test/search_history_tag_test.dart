// The Search home history tag (RaftSearchHistoryTag): Web `py-1.5 pl-2.5 pr-1`
// button in a 1px border is 30px tall at the default text size. The 28px is a
// minimum, so the Android Chinese control profile's taller line (1.3) and larger
// text grow the tag instead of squeezing the label into a box shorter than its
// line (which pushed the Chinese ink down and cut the descenders).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Future<void> _pump(
  WidgetTester t, {
  required TargetPlatform platform,
  required Locale locale,
  double scale = 1,
  String query = '对齐 gpqy',
  bool editing = false,
}) async {
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(locale: locale, platform: platform),
      locale: locale,
      home: Scaffold(
        // A Wrap, like Search home: the control sizes to its content.
        body: Wrap(
          children: [
            RaftSearchHistoryTag(
              query: query,
              touch: true,
              editing: editing,
              onPressed: () {},
              onRemove: () {},
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  for (final (name, platform, locale) in [
    ('web', TargetPlatform.macOS, const Locale('en')),
    ('android-zh', TargetPlatform.android, const Locale('zh', 'CN')),
  ]) {
    testWidgets('$name tag is 30px at 1.0x and grows with text', (t) async {
      await _pump(t, platform: platform, locale: locale);
      final tag = find.byType(RaftSearchHistoryTag);
      expect(t.getSize(tag).height, 30);
      final label = find.text('对齐 gpqy');
      // The label is centred in the tag, not pinned to the top of a short box.
      expect(
        (t.getRect(label).center.dy - t.getRect(tag).center.dy).abs(),
        lessThanOrEqualTo(0.5),
      );
      expect(
        t.getRect(label).height,
        greaterThanOrEqualTo(
          t.renderObject<RenderParagraph>(label).getMinIntrinsicHeight(1000),
        ),
        reason: 'the label gets its whole line box',
      );
      await _pump(t, platform: platform, locale: locale, scale: 2);
      expect(t.getSize(tag).height, greaterThan(30));
      expect(
        t.getRect(label).top,
        greaterThanOrEqualTo(t.getRect(tag).top),
        reason: 'at 2x the line box is inside the tag',
      );
      expect(t.getRect(label).bottom, lessThanOrEqualTo(t.getRect(tag).bottom));
    });
  }
}
