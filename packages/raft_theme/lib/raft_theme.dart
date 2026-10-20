/// The theme contract: what a theme may set, and how a theme pack is read.
///
/// A theme is data. This package owns the vocabulary (colour roles, numeric
/// tokens, structural options) and the `raft-theme/1` file format; it does not
/// import `raft_ui`, and it draws nothing. See `docs/theme-contract.md`.
library;

export 'src/built_in.dart';
export 'src/color_value.dart';
export 'src/raft_pack.g.dart' show raftThemePackId, raftThemePackJson;
export 'src/elegant_pack.g.dart'
    show elegantThemePackId, elegantThemePackJson;
export 'src/brutal_pack.g.dart' show brutalThemePackId, brutalThemePackJson;
export 'src/shadow_value.dart';
export 'src/theme_pack.dart';
