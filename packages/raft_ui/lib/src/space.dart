/// Tailwind spacing steps (`--spacing: 0.25rem`): every step is a multiple of
/// 2px, so Web paddings, margins and gaps (`p-1.5`, `gap-3`) land on this grid.
///
/// `tool/raft_lints` `off_grid_spacing` flags a literal gap or inset that is
/// not on it. A value Web really uses off the grid (`gap-[5px]`, `mt-px`,
/// `py-[1.5px]`) stays only with a `// ds-allow: Web <file> <class>` comment.
abstract final class RaftSpace {
  static const double half = 2, x1 = 4, x1_5 = 6, x2 = 8, x3 = 12, x4 = 16;
  static const double x5 = 20, x6 = 24;

  /// A 1px `border` (Tailwind `border`). Flutter draws a `DecoratedBox` border
  /// without taking layout space, so the Web `p-1.5 border` box is
  /// `x1_5 + hairline` of padding. A themed border (1px elegant, 2px brutal)
  /// is `RaftTokens.border` instead.
  static const double hairline = 1;

  /// SocialProviderIcon `size-[18px]`.
  static const double providerIcon = 18;
}
