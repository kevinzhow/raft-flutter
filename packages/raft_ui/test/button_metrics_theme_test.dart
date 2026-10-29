import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

/// Button heights come from the theme, not from the Raft constants.
///
/// Every value here was measured from that look's own authority: Raft from the
/// official React specimen's DOM, Elegant and Brutal by resolving the recipe on
/// a57b9dab. The point of the test is that a theme's own numbers reach the
/// widget -- before this, all three painted Raft's boxes.
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

    test('Elegant uses its measured heights', () {
      expect(_height(elegantThemePackId, RaftButtonSize.sm), 28);
      expect(_height(elegantThemePackId, RaftButtonSize.md), 32);
      expect(_height(elegantThemePackId, RaftButtonSize.lg), 36);
    }, skip: raftLookSkip(raftLookElegant));

    test('Brutal uses its measured heights', () {
      expect(_height(brutalThemePackId, RaftButtonSize.sm), 28);
      expect(_height(brutalThemePackId, RaftButtonSize.md), 32);
      expect(_height(brutalThemePackId, RaftButtonSize.lg), 40);
    }, skip: raftLookSkip(raftLookBrutal));

    test('the families differ from Raft where the data says they differ', () {
      // lg differs in all three looks, so it is the clearest signal that the
      // token is actually being read rather than the Raft constant reused.
      final lg = {
        for (final id in [
          raftThemePackId,
          elegantThemePackId,
          brutalThemePackId,
        ])
          id: _height(id, RaftButtonSize.lg),
      };
      expect(lg.values.toSet(), hasLength(3), reason: 'lg heights: $lg');
    }, skip: raftLookSkip(raftLookElegant, raftLookBrutal));

    test('xl has no data and no call site, so every theme uses Raft\'s box', () {
      // raft-ui 0.7.1 added xl; the pre-theme looks never had it and nothing
      // calls it, so there is neither a measured family value nor a usage site
      // to read one from. Deriving it from lg would invent a number, so it
      // stays at Raft's 52 for every theme until a call site exists.
      for (final id in raftThemeMatrix([
        raftThemePackId,
        elegantThemePackId,
        brutalThemePackId,
      ], look: raftLookOf)) {
        expect(_height(id, RaftButtonSize.xl), 52, reason: id);
      }
    });

    test('md is the same in every look, which is why it earns no token', () {
      for (final id in raftThemeMatrix([
        raftThemePackId,
        elegantThemePackId,
        brutalThemePackId,
      ], look: raftLookOf)) {
        expect(_height(id, RaftButtonSize.md), 32, reason: id);
      }
    });
  });
}
