import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    Future<void> mount(
      WidgetTester tester,
      Widget child, {
      required double width,
      required RaftDensity density,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: RaftDensityScope(
              density: density,
              // The mounted host Column supplies loose horizontal constraints. A
              // shrinkwrapped strip here used to be centered by this actual host.
              child: Column(children: [child]),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
    }

    for (final density in RaftDensity.values) {
      for (final width in [390.0, 1000.0]) {
        testWidgets(
          '${dark ? 'dark' : 'light'}/$density/$width mounted tabs are source-sized and left anchored',
          (tester) async {
            var selected = RaftConversationTabId.chat;
            var calls = 0;
            await mount(
              tester,
              StatefulBuilder(
                builder: (context, update) => RaftConversationTabs(
                  tabs: const [
                    RaftConversationTab(
                      id: RaftConversationTabId.chat,
                      label: 'Chat',
                    ),
                    RaftConversationTab(
                      id: RaftConversationTabId.tasks,
                      label: 'Tasks',
                      enabled: false,
                    ),
                    RaftConversationTab(
                      id: RaftConversationTabId.files,
                      label: 'Files',
                    ),
                  ],
                  value: selected,
                  onChanged: (value) {
                    calls++;
                    update(() => selected = value);
                  },
                ),
              ),
              width: width,
              density: density,
            );
            final strip = find.byType(RaftConversationTabs);
            final chat = find.byKey(const ValueKey('panel-tab-chat'));
            final files = find.byKey(const ValueKey('panel-tab-files'));
            expect(tester.getRect(strip).left, 0);
            expect(tester.getSize(strip).width, width);
            expect(tester.getRect(chat).left, width < 768 ? 16 : 20);
            final mobile = width < 768;
            // Pinned raft-ui 0.7.0 default tabs: 32px within py8 and a 1px rule.
            const expectedStrip = 49.0;
            const expectedTarget = 32.0;
            expect(tester.getSize(strip).height, expectedStrip);
            expect(tester.getSize(chat).height, expectedTarget);
            final tab = tester.widget<RaftTabButton>(chat);
            expect(tab.variant, RaftTabsVariant.standard);
            expect(tab.padding, isNull);
            final surface = tester.widget<Container>(
              find
                  .descendant(of: strip, matching: find.byType(Container))
                  .first,
            );
            final recipe = RaftConversationTabsRecipe(
              RaftTokens.of(tester.element(strip)),
              mobile: mobile,
              density: density,
            );
            expect(
              (surface.decoration! as BoxDecoration).color,
              recipe.background,
            );
            if (dark && !mobile) {
              expect(
                recipe.background,
                RaftTokens.of(tester.element(strip)).canvas,
              );
              expect(recipe.background, const Color(0xff1b1b19));
            }

            await tester.tap(chat);
            expect(calls, 1);
            await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
            await tester.pump();
            expect(selected, RaftConversationTabId.files);
            expect(calls, 2);
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            expect(calls, 3);
            final disabled = find.byKey(const ValueKey('panel-tab-tasks'));
            await tester.tapAt(tester.getCenter(disabled));
            expect(calls, 3);
            await tester.tapAt(tester.getCenter(files));
            expect(calls, 4);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(milliseconds: 350));
          },
        );
      }
    }
    testWidgets(
      '${dark ? 'dark' : 'light'} date rules consume every remaining content pixel',
      (tester) async {
        await mount(
          tester,
          const SizedBox(
            width: 640,
            child: RaftConversationDateHeader(label: 'Today'),
          ),
          width: 1000,
          density: RaftDensity.desktop,
        );
        final rules = find.byType(RaftSeparator);
        final label = find.text('Today');
        expect(rules, findsNWidgets(2));
        final first = tester.getRect(rules.at(0));
        final second = tester.getRect(rules.at(1));
        final text = tester.getRect(label);
        final outer = tester.getRect(find.byType(RaftConversationDateHeader));
        expect(first.left, outer.left + 12);
        expect(second.right, outer.right - 12);
        expect(text.left - first.right, closeTo(8, .001));
        expect(second.left - text.right, closeTo(8, .001));
        expect(first.width, closeTo(second.width, .001));
        expect(
          first.width + second.width + text.width + 16,
          closeTo(616, .001),
        );
        expect(first.width, greaterThan(200));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 350));
      },
    );
    testWidgets(
      '${dark ? 'dark' : 'light'} long localized date remains bounded without phantom flex space',
      (tester) async {
        await mount(
          tester,
          const SizedBox(
            width: 120,
            child: RaftConversationDateHeader(
              label: 'A genuinely long viewer-localized date 中文 日本語',
            ),
          ),
          width: 390,
          density: RaftDensity.touch,
        );
        expect(tester.takeException(), isNull);
        final outer = tester.getRect(find.byType(RaftConversationDateHeader));
        final label = tester.getRect(find.byType(Text));
        expect(label.left, greaterThanOrEqualTo(outer.left + 12));
        expect(label.right, lessThanOrEqualTo(outer.right - 12));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 350));
      },
    );
  }
}
