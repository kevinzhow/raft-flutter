// Web ExternalIdentityDetailPanel body (components/profile/
// ExternalIdentityDetailPanel.tsx): the provider workspace row and the
// identity block of a provider-owned message author.
import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'list_items.dart';
import 'theme.dart';

class RaftExternalIdentityBody extends StatelessWidget {
  const RaftExternalIdentityBody({
    super.key,
    required this.name,
    required this.subtitle,
    required this.projectionLabel,
    required this.avatar,
    this.fromLabel,
    this.workspaceName,
  });
  final String name, subtitle, projectionLabel;

  /// AvatarSlot `profile-tile` (type app).
  final Widget avatar;

  /// "From" eyebrow of the source row, shown only with a [workspaceName].
  final String? fromLabel, workspaceName;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final strong = t.strong;
    final muted = t.muted;
    return ColoredBox(
      // ExternalIdentityDetailPanel: `ProfilePanelBody ... bg-layer-canvas`.
      color: t.panel,
      child: SingleChildScrollView(
        key: const Key('external-identity-body'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (workspaceName != null && workspaceName!.isNotEmpty)
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
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: t.headingFont,
                              fontSize: 18,
                              height: 28 / 18,
                              fontWeight: FontWeight.w700,
                              color: strong,
                            ),
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RaftTypography.mono(t, color: muted),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            projectionLabel,
                            style: TextStyle(
                              fontFamily: t.headingFont,
                              fontSize: 14,
                              height: 20 / 14,
                              color: muted,
                            ),
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
/// name in bold (Brutal black / Elegant muted); 24px in the profile tile, 14px
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

/// The profile panel's surface (`bg-layer-panel`, Brutal white).
class RaftProfilePanelSurface extends StatelessWidget {
  const RaftProfilePanelSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ColoredBox(color: t.panel, child: child);
  }
}
