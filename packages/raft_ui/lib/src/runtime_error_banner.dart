// Web AgentDetailPanel runtime error banner (a raft-ui PanelNotice under the
// head): an error light, the message (two lines, the full text as tooltip) and,
// for people who may see the details, a "Copy info" icon button and a "View
// logs" link. Presentation only: the app owns the text, the copy and the jump.
import 'package:flutter/material.dart';

import 'agent_profile.dart' show RaftActivityDot;
import 'design_primitives.dart' show RaftTypography;
import 'icons.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftCssText, RaftInlineIconButton;
import 'panel_notice.dart';
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
      color: t.strong,
    ).copyWith(decoration: TextDecoration.underline);
    return RaftPanelNotice(
      key: const ValueKey('runtime-error-banner'),
      leading: Padding(
        // ignore: raft_lints/off_grid_spacing -- Web `mt-[5px]`: centres the light on the first 20px line
        padding: const EdgeInsets.only(top: 5),
        child: RaftActivityDot(color: t.product.brutalOrange, small: true),
      ),
      content: (context, style) => RaftTooltip(
        message: message,
        child: RaftCssText(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
      actions: [
        if (onCopy != null)
          RaftInlineIconButton(
            key: const ValueKey('runtime-error-copy'),
            glyph: copied ? RaftGlyph.check : RaftGlyph.copy,
            size: 14,
            tooltip: raftText(context, copied ? 'Copied' : 'Copy info'),
            onPressed: onCopy,
          ),
        if (onViewLogs != null)
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
    );
  }
}
