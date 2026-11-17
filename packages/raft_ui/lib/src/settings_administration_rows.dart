// Administration rows, Web v1.24.0 features/settings/administration/*: settings
// rows in a ListRowGroup (DS Forms › A setting's row) whose control ends the row
// or, where the group is under 32rem wide (`@max-lg`), goes under the text.
//   ImmediateSetting.tsx  ImmediateSwitchRow / ImmediateSaveStatus
//   OnboardingAgentSection.tsx, ContextViewGrantsSection.tsx,
//   GrantContextViewDialog.tsx, UsageDataSettings.tsx SwitchRow and
//   MemberRemovalImpactNote.tsx OwnComputersTransferNote.
// Presentation only: the app owns data, requests and confirmations.
import 'package:flutter/material.dart';

import '../raft_ui.dart';

/// Web `@container` `@max-lg`: under 32rem the control goes under the text.
const double _narrowWidth = 512;

/// `SelectTrigger fit`: 11rem to 20rem; under the text `max-w-sm` (24rem).
const double _fitMin = 176, _fitMax = 320, _belowMax = 384;

/// raft-ui `SaveStatus` with a `SaveStatusError`: the failure of a setting that
/// applies at once, `text-footnote text-danger-strong`, an alert. Empty it
/// takes no room.
class RaftAdminSaveLine extends StatelessWidget {
  const RaftAdminSaveLine(this.message, {super.key});
  final String? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    if (message == null || message.isEmpty) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    return Semantics(
      liveRegion: true,
      child: Text(
        raftText(context, message),
        style: t.scale(
          RaftTypeScale.footnote,
          color: t.colors['danger-strong'] ?? t.strong,
        ),
      ),
    );
  }
}

/// One row of [RaftAdminRows]: a title, a description, lines under them
/// (failure, hints, banners) and the control that ends the row.
@immutable
class RaftAdminRowSpec {
  const RaftAdminRowSpec({
    this.key,
    this.title,
    this.description,
    this.body = const [],
    this.control,
    this.wrapNarrow = false,
  });
  final Key? key;
  final String? title, description;

  /// Under the text, in order.
  final List<Widget> body;

  /// A switch, select or button ending the row.
  final Widget? control;

  /// Under 32rem the control moves under [body] (selects and buttons; never
  /// switches).
  final bool wrapNarrow;
}

/// The control's width inside a row: a select at the row's end is as wide as
/// its longest option, under the text it is full width up to 24rem.
class _ControlBelow extends InheritedWidget {
  const _ControlBelow({required this.below, required super.child});
  final bool below;
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ControlBelow>()?.below ??
      true;
  @override
  bool updateShouldNotify(_ControlBelow old) => old.below != below;
}

/// `ListRowGroup` of plain, non-interactive rows.
class RaftAdminRows extends StatelessWidget {
  const RaftAdminRows({super.key, required this.rows});
  final List<RaftAdminRowSpec> rows;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow =
          constraints.maxWidth.isFinite && constraints.maxWidth < _narrowWidth;
      return RaftListRowGroup(
        children: [
          for (var i = 0; i < rows.length; i++)
            KeyedSubtree(
              key: rows[i].key,
              child: _row(rows[i], narrow, i > 0),
            ),
        ],
      );
    },
  );

  Widget _row(RaftAdminRowSpec row, bool narrow, bool rule) {
    final below = row.control != null && narrow && row.wrapNarrow;
    final title = row.title, description = row.description;
    return RaftListRow(
      variant: RaftListRowVariant.plain,
      interactive: false,
      topRule: rule,
      children: [
        RaftListRowBody(
          children: [
            if (title != null) RaftListRowTitle(title),
            if (description != null)
              RaftListRowDescription(description, wrap: true),
            ...row.body,
            if (below)
              Padding(
                padding: const EdgeInsets.only(top: RaftSpace.x2),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _belowMax),
                    child: _ControlBelow(below: true, child: row.control!),
                  ),
                ),
              ),
          ],
        ),
        if (row.control != null && !below)
          _ControlBelow(below: false, child: row.control!),
      ],
    );
  }
}

/// A select sized for an Administration row (`SelectTrigger fit`).
class RaftAdminRowSelect<T> extends StatelessWidget {
  const RaftAdminRowSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.label,
    required this.placeholder,
  });
  final T? value;
  final List<RaftSelectItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String label, placeholder;

  @override
  Widget build(BuildContext context) {
    final select = RaftSelectField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      label: raftText(context, label),
      placeholder: placeholder,
    );
    if (_ControlBelow.of(context)) return select;
    final style = RaftTokens.of(
      context,
    ).scale(RaftTypeScale.body, weight: FontWeight.w500);
    var widest = 0.0;
    for (final text in [
      for (final item in items) item.label,
      raftText(context, placeholder),
    ]) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    final width =
        (widest +
                RaftSpace.x3 * 2 +
                RaftSpace.x4 +
                RaftSpace.x2 +
                RaftSpace.hairline * 2 +
                RaftSpace.x1)
            .clamp(_fitMin, _fitMax)
            .toDouble();
    return SizedBox(width: width, child: select);
  }
}

/// ImmediateSwitchRow: a group with one setting whose Switch applies at once.
/// Only a failure shows, under the description; [footer] (a warning about the
/// current value) goes under the group so the row keeps its height.
class RaftAdminImmediateSwitchRow extends StatelessWidget {
  const RaftAdminImmediateSwitchRow({
    super.key,
    required this.title,
    required this.description,
    required this.checked,
    required this.onChanged,
    this.failure,
    this.footer,
    this.switchKey,
    this.descriptionSpan,
  });
  final String title, description;
  final bool checked;

  /// Null disables the switch.
  final ValueChanged<bool>? onChanged;
  final String? failure;
  final List<Widget>? footer;
  final Key? switchKey;

  /// Replaces the plain description (UsageDataSettings' "Learn more").
  final Widget? descriptionSpan;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RaftAdminRows(
        rows: [
          RaftAdminRowSpec(
            title: title,
            description: descriptionSpan == null ? description : null,
            body: [?descriptionSpan, RaftAdminSaveLine(failure)],
            control: RaftSwitch(
              key: switchKey,
              value: checked,
              enabled: onChanged != null,
              semanticLabel: raftText(context, title),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
      if (footer != null && footer!.isNotEmpty) ...[
        const SizedBox(height: RaftSpace.x3),
        for (final (i, widget) in footer!.indexed) ...[
          if (i > 0) const SizedBox(height: RaftSpace.x2),
          widget,
        ],
      ],
    ],
  );
}

/// UsageDataSettings.tsx SwitchRow: the description ends in a strong external
/// "Learn more" link; a failed save is the banner under the group (`mt-3`).
class RaftAdminSwitchCard extends StatelessWidget {
  const RaftAdminSwitchCard({
    super.key,
    required this.title,
    required this.description,
    required this.checked,
    this.onChanged,
    this.error,
    this.switchKey,
    this.descriptionLink,
    this.onDescriptionLink,
  });
  final String title, description;
  final bool checked;
  final ValueChanged<bool>? onChanged;
  final String? error;
  final Key? switchKey;
  final String? descriptionLink;
  final VoidCallback? onDescriptionLink;

  @override
  Widget build(BuildContext context) {
    final link = descriptionLink;
    return RaftAdminImmediateSwitchRow(
      title: title,
      description: description,
      checked: checked,
      onChanged: onChanged,
      switchKey: switchKey,
      descriptionSpan: link == null
          ? null
          : _DescriptionWithLink(
              description: description,
              link: link,
              onLink: onDescriptionLink,
            ),
      footer: [if (error case final error?) RaftErrorBanner(error, small: true)],
    );
  }
}

class _DescriptionWithLink extends StatelessWidget {
  const _DescriptionWithLink({
    required this.description,
    required this.link,
    required this.onLink,
  });
  final String description, link;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = t.scale(RaftTypeScale.footnote, color: t.muted);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: '${raftText(context, description)} '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: RaftTextLink(
              label: raftText(context, link),
              onPressed: onLink,
              variant: RaftTextLinkVariant.strong,
              external: true,
              externalLabel: raftText(context, '(opens in a new tab)'),
              typeStyle: style,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- onboarding

/// OnboardingAgentSection's group: the onboarding agent's Select and the
/// greeting's Switch each apply when changed (a failure shows under the
/// control), then "Server setup" when the server's projection asks for it.
class RaftAdminOnboardingRows extends StatelessWidget {
  const RaftAdminOnboardingRows({
    super.key,
    required this.agentId,
    required this.agents,
    required this.onAgent,
    required this.greeting,
    required this.onGreeting,
    this.agentDisabled = false,
    this.greetingDisabled = false,
    this.agentFailure,
    this.greetingFailure,
    this.showSetup = false,
    this.openingSetup = false,
    this.onFinishSetup,
  });

  /// '' = disabled; otherwise an agent id.
  final String agentId;

  /// `(id, '@name (displayName)')`.
  final List<(String, String)> agents;
  final ValueChanged<String> onAgent;
  final bool greeting;
  final ValueChanged<bool> onGreeting;

  /// Loading, or a save of that setting in flight.
  final bool agentDisabled, greetingDisabled;
  final String? agentFailure, greetingFailure;
  final bool showSetup, openingSetup;
  final VoidCallback? onFinishSetup;

  @override
  Widget build(BuildContext context) => RaftAdminRows(
    rows: [
      RaftAdminRowSpec(
        title: 'Human onboarding agent',
        body: [RaftAdminSaveLine(agentFailure)],
        wrapNarrow: true,
        control: RaftAdminRowSelect<String>(
          key: const ValueKey('admin-onboarding-agent'),
          label: 'Onboarding agent',
          placeholder: 'Onboarding agent',
          value: agentId,
          items: [
            RaftSelectItem(
              value: '',
              label: raftText(context, 'Disabled (no automatic onboarding)'),
              cssText: true,
            ),
            for (final (id, label) in agents)
              RaftSelectItem(value: id, label: label, cssText: true),
          ],
          onChanged: agentDisabled
              ? null
              : (value) {
                  if (value != null) onAgent(value);
                },
        ),
      ),
      RaftAdminRowSpec(
        key: const ValueKey('admin-onboarding-greeting-row'),
        title: 'New agents introduce themselves in #all',
        body: [RaftAdminSaveLine(greetingFailure)],
        control: RaftSwitch(
          key: const ValueKey('admin-onboarding-greeting'),
          value: greeting,
          enabled: !greetingDisabled,
          semanticLabel: raftText(
            context,
            'New agents introduce themselves in #all',
          ),
          onChanged: greetingDisabled ? null : onGreeting,
        ),
      ),
      if (showSetup)
        RaftAdminRowSpec(
          title: 'Server setup',
          wrapNarrow: true,
          control: RaftSettingsRecipeButton(
            key: const ValueKey('finish-server-setup'),
            label: openingSetup ? 'Opening…' : 'Finish setup',
            trailingGlyph: openingSetup ? null : RaftGlyph.chevronRight,
            glyphSize: 14,
            size: RaftButtonRecipeSize.md,
            onPressed: openingSetup ? null : onFinishSetup,
          ),
        ),
    ],
  );
}

// ------------------------------------------------------------ context grants

/// One agent allowed to read other agents' context.
class RaftContextGrant {
  const RaftContextGrant({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.onRevoke,
    this.avatarUrl,
  });
  final String id, name, subtitle;
  final String? avatarUrl;
  final VoidCallback onRevoke;
}

/// ContextViewGrantsSection's group: what the list is with Grant access at the
/// end of the row and the list's state under the text, then a row per grant.
class RaftContextGrantsCard extends StatelessWidget {
  const RaftContextGrantsCard({
    super.key,
    required this.grants,
    required this.loading,
    required this.failed,
    required this.onGrant,
    required this.onRetry,
    this.note,
  });

  /// Null until the list is read.
  final List<RaftContextGrant>? grants;
  final bool loading, failed;

  /// Null disables Grant access (the list is not read yet).
  final VoidCallback? onGrant;
  final VoidCallback onRetry;

  /// "{agent}'s access was already revoked."
  final String? note;

  @override
  Widget build(BuildContext context) {
    final list = grants;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow =
            constraints.maxWidth.isFinite &&
            constraints.maxWidth < _narrowWidth;
        final grant = RaftSettingsRecipeButton(
          key: const ValueKey('context-view-grant-open'),
          label: 'Grant access',
          variant: RaftButtonRecipeVariant.accent,
          size: RaftButtonRecipeSize.md,
          onPressed: onGrant,
        );
        final first = RaftListRow(
          variant: RaftListRowVariant.plain,
          interactive: false,
          children: [
            RaftListRowBody(
              children: [
                const RaftListRowDescription(
                  "An agent with access can search and read other agents' context on this server. Personal assistants' context is never included.",
                  wrap: true,
                ),
                if (list != null && list.isEmpty)
                  const KeyedSubtree(
                    key: ValueKey('context-view-grants-empty'),
                    child: RaftListRowDescription(
                      "No agent has access to other agents' context.",
                      wrap: true,
                    ),
                  ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(top: RaftSpace.x2),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: RaftSpinner(
                        key: ValueKey('context-view-grants-loading'),
                        size: 16,
                      ),
                    ),
                  ),
                if (note case final note?)
                  Padding(
                    padding: const EdgeInsets.only(top: RaftSpace.x2),
                    child: RaftBanner(
                      key: const ValueKey('context-view-grants-note'),
                      status: RaftBannerRecipeStatus.info,
                      size: RaftBannerRecipeSize.sm,
                      live: false,
                      description: note,
                    ),
                  ),
                if (failed)
                  Padding(
                    padding: const EdgeInsets.only(top: RaftSpace.x2),
                    child: RaftBanner(
                      key: const ValueKey('context-view-grants-failed'),
                      status: RaftBannerRecipeStatus.warning,
                      size: RaftBannerRecipeSize.sm,
                      description: raftText(
                        context,
                        "Couldn't load which agents have access.",
                      ),
                      action: RaftSettingsRecipeButton(
                        key: const ValueKey('context-view-grants-retry'),
                        label: 'Retry',
                        variant: RaftButtonRecipeVariant.default_,
                        size: RaftButtonRecipeSize.md,
                        onPressed: onRetry,
                      ),
                    ),
                  ),
                if (narrow)
                  Padding(
                    padding: const EdgeInsets.only(top: RaftSpace.x2),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: grant,
                    ),
                  ),
              ],
            ),
            if (!narrow) grant,
          ],
        );
        return RaftListRowGroup(
          children: [
            first,
            for (final g in list ?? const <RaftContextGrant>[])
              RaftAvatarListRow(
                key: ValueKey('context-view-grant-${g.id}'),
                avatar: RaftAvatarSlot(
                  name: g.name,
                  slot: RaftAvatarSlotContext.surfaceList,
                  agent: true,
                  avatarUrl: g.avatarUrl,
                ),
                name: g.name,
                subtitle: g.subtitle,
                rightContent: [
                  RaftSettingsRecipeButton(
                    key: ValueKey('context-view-revoke-${g.id}'),
                    label: 'Revoke',
                    size: RaftButtonRecipeSize.md,
                    onPressed: g.onRevoke,
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// GrantContextViewDialog's message: the agent field and the disclosure of
/// what the grant reaches.
class RaftGrantContextBody extends StatelessWidget {
  const RaftGrantContextBody({
    super.key,
    required this.options,
    required this.agentId,
    required this.onAgent,
    required this.disclosure,
  });

  /// `(id, label)` of the agents that can be granted.
  final List<(String, String)> options;
  final String agentId;
  final ValueChanged<String> onAgent;

  /// Already localised, naming the picked agent.
  final String disclosure;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          raftText(context, 'Agent'),
          style: t.scale(
            RaftTypeScale.footnote,
            color: t.strong,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: RaftSpace.x1),
        RaftSelectField<String>(
          key: const ValueKey('context-view-grant-agent'),
          label: raftText(context, 'Agent'),
          placeholder: raftText(
            context,
            options.isNotEmpty
                ? 'Choose an agent'
                : 'Every agent here already has access',
          ),
          value: agentId.isEmpty ? null : agentId,
          items: [
            for (final (id, label) in options)
              RaftSelectItem(value: id, label: label, cssText: true),
          ],
          onChanged: options.isEmpty
              ? null
              : (value) => onAgent(value ?? ''),
        ),
        const SizedBox(height: RaftSpace.x4),
        RaftBanner(
          key: const ValueKey('context-view-grant-disclosure'),
          status: RaftBannerRecipeStatus.warning,
          live: false,
          description: disclosure,
        ),
      ],
    );
  }
}

// -------------------------------------------------------------- removal impact

/// OwnComputersTransferNote: an info banner (`mt-3` unless [top] says
/// otherwise) saying the Computers the viewer attached stay online while they
/// are a member. Already localised.
class RaftOwnComputersTransferNote extends StatelessWidget {
  const RaftOwnComputersTransferNote(
    this.message, {
    super.key,
    this.top = RaftSpace.x3,
  });
  final String message;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top),
    child: RaftBanner(
      key: const ValueKey('owner-transfer-computers'),
      status: RaftBannerRecipeStatus.info,
      live: false,
      glyph: RaftGlyph.info,
      description: message,
    ),
  );
}
