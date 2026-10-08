// components.ui.* — raft-ui primitive fixtures. Each builder mirrors the
// React render host frame (packages/web/visual-testing/VisualTestingCases.tsx,
// same width/height/padding/content) and renders the Flutter raft_ui widget
// the app uses for that primitive. Missing Flutter variants are NOT patched
// here: the closest product widget is rendered and the diff shows the gap.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';

final Map<String, ParityCase> uiPrimitiveCases = {
  'components.ui.button.states': _button,
  'components.ui.button.states.elegant': _button,
  'components.ui.card.states': _card,
  'components.ui.card.states.elegant': _card,
  'components.ui.spinner.states': _spinner,
};

final Map<String, ParityUncovered> uiPrimitiveUncovered = {};

final ParityCase _button = ParityCase(
  widgets: const ['raft_ui:RaftButton', 'raft_ui:RaftControl'],
  notes:
      'React Button tones information/success/muted have no RaftControlVariant; '
      'rendered with the nearest Flutter variants (surface/primary/ghost).',
  build: (ctx) => ctx.frame(
    width: 342,
    height: 150,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            RaftButton(
              label: 'Save',
              onPressed: () {},
              variant: RaftControlVariant.outline,
              visualHeight: RaftMetrics.buttonSm,
            ),
            const SizedBox(width: 12),
            RaftButton(
              label: 'Sync',
              onPressed: () {},
              variant: RaftControlVariant.primary,
              visualHeight: RaftMetrics.buttonSm,
            ),
            const SizedBox(width: 12),
            RaftButton(
              label: 'Delete',
              onPressed: () {},
              variant: RaftControlVariant.accent,
              visualHeight: RaftMetrics.buttonSm,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            RaftButton(
              label: 'Add',
              onPressed: () {},
              variant: RaftControlVariant.surface,
              visualHeight: RaftMetrics.buttonXs,
            ),
            const SizedBox(width: 12),
            RaftButton(
              label: 'Continue',
              onPressed: () {},
              variant: RaftControlVariant.primary,
              visualHeight: RaftMetrics.buttonMd,
            ),
            const SizedBox(width: 12),
            const RaftButton(
              label: 'Disabled',
              variant: RaftControlVariant.ghost,
              visualHeight: RaftMetrics.buttonSm,
            ),
          ],
        ),
      ],
    ),
  ),
);

final ParityCase _card = ParityCase(
  widgets: const ['raft_ui:RaftPanel', 'raft_ui:RaftButton'],
  build: (ctx) => ctx.frame(
    width: 342,
    height: 190,
    child: SizedBox(
      width: 310,
      child: RaftPanel(
        padding: const EdgeInsets.all(14),
        shadow: true,
        child: Builder(
          builder: (context) {
            final t = RaftTokens.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Channel settings',
                  style: TextStyle(
                    fontFamily: t.bodyFont,
                    fontSize: 16,
                    height: 20 / 16,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Control who can post and how the channel appears to members.',
                  style: TextStyle(
                    fontFamily: t.bodyFont,
                    fontSize: 12,
                    height: 16 / 12,
                    color: t.muted,
                  ),
                ),
                const SizedBox(height: 8),
                RaftButton(
                  label: 'Save changes',
                  onPressed: () {},
                  variant: RaftControlVariant.primary,
                  visualHeight: RaftMetrics.buttonSm,
                ),
              ],
            );
          },
        ),
      ),
    ),
  ),
);

final ParityCase _spinner = ParityCase(
  widgets: const ['raft_ui:RaftSpinner'],
  notes: 'React renders spinners with animation:none; Flutter uses reduced '
      'motion (MediaQuery.disableAnimations) for the same static frame.',
  build: (ctx) => Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: ctx.frame(
        width: 342,
        height: 92,
        child: Row(
          children: [
            const RaftSpinner(size: 12),
            const SizedBox(width: 20),
            const RaftSpinner(size: 16),
            const SizedBox(width: 20),
            const RaftSpinner(size: 20),
            const SizedBox(width: 20),
            const RaftSpinner(size: 24),
            const SizedBox(width: 20),
            Container(
              color: Colors.black,
              padding: const EdgeInsets.all(8),
              child: const RaftSpinner(size: 16, inverse: true),
            ),
          ],
        ),
      ),
    ),
  ),
);
