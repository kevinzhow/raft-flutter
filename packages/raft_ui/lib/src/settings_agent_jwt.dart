// Settings > Applications: the "Agent access JWT" card of the Web client
// (raft-source v1.21.12 AgentJwtSettings.tsx: `Card space-y-3 p-3`). It shows
// in the installed-app detail, the installed marketplace listing detail and
// the app editor. The app owns the request, the state and the wire contract;
// the layout and the copy live here.
import 'package:flutter/material.dart';

import 'banner.dart';
import 'design_primitives.dart' show RaftTypography;
import 'localization.dart';
import 'recipes/button_variants.g.dart'
    show RaftButtonRecipeSize, RaftButtonRecipeVariant;
import 'settings_controls.dart';
import 'settings_layout.dart';
import 'switch.dart';
import 'theme.dart';

/// The loaded `AppAgentJwtSettings` fields the card renders.
class RaftAgentJwtView {
  const RaftAgentJwtView({
    required this.appScope,
    required this.enabled,
    required this.canEnable,
    required this.audience,
  });

  /// `scope === "app"` (the App declares support) vs `"installation"` (this
  /// Server allows it).
  final bool appScope;

  /// The saved value; [RaftAgentJwtCard.enabled] is the draft.
  final bool enabled, canEnable;
  final String audience;
}

class RaftAgentJwtCard extends StatelessWidget {
  const RaftAgentJwtCard({
    super.key,
    required this.canManage,
    this.registered = true,
    this.loading = false,
    this.failed = false,
    this.saving = false,
    this.settings,
    this.enabled = false,
    this.onChanged,
    this.onSave,
  });

  /// The App has an id; false shows "Register the App, then …".
  final bool registered;
  final bool canManage, loading, failed, saving;
  final RaftAgentJwtView? settings;

  /// The draft switch value.
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    // `text-foreground-muted` (no brutal override on this card).
    final hint = RaftTypography.body(t, size: 12, line: 16, color: t.muted);
    final s = settings;
    String tr(String text) => raftText(context, text);
    Widget gap(Widget child) =>
        Padding(padding: const EdgeInsets.only(top: 12), child: child);
    return RaftSettingsCard(
      key: const ValueKey('agent-jwt-settings'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('Agent access JWT'),
            style: RaftTypography.body(
              t,
              size: 14,
              line: 20,
              weight: FontWeight.w700,
              color: t.strong,
            ),
          ),
          gap(
            Text(
              tr(
                'Let agents authenticate to this App with a five-minute JWT, without a browser callback. The App must be configured to verify Raft JWTs.',
              ),
              style: hint,
            ),
          ),
          if (!registered)
            gap(
              Text(
                tr(
                  'Register the App, then edit its login settings to enable JWT access.',
                ),
                style: hint,
              ),
            ),
          if (loading) gap(Text(tr('Loading…'), style: hint)),
          if (failed)
            gap(
              RaftBanner(
                description: tr(
                  'Could not load or save JWT settings. Retry before relying on this change.',
                ),
                size: RaftBannerRecipeSize.sm,
              ),
            ),
          if (s != null) ...[
            gap(
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(
                        s.appScope
                            ? 'Enable Agent JWT support'
                            : 'Allow Agent JWTs on this Server',
                      ),
                      style: RaftTypography.body(
                        t,
                        size: 14,
                        line: 20,
                        color: t.strong,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  RaftSwitch(
                    key: const ValueKey('agent-jwt-switch'),
                    value: enabled,
                    enabled: canManage && !saving && (s.canEnable || enabled),
                    onChanged: onChanged,
                    semanticLabel: tr(
                      s.appScope
                          ? 'Enable Agent JWT support'
                          : 'Allow Agent JWTs on this Server',
                    ),
                  ),
                ],
              ),
            ),
            gap(
              Text(
                tr(
                  s.appScope
                      ? 'Declares JWT support for this App. Other Servers must separately allow access after installing it.'
                      : 'Allows this Server’s agents to use JWTs with this installed App. Other Servers are unaffected.',
                ),
                style: hint,
              ),
            ),
            gap(
              Text(
                raftFormat(
                  context,
                  'Audience: {audience}. Tokens expire after five minutes. Turning off stops new issuance; existing tokens expire normally.',
                  {'audience': s.audience},
                ),
                key: const ValueKey('agent-jwt-audience'),
                style: hint,
              ),
            ),
            if (!s.canEnable)
              gap(
                Text(
                  tr(
                    s.appScope
                        ? 'Enable the App and its openid/profile login scopes before turning on JWT access.'
                        : 'The App must support JWTs and this installation must be active before access can be enabled.',
                  ),
                  key: const ValueKey('agent-jwt-unavailable'),
                  style: hint,
                ),
              ),
            if (canManage)
              gap(
                Align(
                  alignment: Alignment.centerLeft,
                  child: RaftSettingsRecipeButton(
                    key: const ValueKey('agent-jwt-save'),
                    label: saving ? 'Saving…' : 'Save JWT settings',
                    variant: RaftButtonRecipeVariant.default_,
                    size: RaftButtonRecipeSize.sm,
                    onPressed:
                        saving ||
                            enabled == s.enabled ||
                            (enabled && !s.canEnable)
                        ? null
                        : onSave,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
