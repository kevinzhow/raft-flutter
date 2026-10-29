@Tags(['look-brutal', 'look-elegant'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Shell dimensions come from the theme.
///
/// Measured on a57b9dab's `RaftLayoutMetrics`:
///   rail  `t.brutal ? (viewportHeight <= 600 ? 50 : 64) : 56`
///   drawer a flat 380 in every family (`adaptive_workspace.dart` default, no
///          theme branch at all)
///
/// The rail used to return a literal 56, so Brutal painted Elegant's narrower
/// rail. The contract's Brutal drawer of 420 had no source and is corrected here.
RaftTokens _tokens(String id) => RaftTokens.theme(pack: packForThemeId(id));

void main() {
  group('shell dimensions follow the theme', () {
    test('tall viewport: Raft 57, Elegant 56, Brutal 64', () {
      expect(RaftLayoutMetrics.railWidth(_tokens(raftThemePackId), 800), 57);
      expect(RaftLayoutMetrics.railWidth(_tokens(elegantThemePackId), 800), 56);
      expect(RaftLayoutMetrics.railWidth(_tokens(brutalThemePackId), 800), 64);
    });

    test('short viewport: Raft narrows to 49 and Brutal to 50', () {
      // The 600px threshold is a form rule and lives in the component; the widths
      // are theme values and live in the packs.
      expect(RaftLayoutMetrics.railWidth(_tokens(raftThemePackId), 600), 49);
      expect(RaftLayoutMetrics.railWidth(_tokens(elegantThemePackId), 600), 56);
      expect(RaftLayoutMetrics.railWidth(_tokens(brutalThemePackId), 600), 50);
      // Just above and just below the threshold.
      expect(RaftLayoutMetrics.railWidth(_tokens(brutalThemePackId), 601), 64);
      expect(RaftLayoutMetrics.railWidth(_tokens(brutalThemePackId), 599), 50);
    });

    test(
      'Activity inset leaves the seam to Raft rail and retains legacy edges',
      () {
        for (final (id, width) in [
          (raftThemePackId, 0),
          (elegantThemePackId, 1),
          (brutalThemePackId, 1),
        ]) {
          for (final dark in [false, true]) {
            final tokens = RaftTokens.theme(
              pack: packForThemeId(id),
              dark: dark,
            );
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
      },
    );

    test('the three rails are not all one width', () {
      // The bug was a single literal for every theme.
      final widths = {
        for (final id in [
          raftThemePackId,
          elegantThemePackId,
          brutalThemePackId,
        ])
          RaftLayoutMetrics.railWidth(_tokens(id), 800),
      };
      expect(widths, isNot(hasLength(1)), reason: 'widths: $widths');
    });

    test('the drawer is 380 in every look, as measured', () {
      // Not a theme value: a57b9dab never varied it, so the contract's earlier
      // Brutal 420 was unsourced.
      for (final id in [
        raftThemePackId,
        elegantThemePackId,
        brutalThemePackId,
      ]) {
        expect(_tokens(id).size('size.drawer', fallback: 380), 380, reason: id);
      }
    });

    test('railShort is a real token, not derived from the regular width', () {
      // Guards the pairing: if a future edit drops railShort, Brutal would fall
      // back to 64 on short viewports and lose the measured 50.
      final brutal = _tokens(brutalThemePackId);
      expect(
        brutal.size(
          'size.railShort',
          fallback: brutal.size('size.rail', fallback: 56),
        ),
        50,
      );
      expect(brutal.size('size.rail', fallback: 56), 64);
    });

    test('navigation rows: a57b9dab heights per look and viewport', () {
      double row(String id, double width, double height) =>
          RaftConversationNavigationRecipe(
            _tokens(id),
            kind: RaftConversationNavKind.channel,
          ).rowHeight(viewportWidth: width, viewportHeight: height);
      // (desktop tall, desktop short, phone tall, phone short)
      final expected = {
        raftThemePackId: [36.0, 36.0, 44.0, 44.0],
        elegantThemePackId: [34.0, 30.0, 34.0, 30.0],
        brutalThemePackId: [32.0, 32.0, 40.0, 32.0],
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
