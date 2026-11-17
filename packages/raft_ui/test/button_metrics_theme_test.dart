import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

/// Button heights come from the theme, not from the Raft constants.
///
/// Every value here was measured from the official React specimen's DOM. The
/// point of the test is that the theme's own numbers reach the widget.
double _height(String id, RaftButtonSize size) => RaftButtonMetrics.of(
  size,
  RaftButtonVariant.standard,
  RaftTokens.theme(pack: packForThemeId(id)),
).height;

void main() {
  group('button metrics follow the theme', () {
    test('Raft keeps its own boxes', () {
      // The Raft look must not move: these are what it painted before the
      // metrics read tokens at all.
      expect(_height(raftThemePackId, RaftButtonSize.sm), 32);
      expect(_height(raftThemePackId, RaftButtonSize.md), 32);
      expect(_height(raftThemePackId, RaftButtonSize.lg), 44);
      expect(_height(raftThemePackId, RaftButtonSize.xl), 52);
    });

    test('xl has no data and no call site, so every theme uses Raft\'s box', () {
      // raft-ui 0.7.1 added xl; the pre-theme looks never had it and nothing
      // calls it, so there is neither a measured family value nor a usage site
      // to read one from. Deriving it from lg would invent a number, so it
      // stays at Raft's 52 for every theme until a call site exists.
      for (final id in raftThemeMatrix([raftThemePackId])) {
        expect(_height(id, RaftButtonSize.xl), 52, reason: id);
      }
    });

    test('md is the same in every look, which is why it earns no token', () {
      for (final id in raftThemeMatrix([raftThemePackId])) {
        expect(_height(id, RaftButtonSize.md), 32, reason: id);
      }
    });
  });
}
