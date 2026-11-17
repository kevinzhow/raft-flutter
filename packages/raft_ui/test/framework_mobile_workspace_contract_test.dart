import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

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
            // Web v1.24: the band's WorkspaceButton (on-frame md, 36 tall),
            // its avatar on the 20px edge, the bell 9px from the other.
            final control = find.descendant(
              of: selector,
              matching: find.byType(RaftButton),
            );
            expect(t.getSize(control).height, 36);
            expect(
              t.getSize(find.byType(RaftAttentionDot)),
              const Size(10, 10),
            );
            expect(
              t
                  .getRect(
                    find.descendant(
                      of: selector,
                      matching: find.byType(RaftAvatarSlot),
                    ),
                  )
                  .left,
              20,
            );
            final bell = find.byType(RaftMobileNotificationButton);
            expect(t.getSize(bell), const Size(44, 44));
            expect(t.getRect(bell).right, t.view.physicalSize.width - 9);
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
}
