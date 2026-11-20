// raft-ui 0.95.3 `IconTile` (dist `icon-tile`): a flat square holding a Lucide glyph, sized like an avatar
// (19 / 27 / 35 / 51). Radius by size (sticker / chip / control / container), no border. Decorative unless it carries a [semanticLabel]
// (`role="img"` + `aria-label`).
import 'package:flutter/material.dart';

import '../icons.dart';
import '../theme.dart';
import 'blink_snap.dart';
import 'ui_tokens.dart';

/// `variant` axis of `iconTile`.
enum RaftIconTileVariant { default_, warning, information }

/// `size` axis of `iconTile`: the tile edge and its glyph edge.
enum RaftIconTileSize {
  xs(19, 11),
  sm(27, 14),
  md(35, 18),
  lg(51, 22);

  const RaftIconTileSize(this.extent, this.icon);
  final double extent, icon;
}

class RaftIconTile extends StatelessWidget {
  const RaftIconTile({
    super.key,
    required this.glyph,
    this.iconBuilder,
    this.size = RaftIconTileSize.md,
    this.variant = RaftIconTileVariant.default_,
    this.semanticLabel,
  });

  final RaftGlyph glyph;
  final Widget Function(double size, Color color)? iconBuilder;
  final RaftIconTileSize size;
  final RaftIconTileVariant variant;

  /// Announces the tile as an image; without it the tile is hidden from assistive tech.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ui = RaftTokens.of(context).ui;
    // Translucent tokens (dark `fill-muted`, `foreground-muted`) composite the way Blink does.
    Color opaque(Color c, Color backdrop) =>
        c.a < 1 ? raftChromeBlend(c, backdrop) : c;
    final mutedFill = opaque(ui.fillMuted, ui.layerCanvas);
    final (fill, foreground) = switch (variant) {
      RaftIconTileVariant.default_ => (
        mutedFill,
        opaque(ui.foregroundMuted, mutedFill),
      ),
      RaftIconTileVariant.warning => (
        opaque(ui['warning-soft'], ui.layerCanvas),
        ui.foreground,
      ),
      RaftIconTileVariant.information => (
        opaque(ui['info-soft'], ui.layerCanvas),
        ui.foreground,
      ),
    };
    final t = RaftTokens.of(context);
    // `rounded-sticker` for xs, `rounded-chip` sm, `rounded-control` md, `rounded-container` lg (raft-ui
    // 0.95.3 icon-tile).
    final radius = switch (size) {
      RaftIconTileSize.xs => t.size('radius.sticker', fallback: 4),
      RaftIconTileSize.sm => t.size('radius.chip', fallback: 6),
      RaftIconTileSize.md => t.size('radius.control', fallback: 8),
      RaftIconTileSize.lg => t.size('radius.container', fallback: 10),
    };
    final tile = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox.square(
        dimension: size.extent,
        child: Center(
          // Blink snaps the svg box to a device pixel (a 22px glyph in a 51px tile sits on a half pixel).
          child: RaftBlinkSnap(
            child:
                iconBuilder?.call(size.icon, foreground) ??
                RaftIcon(glyph, size: size.icon, color: foreground),
          ),
        ),
      ),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: tile)
        : Semantics(label: semanticLabel, image: true, child: tile);
  }
}
