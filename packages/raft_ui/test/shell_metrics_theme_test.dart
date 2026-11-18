import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Shell dimensions come from the theme.
RaftTokens _tokens(String id) => RaftTokens.theme(pack: packForThemeId(id));

void main() {
  group('shell dimensions follow the theme', () {
    test('tall viewport: the rail is 57', () {
      expect(RaftLayoutMetrics.railWidth(_tokens(raftThemePackId), 800), 57);
    });

    test('short viewport: the rail narrows to 49', () {
      // The 600px threshold is a form rule and lives in the component; the widths
      // are theme values and live in the packs.
      expect(RaftLayoutMetrics.railWidth(_tokens(raftThemePackId), 600), 49);
    });

    test('Activity inset leaves the seam to the Raft rail', () {
      for (final (id, width) in [(raftThemePackId, 0)]) {
        for (final dark in [false, true]) {
          final tokens = RaftTokens.theme(pack: packForThemeId(id), dark: dark);
          final side = RaftPanelEdge.side(
            tokens,
            RaftPanelEdgeStyle.activityInbox,
          );
          expect(side?.width ?? 0, width, reason: '$id/$dark');
          expect(
            RaftPanelEdge.leftFor(
              tokens,
              RaftPanelPresentation.phonePage,
              RaftPanelEdgeStyle.activityInbox,
            ),
            isNull,
          );
        }
      }
    });

    test('the drawer is 380 in every look, as measured', () {
      // Not a theme value: a57b9dab never varied it, so the contract's earlier
      // Brutal 420 was unsourced.
      for (final id in [raftThemePackId]) {
        expect(_tokens(id).size('size.drawer', fallback: 380), 380, reason: id);
      }
    });

    test('navigation rows: base touch heights per viewport', () {
      double row(String id, double width, double height) =>
          RaftConversationNavigationRecipe(
            _tokens(id),
            kind: RaftConversationNavKind.channel,
          ).rowHeight(viewportWidth: width, viewportHeight: height);
      // (desktop tall, desktop short, phone tall, phone short)
      final expected = {
        raftThemePackId: [38.0, 38.0, 44.0, 44.0],
      };
      for (final MapEntry(key: id, value: heights) in expected.entries) {
        expect(
          [
            row(id, 1280, 800),
            row(id, 1280, 600),
            row(id, 390, 844),
            row(id, 390, 600),
          ],
          heights,
          reason: id,
        );
      }
    });
  });
}
