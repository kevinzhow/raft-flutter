import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'artifact_models.dart';
import 'artifact_text.dart';

class ArtifactScopeChip extends StatelessWidget {
  const ArtifactScopeChip({
    super.key,
    required this.card,
    this.serverName,
    this.iconOnly = false,
    this.viewerHeader = false,
    this.choices = const [],
  });

  final ArtifactCard card;
  final String? serverName;
  final bool iconOnly;
  final bool viewerHeader;
  final List<RaftMenuEntry> choices;

  @override
  Widget build(BuildContext context) {
    final label = artifactScopeLabel(
      context,
      card.home,
      fromAnotherServer: card.fromAnotherServer,
      serverName: serverName,
    );
    final glyph = artifactScopeGlyph(card.home);
    final badge = RaftBadge(
      label: iconOnly ? '' : label,
      glyph: iconOnly ? null : glyph,
      // ArtifactScopeLabel's header badge uses `[&_svg]:size-3`.
      glyphSize: viewerHeader ? RaftSpace.x3 : null,
      leading: iconOnly ? RaftIcon(glyph, size: RaftSpace.x3) : null,
      appearance: RaftBadgeRecipeAppearance.outline,
      variant: iconOnly || viewerHeader
          ? RaftBadgeRecipeVariant.muted
          : RaftBadgeRecipeVariant.default_,
    );
    if (choices.isEmpty && !iconOnly && card.home.conversationType != 'dm') {
      return badge;
    }
    return RaftDropdownMenu(
      label: label,
      kind: RaftMenuKind.dropdownMenu,
      width: 240,
      entries: choices,
      header: choices.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(RaftSpace.x2),
              child: Text(artifactAudience(context, card.home, serverName)),
            )
          : null,
      triggerBuilder: (_, focus, onPressed) => RaftInteractive(
        focusNode: focus,
        onPressed: onPressed,
        semanticLabel: label,
        builder: (_, _) => badge,
      ),
    );
  }
}
