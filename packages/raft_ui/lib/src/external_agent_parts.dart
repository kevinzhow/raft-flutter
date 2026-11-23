// The parts the external agent setup is made of (Web v1.24
// features/agent/ExternalSetupCopy.tsx, ExternalAgentConnectionCard.tsx,
// ExternalAgentCredentialList.tsx): a copy field and a copy block, the status
// card, the setup steps for an existing agent or the SDK, and the credential
// list. The create dialog and the agent page's connection card compose them;
// the app owns every request and passes values and callbacks in.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'card.dart';
import 'design_primitives.dart'
    show
        RaftDropdownAlign,
        RaftDropdownMenu,
        RaftMenuEntry,
        RaftMenuKind,
        RaftTextLink,
        RaftTextLinkVariant;
import 'icons.dart';
import 'interaction.dart';
import 'list_items.dart' show RaftSectionEyebrow;
import 'localization.dart';
import 'panel_layout.dart' show RaftCssText;
import 'raft/button.dart';
import 'raft/status.dart';
import 'raft/ui_tokens.dart';
import 'separator.dart';
import 'theme.dart';
import 'tokens/tokens.dart';
import 'tooltip.dart';

/// How the external agent connects: Web `ExternalSetupMethod`.
enum RaftExternalMethod { existingAgent, sdk }

const double _controlRadius = 10;

/// `rounded-control border border-line bg-layer-sunken` as it renders: the
/// default (line-strong) 1px border over the dialog's own fill.
BoxDecoration _boxDecoration(BuildContext context) {
  final t = RaftTokens.of(context);
  return BoxDecoration(
    border: Border.all(color: t.ui.lineStrong),
    borderRadius: BorderRadius.circular(
      t.size('radius.control', fallback: _controlRadius),
    ),
  );
}

TextStyle _body(RaftTokens t, {FontWeight? weight, Color? color}) => t.scale(
  RaftTypeScale.body,
  weight: weight,
  color: color ?? t.ui.foreground,
);
TextStyle _callout(RaftTokens t, {FontWeight? weight, Color? color}) => t.scale(
  RaftTypeScale.callout,
  weight: weight,
  color: color ?? t.ui.foregroundMuted,
);
TextStyle _footnote(RaftTokens t, {Color? color, bool mono = false}) => t.scale(
  RaftTypeScale.footnote,
  mono: mono,
  color: color ?? t.ui.foregroundMuted,
);

/// A step heading (`text-body font-semibold`).
class RaftExternalHeading extends StatelessWidget {
  const RaftExternalHeading(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => RaftCssText(
    raftText(context, text),
    style: _body(RaftTokens.of(context), weight: FontWeight.w600),
  );
}

/// Quiet explanatory text (`text-callout text-foreground-muted`).
class RaftExternalNote extends StatelessWidget {
  const RaftExternalNote(
    this.text, {
    super.key,
    this.small = false,
    this.topGap = 0,
  });

  /// Space above the note.
  final double topGap;

  /// Already localized.
  final String text;

  /// `text-footnote`.
  final bool small;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final note = RaftCssText(text, style: small ? _footnote(t) : _callout(t));
    return topGap == 0
        ? note
        : Padding(
            padding: EdgeInsets.only(top: topGap),
            child: note,
          );
  }
}

/// A failure line under the credentials (`text-footnote font-semibold
/// text-warning-strong`); [text] is an English source.
class RaftExternalWarning extends StatelessWidget {
  const RaftExternalWarning(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftCssText(
      raftText(context, text),
      style: t.scale(
        RaftTypeScale.footnote,
        weight: FontWeight.w600,
        color: t.colors['warning-strong'],
      ),
    );
  }
}

Future<void> _copy(String text) => Clipboard.setData(ClipboardData(text: text));

/// Web `CopyField`: a value with its copy button at the field's end.
class RaftExternalCopyField extends StatefulWidget {
  const RaftExternalCopyField({super.key, required this.text, this.copyKey});
  final String text;

  /// Key of the copy button.
  final Key? copyKey;
  @override
  State<RaftExternalCopyField> createState() => _RaftExternalCopyFieldState();
}

class _RaftExternalCopyFieldState extends State<RaftExternalCopyField> {
  bool copied = false;

  Future<void> copy() async {
    try {
      await _copy(widget.text);
      if (mounted) setState(() => copied = true);
    } catch (_) {
      if (mounted) setState(() => copied = false);
    }
  }

  @override
  void didUpdateWidget(RaftExternalCopyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) copied = false;
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final touch = RaftInteraction.of(context).touch;
    final label = raftText(context, 'Copy');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Expanded(
          // `min-h-11 px-3 py-2`, `md:pointer-fine:min-h-[34px] py-1.5`.
          child: Container(
            constraints: BoxConstraints(minHeight: touch ? 44 : 34),
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: touch ? 8 : 6,
            ),
            decoration: _boxDecoration(context),
            alignment: AlignmentDirectional.centerStart,
            child: RaftCssText(
              widget.text,
              style: _footnote(t, color: t.ui.foreground, mono: true),
            ),
          ),
        ),
        RaftButton(
          key: widget.copyKey,
          glyph: copied ? RaftGlyph.check : RaftGlyph.copy,
          glyphSize: 20,
          uiVariant: RaftButtonVariant.outline,
          uiSize: RaftButtonSize.iconLg,
          semanticLabel: label,
          tooltip: label,
          onPressed: () => copy(),
        ),
      ],
    );
  }
}

/// Web `CopyBlock`: a longer block (a prompt) with its own copy button under
/// it; [collapsed] shows the first lines and a Show full prompt / Show less
/// link.
class RaftExternalCopyBlock extends StatefulWidget {
  const RaftExternalCopyBlock({
    super.key,
    required this.text,
    required this.label,
    this.primary = false,
    this.collapsed = false,
    this.copyKey,
    this.toggleKey,
  });
  final String text;

  /// The copy button's English source ("Copy prompt").
  final String label;
  final bool primary, collapsed;
  final Key? copyKey, toggleKey;
  @override
  State<RaftExternalCopyBlock> createState() => _RaftExternalCopyBlockState();
}

class _RaftExternalCopyBlockState extends State<RaftExternalCopyBlock> {
  bool copied = false;
  late bool open = !widget.collapsed;

  Future<void> copy() async {
    try {
      await _copy(widget.text);
      if (mounted) setState(() => copied = true);
    } catch (_) {
      if (mounted) setState(() => copied = false);
    }
  }

  @override
  void didUpdateWidget(RaftExternalCopyBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) copied = false;
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    Widget text = RaftCssText(
      widget.text,
      style: _footnote(t, color: t.ui.foreground, mono: true),
    );
    if (!open) {
      // `max-h-24 overflow-hidden`
      text = ClipRect(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 96),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: text,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: _boxDecoration(context),
          child: text,
        ),
        if (widget.collapsed)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: RaftTextLink(
              key: widget.toggleKey,
              label: raftText(context, open ? 'Show less' : 'Show full prompt'),
              variant: RaftTextLinkVariant.muted,
              textStyle: _callout(t, weight: FontWeight.w500),
              onPressed: () => setState(() => open = !open),
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: RaftButton(
            key: widget.copyKey,
            label: raftText(context, copied ? 'Copied' : widget.label),
            glyph: RaftGlyph.copy,
            uiVariant: widget.primary
                ? RaftButtonVariant.primary
                : RaftButtonVariant.outline,
            uiSize: RaftButtonSize.md,
            onPressed: () => copy(),
          ),
        ),
      ],
    );
  }
}

/// The presence the status card shows: a person must act (orange), online
/// (green), offline (stone).
enum RaftExternalLight { attention, online, offline }

/// The external agent's status line (Web `StatusLine`, and the create
/// dialog's status card): a light, a title, a hint and, once connected, the
/// How it connects toggle.
class RaftExternalStatusCard extends StatelessWidget {
  const RaftExternalStatusCard({
    super.key,
    required this.light,
    required this.title,
    required this.hint,
    this.titleTooltip,
    this.toggleLabel,
    this.expanded = false,
    this.onToggle,
    this.titleKey,
    this.toggleKey,
  });
  final RaftExternalLight light;

  /// Already localized.
  final String title, hint;

  /// The exact time of "Offline · last seen 3 hours ago".
  final String? titleTooltip;

  /// English source of the toggle ("How it connects"); null: no toggle.
  final String? toggleLabel;
  final bool expanded;
  final VoidCallback? onToggle;
  final Key? titleKey, toggleKey;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    Widget heading = RaftCssText(
      title,
      key: titleKey,
      style: _body(t, weight: FontWeight.w600),
    );
    if (titleTooltip != null) {
      heading = RaftTooltip(message: titleTooltip!, child: heading);
    }
    const toggleSize = RaftButtonSize.md;
    const toggleVariant = RaftButtonVariant.ghost;
    return Container(
      // `rounded-control border border-line px-4 py-3`
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _boxDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          // `mt-1.5`
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: RaftStatusDot(
              activity: switch (light) {
                RaftExternalLight.online => RaftActivityTone.online,
                RaftExternalLight.offline => RaftActivityTone.offline,
                RaftExternalLight.attention => RaftActivityTone.error,
              },
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                RaftCssText(hint, style: _callout(t)),
              ],
            ),
          ),
          if (toggleLabel != null)
            RaftButton(
              key: toggleKey,
              label: raftText(context, toggleLabel!),
              trailingGlyph: expanded
                  ? RaftGlyph.chevronUp
                  : RaftGlyph.chevronDown,
              uiVariant: toggleVariant,
              uiSize: toggleSize,
              padding: EdgeInsets.symmetric(
                horizontal: RaftButtonMetrics.of(
                  toggleSize,
                  toggleVariant,
                  t,
                ).paddingX,
              ),
              semanticLabel: raftText(context, toggleLabel!),
              expanded: expanded,
              onPressed: onToggle,
            ),
        ],
      ),
    );
  }
}

/// The link that switches how the agent connects (Web: "Build it with the SDK
/// instead" / "Use an existing agent instead"), quiet under the status card.
class RaftExternalSwitchLink extends StatelessWidget {
  const RaftExternalSwitchLink({
    super.key,
    required this.label,
    required this.onPressed,
  });

  /// English source.
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    // A text link is one line; in a window too narrow for it, it shrinks
    // to fit instead of overflowing.
    return LayoutBuilder(
      builder: (context, box) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: box.maxWidth),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: RaftTextLink(
              label: raftText(context, label),
              variant: RaftTextLinkVariant.muted,
              textStyle: _callout(t, weight: FontWeight.w500),
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    );
  }
}

/// The setup steps for [method] (Web: the dialog's step 2 and the page's
/// steps). [credentialStep] is the credential block (the shown-once secret,
/// the create button, who to ask); without one the headings lose their
/// numbers and the credential section is left out.
class RaftExternalSetupSteps extends StatelessWidget {
  const RaftExternalSetupSteps({
    super.key,
    required this.method,
    required this.name,
    required this.promptText,
    required this.installCommand,
    required this.starterCode,
    required this.onOpenSdkGuide,
    this.credentialStep,
    this.keyPrefix = 'external-agent',
  });
  final RaftExternalMethod method;

  /// The agent's name (already localized text, not a catalog source).
  final String name;
  final String promptText, installCommand, starterCode;
  final Widget? credentialStep;
  final VoidCallback onOpenSdkGuide;

  /// Prefix of the keys of the steps' parts (`-prompt`, `-install`, `-code`).
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final numbered = credentialStep != null;
    Widget section(String heading, List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [RaftExternalHeading(heading), ...children],
    );
    final steps = switch (method) {
      RaftExternalMethod.existingAgent => [
        section(
          numbered
              ? '1. Send this prompt to your agent'
              : 'Send this prompt to your agent',
          [
            RaftExternalCopyBlock(
              key: ValueKey('$keyPrefix-prompt'),
              text: promptText,
              label: 'Copy prompt',
              primary: true,
              collapsed: true,
              copyKey: ValueKey('$keyPrefix-prompt-copy'),
              toggleKey: ValueKey('$keyPrefix-prompt-toggle'),
            ),
          ],
        ),
        if (credentialStep != null)
          section('2. Give it the agent credential when it asks', [
            credentialStep!,
          ]),
      ],
      RaftExternalMethod.sdk => [
        if (credentialStep != null)
          section('1. Copy the agent credential', [credentialStep!]),
        section(
          numbered
              ? '2. Install the SDK and connect'
              : 'Install the SDK and connect',
          [
            RaftExternalCopyField(
              key: ValueKey('$keyPrefix-install'),
              text: installCommand,
              copyKey: ValueKey('$keyPrefix-install-copy'),
            ),
            RaftExternalCopyField(
              key: ValueKey('$keyPrefix-code'),
              text: starterCode,
              copyKey: ValueKey('$keyPrefix-code-copy'),
            ),
            // `{name} shows as online after the first call.` and the guide
            // link, in one paragraph: the link follows the sentence and drops
            // to the next line where it does not fit.
            Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                RaftCssText(
                  raftFormat(
                    context,
                    '{name} shows as online after the first call.',
                    {'name': name},
                  ),
                  style: _callout(t),
                ),
                RaftTextLink(
                  key: ValueKey('$keyPrefix-sdk-guide'),
                  label: raftText(context, 'Read the SDK guide'),
                  variant: RaftTextLinkVariant.strong,
                  textStyle: _callout(
                    t,
                    weight: FontWeight.w600,
                    color: t.ui.foreground,
                  ),
                  // Web `TextLinkExternalIcon`: the link leaves Raft.
                  external: true,
                  onPressed: onOpenSdkGuide,
                ),
              ],
            ),
          ],
        ),
      ],
    };
    return Column(
      key: ValueKey('$keyPrefix-steps-${method.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: steps,
    );
  }
}

/// One credential of the list.
@immutable
class RaftExternalCredentialRow {
  const RaftExternalCredentialRow({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.canReplace,
  });
  final String id;

  /// Already localized: "Created on this page", its name or "Agent credential".
  final String title;

  /// Already localized: "Created {date} · last used {time}" or "not used yet".
  final String subtitle;

  /// The page's own credential: Create new credential is offered.
  final bool canReplace;
}

/// Web `ExternalAgentCredentialList`: each credential by where it came from
/// and when it was last used; the row menu has Create new credential (the
/// page's own credential only) and Revoke.
class RaftExternalCredentialList extends StatelessWidget {
  const RaftExternalCredentialList({
    super.key,
    required this.credentials,
    required this.loading,
    required this.listError,
    required this.disabled,
    required this.onReplace,
    required this.onRevoke,
  });
  final List<RaftExternalCredentialRow> credentials;
  final bool loading, listError, disabled;
  final ValueChanged<String> onReplace, onRevoke;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final warning = t.scale(
      RaftTypeScale.footnote,
      weight: FontWeight.w600,
      color: t.colors['warning-strong'],
    );
    final hint = _footnote(t, color: t.ui.foregroundHint);
    return Column(
      key: const ValueKey('external-agent-credentials'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        RaftSectionEyebrow(raftText(context, 'Credentials')),
        if (loading)
          Semantics(
            liveRegion: true,
            child: RaftCssText(
              raftText(context, 'Loading credentials…'),
              style: hint,
            ),
          ),
        if (listError)
          Semantics(
            liveRegion: true,
            child: RaftCssText(
              raftText(context, "Raft couldn't load the credentials."),
              style: warning,
            ),
          ),
        if (!loading && !listError && credentials.isEmpty)
          RaftCssText(raftText(context, 'No credentials yet.'), style: hint),
        if (!loading && !listError && credentials.isNotEmpty)
          RaftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, c) in credentials.indexed) ...[
                  if (i > 0) const RaftSeparator(),
                  _CredentialItem(
                    key: ValueKey('external-credential-${c.id}'),
                    credential: c,
                    disabled: disabled,
                    onReplace: onReplace,
                    onRevoke: onRevoke,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _CredentialItem extends StatelessWidget {
  const _CredentialItem({
    super.key,
    required this.credential,
    required this.disabled,
    required this.onReplace,
    required this.onRevoke,
  });
  final RaftExternalCredentialRow credential;
  final bool disabled;
  final ValueChanged<String> onReplace, onRevoke;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final c = credential;
    final menuLabel = raftFormat(context, 'Actions for {credential}', {
      'credential': c.title,
    });
    return Padding(
      // `px-3 py-2.5`
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RaftCssText(
                  c.title,
                  style: _callout(
                    t,
                    weight: FontWeight.w600,
                    color: t.ui.foreground,
                  ),
                ),
                RaftCssText(c.subtitle, style: _footnote(t)),
              ],
            ),
          ),
          RaftDropdownMenu(
            key: ValueKey('external-credential-menu-${c.id}'),
            label: menuLabel,
            tooltip: menuLabel,
            enabled: !disabled,
            kind: RaftMenuKind.dropdownMenu,
            align: RaftDropdownAlign.end,
            triggerBuilder: (context, focusNode, open) => RaftButton(
              glyph: RaftGlyph.ellipsisVertical,
              focusNode: focusNode,
              tooltip: menuLabel,
              semanticLabel: menuLabel,
              uiVariant: RaftButtonVariant.ghost,
              uiSize: RaftButtonSize.iconLg,
              onPressed: disabled ? null : open,
            ),
            entries: [
              if (c.canReplace)
                RaftMenuEntry(
                  label: raftText(context, 'Create new credential'),
                  glyph: RaftGlyph.plus,
                  onPressed: () => onReplace(c.id),
                ),
              RaftMenuEntry(
                label: raftText(context, 'Revoke'),
                glyph: RaftGlyph.ban,
                onPressed: () => onRevoke(c.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Step 2 of the create dialog: the failure line, the status card, the method
/// switch and the steps (Web `CreateExternalAgentDialog` setup body).
class RaftExternalSetupBody extends StatelessWidget {
  const RaftExternalSetupBody({
    super.key,
    required this.status,
    this.error,
    this.switchLabel,
    this.onSwitch,
    this.steps,
  });
  final Widget status;
  final String? error;
  final String? switchLabel;
  final VoidCallback? onSwitch;
  final Widget? steps;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        if (error != null)
          Semantics(
            liveRegion: true,
            child: RaftCssText(
              error!,
              key: const ValueKey('create-external-agent-error'),
              style: t.scale(RaftTypeScale.callout, color: t.ui.danger),
            ),
          ),
        status,
        if (switchLabel != null)
          RaftExternalSwitchLink(
            key: const ValueKey('create-external-agent-switch'),
            label: switchLabel!,
            onPressed: onSwitch,
          ),
        ?steps,
      ],
    );
  }
}

/// The setup footer: the "finish later" note at the start, the buttons at the
/// end.
class RaftExternalSetupFooter extends StatelessWidget {
  const RaftExternalSetupFooter({super.key, this.note, required this.children});
  final String? note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Row(
      spacing: 12,
      children: [
        Expanded(
          child: note == null
              ? const SizedBox.shrink()
              : RaftCssText(
                  raftText(context, note!),
                  style: t.scale(
                    RaftTypeScale.callout,
                    color: t.ui.foregroundMuted,
                  ),
                ),
        ),
        ...children,
      ],
    );
  }
}
