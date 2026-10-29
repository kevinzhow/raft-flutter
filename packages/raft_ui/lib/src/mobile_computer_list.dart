import 'package:flutter/material.dart';

import 'system_inset.dart';
import 'components.dart';
import 'design_primitives.dart';
import 'feedback_inbox.dart' show RaftDashedBorderPainter;
import 'icons.dart';
import 'indicators.dart';
import 'panel_layout.dart';
import 'theme.dart';

/// MobileComputersPanel's scrolling card body. The workspace owns its header,
/// accepted rows, loading state, permissions and navigation.
class RaftMobileComputerList extends StatelessWidget {
  const RaftMobileComputerList({
    super.key,
    required this.rows,
    this.loading = false,
    this.error,
    required this.emptyTitle,
    required this.emptyDetail,
    this.onRetry,
    this.onAdd,
    required this.addLabel,
    required this.retryLabel,
    this.refreshError,
    this.errorTitle,
    this.errorDetail,
  });
  final List<Widget> rows;
  final bool loading;
  final String? error;

  /// Load-error `EmptyState` copy shown when [error] is set.
  final String? errorTitle, errorDetail;

  /// A failed refresh that kept the accepted [rows]: Web's
  /// `computers-refresh-error` banner (copy + Retry) above the list.
  final String? refreshError;
  final String emptyTitle, emptyDetail, addLabel, retryLabel;
  final VoidCallback? onRetry, onAdd;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final children = <Widget>[
      if (error != null)
        // `EmptyState` (Monitor 36, load-error title / description) with the
        // Retry action; Web shows no Add row in this state.
        Semantics(
          liveRegion: true,
          child: RaftEmptyState(
            title: errorTitle ?? error!,
            detail: errorDetail ?? '',
            glyph: RaftGlyph.monitor,
            action: onRetry == null
                ? null
                : RaftButton(
                    label: retryLabel,
                    glyph: RaftGlyph.refreshCw,
                    onPressed: onRetry,
                  ),
          ),
        ),
      if (refreshError != null && !loading)
        Semantics(
          liveRegion: true,
          child: Container(
            key: const ValueKey('computers-refresh-error'),
            // `flex items-center justify-between gap-3 p-3 text-sm`.
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.colors['primary-soft'],
              border: Border.all(color: t.colors['line-muted']!, width: 1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: RaftCssText(
                    refreshError!,
                    style: RaftTypography.body(
                      t,
                      size: 14,
                      line: 20,
                      weight: FontWeight.w600,
                      color: t.strong,
                    ),
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(width: 12),
                  RaftTextButton(
                    label: retryLabel,
                    glyph: RaftGlyph.refreshCw,
                    // The Web Button box is the layout box (no touch inflation).
                    minimumTargetSize: RaftMetrics.buttonMd,
                    onPressed: onRetry,
                  ),
                ],
              ],
            ),
          ),
        ),
      if (loading && rows.isEmpty)
        for (var i = 0; i < 4; i++)
          ExcludeSemantics(
            child: Container(
              constraints: const BoxConstraints(minHeight: 68),
              padding: const EdgeInsets.all(12),
              decoration: _card(t),
              child: const RaftSkeletonRow(
                avatar: true,
                avatarSize: 40,
                gap: 12,
                lineFractions: [.4, .6],
              ),
            ),
          )
      else
        ...rows,
      if (!loading && rows.isEmpty && error == null)
        RaftEmptyState(
          title: emptyTitle,
          detail: emptyDetail,
          glyph: RaftGlyph.monitor,
        ),
      if (!loading && onAdd != null && error == null)
        RaftInteractive(
          key: const ValueKey('computers-add-row'),
          semanticLabel: addLabel,
          onPressed: onAdd,
          builder: (context, state) {
            final border =
                t.colors[state.hovered ? 'line-strong' : 'line-muted']!;
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CustomPaint(
                foregroundPainter: RaftDashedBorderPainter(border, 1),
                child: Container(
                  color: t.panel,
                  // `p-3` inside the border box (the dashed border adds to it).
                  padding: EdgeInsets.all(12.0 + (1)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RaftIcon(RaftGlyph.plus, size: 16, color: t.muted),
                      const SizedBox(width: 8),
                      Flexible(
                        child: RaftCssText(
                          addLabel,
                          style: RaftTypography.body(
                            t,
                            size: 14,
                            line: 20,
                            weight: FontWeight.w700,
                            color: t.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
    ];
    return ColoredBox(
      color: t.canvas,
      child: ListView(
        key: const Key('mobile-computers-list'),
        padding: raftScrollPadding(context, const EdgeInsets.all(16)),
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) const SizedBox(height: 10),
            child,
          ],
        ],
      ),
    );
  }

  BoxDecoration _card(RaftTokens t) => BoxDecoration(
    color: t.panel,
    border: Border.all(color: t.colors['line-muted']!, width: 1),
    borderRadius: BorderRadius.circular(6),
    boxShadow: t.themeShadows.sm.paintOrder,
  );
}
