// Web AgentRuntimeErrorNotice (v1.24.0, features/agent/AgentRuntimeErrorNotice.tsx):
// the strip under the agent panel head while the agent has a runtime error. A
// warning icon, the message (two lines, the full text as tooltip) and, for
// people who may see the details, a "Copy info" icon button and a "View logs"
// link.
//
// Three shapes of the message:
//  - plain: one headline (a classified catalog message, a member's sentence);
//  - headline + [detail]: the managers' sentence for the error's code above
//    the scrubbed detail (two lines, the full text as tooltip);
//  - billing ([billingBody]): "Model service balance too low", what it means
//    and one action: "View model settings" for whoever may open them, else who
//    can fix it.
// Presentation only: the app owns the text, the copy and the jumps.
import 'package:flutter/material.dart';

import 'design_primitives.dart' show RaftTypography;
import 'icons.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftCssText, RaftInlineIconButton;
import 'panel_notice.dart';
import 'raft/button.dart';
import 'recipes/button_variants.g.dart'
    show RaftButtonRecipeSize, RaftButtonRecipeVariant;
import 'theme.dart';
import 'tooltip.dart';

class RaftRuntimeErrorBanner extends StatelessWidget {
  const RaftRuntimeErrorBanner({
    super.key,
    required this.message,
    this.detail,
    this.billingBody,
    this.billingNote,
    this.onOpenModelSettings,
    this.copied = false,
    this.onCopy,
    this.onViewLogs,
  });

  /// The message (already localized text): the headline, or the billing
  /// banner's title.
  final String message;

  /// The scrubbed error text under the headline (a manager reading a coded
  /// error); two lines, the full text as tooltip.
  final String? detail;

  /// Non-null makes this the billing banner: [message] is its title and this
  /// what it means for the agent. Every viewer sees it.
  final String? billingBody;

  /// The billing banner's last line when it has no action: who fixes it.
  final String? billingNote;

  /// The billing banner's one action ("View model settings"), for whoever may
  /// open the agent's model settings.
  final VoidCallback? onOpenModelSettings;

  /// The copy button reads "Copied" with a check for a moment after a copy.
  final bool copied;

  /// Null hides the copy button (a person who may not see the details).
  final VoidCallback? onCopy;

  /// Null hides "View logs" (already on the Activity tab, no access, or the
  /// billing banner, which keeps one action).
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
    final billing = billingBody != null;
    return RaftPanelNotice(
      key: const ValueKey('runtime-error-banner'),
      // `TriangleAlert size-4`, on the first 20px line.
      leading: const Padding(
        padding: EdgeInsets.only(top: 2),
        child: RaftIcon(RaftGlyph.triangleAlert, size: 16),
      ),
      content: (context, style) {
        final quiet = style.copyWith(
          fontWeight: FontWeight.w400,
          color: t.colors['foreground-muted'],
        );
        if (billing) {
          // Never a reset, never the provider's name: the copy is typed, not
          // the provider's reply.
          return Column(
            key: const ValueKey('agent-billing-banner'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RaftCssText(message, style: style),
              RaftCssText(billingBody!, style: quiet),
              if (billingNote != null)
                RaftCssText(
                  billingNote!,
                  key: const ValueKey('agent-billing-banner-ask-admin'),
                  style: quiet,
                ),
            ],
          );
        }
        if (detail != null) {
          return Column(
            key: const ValueKey('runtime-error-headline'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RaftCssText(message, style: style),
              RaftTooltip(
                message: detail!,
                child: RaftCssText(
                  detail!,
                  key: const ValueKey('runtime-error-detail'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: quiet,
                ),
              ),
            ],
          );
        }
        return RaftTooltip(
          message: message,
          child: RaftCssText(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        );
      },
      actions: [
        if (billing && onOpenModelSettings != null)
          RaftButton(
            key: const ValueKey('agent-billing-banner-model-settings'),
            label: raftText(context, 'View model settings'),
            tone: RaftButtonRecipeVariant.ghost,
            size: RaftButtonRecipeSize.md,
            onPressed: onOpenModelSettings,
          ),
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
