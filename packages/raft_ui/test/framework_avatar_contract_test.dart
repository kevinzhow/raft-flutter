import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// db5e399f AvatarSlot sidebarList / GravatarAvatar: the fallback is User,
// with the 2xs leaf's 10px glyph. The frozen packs keep their identity fallback.
void main() {
  for (final pack in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      testWidgets('$pack/$dark sidebar fallback and other contexts', (t) async {
        for (final gravatar in [false, true]) {
          for (final name in ['', 'Designer']) {
            await t.pumpWidget(
              MaterialApp(
                theme: raftTheme(pack: packForThemeId(pack), dark: dark),
                home: Material(
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 19,
                        child: RaftMountedAvatarFallback(
                          key: const ValueKey('sidebar'),
                          avatarContext: RaftMountedAvatarContext.sidebarList,
                          gravatar: gravatar,
                          initials: name,
                        ),
                      ),
                      SizedBox.square(
                        dimension: 35,
                        child: RaftMountedAvatarFallback(
                          key: const ValueKey('panel'),
                          initials: name,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            final sidebar = find.byKey(const ValueKey('sidebar'));
            if (pack == raftThemePackId) {
              final glyph = find.descendant(
                of: sidebar,
                matching: find.byType(RaftIcon),
              );
              expect(glyph, findsOneWidget);
              expect(t.widget<RaftIcon>(glyph).glyph, RaftGlyph.user);
              expect(t.widget<RaftIcon>(glyph).size, 10);
            } else {
              expect(
                find.descendant(
                  of: sidebar,
                  matching: find.byType(
                    name.isEmpty ? RaftAvatarPlaceholder : RaftAvatarInitials,
                  ),
                ),
                findsOneWidget,
              );
            }
            expect(
              find.descendant(
                of: find.byKey(const ValueKey('panel')),
                matching: find.byType(
                  pack == raftThemePackId || name.isEmpty
                      ? RaftAvatarPlaceholder
                      : RaftAvatarInitials,
                ),
              ),
              findsOneWidget,
            );
            expect(t.takeException(), isNull);
          }
        }
        await t.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
    }
  }
}
