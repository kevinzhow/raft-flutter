import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/channel_management_previews.dart';
import 'package:raft_ui/raft_ui.dart';

/// Owner decision 2026-10-12: phone pages draw no left edge line (an intended
/// difference from Web); the desktop `Panel edge="attached"` borders stay.
bool _fullHeightLeftEdge(WidgetTester t, Finder scope) {
  final viewHeight = t.view.physicalSize.height / t.view.devicePixelRatio;
  for (final box in t.widgetList<DecoratedBox>(
    find.descendant(of: scope, matching: find.byType(DecoratedBox)),
  )) {
    final decoration = box.decoration;
    if (decoration is! BoxDecoration) continue;
    final border = decoration.border;
    if (border is! Border || border.left.style != BorderStyle.solid) continue;
    if (border.left.width <= 0) continue;
    final size = t.getSize(find.byWidget(box));
    // A page edge spans the whole viewport column, not a small row accent.
    if (size.height >= viewHeight - 130) return true;
  }
  return false;
}

void main() {
  Future<void> pumpAt(WidgetTester t, double width, Widget home) async {
    t.view.physicalSize = Size(width, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: home),
      ),
    );
    await t.pumpAndSettle();
  }

  final frame = RaftSettingsPanelFrame(
    header: const SizedBox(height: 56),
    child: const SizedBox.expand(),
  );

  testWidgets('settings sub-page frame: no left edge on phone', (t) async {
    await pumpAt(t, 390, frame);
    expect(
      _fullHeightLeftEdge(t, find.byType(RaftSettingsPanelFrame)),
      isFalse,
    );
  });

  testWidgets('settings sub-page frame: left edge on desktop', (t) async {
    await pumpAt(t, 1024, frame);
    expect(_fullHeightLeftEdge(t, find.byType(RaftSettingsPanelFrame)), isTrue);
  });

  testWidgets('channel members page: no left edge on phone', (t) async {
    await pumpAt(t, 390, channelMembersPagePreview());
    expect(find.byKey(const ValueKey('member-page')), findsOneWidget);
    expect(_fullHeightLeftEdge(t, find.byType(Scaffold)), isFalse);
  });

  testWidgets('members page in the bare phone sheet: no left edge', (t) async {
    await pumpAt(
      t,
      390,
      RaftOverflowBareSheet(page: true, child: channelMembersPagePreview()),
    );
    expect(find.byKey(const ValueKey('member-page')), findsOneWidget);
    expect(_fullHeightLeftEdge(t, find.byType(Scaffold)), isFalse);
  });

  testWidgets('channel settings page: no left edge on phone', (t) async {
    await pumpAt(t, 390, channelSettingsPagePreview());
    expect(find.byType(RaftOverflowSheet), findsOneWidget);
    expect(_fullHeightLeftEdge(t, find.byType(Scaffold)), isFalse);
  });

  testWidgets(
    'phone page frame keeps no edge, desktop drawer has none either',
    (t) async {
      Widget sheet({required bool page}) => RaftOverflowSheet(
        title: '#general',
        onClose: () {},
        page: page,
        children: const [SizedBox(height: 40)],
      );
      await pumpAt(t, 1024, sheet(page: false));
      final desktopEdge = _fullHeightLeftEdge(
        t,
        find.byKey(const ValueKey('channel-overflow-sheet')),
      );
      // The drawer never had a left edge.
      expect(desktopEdge, isFalse);
      await pumpAt(t, 390, sheet(page: true));
      expect(
        _fullHeightLeftEdge(
          t,
          find.byKey(const ValueKey('channel-overflow-sheet')),
        ),
        isFalse,
      );
    },
  );
}
