import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} mobile channel retains identity description and scoped actions',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        var backs = 0, searches = 0, settings = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Column(
                children: [
                  RaftChannelHeader(
                    name: '首页专修',
                    kind: 'private',
                    description: 'Public description across more than one line and still inside the identity header.',
                    onBack: () => ++backs,
                    onSearch: () => ++searches,
                    onSettings: () => ++settings,
                  ),
                ],
              ),
            ),
          ),
        );
        expect(find.text('首页专修'), findsOneWidget);
        // Below md Web renders the same PanelHeader recipe (`max-md:` variants
        // resolved at 390px): h-56, 44px ghost Back,
        // identity icon cell, title + meta.
        final header = find.byType(RaftConversationHeader);
        expect(t.getSize(header).height, 56);
        expect(find.byType(RaftMobilePageHeader), findsNothing);
        final back = find.byType(RaftPanelAction);
        expect(t.getSize(back), const Size(44, 44));
        // panelHeadEdges: pl-4 plus the leading -ml-[13px].
        expect(t.getTopLeft(back).dx, 3);
        for (final label in ['Search This Channel', 'Channel Settings']) {
          expect(t.getSize(find.bySemanticsLabel(label)), const Size(32, 32));
        }
        // PanelMeta is `truncate`: ChannelDescription's line clamp never
        // wraps; the one line is clipped at the content edge.
        final description = t.widget<Text>(
          find.textContaining('Public description'),
        );
        expect(description.maxLines, 1);
        expect(description.softWrap, false);
        expect(
          find.byWidgetPredicate(
            (w) => w is RaftIcon && w.glyph == RaftGlyph.lock,
          ),
          findsOneWidget,
        );
        await t.tap(find.bySemanticsLabel('Back'));
        await t.tap(find.bySemanticsLabel('Search This Channel'));
        await t.tap(find.bySemanticsLabel('Channel Settings'));
        expect([backs, searches, settings], [1, 1, 1]);
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      '${dark ? 'dark' : 'light'} header icon preserves touch and keyboard access',
      (t) async {
        var searches = 0;
        Future<void> mount({required bool enabled}) => t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Center(
                child: RaftDensityScope(
                  density: RaftDensity.touch,
                  child: RaftPanelIconButton(
                    glyph: RaftGlyph.search,
                    tooltip: 'Search This Channel',
                    onPressed: enabled ? () => ++searches : null,
                  ),
                ),
              ),
            ),
          ),
        );
        await mount(enabled: true);
        final button = find.byType(RaftPanelIconButton);
        final rect = t.getRect(button);
        // Touch input keeps the 44px PanelAction even on a wide viewport.
        expect(rect.size, const Size(44, 44));
        await t.tapAt(rect.center + const Offset(0, 23));
        await t.pump();
        expect(searches, 1);
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pump();
        expect(searches, 2);
        final semantics = t.ensureSemantics();
        expect(t, meetsGuideline(androidTapTargetGuideline));
        expect(t, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
        await mount(enabled: false);
        await t.tapAt(rect.center);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(searches, 2);
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      '${dark ? 'dark' : 'light'} DM header keeps its layout when agent status arrives',
      (t) async {
        t.view.physicalSize = const Size(1000, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        var searches = 0, settings = 0, avatarTaps = 0;
        Future<void> mount({RaftActivityTone? activity, String? text}) =>
            t.pumpWidget(
              MaterialApp(
                theme: raftTheme(dark: dark),
                home: Scaffold(
                  body: Column(
                    children: [
                      RaftDmHeader(
                        key: const Key('dm'),
                        name: 'Cindy',
                        avatar: const SizedBox.square(
                          key: Key('avatar'),
                          dimension: 36,
                        ),
                        activity: activity,
                        activityText: text,
                        onSearch: () => ++searches,
                        onSettings: () => ++settings,
                        onAvatarTap: () => ++avatarTaps,
                      ),
                    ],
                  ),
                ),
              ),
            );
        await mount();
        final header = t.getRect(find.byKey(const Key('dm')));
        final avatar = t.getRect(find.byKey(const Key('avatar')));
        final name = t.getRect(find.text('Cindy'));
        await mount(
          activity: RaftActivityTone.working,
          text: 'Capturing visual testing baselines',
        );
        // A status arriving later only adds the dot and text after the name.
        expect(t.getRect(find.byKey(const Key('dm'))), header);
        expect(t.getRect(find.byKey(const Key('avatar'))), avatar);
        expect(t.getRect(find.text('Cindy')), name);
        expect(find.byType(RaftStatusDot), findsOneWidget);
        expect(find.text('Capturing visual testing baselines'), findsOneWidget);
        // Fully visible texts never repeat themselves in a tooltip.
        for (final tooltip in t.widgetList<RaftTooltip>(
          find.ancestor(
            of: find.text('Cindy'),
            matching: find.byType(RaftTooltip),
          ),
        )) {
          expect(tooltip.onlyWhenTruncated, true);
        }
        await t.tap(find.byKey(const ValueKey('channel-topbar-search')));
        await t.tap(find.byKey(const ValueKey('channel-overflow-trigger')));
        await t.tap(find.byKey(const Key('dm-header-avatar-button')));
        expect([searches, settings, avatarTaps], [1, 1, 1]);
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      '${dark ? 'dark' : 'light'} channel description collapses authored newlines',
      (t) async {
        t.view.physicalSize = const Size(1000, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: const Scaffold(
              body: Column(
                children: [
                  RaftChannelHeader(
                    name: 'colvalley',
                    description: '日语 lost and found 单词 App\n结合了  crowded scene',
                  ),
                ],
              ),
            ),
          ),
        );
        expect(
          find.text('日语 lost and found 单词 App 结合了 crowded scene'),
          findsOneWidget,
        );
        // One line: the header keeps its shell height.
        expect(t.getSize(find.byType(RaftChannelHeader)).height, 56);
        expect(t.takeException(), isNull);
      },
    );
  }
}
