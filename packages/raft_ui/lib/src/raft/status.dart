// raft-ui 0.7.1 `Status` (dist `status`): a square presence pixel, `bg-(--status-color) rounded-[2px]
// border-[1.5px] border-sticker-ink`. The five presence lights have fixed meanings (online green, busy yellow,
// error orange, offline stone, external cyan); the `variant` axis paints the brand / status colours instead.
// `RaftStatusDot` and `RaftAttentionDot` (the older call-site names) draw the same pixel.
import 'package:flutter/material.dart';

import '../theme.dart';
import 'blink_snap.dart';
import 'css_box.dart';
import 'ui_tokens.dart';

/// The five presence lights (`presence.ts` `PRESENCE_COLOR`).
enum RaftPresence {
  online,
  busy,
  error,
  offline,
  external;

  /// `--presence-<name>`.
  String get token => 'presence-$name';
}

/// `variant` axis of `status`.
enum RaftStatusVariant {
  default_,
  primary,
  information,
  muted,
  accent,
  success,
  warning,
  danger;

  /// The `--status-color` token of the variant (`[--status-color:var(--color-*)]`).
  String get token => switch (this) {
    default_ => 'presence-offline',
    primary => 'brand-400',
    information => 'info',
    muted => 'palette-stone-400',
    accent => 'attention-400',
    success => 'success',
    warning => 'warning',
    danger => 'danger',
  };
}

/// `size` axis of `status`: `size-1.5` (1px border, 1px radius), `size-2`, `size-[9px]`, `size-[11px]`.
enum RaftStatusSize {
  xs(6, 1, 1),
  sm(8, 2, 1.5),
  md(9, 2, 1.5),
  lg(11, 2, 1.5);

  const RaftStatusSize(this.px, this.radius, this.border);

  /// Outer edge (border box).
  final double px;

  /// `rounded-[2px]` (`rounded-[1px]` for xs).
  final double radius;

  /// CSS border width before Blink's floor.
  final double border;
}

/// raft-ui `Status`. Pass a [presence] light, or a [variant]; an explicit [color] wins over both (a caller that
/// already resolved its own fill).
class RaftStatus extends StatelessWidget {
  const RaftStatus({
    super.key,
    this.size = RaftStatusSize.md,
    this.variant = RaftStatusVariant.default_,
    this.presence,
    this.color,
    this.semanticLabel,
  });

  final RaftStatusSize size;
  final RaftStatusVariant variant;
  final RaftPresence? presence;
  final Color? color;

  /// `role="img"` + `aria-label`; without it the pixel is decorative (`aria-hidden`).
  final String? semanticLabel;

  /// The fill of [presence] / [variant] in the active mode.
  static Color fillOf(
    RaftUiColors ui, {
    RaftPresence? presence,
    RaftStatusVariant variant = RaftStatusVariant.default_,
  }) => ui[presence?.token ?? variant.token];

  @override
  Widget build(BuildContext context) {
    final ui = RaftTokens.of(context).ui;
    final box = RaftCssBox(
      radius: size.radius,
      fill: color ?? fillOf(ui, presence: presence, variant: variant),
      borderWidth: raftControlBorderPx(context, size.border),
      borderColor: ui.stickerInk,
      width: size.px,
      height: size.px,
    );
    final snapped = RaftBlinkSnap(child: box);
    return semanticLabel == null
        ? ExcludeSemantics(child: snapped)
        : Semantics(label: semanticLabel, image: true, child: snapped);
  }
}

/// Dot sizes of the older call sites, mapped onto the pixel sizes.
enum RaftStatusDotSize {
  /// `size-2`
  sm(RaftStatusSize.sm),

  /// `size-[9px]` (the pixel's default; was `size-2.5`)
  md(RaftStatusSize.md),

  /// `size-[11px]`
  lg(RaftStatusSize.lg);

  const RaftStatusDotSize(this.status);
  final RaftStatusSize status;
  double get px => status.px;
}

/// Agent activity → presence light (`getActivityDotClass`, web utils/activity.ts).
enum RaftActivityTone { online, thinking, working, error, offline }

/// Presence pixel of an agent: [RaftStatus] with the call-site vocabulary (an activity, an external agent, or a
/// caller-resolved fill). Default light is `offline`.
class RaftStatusDot extends StatelessWidget {
  const RaftStatusDot({
    super.key,
    this.color,
    this.activity,
    this.external = false,
    this.size = RaftStatusDotSize.md,
  });

  /// Explicit fill; wins over [activity].
  final Color? color;
  final RaftActivityTone? activity;

  /// External agents: `presence-external` regardless of activity.
  final bool external;
  final RaftStatusDotSize size;

  static RaftPresence presenceOf(RaftActivityTone a) => switch (a) {
    RaftActivityTone.online => RaftPresence.online,
    RaftActivityTone.thinking || RaftActivityTone.working => RaftPresence.busy,
    RaftActivityTone.error => RaftPresence.error,
    RaftActivityTone.offline => RaftPresence.offline,
  };

  /// The light's fill in the mode of [t].
  static Color activityColor(RaftTokens t, RaftActivityTone a) =>
      t.ui.presence(presenceOf(a).name);

  @override
  Widget build(BuildContext context) => RaftStatus(
    size: size.status,
    color: color,
    presence: external
        ? RaftPresence.external
        : activity != null
        ? presenceOf(activity!)
        : RaftPresence.offline,
  );
}

/// An unread / attention marker: the presence pixel in `attention-400` (`warning`: `warning`, `danger`:
/// `danger`). [compact] is the `xs` pixel.
class RaftAttentionDot extends StatelessWidget {
  const RaftAttentionDot({
    super.key,
    this.compact = false,
    this.warning = false,
    this.danger = false,
  });

  final bool compact;
  final bool warning;

  /// "Update available": the `--danger` red.
  final bool danger;

  @override
  Widget build(BuildContext context) => RaftStatus(
    size: compact ? RaftStatusSize.xs : RaftStatusSize.md,
    variant: danger
        ? RaftStatusVariant.danger
        : warning
        ? RaftStatusVariant.warning
        : RaftStatusVariant.accent,
  );
}
