import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_theme/raft_theme.dart' show RaftFontSpec, builtInRaftTheme;

/// The theme pack's `fonts` decide the typeface; Raft's are Space Grotesk / Space Mono.
RaftTokens _tokens(String id) => RaftTokens.theme(pack: packForThemeId(id));

void main() {
  group('theme fonts come from the theme pack', () {
    test('Raft keeps Space Grotesk and Space Mono', () {
      final t = _tokens(raftThemePackId);
      expect(t.headingFont, 'packages/raft_ui/SpaceGrotesk');
      expect(t.bodyFont, 'packages/raft_ui/SpaceGrotesk');
      expect(t.monoFont, 'packages/raft_ui/SpaceMono');
    });

    test('unknown user font families are not rewritten', () {
      final set = RaftTokenSet.fromPack(
        RaftThemeId.light,
        mode: builtInRaftTheme.light,
        fonts: const {
          'heading': RaftFontSpec(family: 'User Serif', stack: ['User Serif']),
        },
      );
      expect(set.metrics.headingFont, 'User Serif');
    });
  });
}
