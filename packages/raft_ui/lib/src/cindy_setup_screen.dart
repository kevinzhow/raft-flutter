// OnboardingCreateAgent ("Create Cindy" Step C) framing aligned to Web v1.24.
// Product layout slots are controlled; admission and protocol-v2 fields remain app-owned.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../raft_ui.dart';

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
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final screen = MediaQuery.sizeOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final availableWidth = box.hasBoundedWidth
            ? math.min(screen.width, box.maxWidth)
            : screen.width;
        final availableHeight = box.hasBoundedHeight
            ? math.min(screen.height, box.maxHeight)
            : screen.height;
        final wide = availableWidth >= 768;
        final sm = availableWidth >= 640;
        final seamWidth = raftControlBorderPx(
          context,
          t.size('border.seam', fallback: 1),
        );
        final stickerWidth = raftControlBorderPx(
          context,
          t.size('border.sticker', fallback: 1.5),
        );
        final containerRadius = t.size(
          'radius.container',
          fallback: RaftRadius.container,
        );
        final seam = BorderSide(color: ui.lineSeam, width: seamWidth);
        final stickerShadow =
            (t.dark ? RaftDark.elevationSticker : RaftLight.elevationSticker)
                .outer;

        final header = Container(
          decoration: BoxDecoration(border: Border(bottom: seam)),
          padding: EdgeInsets.fromLTRB(wide ? 36 : 24, 24, wide ? 36 : 24, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RaftSectionEyebrow(raftText(context, 'Set up your server')),
                    const SizedBox(height: 4),
                    Text(
                      raftText(context, 'Meet Cindy'),
                      style: t.scale(
                        RaftTypeScale.title,
                        weight: FontWeight.w700,
                        color: ui.foreground,
                      ),
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

        final heroSticker = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Transform.rotate(
              angle: -1.5 * math.pi / 180,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  color: ui.layerCanvas,
                  borderRadius: BorderRadius.all(
                    Radius.circular(containerRadius),
                  ),
                  border: Border.all(color: ui.lineStrong, width: stickerWidth),
                  boxShadow: stickerShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: wide ? 20 : 12),
                      child: RaftAvatarSlot(
                        name: 'Cindy',
                        avatarUrl: 'pixel:mug',
                        slot: RaftAvatarSlotContext.profileHero,
                        sizeOverride: RaftAvatarSize.xl.extent,
                      ),
                    ),
                    Text(
                      raftText(context, 'Cindy'),
                      textAlign: TextAlign.center,
                      style: t.scale(
                        wide ? RaftTypeScale.display : RaftTypeScale.title,
                        weight: FontWeight.w700,
                        color: ui.foreground,
                      ),
                    ),
                    SizedBox(height: wide ? 12 : 8),
                    Text(
                      raftText(
                        context,
                        'Your first agent. She helps you onboard, sets up the server, and brings your team in.',
                      ),
                      textAlign: TextAlign.center,
                      style: t.scale(
                        wide ? RaftTypeScale.body : RaftTypeScale.callout,
                        weight: FontWeight.w500,
                        color: ui.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final heroPane = Container(
          decoration: BoxDecoration(
            color: ui.layerSidebar,
            border: wide ? Border(right: seam) : Border(bottom: seam),
          ),
          child: CustomPaint(
            painter: _SetupPaperDotPainter(
              color: ui.lineHairline.withValues(alpha: ui.lineHairline.a * 0.6),
              grid: t.size('size.onboardingDotGrid', fallback: 14),
              radius: t.size('size.onboardingDotRadius', fallback: 1.5),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 32,
                vertical: wide ? 32 : 20,
              ),
              child: heroSticker,
            ),
          ),
        );

        final fieldsPane = Padding(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 32 : 24,
            vertical: 24,
          ),
          child: fields,
        );

        final create = RaftButton(
          label: raftText(context, 'Create Cindy'),
          uiVariant: RaftButtonVariant.accent,
          uiSize: RaftButtonSize.lg,
          expand: !sm,
          busy: busy,
          opacityCompositing: RaftOpacityCompositing.alphaFilter,
          onPressed: busy ? null : onCreate,
        );

        final footer = Container(
          decoration: BoxDecoration(border: Border(top: seam)),
          padding: EdgeInsets.symmetric(horizontal: sm ? 36 : 20, vertical: 12),
          child: sm
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: sessionActions ?? const SizedBox.shrink()),
                    const SizedBox(width: 12),
                    create,
                  ],
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

        final targetWidth = math.max(
          0.0,
          math.min(wide ? 960.0 : double.infinity, availableWidth - 16.0),
        );
        final targetHeight = wide
            ? math.max(0.0, math.min(720.0, availableHeight - 32.0))
            : null;

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: wide ? 960.0 : math.max(0.0, screen.width - 16.0),
            maxHeight: targetHeight ?? availableHeight,
          ),
          child: SizedBox(
            width: wide ? targetWidth : null,
            height: targetHeight,
            child: RaftDialogSurface(
              child: Column(
                mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  if (wide)
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 95, child: heroPane),
                          Expanded(
                            flex: 105,
                            child: SingleChildScrollView(child: fieldsPane),
                          ),
                        ],
                      ),
                    )
                  else
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [heroPane, fieldsPane],
                        ),
                      ),
                    ),
                  footer,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SetupPaperDotPainter extends CustomPainter {
  const _SetupPaperDotPainter({
    required this.color,
    required this.grid,
    required this.radius,
  });

  final Color color;
  final double grid;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    for (var y = grid / 2; y < size.height; y += grid) {
      for (var x = grid / 2; x < size.width; x += grid) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SetupPaperDotPainter old) =>
      old.color != color || old.grid != grid || old.radius != radius;
}

class RaftCindySessionLink extends StatelessWidget {
  const RaftCindySessionLink({
    super.key,
    required this.onPressed,
    this.label = 'Switch Server',
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = raftText(context, label);
    return RaftTextLink(
      label: text,
      semanticLabel: text,
      variant: RaftTextLinkVariant.muted,
      scale: RaftTypeScale.footnote,
      onPressed: onPressed,
    );
  }
}

/// SetupSessionFooter.tsx: `flex items-center gap-4 text-sm` with the muted
/// "Switch server" link and, for the server's owner, "Delete this server".
class RaftCindySessionFooter extends StatelessWidget {
  const RaftCindySessionFooter({
    super.key,
    this.onSwitchServer,
    this.onDeleteServer,
    this.showDeleteServer,
  });

  final VoidCallback? onSwitchServer, onDeleteServer;
  final bool? showDeleteServer;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 16,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      RaftCindySessionLink(onPressed: onSwitchServer),
      if (showDeleteServer ?? onDeleteServer != null)
        RaftCindySessionLink(
          key: const ValueKey('setup-delete-server'),
          label: 'Delete this server',
          onPressed: onDeleteServer,
        ),
    ],
  );
}
