// #proj-raft-computer:#68 readiness and "needs attention" in words (Web v1.24
// utils/readinessCopy.ts). The server sends codes and params only, already
// trimmed for this viewer; a readiness with no `primary` (a viewer who may not
// see the reason) or a code this build does not know reads the generic
// sentence. ICU plurals and selects are separate English keys here (raftText
// does not interpret ICU).
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'computers_rack/computers_rack_model.dart' show rackRuntimeDisplayName;

/// shared readiness.ts READINESS_CODES.
const readinessCodes = {
  'verification_required',
  'computer_offline',
  'computer_reconnecting',
  'computer_restarting',
  'computer_updating',
  'computer_too_old',
  'runtime_missing',
};

/// Waits that end when a usage limit resets.
const readinessLimitWaitCodes = {'quota_exhausted', 'rate_limited'};

/// shared ANTHROPIC_VERIFICATION_PORTAL_URL.
const anthropicVerificationPortalUrl = 'https://portal.anthropic.com/verify';

const _actions = {'sign_in', 'verify_account', 'update_computer', 'fix'};
String _knownAction(Object? action) =>
    action is String && _actions.contains(action) ? action : 'fix';

/// rackResetText.ts rackReset: whole minutes (at least 1) under an hour,
/// hours under two days, else days (rounded down); null when unknown or past.
({String unit, int count})? rackReset(int? untilMs, int nowMs) {
  if (untilMs == null) return null;
  final left = untilMs - nowMs;
  if (left <= 0) return null;
  const minute = 60000, hour = 60 * minute, day = 24 * hour;
  if (left < hour) {
    final count = left ~/ minute;
    return (unit: 'm', count: count < 1 ? 1 : count);
  }
  if (left < 48 * hour) return (unit: 'h', count: left ~/ hour);
  return (unit: 'd', count: left ~/ day);
}

class ReadinessCopy {
  const ReadinessCopy({
    required this.title,
    required this.detail,
    this.scope,
    this.actor,
    this.link,
  });
  final String title, detail;
  final String? scope, actor;
  final ({String href, String text})? link;
}

String _runtimeOf(Map readiness, String? fallbackRuntimeId) {
  final primary = readiness['primary'];
  final resource = primary is Map ? primary['resource'] : null;
  if (resource is Map) {
    if (resource['kind'] == 'runtime' && resource['runtime'] is String) {
      return rackRuntimeDisplayName(resource['runtime'] as String);
    }
    final key = resource['key'];
    if ((resource['kind'] == 'login' || resource['kind'] == 'login_window') &&
        key is String &&
        key.startsWith('shared:')) {
      return rackRuntimeDisplayName(key.substring('shared:'.length));
    }
  }
  return fallbackRuntimeId == null
      ? ''
      : rackRuntimeDisplayName(fallbackRuntimeId);
}

/// readinessWho: "Olive can sign in" / "… can update this computer".
String readinessWho(BuildContext context, String name, Object? action) =>
    raftFormat(
      context,
      switch (_knownAction(action)) {
        'sign_in' => '{name} can sign in',
        'verify_account' => '{name} can verify the account',
        'update_computer' => '{name} can update this computer',
        _ => '{name} can fix it',
      },
      {'name': name},
    );

/// readinessWhoOf: by name when the server sent one, else by role; null with
/// neither.
String? readinessWhoOf(BuildContext context, Map of) {
  final name = of['actorName'];
  if (name is String && name.isNotEmpty) {
    return readinessWho(context, name, of['action']);
  }
  final actor = of['actor'];
  if (actor is! String) return null;
  final action = _knownAction(of['action']);
  // readiness.ownerCan.<action>, one key per actor (ICU select).
  return raftText(context, switch ((actor, action)) {
    ('computer_owner', 'sign_in') => "The computer's owner can sign in",
    ('computer_owner', 'verify_account') =>
      "The computer's owner can verify the account",
    ('computer_owner', 'update_computer') =>
      "The computer's owner can update this computer",
    ('computer_owner', _) => "The computer's owner can fix it",
    ('agent_owner', 'sign_in') => "The agent's owner can sign in",
    ('agent_owner', 'verify_account') =>
      "The agent's owner can verify the account",
    ('agent_owner', 'update_computer') =>
      "The agent's owner can update this computer",
    ('agent_owner', _) => "The agent's owner can fix it",
    (_, 'sign_in') => 'A server admin can sign in',
    (_, 'verify_account') => 'A server admin can verify the account',
    (_, 'update_computer') => 'A server admin can update this computer',
    _ => 'A server admin can fix it',
  });
}

/// readinessDoLabel: "Sign in", "Verify account", "Update", "Open".
String readinessDoLabel(BuildContext context, Object? action) =>
    raftText(context, switch (_knownAction(action)) {
      'sign_in' => 'Sign in',
      'verify_account' => 'Verify account',
      'update_computer' => 'Update',
      _ => 'Open',
    });

/// formatReadiness.
ReadinessCopy formatReadiness(
  BuildContext context,
  Map readiness, {
  String? runtimeId,
  bool onAgent = false,
  int? nowMs,
}) {
  String tr(String s) => raftText(context, s);
  final primary = readiness['primary'] is Map
      ? readiness['primary'] as Map
      : null;
  final who = readiness['state'] == 'blocked'
      ? readinessWhoOf(context, readiness)
      : null;
  final named = who == null
      ? null
      : raftFormat(context, '{text}.', {'text': who});
  final code = primary?['code'];
  if (code is String && readinessLimitWaitCodes.contains(code)) {
    final until = primary?['until'];
    final reset = rackReset(
      until is num ? until.toInt() : null,
      nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    return ReadinessCopy(
      title: reset == null
          ? tr("Can't reply right now")
          : raftFormat(
              context,
              switch (reset.unit) {
                'm' => 'Back in {count}m',
                'h' => 'Back in {count}h',
                _ => 'Back in {count}d',
              },
              {'count': reset.count},
            ),
      detail: tr(
        "This agent can't reply right now. Its messages are kept and will be delivered.",
      ),
    );
  }
  if (code is! String || !readinessCodes.contains(code)) {
    return ReadinessCopy(
      title: tr("Can't reply right now"),
      detail: tr(
        "This agent can't reply right now. Its messages are kept and will be delivered.",
      ),
      actor: named,
    );
  }
  final runtime = _runtimeOf(readiness, runtimeId);
  final scope = switch (readiness['scope']) {
    'computer' => tr("This Computer's problem"),
    'agent' => tr("This agent's problem"),
    'server' => tr("This server's problem"),
    _ => null,
  };
  final actor = switch (readiness['actor']) {
    'computer_owner' => tr("The computer's owner can fix it."),
    'agent_owner' => tr("The agent's owner can fix it."),
    'server_admin' => tr('A server admin can fix it.'),
    _ => null,
  };
  ReadinessCopy copy(String title, String detail, {bool withActor = true}) =>
      ReadinessCopy(
        title: title,
        detail: detail,
        scope: scope,
        actor: withActor ? actor : null,
      );
  switch (code) {
    case 'verification_required':
      return ReadinessCopy(
        title: tr('Account needs verification'),
        scope: scope,
        detail: raftFormat(
          context,
          "The {runtime} account signed in here can't receive replies until it is verified. The account holder must finish the step in the Anthropic Verification Portal, then choose Retry. Messages are kept and will be delivered.",
          {'runtime': runtime},
        ),
        actor: actor,
        link: (
          href: anthropicVerificationPortalUrl,
          text: tr('Open the Anthropic verification portal'),
        ),
      );
    case 'computer_offline':
      return copy(
        tr('Computer offline'),
        tr(
          'This Computer is offline. Messages are kept and will be delivered when it reconnects.',
        ),
      );
    case 'computer_reconnecting':
      return copy(
        tr('Reconnecting'),
        tr(
          'This Computer just disconnected and is likely to be back in a moment. Messages are kept and will be delivered.',
        ),
        withActor: false,
      );
    case 'computer_restarting':
      return copy(
        tr(onAgent ? 'Computer restarting' : 'Restarting…'),
        tr(
          'This Computer was stopped or restarted on purpose. Messages are kept and will be delivered when it is back.',
        ),
        withActor: false,
      );
    case 'computer_updating':
      return copy(
        tr(onAgent ? 'Computer updating' : 'Updating…'),
        tr(
          'This Computer is installing an update and will be back in a few minutes. Messages are kept and will be delivered when it is back.',
        ),
        withActor: false,
      );
    case 'computer_too_old':
      final params = primary?['params'];
      final desktop = params is Map && params['managedByDesktop'] == true;
      return copy(
        tr('Computer too old'),
        tr(
          desktop
              ? "This Computer's Raft version is too old to run agents. Update Raft Desktop on it. Messages are kept and will be delivered."
              : "This Computer's Raft version is too old to run agents. Upgrade or reinstall Raft Computer on it. Messages are kept and will be delivered.",
        ),
      );
    default: // runtime_missing
      return copy(
        raftFormat(context, '{runtime} not installed', {'runtime': runtime}),
        raftFormat(
          context,
          "{runtime} isn't installed on this Computer. Install it there, or move the agent to a Computer that has it. Messages are kept and will be delivered.",
          {'runtime': runtime},
        ),
      );
  }
}

/// readinessHeading: "This Computer's problem: Needs account verification".
String readinessHeading(BuildContext context, ReadinessCopy copy) =>
    copy.scope == null
    ? copy.title
    : raftFormat(context, '{scope}: {text}', {
        'scope': copy.scope,
        'text': copy.title,
      });

/// readinessBody: what happened, then who fixes it.
String readinessBody(BuildContext context, ReadinessCopy copy) =>
    copy.actor == null
    ? copy.detail
    : raftFormat(context, '{detail} {actor}', {
        'detail': copy.detail,
        'actor': copy.actor,
      });

/// formatAttentionItem: one "needs attention" item's title ("Update
/// available", "Claude Code: Account needs verification", "Needs attention"
/// for a trimmed viewer or an unknown code) and who acts.
({String title, String? who}) formatAttentionItem(
  BuildContext context,
  Map item,
) {
  final who = readinessWhoOf(context, item);
  final code = item['code'];
  if (code == 'computer_update_available') {
    return (title: raftText(context, 'Update available'), who: who);
  }
  if (code == 'computer_update_required') {
    return (title: raftText(context, 'Update required'), who: who);
  }
  final resource = item['resource'];
  if (code is! String || resource is! Map || !readinessCodes.contains(code)) {
    return (title: raftText(context, 'Needs attention'), who: who);
  }
  final readiness = {
    'state': 'blocked',
    'primary': {'resource': resource, 'code': code, 'behaviour': 'blocked'},
    'scope': null,
    'actor': item['actor'],
  };
  final title = formatReadiness(context, readiness).title;
  final key = resource['key'];
  final onLogin =
      (resource['kind'] == 'login' || resource['kind'] == 'login_window') &&
      key is String &&
      key.startsWith('shared:');
  return (
    title: onLogin
        ? raftFormat(context, '{runtime}: {title}', {
            'runtime': _runtimeOf(readiness, null),
            'title': title,
          })
        : title,
    who: who,
  );
}

/// attentionItemLines: `<title> · <who>` per item of a Computer's summary.
List<String> attentionItemLines(BuildContext context, Object? attention) {
  final items = attention is Map && attention['items'] is List
      ? attention['items'] as List
      : const [];
  return [
    for (final item in items.whereType<Map>())
      () {
        final (:title, :who) = formatAttentionItem(context, item);
        return who == null
            ? title
            : raftFormat(context, '{title} · {who}', {
                'title': title,
                'who': who,
              });
      }(),
  ];
}

/// formatWaitBackIn: "back in 6d" for the earliest end of a wait.
String? formatWaitBackIn(BuildContext context, int? untilMs, int nowMs) {
  final reset = rackReset(untilMs, nowMs);
  return reset == null
      ? null
      : raftFormat(
          context,
          switch (reset.unit) {
            'm' => 'back in {count}m',
            'h' => 'back in {count}h',
            _ => 'back in {count}d',
          },
          {'count': reset.count},
        );
}

/// "{count} computer(s)" in the rack's machine type, ICU one/other.
String rackComputerCount(BuildContext context, int count) => raftFormat(
  context,
  count == 1 ? '{count} computer' : '{count} computers',
  {'count': count},
);

String rackAgentCount(BuildContext context, int count) => raftFormat(
  context,
  count == 1 ? '{count} agent' : '{count} agents',
  {'count': count},
);
