import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

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
    });

    test('Brutal uses its measured heights', () {
      expect(_height(brutalThemePackId, RaftButtonSize.sm), 28);
      expect(_height(brutalThemePackId, RaftButtonSize.md), 32);
      expect(_height(brutalThemePackId, RaftButtonSize.lg), 40);
    });

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
    });

    test('xl exists only for Raft, and keeps its delta from lg elsewhere', () {
      // raft-ui 0.7.1 added xl; the pre-theme looks never had it, so Elegant
      // and Brutal have no measured value. They keep Raft's 8px step from lg
      // rather than collapsing xl onto lg.
      expect(_height(raftThemePackId, RaftButtonSize.xl), 52);
      expect(_height(elegantThemePackId, RaftButtonSize.xl), 44);
      expect(_height(brutalThemePackId, RaftButtonSize.xl), 48);
    });

    test('md is the same in every look, which is why it earns no token', () {
      for (final id in [
        raftThemePackId,
        elegantThemePackId,
        brutalThemePackId,
      ]) {
        expect(_height(id, RaftButtonSize.md), 32, reason: id);
      }
    });
  });
}
