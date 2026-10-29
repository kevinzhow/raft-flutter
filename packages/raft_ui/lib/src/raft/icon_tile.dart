// raft-ui 0.7.1 `IconTile` (dist `iconTile`): a flat square holding a Lucide glyph, sized like an avatar
// (19 / 27 / 35 / 51). `rounded-sticker`, no border. Decorative unless it carries a [semanticLabel]
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
    this.size = RaftIconTileSize.md,
    this.variant = RaftIconTileVariant.default_,
    this.semanticLabel,
  });

  final RaftGlyph glyph;
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
    final tile = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(4),
      ),
      child: SizedBox.square(
        dimension: size.extent,
        child: Center(
          // Blink snaps the svg box to a device pixel (a 22px glyph in a 51px tile sits on a half pixel).
          child: RaftBlinkSnap(
            child: RaftIcon(glyph, size: size.icon, color: foreground),
          ),
        ),
      ),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: tile)
        : Semantics(label: semanticLabel, image: true, child: tile);
  }
}
