import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('packages/raft_ui/SpaceGrotesk')
      ..addFont(
        rootBundle.load('packages/raft_ui/assets/fonts/SpaceGrotesk.ttf'),
      );
    await loader.load();
  });
  for (final dark in [false, true]) {
    for (final height in [480.0, 844.0]) {
      for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
        testWidgets(
          'phone frame $dark/$height/$platform keeps source layout and actions',
          (t) async {
            t.view.devicePixelRatio = 1;
            t.view.physicalSize = Size(
              platform == TargetPlatform.android ? 856 : 390,
              height,
            );
            addTearDown(t.view.reset);
            var opened = 0, notifications = 0;
            final semantics = t.ensureSemantics();
            await t.pumpWidget(
              MaterialApp(
                theme: raftTheme(dark: dark),
                home: Scaffold(
                  body: RaftMobileRootHeader(
                    workspace: true,
                    viewportHeight: height,
                    leading: RaftMobileServerSelector(
                      key: const Key('selector'),
                      label: 'Visual Server',
                      attention: true,
                      viewportHeight: height,
                      onPressed: () => opened++,
                    ),
                    actions: [
                      RaftMobileNotificationButton(
                        mobileHeader: true,
                        onPressed: () => notifications++,
                      ),
                    ],
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();
            final selector = find.byKey(const Key('selector'));
            final control = find.descendant(
              of: selector,
              matching: find.byType(RaftControl),
            );
            expect(t.widget<RaftControl>(control).visualHeight, 36);
            expect(t.getSize(find.byType(RaftAttentionDot)), const Size(9, 9));
            final label = t.widget<Text>(find.text('Visual Server'));
            expect(label.style!.fontSize, 17);
            expect(label.style!.height, 22 / 17);
            final recipe = RaftMobileServerSelectorRecipe(
              RaftTokens.of(t.element(selector)),
              viewportHeight: height,
            );
            expect(recipe.chevronAngle, 0);
            final bell = find.byType(RaftMobileNotificationButton);
            expect(t.getSize(bell), const Size(44, 44));
            if (height <= 600) {
              expect(t.getRect(selector).left, 16);
              expect(t.getRect(selector).top, 5.5);
              // Blink advances quantize to 1/64 CSS px; the DOM dump rounds
              // to .01px. Keep that precision allowance separate from pixels.
              expect(t.getRect(selector).width, closeTo(129.55, .02));
              final dot = t.getRect(find.byType(RaftAttentionDot));
              expect(dot.left, closeTo(140.55, .02));
              expect(dot.top, 1.5);
            }
            await t.sendKeyEvent(LogicalKeyboardKey.tab);
            await t.sendKeyEvent(LogicalKeyboardKey.enter);
            await t.pump();
            expect(opened, 1);
            await t.tapAt(
              Offset(t.getCenter(selector).dx, height <= 600 ? .5 : 4),
            );
            await t.pump();
            expect(opened, platform == TargetPlatform.android ? 2 : 1);
            await t.tap(control);
            await t.pump();
            expect(opened, platform == TargetPlatform.android ? 3 : 2);
            await t.tap(bell);
            await t.pump();
            expect(notifications, 1);
            expect(t.takeException(), isNull);
            semantics.dispose();
            await t.pumpWidget(const SizedBox.shrink());
          },
          variant: TargetPlatformVariant.only(platform),
        );
      }
    }
  }
  for (final pack in raftThemeMatrix([
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      for (final height in [480.0, 844.0]) {
        testWidgets(
          'a57 $pack/$dark/$height preserves mobile workspace geometry',
          (t) async {
            await t.pumpWidget(
              MaterialApp(
                theme: raftTheme(pack: packForThemeId(pack), dark: dark),
                home: Scaffold(
                  body: RaftMobileRootHeader(
                    workspace: true,
                    viewportHeight: height,
                    leading: RaftMobileServerSelector(
                      label: 'Legacy',
                      viewportHeight: height,
                      onPressed: () {},
                    ),
                    actions: const [
                      RaftMobileNotificationButton(mobileHeader: true),
                    ],
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();
            expect(find.byType(RaftMobilePageHeader), findsOneWidget);
            final text = t.widget<Text>(find.text('Legacy'));
            expect(text.style!.fontSize, 16);
            expect(text.style!.height, 24 / 16);
            final bell = find.byType(RaftMobileNotificationButton);
            expect(t.getSize(bell), const Size(32, 32));
            expect(
              t
                  .widget<RaftIcon>(
                    find.descendant(of: bell, matching: find.byType(RaftIcon)),
                  )
                  .size,
              16,
            );
            final control = t.widget<RaftControl>(
              find.descendant(
                of: find.byType(RaftMobileServerSelector),
                matching: find.byType(RaftControl),
              ),
            );
            expect(control.visualHeight, height <= 600 ? 24 : 36);
            await t.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
}
