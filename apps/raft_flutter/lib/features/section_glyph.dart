import 'package:raft_ui/raft_ui.dart';

/// The glyph of a workspace section in the page header.
RaftGlyph sectionGlyph(String section) => switch (section) {
  'chat' => RaftGlyph.hash,
  'activity' => RaftGlyph.activity,
  'search' => RaftGlyph.search,
  'tasks' => RaftGlyph.checkSquare,
  'saved' => RaftGlyph.bookmark,
  'members' => RaftGlyph.users,
  'agents' => RaftGlyph.bot,
  'computers' => RaftGlyph.monitor,
  _ => RaftGlyph.settings,
};
