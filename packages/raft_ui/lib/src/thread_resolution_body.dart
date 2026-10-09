import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'dialog_card.dart';
import 'panel_layout.dart';
import 'recipes/button_variants.g.dart';
import 'theme.dart';
import 'thread_composition.dart';

/// Source ThreadPanel.tsx:2236–2290 at 26f77ef. The host owns its header.
/// First-open resolution has no timeline tabs, parent record or composer.
class RaftThreadResolutionBody extends StatelessWidget {
  const RaftThreadResolutionBody({
    super.key,
    required this.loadingLabel,
    this.errorTitle,
    this.errorBody,
    this.retryLabel = 'Retry',
    this.onRetry,
  });
  final String loadingLabel, retryLabel;
  final String? errorTitle, errorBody;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final loadingStyle = RaftTypography.mono(
      t,
      size: 14,
      line: 20,
      color: t.muted,
    );
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: errorTitle == null
            ? RaftCssLineBox(
                style: loadingStyle,
                textScaler: MediaQuery.textScalerOf(context),
                child: Text(loadingLabel, style: loadingStyle),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    errorTitle!,
                    textAlign: TextAlign.center,
                    style: RaftTypography.heading(t, size: 18, line: 28),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      errorBody ?? '',
                      textAlign: TextAlign.center,
                      style: RaftTypography.body(
                        t,
                        size: 14,
                        line: 20,
                        color: t.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  RaftRecipeButton(
                    label: retryLabel,
                    size: RaftButtonRecipeSize.sm,
                    variant: RaftButtonRecipeVariant.outline,
                    onPressed: onRetry,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Source ThreadPanel.tsx:2523–2552. Reply loading is independent of the
/// parent lookup and leaves the real composer mounted in its host.
class RaftThreadRepliesLoadingBody extends StatelessWidget {
  const RaftThreadRepliesLoadingBody({
    super.key,
    required this.loadingLabel,
    this.parent,
  });
  final String loadingLabel;
  final Widget? parent;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final viewport = MediaQuery.sizeOf(context);
    final recipe = RaftThreadCompositionRecipe(
      t,
      viewportWidth: viewport.width,
      viewportHeight: viewport.height,
      presentation: RaftThreadPresentation.side,
    );
    final style = RaftTypography.mono(
      t,
      size: 14,
      line: 20,
      color: t.brutal
          ? Colors.black.withValues(alpha: .4)
          : t.colors['foreground-placeholder'],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (parent != null)
          Container(
            padding: recipe.parentInset,
            decoration: BoxDecoration(
              color: recipe.parentBackground,
              border: Border(bottom: recipe.parentBorder),
            ),
            child: parent,
          ),
        Expanded(
          child: Center(
            child: RaftCssLineBox(
              style: style,
              textScaler: MediaQuery.textScalerOf(context),
              child: Text(loadingLabel, style: style),
            ),
          ),
        ),
      ],
    );
  }
}
