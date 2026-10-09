import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'panel_layout.dart';
import 'theme.dart';

/// MainLayout.tsx:387–439 ChannelById and ChatPanel.tsx:1208–1218.
/// Unknown channel loading and unavailable selection share the Source linebox;
/// neither borrows a header, tabs, message window or composer.
class RaftChannelResolutionBody extends StatelessWidget {
  const RaftChannelResolutionBody({
    super.key,
    required this.label,
    this.onBack,
    this.backLabel = 'Back',
  });
  final String label;
  final VoidCallback? onBack;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onBack != null && constraints.maxWidth < 768) ...[
              RaftPanelIconButton(
                glyph: RaftGlyph.arrowLeft,
                tooltip: backLabel,
                onPressed: onBack,
              ),
              const SizedBox(height: 16),
            ],
            RaftCssText(
              label.toUpperCase(),
              style: RaftTypography.heading(
                t,
                size: 18,
                line: 28,
                weight: FontWeight.w700,
              ).copyWith(color: t.muted),
            ),
          ],
        ),
      ),
    );
  }
}
