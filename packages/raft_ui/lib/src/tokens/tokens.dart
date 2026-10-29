/// Design tokens generated from raft-ui CSS and tokens.json by `tool/gen-tokens`.
///
/// Tiers: [RaftPrimitiveColors] (raw ramps) → [RaftSemanticColors] (theme
/// blocks) / [RaftProductColors] (Tailwind aliases incl. Web product
/// overrides) → [RaftComponentColors] (recipe roles). Shadows live in
/// [RaftThemeShadows], metrics in [RaftThemeMetrics] and [RaftScale]. Control-label
/// typography policy values live in [RaftControlTypographyTokens], the media
/// browser's open / close motion in [RaftMediaMotionTokens].
/// [RaftLight] / [RaftDark] (raft_tokens.g.dart) are the raft-ui 0.7.1 single look
/// generated from its `tokens.json`. The tier classes above are only the field
/// schemas now: [RaftTokenSet] fills them from [RaftLight] / [RaftDark] through the
/// table in raft_token_mapping.dart.
/// See docs/design-tokens.md.
library;

export 'component_colors.g.dart';
export 'media_motion.g.dart';
export 'metrics.g.dart';
export 'primitive_colors.g.dart';
export 'product_colors.g.dart';
export 'raft_token_mapping.dart';
export 'raft_tokens.g.dart';
export 'semantic_colors.g.dart';
export 'shadows.g.dart';
export 'token_set.dart';
export 'typography.g.dart';
