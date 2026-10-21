// Settings > Applications: the installation-setup surfaces of the Web client
// (raft-source v1.21.23 components/integrations/AppSetup.tsx): the editor's
// "Requires configuration after installation" fields, the "Setup required"
// notice shown before an install, and the per-installation setup panel. The
// app owns the request, the URL validation and the wire contract; the layout
// and the copy live here.
import 'package:flutter/material.dart';

import 'design_primitives.dart' show RaftTypography;
import 'icons.dart';
import 'indicators.dart'
    show RaftBadge, RaftCheckbox, RaftStatusDot, RaftStatusDotSize;
import 'localization.dart';
import 'recipes/badge.g.dart';
import 'recipes/button_variants.g.dart'
    show RaftButtonRecipeSize, RaftButtonRecipeVariant;
import 'settings_app_editor.dart' show RaftAppEditorField, RaftAppEditorStack;
import 'settings_controls.dart';
import 'settings_layout.dart';
import 'theme.dart';

/// `AppSetupFields`: a yes/no saved with the form is a checkbox; the URL and
/// the instructions show only while it is on.
class RaftAppSetupFields extends StatelessWidget {
  const RaftAppSetupFields({
    super.key,
    required this.required,
    required this.url,
    required this.description,
    required this.onRequiredChanged,
  });

  final bool required;
  final TextEditingController url, description;
  final ValueChanged<bool> onRequiredChanged;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftAppEditorStack(
      gap: RaftSpace.x3,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: RaftSpace.x3,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: RaftCheckbox(
                key: const ValueKey('app-setup-required'),
                value: required,
                semanticLabel: raftText(
                  context,
                  'Requires configuration after installation',
                ),
                onChanged: onRequiredChanged,
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onRequiredChanged(!required),
                child: Text(
                  raftText(
                    context,
                    'Requires configuration after installation',
                  ),
                  style: RaftTypography.body(
                    t,
                    size: 14,
                    line: 20,
                    weight: FontWeight.w600,
                    color: t.strong,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (required) ...[
          RaftAppEditorField(
            label: 'Setup page URL',
            hint: 'Use an HTTPS page. Raft adds installation and Server identifiers; this is separate from the login callback.',
            child: RaftRecipeInput(
              fieldKey: const ValueKey('app-setup-url'),
              controller: url,
              maxLength: 2000,
              keyboardType: TextInputType.url,
            ),
          ),
          RaftAppEditorField(
            label: 'Configuration instructions',
            optional: true,
            child: RaftRecipeInput(
              fieldKey: const ValueKey('app-setup-description'),
              controller: description,
              maxLength: 500,
            ),
          ),
        ],
      ],
    );
  }
}

TextStyle _callout(RaftTokens t, {Color? color}) =>
    RaftTypography.body(t, size: 14, line: 20, color: color ?? t.muted);

/// `AppSetupRequirement`: before an install, the notice that the App needs
/// configuration afterwards. Publisher-authored text is rendered as text.
class RaftAppSetupRequirement extends StatelessWidget {
  const RaftAppSetupRequirement({
    super.key,
    required this.domain,
    this.description,
  });

  final String domain;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = description;
    return RaftSettingsCard(
      key: const ValueKey('app-setup-requirement'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: RaftSpace.x2,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _statusBadge(context, 'Setup required', warning: true),
          ),
          Text(
            raftFormat(
              context,
              'After installation, continue configuration at {domain}.',
              {'domain': domain},
            ),
            style: _callout(t),
          ),
          if (text != null && text.isNotEmpty)
            Text(text, style: _callout(t, color: t.strong)),
        ],
      ),
    );
  }
}

Widget _statusBadge(
  BuildContext context,
  String label, {
  required bool warning,
}) {
  final t = RaftTokens.of(context);
  return RaftBadge(
    label: raftText(context, label),
    appearance: RaftBadgeRecipeAppearance.soft,
    variant: warning
        ? RaftBadgeRecipeVariant.warning
        : RaftBadgeRecipeVariant.success,
    leading: RaftStatusDot(
      color: warning ? t.colors['warning-strong'] : t.colors['success-strong'],
      size: RaftStatusDotSize.sm,
    ),
  );
}

/// What [RaftAppSetupPanel] shows for one installation.
class RaftAppSetupView {
  const RaftAppSetupView({
    required this.complete,
    required this.canConfigure,
    this.description,
    this.domain,
  });

  /// `status === "complete"` (otherwise `pending`).
  final bool complete, canConfigure;
  final String? description;

  /// Host of the setup URL; with [canConfigure] it enables the button.
  final String? domain;
}

/// `AppSetupPanel`: the per-installation state. Returning from the App only
/// refreshes; it never writes completion.
class RaftAppSetupPanel extends StatelessWidget {
  const RaftAppSetupPanel({
    super.key,
    this.view,
    this.failed = false,
    this.onOpen,
    this.onRefresh,
  });

  /// Null while loading (or failed).
  final RaftAppSetupView? view;
  final bool failed;
  final VoidCallback? onOpen, onRefresh;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final v = view;
    String tr(String s) => raftText(context, s);
    final children = <Widget>[
      Text(
        tr('Installation setup'),
        style: RaftTypography.body(
          t,
          size: 14,
          line: 20,
          weight: FontWeight.w600,
          color: t.strong,
        ),
      ),
      if (failed)
        Semantics(
          liveRegion: true,
          child: Text(
            tr('Could not load configuration status. Try again.'),
            style: RaftTypography.body(
              t,
              size: 12,
              line: 16,
              weight: FontWeight.w600,
              color: t.colors['warning-strong'],
            ),
          ),
        )
      else if (v == null)
        Text(tr('Loading…'), style: _callout(t))
      else ...[
        Align(
          alignment: Alignment.centerLeft,
          child: _statusBadge(
            context,
            v.complete ? 'Configured' : 'Installed, setup pending',
            warning: !v.complete,
          ),
        ),
        if (v.description != null && v.description!.isNotEmpty)
          Text(v.description!, style: _callout(t, color: t.strong)),
        if (v.canConfigure && v.domain != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: RaftSpace.x2,
            children: [
              RaftSettingsRecipeButton(
                key: const ValueKey('app-setup-open'),
                label: tr(
                  v.complete ? 'Manage configuration' : 'Continue setup',
                ),
                glyph: RaftGlyph.externalLink,
                glyphSize: 16,
                size: RaftButtonRecipeSize.sm,
                onPressed: onOpen,
              ),
              Text(
                raftFormat(context, 'Opens {domain} in a new tab', {
                  'domain': v.domain!,
                }),
                style: RaftTypography.body(
                  t,
                  size: 12,
                  line: 16,
                  color: t.colors['foreground-hint'],
                ),
              ),
            ],
          )
        else
          Text(
            tr(
              v.complete
                  ? 'A Server administrator can manage configuration.'
                  : 'Ask a Server administrator to complete configuration.',
            ),
            style: _callout(t),
          ),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: RaftSettingsRecipeButton(
          key: const ValueKey('app-setup-refresh'),
          label: tr('Refresh status'),
          size: RaftButtonRecipeSize.sm,
          variant: RaftButtonRecipeVariant.outline,
          onPressed: onRefresh,
        ),
      ),
    ];
    return RaftSettingsCard(
      key: const ValueKey('app-installation-setup'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: RaftSpace.x3,
        children: children,
      ),
    );
  }
}
