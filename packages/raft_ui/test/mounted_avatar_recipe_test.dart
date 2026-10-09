import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/components.dart';
import 'package:raft_ui/src/icons.dart';
import 'package:raft_ui/src/mounted_avatar_recipe.dart';
import 'package:raft_ui/src/theme.dart';
import 'package:raft_ui/src/tooltip.dart';

const busy = RaftAvatarPresence(activity: RaftAvatarActivity.working);
Widget host(Widget child, RaftFamily family, bool dark) => MaterialApp(
  theme: raftTheme(family, dark: dark),
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final (context, extent, inner) in [
      (RaftMountedAvatarContext.panelHeader, 36.0, 32.0),
      (RaftMountedAvatarContext.compactList, 20.0, 18.0),
      (RaftMountedAvatarContext.previewMini, 14.0, 12.0),
    ]) {
      testWidgets(
        'mounted $context frame and real inner content $family/$dark',
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
              family,
              dark,
            ),
          );
          expect(
            tester.getSize(find.byType(RaftMountedAvatarFrame)),
            Size.square(extent),
          );
          expect(
            tester.getSize(find.byKey(const Key('public-content'))),
            Size.square(inner),
          );
          final frame = tester.widget<DecoratedBox>(
            find.byKey(const ValueKey('mounted-avatar-frame')),
          );
          final decoration = frame.decoration as BoxDecoration;
          expect(decoration.border!.top.width, (extent - inner) / 2);
          expect(
            decoration.border!.top.color,
            family == RaftFamily.brutal ? Colors.black : Colors.transparent,
          );
          expect(
            decoration.borderRadius,
            BorderRadius.circular(family == RaftFamily.brutal ? 0 : extent / 2),
          );
          final fill = tester.widget<DecoratedBox>(
            find.byKey(const ValueKey('mounted-avatar-fallback-fill')),
          );
          final t = Theme.of(
            tester.element(find.byType(RaftMountedAvatarFrame)),
          ).extension<RaftTokens>()!;
          expect(
            (fill.decoration as BoxDecoration).color,
            t.colors[family == RaftFamily.brutal
                ? 'color-brutal-lavender'
                : 'fill-strong'],
          );
          expect(
            find.byKey(const ValueKey('mounted-avatar-presence')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      'agent panel badge matches mounted DOM and remains outside image clip $family/$dark',
      (tester) async {
        await tester.pumpWidget(
          host(
            const RaftMountedAvatarFrame(
              name: 'Cindy',
              identity: RaftMountedAvatarIdentity.agent,
              presence: busy,
              child: ColoredBox(color: Colors.blue),
            ),
            family,
            dark,
          ),
        );
        final badge = find.byKey(const ValueKey('mounted-avatar-presence'));
        final row = find.byType(RaftMountedAvatarFrame);
        final delta = tester.getTopLeft(badge) - tester.getTopLeft(row);
        expect(tester.getSize(badge), const Size.square(10));
        expect(delta.dx, family == RaftFamily.brutal ? 28.75 : 25);
        expect(delta.dy, family == RaftFamily.brutal ? 28.75 : 25);
        expect(
          find.ancestor(of: badge, matching: find.byType(ClipRRect)),
          findsNothing,
        );
        final decoration =
            tester.widget<DecoratedBox>(badge).decoration as BoxDecoration;
        expect(decoration.color, const Color(0xffffd440));
        expect(decoration.border!.top.width, 1);
        expect(
          decoration.boxShadow!.length,
          family == RaftFamily.brutal ? 0 : 1,
        );
        if (family == RaftFamily.elegant) {
          final t = RaftTokens.of(tester.element(row));
          expect(decoration.boxShadow!.single.color, t.panel);
          expect(decoration.boxShadow!.single.spreadRadius, 2);
        }
        await tester.pump();
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );
    testWidgets(
      'explicit and nested Gravatar fallbacks use separate source glyph sizes $family/$dark',
      (tester) async {
        await tester.pumpWidget(
          host(
            const RaftMountedAvatarFrame(name: 'Public human'),
            family,
            dark,
          ),
        );
        var glyph = tester.widget<RaftIcon>(find.byType(RaftIcon));
        expect(glyph.size, 18);
        final t = RaftTokens.of(
          tester.element(find.byType(RaftMountedAvatarFrame)),
        );
        expect(
          glyph.color,
          family == RaftFamily.brutal
              ? Colors.black
              : t.colors['foreground-placeholder']!.withValues(alpha: .7),
        );
        await tester.pumpWidget(
          host(
            const RaftMountedAvatarFrame(
              name: 'Public human',
              child: RaftMountedAvatarFallback(gravatar: true),
            ),
            family,
            dark,
          ),
        );
        glyph = tester.widget<RaftIcon>(find.byType(RaftIcon));
        expect(glyph.size, 16);
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
            RaftFamily.elegant,
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
          RaftFamily.elegant,
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
          RaftFamily.elegant,
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
            RaftFamily.elegant,
            true,
          ),
        );
        final t = RaftTokens.of(
          tester.element(find.byType(RaftMountedAvatarFrame)),
        );
        final d =
            tester
                    .widget<DecoratedBox>(
                      find.byKey(const ValueKey('mounted-avatar-presence')),
                    )
                    .decoration
                as BoxDecoration;
        expect(
          d.color,
          online
              ? RaftAvatarStatusPrimitives.busy
              : t.colors['color-brutal-cyan'],
        );
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
          RaftFamily.brutal,
          false,
        ),
      );
      expect(
        tester.widget<RaftTooltip>(find.byType(RaftTooltip)).message,
        'Online',
      );
      await tester.pumpWidget(
        host(const SizedBox.shrink(), RaftFamily.brutal, false),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(RaftTooltip), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('generic avatar preserves arbitrary size and original behavior', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const RaftAvatar(name: 'Public generic', size: 44),
        RaftFamily.elegant,
        false,
      ),
    );
    expect(find.byType(RaftMountedAvatarFrame), findsNothing);
    expect(tester.getSize(find.byType(RaftAvatar)), const Size.square(44));
    await tester.pumpWidget(
      host(
        const RaftAvatar(
          name: 'Public mounted',
          mountedContext: RaftMountedAvatarContext.compactList,
        ),
        RaftFamily.elegant,
        false,
      ),
    );
    expect(tester.getSize(find.byType(RaftAvatar)), const Size.square(20));
    expect(find.byType(RaftMountedAvatarFrame), findsOneWidget);
  });
}
