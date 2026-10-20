import 'brutal_pack.g.dart';
import 'elegant_pack.g.dart';
import 'raft_pack.g.dart';
import 'theme_pack.dart';

/// The built-in Raft theme, parsed from the compile-time constant.
///
/// Synchronous on purpose: the first frame must already be themed, and reading
/// the same pack from an asset is async — a frame painted before it lands is the
/// theme flash `docs/theme-flash.md` describes. The asset of the same name
/// exists for tooling and for anyone who wants to start from a copy.
RaftThemePack? _raft;

RaftThemePack get builtInRaftTheme =>
    _raft ??= RaftThemePack.parse(raftThemePackJson, origin: 'raft');

RaftThemePack? _elegant;

/// The built-in Elegant theme. Its dark mode is its own values.
RaftThemePack get builtInElegantTheme =>
    _elegant ??= RaftThemePack.parse(elegantThemePackJson, origin: 'elegant');

RaftThemePack? _brutal;

/// The built-in Brutal theme. Brutal has no dark look of its own: its dark
/// mode carries the light values, which is Kevin's decision recorded in the
/// contract — Brutal dark equals Elegant dark in the old app, and the family
/// pack reproduces that by writing the same column twice.
RaftThemePack get builtInBrutalTheme =>
    _brutal ??= RaftThemePack.parse(brutalThemePackJson, origin: 'brutal');

/// Every built-in pack, keyed by id. This is what `extends` chains resolve
/// through and what the appearance setting offers.
final Map<String, RaftThemePack> builtInThemes = Map.unmodifiable({
  raftThemePackId: builtInRaftTheme,
  elegantThemePackId: builtInElegantTheme,
  brutalThemePackId: builtInBrutalTheme,
});

/// The built-in pack with [id], or null when no such theme ships.
RaftThemePack? builtInTheme(String id) => builtInThemes[id];

/// Resolves a theme id to a pack, falling back to Raft for an id that does not
/// name a built-in theme.
///
/// The fallback is deliberate and narrow: a stored id can outlive the theme it
/// names (an uninstalled user pack, a theme removed in a release), and painting
/// the default look is a better failure than a blank or crashing window. The
/// appearance setting still shows the real id, so the setting does not silently
/// claim to be a theme that is not there.
RaftThemePack packForThemeId(String? id) =>
    (id == null ? null : builtInThemes[id]) ?? builtInRaftTheme;
