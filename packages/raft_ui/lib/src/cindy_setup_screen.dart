// Mounted CreateAgentDialog.tsx onboarding branch (1383–1683), not DialogCard.
// Product layout slots are controlled; admission and protocol-v2 fields remain app-owned.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../raft_ui.dart';

/// CreateAgentDialog onboarding form uses `space-y-3` (12px). The capacity
/// banner uses `mb-4` (16px), so it adds 4px to that regular field spacing.
const double raftCindyFieldGap = 12;
const EdgeInsets raftCindyCapacityFieldInset = EdgeInsets.only(bottom: 4);

class RaftCindySetupScreen extends StatelessWidget {
  const RaftCindySetupScreen({
    super.key,
    required this.fields,
    required this.onCreate,
    this.busy = false,
    this.onClose,
    this.sessionActions,
  });
  final Widget fields;
  final VoidCallback? onCreate, onClose;
  final Widget? sessionActions;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), size = MediaQuery.sizeOf(context);
    final desktop = size.width >= 768, wide = size.width >= 640;
    final border = t.brutal ? Colors.black : t.colors['line-muted']!;
    TextStyle style(
      double font,
      double line,
      FontWeight weight, {
      Color? color,
      String? family,
      double tracking = 0,
    }) => TextStyle(
      fontFamily: family ?? t.bodyFont,
      fontSize: font,
      height: line / font,
      fontWeight: weight,
      // The source Google Fonts face declares wght 300..700; CSS font-black
      // keeps computed 900 but clamps the selected variable face to 700.
      fontVariations: !t.systemFonts && weight == FontWeight.w900
          ? const [FontVariation('wght', 700)]
          : null,
      color: color ?? t.strong,
      letterSpacing: tracking,
    );
    final muted = t.colors['foreground-muted'];
    final header = Container(
      padding: EdgeInsets.fromLTRB(wide ? 36 : 24, 24, wide ? 36 : 24, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RaftCssText(
                  raftText(context, 'Set up your server').toUpperCase(),
                  style: style(
                    10,
                    15,
                    FontWeight.w700,
                    color: muted,
                    family: t.monoFont,
                    tracking: .25,
                  ),
                ),
                const SizedBox(height: 8),
                RaftCssText(
                  raftText(context, 'Meet Cindy'),
                  style: style(20, 28, FontWeight.w700),
                ),
                const SizedBox(height: 4),
                RaftCssText(
                  raftText(
                    context,
                    'Cindy is the onboarding agent that knows Raft inside out.',
                  ),
                  style: style(12, 20, FontWeight.w400, color: muted),
                ),
              ],
            ),
          ),
          if (onClose != null) ...[
            const SizedBox(width: 12),
            RaftAgentCloseButton(onPressed: busy ? null : onClose),
          ],
        ],
      ),
    );
    final hero = Container(
      padding: EdgeInsets.symmetric(
        horizontal: 32,
        vertical: desktop ? 32 : 20,
      ),
      decoration: BoxDecoration(
        color: t.colors['soft-pink'] ?? t.colors['layer-panel'],
        border: desktop
            ? Border(right: BorderSide(color: border, width: 2))
            : Border(bottom: BorderSide(color: border, width: 2)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: t.brutal
                      ? RaftProductShadows.shadowBrutalLg.outer
                      : null,
                ),
                child: RaftAvatarSlot(
                  name: 'Cindy',
                  avatarUrl: 'pixel:mug',
                  slot: RaftAvatarSlotContext.profileTile,
                  sizeOverride: desktop ? 132 : 88,
                ),
              ),
              SizedBox(height: desktop ? 20 : 12),
              RaftCssText(
                'Cindy',
                style: style(
                  desktop ? 36 : 24,
                  desktop ? 40 : 32,
                  FontWeight.w900,
                ),
              ),
              SizedBox(height: desktop ? 12 : 8),
              RaftCssText(
                raftText(
                  context,
                  'Your first agent. She helps you onboard, sets up the server, and brings your team in.',
                ),
                textAlign: TextAlign.center,
                style: style(
                  desktop ? 16 : 14,
                  desktop ? 26 : 22.75,
                  FontWeight.w500,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final fieldHost = SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: desktop ? 32 : 24,
          vertical: 24,
        ),
        child: fields,
      ),
    );
    final create = RaftButton(
      label: raftText(context, 'Create Cindy'),
      tone: RaftButtonRecipeVariant.accent,
      size: RaftButtonRecipeSize.lg,
      expand: !wide,
      busy: busy,
      // Source's onboarding footer groups the disabled surface differently
      // from ordinary CreateAgent dialogs (original99 measured RGBA bytes).
      opacityCompositing: RaftOpacityCompositing.alphaFilter,
      onPressed: busy ? null : onCreate,
    );
    final footer = Container(
      padding: EdgeInsets.symmetric(horizontal: wide ? 36 : 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: border, width: 2)),
      ),
      child: wide
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [sessionActions ?? const SizedBox.shrink(), create],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                create,
                if (sessionActions != null) ...[
                  const SizedBox(height: 12),
                  sessionActions!,
                ],
              ],
            ),
    );
    final body = desktop
        ? SizedBox(
            height: math.min(720, size.height - 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 95, child: hero),
                      Expanded(flex: 105, child: fieldHost),
                    ],
                  ),
                ),
                footer,
              ],
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              hero,
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: math.min(size.height * .7, size.height - 192),
                ),
                child: fieldHost,
              ),
              footer,
            ],
          );
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        width: math.min(desktop ? 960 : double.infinity, size.width - 16),
        child: Container(
          decoration: BoxDecoration(
            color: t.colors['layer-panel'],
            border: Border.all(
              color: t.colors[t.brutal ? 'line-strong' : 'line-muted']!,
              width: t.brutal ? 2 : 1,
            ),
            boxShadow: t.brutal
                ? RaftProductShadows.shadowBrutal.outer
                : t.themeShadows.md.outer,
          ),
          child: body,
        ),
      ),
    );
  }
}

/// SetupSessionFooter.tsx + the product muted TextLink (no button box).
class RaftCindySessionLink extends StatelessWidget {
  const RaftCindySessionLink({super.key, required this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftInteractive(
      semanticLabel: raftText(context, 'Switch server'),
      onPressed: onPressed,
      builder: (context, state) => CustomPaint(
        foregroundPainter: RaftCssFocusOutline(
          enabled: state.focusVisible,
          color: t.colors['line-strong']!,
        ),
        child: Opacity(
          opacity: state.enabled ? 1 : .5,
          child: RaftCssText(
            raftText(context, 'Switch server'),
            style: TextStyle(
              fontFamily: t.bodyFont,
              fontSize: 14,
              height: 20 / 14,
              color: state.hovered ? t.strong : t.colors['foreground-muted'],
              fontWeight: FontWeight.w400,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    );
  }
}
