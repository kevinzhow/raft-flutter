// The rack's lucide glyphs that arrive with the raft-ui 0.95.3 glyph set
// (WP-DS0: circle-arrow-up, circle-dot, cpu, rows-3, search-x). Until DS0
// lands they are the nearest glyph already in the set; this file is the one
// place to switch them.
import 'package:raft_ui/raft_ui.dart' show RaftGlyph;

/// RackRowAction's Upgrade (lucide CircleArrowUp).
const rackGlyphCircleArrowUp = RaftGlyph.arrowUp;

/// The Status filter (lucide CircleDot).
const rackGlyphCircleDot = RaftGlyph.circle;

/// The Runtime filter (lucide Cpu).
const rackGlyphCpu = RaftGlyph.hardDrive;

/// Group (lucide Rows3).
const rackGlyphRows3 = RaftGlyph.list;

/// No computers match (lucide SearchX).
const rackGlyphSearchX = RaftGlyph.search;
