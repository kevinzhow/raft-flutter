import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/components.dart';
import 'package:raft_ui/src/mounted_avatar_recipe.dart';
import 'package:raft_ui/src/raft/raft.dart';
import 'package:raft_ui/src/theme.dart';
import 'package:raft_ui/src/tooltip.dart';
import 'package:raft_ui/test_themes.dart';

/// `border-[1.5px]` floored to whole device pixels at the test binding's 3.0 device ratio.
const _border = 4 / 3;

const busy = RaftAvatarPresence(activity: RaftAvatarActivity.working);
Widget host(Widget child, bool dark) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

void main() {
  for (final (dark) in raftThemeMatrix([(false), (true)], full: true)) {
    // Square sticker: `border-[1.5px]` paints whole device pixels, 4/3 px at the test's 3.0 ratio.
    for (final (context, extent) in [
      (RaftMountedAvatarContext.panelHeader, 36.0),
      (RaftMountedAvatarContext.compactList, 20.0),
      (RaftMountedAvatarContext.previewMini, 14.0),
    ]) {
      testWidgets(
        'mounted $context frame and real inner content ${dark ? 'dark' : 'light'}',
        (tester) async {
          await tester.pumpWidget(
            host(
              RaftMountedAvatarFrame(
                name: 'Public identity',
                avatarContext: context,
                child: const ColoredBox(
                  key: Key('public-content'),
                  color: Colors.red,
                ),
              ),
              dark,
            ),
          );
          expect(
            tester.getSize(find.byType(RaftMountedAvatarFrame)),
            Size.square(extent),
          );
          expect(
            tester.getSize(find.byKey(const Key('public-content'))).width,
            closeTo(extent - 2 * _border, 1e-9),
          );
          final frame = tester.widget<RaftCssBox>(
            find.byKey(const ValueKey('mounted-avatar-frame')),
          );
          final t = Theme.of(
            tester.element(find.byType(RaftMountedAvatarFrame)),
          ).extension<RaftTokens>()!;
          expect(frame.borderWidth, closeTo(_border, 1e-9));
          expect(frame.borderColor, t.ui.stickerInk);
          // `rounded-sticker`: a 4px square sticker, not a circle.
          expect(frame.radius, 4);
          expect(frame.fill, t.ui['palette-lavender-400']);
          expect(
            find.byKey(const ValueKey('mounted-avatar-presence')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      'muted mention frame hides status without changing layout ${dark ? 'dark' : 'light'}',
      (tester) async {
        await tester.pumpWidget(
          host(
            const RaftAvatar(
              name: 'Cindy',
              kind: RaftAvatarKind.agent,
              mountedContext: RaftMountedAvatarContext.compactList,
              presence: busy,
              muted: true,
            ),
            dark,
          ),
        );
        expect(
          tester.getSize(find.byType(RaftMountedAvatarFrame)),
          const Size.square(20),
        );
        expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, .6);
        expect(
          find.byKey(const ValueKey('mounted-avatar-presence')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'agent panel badge matches mounted DOM and remains outside image clip ${dark ? 'dark' : 'light'}',
      (tester) async {
        await tester.pumpWidget(
          host(
            const RaftMountedAvatarFrame(
              name: 'Cindy',
              identity: RaftMountedAvatarIdentity.agent,
              presence: busy,
              child: ColoredBox(color: Colors.blue),
            ),
            dark,
          ),
        );
        final badge = find.byKey(const ValueKey('mounted-avatar-presence'));
        final row = find.byType(RaftMountedAvatarFrame);
        final delta = tester.getTopLeft(badge) - tester.getTopLeft(row);
        // md sticker badge: 11px, pinned `-right-1 -bottom-1` of the padding box (36 - border + 4 - 11).
        expect(tester.getSize(badge), const Size.square(11));
        expect(delta.dx, closeTo(36 - _border + 4 - 11, 1e-9));
        expect(delta.dy, closeTo(36 - _border + 4 - 11, 1e-9));
        expect(
          find.ancestor(of: badge, matching: find.byType(ClipRRect)),
          findsNothing,
        );
        final dot = tester.widget<RaftCssBox>(
          find.descendant(of: badge, matching: find.byType(RaftCssBox)),
        );
        final t = RaftTokens.of(tester.element(row));
        expect(dot.fill, t.ui.presence('busy'));
        expect(dot.borderWidth, closeTo(_border, 1e-9));
        expect(dot.borderColor, t.ui.stickerInk);
        expect(dot.radius, 2);
        expect(dot.rings.length, 1);
        expect(dot.rings.single.color, t.panel);
        expect(dot.rings.single.spread, 2);

        await tester.pump();
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );
    testWidgets(
      'a named person shows initials, an anonymous one the placeholder icon ${dark ? 'dark' : 'light'}',
      (tester) async {
        await tester.pumpWidget(
          host(const RaftMountedAvatarFrame(name: 'Public human'), dark),
        );
        final t = RaftTokens.of(
          tester.element(find.byType(RaftMountedAvatarFrame)),
        );
        if (t.option('avatar.humanFallback', or: 'initials') == 'icon') {
          // v1.21.23 AvatarSlot: a person without a picture is the Gravatar
          // fallback, the person glyph (the Raft look).
          expect(find.text('PH'), findsNothing);
          expect(find.byType(RaftAvatarPlaceholder), findsOneWidget);
        } else {
          expect(find.text('PH'), findsOneWidget);
          expect(find.byType(RaftAvatarPlaceholder), findsNothing);
          expect(
            tester.widget<Text>(find.text('PH')).style!.color,
            t.ui.stickerInk,
          );
        }
        for (final gravatar in [false, true]) {
          await tester.pumpWidget(
            host(
              RaftMountedAvatarFrame(
                name: 'Public human',
                child: RaftMountedAvatarFallback(gravatar: gravatar),
              ),
              dark,
            ),
          );
          // The explicit humanPlaceholder branch and the nested Gravatar fallback draw the same icon (md: 18).
          final placeholder = tester.widget<RaftAvatarPlaceholder>(
            find.byType(RaftAvatarPlaceholder),
          );
          expect(placeholder.size.icon, 18);
          expect(placeholder.color, isNull);
        }
      },
    );
  }

  testWidgets(
    'unknown/human/deactivated status is not admitted and replacement clears badge',
    (tester) async {
      for (final identity in RaftMountedAvatarIdentity.values) {
        await tester.pumpWidget(
          host(
            RaftMountedAvatarFrame(
              name: 'Public',
              identity: identity,
              presence: busy,
            ),
            false,
          ),
        );
        expect(
          find.byKey(const ValueKey('mounted-avatar-presence')),
          identity == RaftMountedAvatarIdentity.agent
              ? findsOneWidget
              : findsNothing,
        );
      }
      await tester.pumpWidget(
        host(
          const RaftMountedAvatarFrame(
            name: 'Public',
            identity: RaftMountedAvatarIdentity.agent,
            presence: busy,
            deactivated: true,
          ),
          false,
        ),
      );
      expect(
        find.byKey(const ValueKey('mounted-avatar-presence')),
        findsNothing,
      );
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, .6);
      expect(find.byType(ColorFiltered), findsOneWidget);
      await tester.pumpWidget(
        host(
          const RaftMountedAvatarFrame(
            name: 'Public',
            identity: RaftMountedAvatarIdentity.agent,
          ),
          false,
        ),
      );
      expect(
        find.byKey(const ValueKey('mounted-avatar-presence')),
        findsNothing,
      );
      expect(find.byType(ColorFiltered), findsNothing);
    },
  );

  testWidgets(
    'external offline stays neutral, online external uses authorized activity',
    (tester) async {
      for (final online in [false, true]) {
        await tester.pumpWidget(
          host(
            RaftMountedAvatarFrame(
              name: 'Public external',
              identity: RaftMountedAvatarIdentity.agent,
              presence: RaftAvatarPresence(
                activity: RaftAvatarActivity.working,
                external: true,
                online: online,
              ),
            ),
            true,
          ),
        );
        final t = RaftTokens.of(
          tester.element(find.byType(RaftMountedAvatarFrame)),
        );
        final dot = tester.widget<RaftCssBox>(
          find.descendant(
            of: find.byKey(const ValueKey('mounted-avatar-presence')),
            matching: find.byType(RaftCssBox),
          ),
        );
        expect(dot.fill, t.ui.presence(online ? 'busy' : 'external'));
      }
    },
  );

  testWidgets(
    'status tooltip is provider-owned and disposal releases the surface',
    (tester) async {
      await tester.pumpWidget(
        host(
          const RaftTooltipProvider(
            delay: Duration(milliseconds: 600),
            child: RaftMountedAvatarFrame(
              name: 'Public agent',
              identity: RaftMountedAvatarIdentity.agent,
              presence: RaftAvatarPresence(
                activity: RaftAvatarActivity.online,
                label: 'Online',
              ),
            ),
          ),
          false,
        ),
      );
      expect(
        tester.widget<RaftTooltip>(find.byType(RaftTooltip)).message,
        'Online',
      );
      await tester.pumpWidget(host(const SizedBox.shrink(), false));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(RaftTooltip), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('generic avatar preserves arbitrary size and original behavior', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const RaftAvatar(name: 'Public generic', size: 44), false),
    );
    expect(find.byType(RaftMountedAvatarFrame), findsNothing);
    expect(tester.getSize(find.byType(RaftAvatar)), const Size.square(44));
    await tester.pumpWidget(
      host(
        const RaftAvatar(
          name: 'Public mounted',
          mountedContext: RaftMountedAvatarContext.compactList,
        ),
        false,
      ),
    );
    expect(tester.getSize(find.byType(RaftAvatar)), const Size.square(20));
    expect(find.byType(RaftMountedAvatarFrame), findsOneWidget);
  });
}
