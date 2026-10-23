// Web AgentDetailPanel runtime error banner (a raft-ui PanelNotice under the
// head): an error light, the message (two lines, the full text as tooltip) and,
// for people who may see the details, a "Copy info" icon button and a "View
// logs" link. Presentation only: the app owns the text, the copy and the jump.
import 'package:flutter/material.dart';

import 'agent_profile.dart' show RaftActivityDot, RaftPanelText;
import 'design_primitives.dart' show RaftTypography;
import 'icons.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftCssText, RaftInlineIconButton;
import 'theme.dart';
import 'tooltip.dart';

class RaftRuntimeErrorBanner extends StatelessWidget {
  const RaftRuntimeErrorBanner({
    super.key,
    required this.message,
    this.copied = false,
    this.onCopy,
    this.onViewLogs,
  });

  /// The message (already localized text).
  final String message;

  /// The copy button reads "Copied" with a check for a moment after a copy.
  final bool copied;

  /// Null hides the copy button (a person who may not see the details).
  final VoidCallback? onCopy;

  /// Null hides "View logs" (already on the Activity tab, or no access).
  final VoidCallback? onViewLogs;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final link = RaftTypography.body(
      t,
      size: 13,
      line: 18,
      weight: FontWeight.w600,
      color: t.brutal ? Colors.black : t.strong,
    ).copyWith(decoration: TextDecoration.underline);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: const ValueKey('runtime-error-banner'),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: t.brutal
              ? t.product.brutalOrange.withValues(alpha: .2)
              : t.colors['warning-soft'],
          border: Border(
            bottom: BorderSide(
              color: t.brutal ? Colors.black : t.colors['line-muted']!,
              width: t.brutal ? 2 : 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              // ignore: raft_lints/off_grid_spacing -- Web `mt-[5px]`: centres the light on the first 20px line
              padding: const EdgeInsets.only(top: 5),
              child: RaftActivityDot(
                color: t.product.brutalOrange,
                small: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RaftTooltip(
                message: message,
                child: RaftCssText(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: RaftPanelText.value(t),
                ),
              ),
            ),
            if (onCopy != null) ...[
              const SizedBox(width: 8),
              RaftInlineIconButton(
                key: const ValueKey('runtime-error-copy'),
                glyph: copied ? RaftGlyph.check : RaftGlyph.copy,
                size: 14,
                tooltip: raftText(context, copied ? 'Copied' : 'Copy info'),
                onPressed: onCopy,
              ),
            ],
            if (onViewLogs != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                key: const ValueKey('runtime-error-view-logs'),
                behavior: HitTestBehavior.opaque,
                onTap: onViewLogs,
                child: Semantics(
                  button: true,
                  child: RaftCssText(
                    raftText(context, 'View logs'),
                    maxLines: 1,
                    style: link,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
