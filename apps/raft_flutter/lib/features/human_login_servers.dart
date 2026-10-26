import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_setup.dart' show appSetupDomain;
import 'human_login.dart';

/// The server part of Web `HumanLoginSetupPage` (pinned v1.21.23): the
/// Raft Server field, the commit zone of a Marketplace app, the FAQ and the
/// "not accessible" card. The sheet that hosts them is
/// `human_login_sheet.dart`.

/// What the person has to do next on the selected server (Web's commit zone).
enum HumanLoginCommit {
  /// Installed: continue the login.
  ready,

  /// Not installed and the person may install it.
  install,

  /// Not installed and only an owner or admin may install it.
  adminNeeded,

  /// The lookup did not answer for this server.
  unavailable,
}

HumanLoginCommit humanLoginCommit(HumanLoginRow? row) {
  final client = row?.client;
  if (client == null) return HumanLoginCommit.unavailable;
  if (!client.installRequired) return HumanLoginCommit.ready;
  return client.canInstall
      ? HumanLoginCommit.install
      : HumanLoginCommit.adminNeeded;
}

TextStyle _body(
  RaftTokens t, {
  double size = 14,
  double line = 20,
  Color? color,
  FontWeight weight = FontWeight.w400,
}) => RaftTypography.inherited(
  t,
  size: size,
  line: line,
  color: color ?? t.muted,
  weight: weight,
);

/// `<b>…</b>` of a Web message: the same text, the tagged part in bold.
Text _boldText(
  BuildContext context,
  String source,
  Map<String, Object?> values, {
  Color? color,
}) {
  final t = RaftTokens.of(context);
  return Text.rich(
    TextSpan(
      children: raftRichText(context, source, {
        'b': (inner) => TextSpan(
          text: inner,
          style: _body(t, weight: FontWeight.w700, color: t.ink),
        ),
      }, values: values),
    ),
    style: _body(t, color: color ?? t.ink),
  );
}

/// The Raft Server field. A Marketplace app lists every server the account can
/// use, with a search over more than five and each server's state (Web
/// `MarketplaceServerRow`); any other app lists the servers that have it, as
/// one card for a single server and a choice for several.
class HumanLoginServerField extends StatefulWidget {
  const HumanLoginServerField({
    super.key,
    required this.lookup,
    required this.selectedId,
    required this.enabled,
    required this.onSelect,
    this.installingId = '',
  });
  final HumanLoginLookup lookup;
  final String selectedId;

  /// False while an install or the authorization is under way.
  final bool enabled;

  /// The server being installed on: its row shows a spinner.
  final String installingId;
  final ValueChanged<String> onSelect;

  @override
  State<HumanLoginServerField> createState() => _HumanLoginServerFieldState();
}

class _HumanLoginServerFieldState extends State<HumanLoginServerField> {
  final query = TextEditingController();
  final queryFocus = FocusNode();

  @override
  void dispose() {
    query.dispose();
    queryFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final marketplace = widget.lookup.isMarketplace;
    return Column(
      key: const ValueKey('human-login-servers'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x1_5,
      children: [
        RaftDialogSectionEyebrow('Raft Server'),
        if (marketplace) _marketplace(context) else _plain(context),
        Text(
          tr(
            marketplace
                ? 'All Raft Servers you can access are shown here. Continue with an installed Server, or install the App where you have permission.'
                : 'Choose where you want to use this app. Only available servers are shown here.',
          ),
          style: _body(
            t,
            size: 12,
            line: 16,
            color: t.colors['foreground-hint'],
          ),
        ),
      ],
    );
  }

  /// Servers that have the app: Web's Select, drawn as the app's choice cards.
  Widget _plain(BuildContext context) {
    final t = RaftTokens.of(context);
    final choices = widget.lookup.choices;
    final several = choices.length > 1;
    Widget label(String text) => Text(
      text,
      style: _body(t, weight: FontWeight.w600, color: t.ink),
    );
    return RaftRadioGroup<String>(
      value: widget.selectedId,
      onChanged: widget.enabled && several ? widget.onSelect : null,
      spacing: RaftSpace.x1_5,
      children: [
        for (final choice in choices)
          RaftCard(
            variant: RaftCardRecipeVariant.option,
            key: ValueKey('human-login-server-${choice.server.id}'),
            onTap: widget.enabled && several
                ? () => widget.onSelect(choice.server.id)
                : null,
            padding: const EdgeInsets.all(RaftSpace.x3),
            child: several
                ? RaftRadioGroupItem<String>(
                    value: choice.server.id,
                    gap: RaftSpace.x2,
                    child: label(choice.server.label),
                  )
                : label(choice.server.label),
          ),
      ],
    );
  }

  Widget _marketplace(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final rows = widget.lookup.rows;
    final needle = query.text.trim().toLowerCase();
    final shown = [
      for (final row in rows)
        if (needle.isEmpty ||
            row.server.name.toLowerCase().contains(needle) ||
            row.server.slug.toLowerCase().contains(needle))
          row,
    ];
    List<Widget> rowWidgets() => [
      for (final row in shown)
        _ServerRow(
          row: row,
          selected: row.server.id == widget.selectedId,
          enabled: widget.enabled,
          installing: row.server.id == widget.installingId,
          onTap: () => widget.onSelect(row.server.id),
        ),
      if (shown.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: RaftSpace.x3,
            vertical: RaftSpace.x6,
          ),
          child: Text(
            tr('No Servers match your search.'),
            key: const ValueKey('human-login-no-server-match'),
            textAlign: TextAlign.center,
            style: _body(t, color: t.colors['foreground-hint']),
          ),
        ),
    ];
    return RaftCard(
      key: const ValueKey('human-login-marketplace-servers'),
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rows.length > 5)
            Padding(
              padding: const EdgeInsets.all(RaftSpace.x2),
              child: IgnorePointer(
                ignoring: !widget.enabled,
                child: RaftSearchInput(
                  key: const ValueKey('human-login-server-search'),
                  controller: query,
                  focusNode: queryFocus,
                  hint: tr('Search Servers'),
                  clearLabel: tr('Clear Search'),
                  onClear: () => setState(query.clear),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
          // Web `max-h-72`: a long list scrolls inside the card. A short one
          // is plain rows, so a drag over it scrolls the sheet.
          if (shown.length > 4)
            ConstrainedBox(
              // ds-allow: Web `max-h-72` on the server list card
              constraints: const BoxConstraints(maxHeight: 288),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: rowWidgets(),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rowWidgets(),
            ),
        ],
      ),
    );
  }
}

/// Web `MarketplaceServerRow`.
class _ServerRow extends StatelessWidget {
  const _ServerRow({
    required this.row,
    required this.selected,
    required this.enabled,
    required this.installing,
    required this.onTap,
  });
  final HumanLoginRow row;
  final bool selected, enabled, installing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final state = humanLoginCommit(row);
    final badge = switch (state) {
      HumanLoginCommit.ready => 'Installed',
      HumanLoginCommit.install => 'Not installed',
      HumanLoginCommit.adminNeeded => 'Admin needed',
      HumanLoginCommit.unavailable => 'Unavailable',
    };
    return RaftAvatarListRow(
      key: ValueKey('human-login-server-${row.server.id}'),
      avatar: RaftAvatarSlot(
        name: row.server.name,
        slot: RaftAvatarSlotContext.surfaceList,
        agent: false,
        server: true,
        content: RaftAvatarContent(
          name: row.server.name,
          kind: RaftAvatarContentKind.server,
          uploadedUrl: row.server.avatarUrl,
          // Web AvatarSlot `type="server"`: the initial in the server ink.
          fallback: Center(
            child: Text(
              row.server.name.trim().isEmpty
                  ? 'S'
                  : row.server.name.trim().characters.first.toUpperCase(),
              style: RaftTypography.body(
                t,
                size: 14,
                line: 16,
                weight: FontWeight.w700,
                color: t.colors['foreground-avatar-server'] ?? t.strong,
              ),
            ),
          ),
        ),
      ),
      name: row.server.name,
      subtitle: row.server.slug,
      rightContent: [
        if (installing)
          const RaftSpinner(
            key: ValueKey('human-login-install-row-spinner'),
            size: 16,
          )
        else
          RaftSettingsRecipeBadge(
            key: ValueKey('human-login-server-state-${row.server.id}'),
            label: tr(badge),
            variant: state == HumanLoginCommit.ready
                ? RaftBadgeRecipeVariant.success
                : RaftBadgeRecipeVariant.muted,
            appearance: RaftBadgeRecipeAppearance.soft,
          ),
      ],
      selected: selected,
      onTap: enabled ? onTap : null,
    );
  }
}

/// Web's commit zone: what happens on the selected server, and the install it
/// asks for. Nothing here acts; the buttons are the sheet's.
class HumanLoginCommitZone extends StatelessWidget {
  const HumanLoginCommitZone({
    super.key,
    required this.row,
    required this.scopes,
    required this.busy,
  });
  final HumanLoginRow? row;
  final List<String> scopes;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final server = row?.server;
    final client = row?.client;
    final appName = client?.name ?? '';
    final state = humanLoginCommit(row);
    final setupDomain = state == HumanLoginCommit.install
        ? appSetupDomain(client?.setupUrl)
        : null;
    return RaftCard(
      key: const ValueKey('human-login-commit-zone'),
      background: t.colors['fill-muted'],
      padding: const EdgeInsets.all(RaftSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: RaftSpace.x2,
        children: [
          switch (state) {
            HumanLoginCommit.ready => _boldText(
              context,
              'Selected <b>{serverName}</b>.',
              {'serverName': server!.name},
            ),
            HumanLoginCommit.install => _boldText(
              context,
              '<b>{serverName}</b> has not installed {appName}. You are an admin of this Server. Continuing will install the App as you.',
              {'serverName': server!.name, 'appName': appName},
            ),
            HumanLoginCommit.adminNeeded => _boldText(
              context,
              '<b>{serverName}</b> has not installed {appName}. Only an owner or admin of this Server can install it.',
              {'serverName': server!.name, 'appName': appName},
            ),
            HumanLoginCommit.unavailable => Text(
              tr(
                'Installation status could not be loaded. Reload this page to try again.',
              ),
              style: _body(t, color: t.ink),
            ),
          },
          if (state == HumanLoginCommit.install)
            Text(
              raftFormat(context, 'Access granted: {scopes}', {
                'scopes': scopes.join(' · '),
              }),
              key: const ValueKey('human-login-install-scopes'),
              style: RaftTypography.mono(t, size: 12, line: 16, color: t.muted),
            ),
          if (setupDomain != null)
            RaftAppSetupRequirement(
              domain: setupDomain,
              description: client?.setupDescription,
            ),
        ],
      ),
    );
  }
}

/// Web's FAQ aside: three questions. A sheet has no side column, so it is a
/// row at the bottom that opens in place.
class HumanLoginFaq extends StatefulWidget {
  const HumanLoginFaq({super.key});

  @override
  State<HumanLoginFaq> createState() => _HumanLoginFaqState();
}

class _HumanLoginFaqState extends State<HumanLoginFaq> {
  bool open = false;

  static const _items = [
    (
      'What is Login with Raft?',
      'Login with Raft lets humans and agents use apps with their Raft accounts. Humans use this page with their human Raft account. Agents can request app access through Raft with their agent Raft account when they need to work with the app.',
    ),
    (
      'How to register an App?',
      'Server owners and admins can register apps in Settings > Applications.',
    ),
    (
      'How can my agent use this app?',
      'Agents should not use this browser page or complete human OAuth. Ask the agent to use Raft Agent Login for the registered service. If the service is not available to the agent yet, ask a server owner or admin to register or connect the app first.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x2,
      children: [
        RaftCard(
          variant: RaftCardRecipeVariant.option,
          key: const ValueKey('human-login-faq'),
          onTap: () => setState(() => open = !open),
          semanticLabel: tr('FAQ'),
          padding: const EdgeInsets.all(RaftSpace.x3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  tr('FAQ'),
                  style: RaftTypography.heading(t, size: 14, line: 20),
                ),
              ),
              RaftIcon(
                open ? RaftGlyph.chevronUp : RaftGlyph.chevronDown,
                size: 16,
              ),
            ],
          ),
        ),
        if (open)
          Column(
            key: const ValueKey('human-login-faq-body'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: RaftSpace.x3,
            children: [
              for (final (question, answer) in _items)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: RaftSpace.x1,
                  children: [
                    Text(
                      tr(question),
                      style: _body(t, weight: FontWeight.w700, color: t.ink),
                    ),
                    Text(tr(answer), style: _body(t)),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}

/// Web's page for an app no server of the account has: the explanation and
/// how to get access (it replaces the form).
class HumanLoginNotAccessible extends StatelessWidget {
  const HumanLoginNotAccessible({super.key});

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    return Column(
      key: const ValueKey('human-login-not-accessible'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x3,
      children: [
        Text(
          tr('This App is not accessible yet'),
          style: RaftTypography.heading(t, size: 16, line: 22),
        ),
        Text(
          tr(
            'This private third-party App is not available on any Raft Server you can access.',
          ),
          style: _body(t),
        ),
        RaftCard(
          background: t.colors['info-soft'],
          padding: const EdgeInsets.all(RaftSpace.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: RaftSpace.x1,
            children: [
              Text(
                tr('How can I get access?'),
                style: _body(t, weight: FontWeight.w700, color: t.ink),
              ),
              Text(
                tr(
                  'Ask the third party that provides this App to add you to a Raft Server where the App is integrated, or ask them to publish the App to the Raft Marketplace.',
                ),
                style: _body(t, color: t.ink),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
