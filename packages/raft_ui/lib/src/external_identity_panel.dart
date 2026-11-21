// Web ExternalIdentityDetailPanel body (components/profile/
// ExternalIdentityDetailPanel.tsx): the provider workspace row and the
// identity block of a provider-owned message author.
import 'package:flutter/material.dart';

import 'list_items.dart';
import 'panel_layout.dart' show RaftCssText;
import 'raft/ui_tokens.dart';
import 'space.dart';
import 'theme.dart';
import 'tokens/tokens.dart';

class RaftExternalIdentityBody extends StatelessWidget {
  const RaftExternalIdentityBody({
    super.key,
    required this.name,
    required this.subtitle,
    required this.projectionLabel,
    required this.avatar,
    this.fromLabel,
    this.workspaceName,
    this.sourceLabel,
    this.postedAs,
  });
  final String name, subtitle, projectionLabel;

  /// AvatarSlot `profile-hero` (type app).
  final Widget avatar;

  /// "From" eyebrow of the source row, shown only with a [workspaceName].
  final String? fromLabel, workspaceName;
  final String? sourceLabel, postedAs;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final strong = t.ui.foreground;
    final muted = t.ui.foregroundMuted;
    return ColoredBox(
      color: t.colors['layer-profile-content']!,
      child: SingleChildScrollView(
        key: const Key('external-identity-body'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sourceLabel != null)
              Padding(
                key: const Key('external-identity-source'),
                padding: const EdgeInsets.symmetric(
                  horizontal: RaftSpace.x5,
                  vertical: RaftSpace.x3,
                ),
                child: RaftCssText(
                  sourceLabel!,
                  style: t.scale(
                    RaftTypeScale.callout,
                    weight: FontWeight.w600,
                    color: strong,
                  ),
                ),
              )
            else if (workspaceName != null && workspaceName!.isNotEmpty)
              Container(
                key: const Key('external-identity-source'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: t.colors['line-muted']!),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RaftSectionEyebrow(fromLabel ?? 'From'),
                    const SizedBox(height: 4),
                    Text(
                      workspaceName!,
                      style: TextStyle(
                        fontFamily: t.headingFont,
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w700,
                        color: strong,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  avatar,
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RaftCssText(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.scale(
                              RaftTypeScale.headline,
                              color: strong,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: RaftSpace.half),
                            child: RaftCssText(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.scale(
                                RaftTypeScale.caption,
                                color: t.ui.foregroundHint,
                              ),
                            ),
                          ),
                          if (postedAs != null)
                            Padding(
                              padding: const EdgeInsets.only(top: RaftSpace.x1),
                              child: RaftCssText(
                                postedAs!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.scale(
                                  RaftTypeScale.footnote,
                                  color: muted,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          RaftCssText(
                            projectionLabel,
                            style: t.scale(RaftTypeScale.callout, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `AvatarSlot type="app"` initials fallback: the first two characters of the
/// name in bold (muted); 24px in the profile tile, 14px
/// elsewhere.
class RaftExternalInitials extends StatelessWidget {
  const RaftExternalInitials({
    super.key,
    required this.name,
    this.large = false,
  });
  final String name;
  final bool large;
  static String initials(String name) =>
      String.fromCharCodes(name.trim().runes.take(2)).toUpperCase();

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Center(
      child: Text(
        initials(name),
        style: TextStyle(
          fontFamily: t.headingFont,
          fontSize: large ? 24 : 14,
          height: 1,
          fontWeight: FontWeight.w600,
          color: t.muted,
        ),
      ),
    );
  }
}

/// The profile panel's surface (`bg-layer-panel`).
class RaftProfilePanelSurface extends StatelessWidget {
  const RaftProfilePanelSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ColoredBox(color: t.panel, child: child);
  }
}
