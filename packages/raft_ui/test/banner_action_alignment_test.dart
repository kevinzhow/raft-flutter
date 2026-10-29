import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import '../../../tool/testing/vertical_alignment.dart';

/// An explicitly centered banner row (icon, copy, trailing action) keeps its children on one
/// vertical centre, like Web's `items-center` grid with the `BannerAction`
/// `flex items-center` group. Single-line copy only: a title and description
/// stack, and Web then top-aligns the action across both rows (`row-span-2`).
void main() {
  for (final androidZh in [false, true])
    for (final dark in raftThemeMatrix([false, true])) {
      for (final size in RaftBannerRecipeSize.values) {
        for (final glyph in [null, RaftGlyph.info]) {
          for (final width in [460.0, 700.0]) {
            testWidgets(
              'banner copy, icon and action share a centre: ${dark ? 'dark' : 'light'} '
              '${androidZh ? 'android-zh ' : ''}'
              '${size.name} ${glyph == null ? 'no icon' : 'icon'} ${width}px',
              (tester) async {
                await tester.pumpWidget(
                  MaterialApp(
                    locale: androidZh ? const Locale('zh') : null,
                    theme: raftTheme(
                      dark: dark,
                      locale: androidZh ? const Locale('zh') : null,
                      platform: androidZh ? TargetPlatform.android : null,
                    ),
                    home: Scaffold(
                      body: Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: width,
                          child: RaftBanner(
                            key: const ValueKey('banner'),
                            // Current Web defaults to items-start; callers such as the
                            // machine-detail disk banner explicitly center their action.
                            centerAction: true,
                            description: 'Reconnect to send',
                            size: size,
                            glyph: glyph,
                            action: RaftButton(
                              key: const ValueKey('action'),
                              label: 'Retry',
                              size: RaftButtonRecipeSize.sm,
                              visualHeight: RaftMetrics.buttonSm,
                              onPressed: () {},
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                expectVerticallyCentered(tester, [
                  find.byKey(const ValueKey('action')),
                  find.text('Reconnect to send'),
                  if (glyph != null) find.byType(RaftIcon),
                ], reason: 'RaftBanner ${size.name}');
                expectCenteredIn(tester, find.byKey(const ValueKey('banner')), [
                  find.byKey(const ValueKey('action')),
                ], reason: 'RaftBanner ${size.name} action in the banner');
              },
            );
          }
        }
      }
    }
}
