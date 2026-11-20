import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/app_install_expectation.dart';
import 'app_notifications_catalog.dart';
import 'integrations_views.dart' show integrationScopeCopy;

const _groupSummary = {
  'server': 'Server information',
  'agent': 'Directory, profiles, and status',
  'channel': 'Public channel information',
  'computer': 'Status and version',
  'agent_reminder_write': 'Write due reminders (official apps only)',
};

class ConnectedAppPermissionSet extends StatelessWidget {
  const ConnectedAppPermissionSet({
    super.key,
    required this.permissions,
    this.newScopes = const [],
    this.newGroups = const [],
  });

  final AppInstallExpectation permissions;
  final List<String> newScopes, newGroups;

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    String tr(String text) => raftText(context, text);
    Widget lines(
      List<String> values,
      List<String> additions,
      String Function(String) name,
      String Function(String) description,
    ) => values.isEmpty
        ? Text(tr('None'))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: RaftSpace.x2,
            children: [
              for (final value in values.toSet())
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: RaftSpace.x1_5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          tr(name(value)),
                          style: tokens.scale(
                            RaftTypeScale.callout,
                            weight: FontWeight.w600,
                          ),
                        ),
                        if (additions.contains(value))
                          Text(
                            tr('New in this update'),
                            style: tokens.scale(RaftTypeScale.footnote),
                          ),
                      ],
                    ),
                    Text(
                      tr(description(value)),
                      style: tokens.scale(RaftTypeScale.footnote),
                    ),
                  ],
                ),
            ],
          );
    return RaftDescriptionList(
      entries: [
        RaftDescriptionEntry(
          tr('Login scopes'),
          '',
          detailsChild: lines(
            permissions.scopes,
            newScopes,
            (scope) => scope,
            (scope) =>
                integrationScopeCopy[scope] ??
                (scope == 'agent:action_request:write'
                    ? "Lets the app ask the one agent you authorize to take an action. Reserved: Raft doesn't use it yet."
                    : 'Raft has no description for this scope.'),
          ),
        ),
        RaftDescriptionEntry(
          tr('Data access'),
          '',
          detailsChild: lines(
            permissions.groups,
            newGroups,
            (group) => appNotificationGroupLabels[group] ?? group,
            (group) =>
                _groupSummary[group] ??
                'Raft has no description for this data group.',
          ),
        ),
      ],
    );
  }
}

class ConnectedAppPromptText {
  const ConnectedAppPromptText({
    required this.name,
    this.description,
    this.whenToUse,
    this.service,
  });

  final String name;
  final String? description, whenToUse, service;

  static ConnectedAppPromptText? read(Object? raw, {String? service}) {
    if (raw case {'name': final String name}) {
      final fields = raw as Map;
      return ConnectedAppPromptText(
        name: name,
        description: fields['description'] is String
            ? fields['description']
            : null,
        whenToUse: fields['when_to_use'] is String
            ? fields['when_to_use']
            : null,
        service: service,
      );
    }
    return null;
  }

  static final _controls = RegExp(r'\p{Cc}', unicode: true);
  static final _formatting = RegExp(r'\p{Cf}', unicode: true);
  static final _spaces = RegExp(r'\s+', unicode: true);
  static final _slug = RegExp(r'^[a-z][a-z0-9-]{2,63}$');

  static String _line(String? value) {
    final line = (value ?? '')
        .replaceAll(_formatting, '')
        .replaceAll(_controls, ' ')
        .replaceAll(_spaces, ' ')
        .trim();
    return line.runes.length <= 160
        ? line
        : '${String.fromCharCodes(line.runes.take(160))}[truncated]';
  }

  String? get lines {
    final label = _line(name);
    final guidance = _line(whenToUse);
    if (label.isEmpty || guidance.isEmpty) return null;
    final summary = _line(description);
    final id = service;
    final reference = id != null && _slug.hasMatch(id)
        ? ' (service `$id`)'
        : '';
    return '- $label$reference${summary.isEmpty ? '' : ' — $summary'}\n'
        '  Use it when: $guidance';
  }
}

class ConnectedAppPromptComparison extends StatelessWidget {
  const ConnectedAppPromptComparison({
    super.key,
    required this.before,
    required this.after,
    required this.beforeTitle,
    required this.afterTitle,
  });

  final ConnectedAppPromptText? before, after;
  final String beforeTitle, afterTitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: RaftSpace.x3,
    children: [
      if (before case final text?)
        ConnectedAppPromptTextBlock(title: beforeTitle, text: text)
      else
        Text(
          raftText(
            context,
            "No confirmed text yet, so agent prompts don't list this app.",
          ),
        ),
      if (after case final text?)
        ConnectedAppPromptTextBlock(title: afterTitle, text: text),
    ],
  );
}

class ConnectedAppPromptTextBlock extends StatelessWidget {
  const ConnectedAppPromptTextBlock({
    super.key,
    required this.text,
    this.title,
  });

  final ConnectedAppPromptText text;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    final lines = text.lines;
    final code = RaftCodeRecipe(tokens);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x2,
      children: [
        if (title != null)
          Text(
            raftText(context, title!),
            style: tokens.scale(
              RaftTypeScale.footnote,
              weight: FontWeight.w600,
            ),
          ),
        if (lines == null)
          Text(
            raftText(
              context,
              'Not added to agent prompts: this app has no When to use.',
            ),
          )
        else
          DecoratedBox(
            decoration: BoxDecoration(
              color: code.background,
              border: Border.all(color: code.border),
              borderRadius: code.radius,
            ),
            child: Padding(
              padding: const EdgeInsets.all(RaftSpace.x3),
              child: Text(lines, style: code.textStyle),
            ),
          ),
      ],
    );
  }
}

class ConnectedAppInstallPromptText extends StatelessWidget {
  const ConnectedAppInstallPromptText({super.key, required this.text});

  final ConnectedAppPromptText text;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: RaftSpace.x2,
    children: [
      Text(raftText(context, 'Text added to agent prompts')),
      Text(
        raftText(
          context,
          'Raft adds this to the system prompt of every agent on this Server. Agents get it the next time they start.',
        ),
        style: RaftTokens.of(context).scale(RaftTypeScale.footnote),
      ),
      ConnectedAppPromptTextBlock(text: text),
    ],
  );
}

class ConnectedAppInstallBotOption extends StatelessWidget {
  const ConnectedAppInstallBotOption({
    super.key,
    required this.app,
    required this.handle,
    required this.server,
    required this.checked,
    required this.onChanged,
  });

  final String app, handle, server;
  final bool checked;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => RaftCheckboxRow(
    key: const ValueKey('connected-app-bot-install-checkbox'),
    title: raftFormat(context, 'Also add @{handle} to {server}', {
      'handle': handle,
      'server': server,
    }),
    description: raftFormat(
      context,
      'It can DM members as {app}, and post in channels once it’s invited',
      {'app': app},
    ),
    value: checked,
    onChanged: onChanged,
  );
}
