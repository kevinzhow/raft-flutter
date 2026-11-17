// A person deleting their own account (server v1.24.0 routes/
// accountDeletion.ts; Web features/settings/account/accountDeletionApi.ts,
// store/accountDeletionPending.ts).
//
// While a deletion is scheduled every API but GET/DELETE
// /me/account/deletion and POST /auth/logout answers 403
// `account_deletion_pending` with `scheduledFor` (middleware/auth.ts). The
// client notes the first such answer in [AccountDeletionGate]; the app then
// shows the pending page in place of the whole shell, so nothing in the shell
// keeps asking. A successful request (POST) signs out every sign-in, so the
// app also shows the confirmation in place of the shell until OK signs out.

import 'client.dart';
import 'second_factor.dart';
import 'second_factor_settings.dart' show StepUpAnswer;

/// The refusal code of every route a scheduled deletion keeps closed.
const accountDeletionPendingCode = 'account_deletion_pending';

/// The event the client emits whenever [AccountDeletionGate] changes.
const accountDeletionEventName = 'auth:account-deletion';

/// Web `useAccountDeletionPendingStore`: what the app knows about the
/// person's deletion, kept per client (a sign-out starts a new one).
class AccountDeletionGate {
  final _listeners = <void Function()>{};

  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);

  /// Calls the listeners of a copy, so one may remove itself.
  void notifyListeners() {
    for (final listener in _listeners.toList()) {
      if (_listeners.contains(listener)) listener();
    }
  }

  bool _pending = false;
  String? _scheduledFor;
  ({String? scheduledFor})? _requested;

  /// A request was refused with 403 `account_deletion_pending`, or a sign-in
  /// said the deletion is scheduled.
  bool get pending => _pending;

  /// ISO time the account is deleted, from the 403; null when it didn't say.
  String? get scheduledFor => _scheduledFor;

  /// This client just requested the deletion: every sign-in, this one too, is
  /// gone, and the confirmation stands in for the shell until OK signs out.
  bool get requested => _requested != null;
  String? get requestedScheduledFor => _requested?.scheduledFor;

  /// The shell is replaced by one of the two pages.
  bool get active => _pending || _requested != null;

  static String? _time(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  /// From the client's error path: any request's answer. True when it was a
  /// refusal this gate had not seen yet.
  bool noteRefusal(int? status, Object? body) {
    if (status != 403 || body is! Map) return false;
    if (body['code'] != accountDeletionPendingCode) return false;
    return notePending(body['scheduledFor']);
  }

  /// A sign-in that read the deletion (`accountDeletion.status ==
  /// "scheduled"`) before anything else asked.
  bool noteSignIn(Object? accountDeletion) {
    if (accountDeletion is! Map || accountDeletion['status'] != 'scheduled') {
      return false;
    }
    return notePending(accountDeletion['scheduledFor']);
  }

  bool notePending(Object? scheduledFor) {
    final next = _time(scheduledFor) ?? _scheduledFor;
    if (_pending && _scheduledFor == next) return false;
    _pending = true;
    _scheduledFor = next;
    notifyListeners();
    return true;
  }

  /// Web `markAccountDeletionRequested`: the request went through.
  void markRequested(String? scheduledFor) {
    _requested = (scheduledFor: _time(scheduledFor));
    notifyListeners();
  }

  /// Signed out, or the deletion was cancelled.
  void clear() {
    if (!active && _scheduledFor == null) return;
    _pending = false;
    _scheduledFor = null;
    _requested = null;
    notifyListeners();
  }
}

// ── Wire shapes (accountDeletionApi.ts) ──────────────────────────────────

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

Map<String, dynamic>? _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

String? _time(Object? value) =>
    value is String && value.isNotEmpty && DateTime.tryParse(value) != null
    ? value
    : null;

/// A server named by the checklist.
class AccountDeletionServer {
  const AccountDeletionServer({
    required this.id,
    required this.name,
    required this.slug,
  });
  final String id, name, slug;

  /// Null without a string `id` and `slug`.
  static AccountDeletionServer? parse(Object? value) {
    final m = _map(value);
    if (m == null || m['id'] is! String || m['slug'] is! String) return null;
    return AccountDeletionServer(
      id: m['id'] as String,
      slug: m['slug'] as String,
      name: m['name'] is String ? m['name'] as String : m['slug'] as String,
    );
  }
}

/// A server the person is the only owner of, with other members (409
/// `sole_owner_servers`).
class SoleOwnerServer extends AccountDeletionServer {
  const SoleOwnerServer({
    required super.id,
    required super.name,
    required super.slug,
    required this.memberCount,
  });
  final int memberCount;

  static SoleOwnerServer? parse(Object? value) {
    final base = AccountDeletionServer.parse(value);
    if (base == null) return null;
    final count = (value as Map)['memberCount'];
    return SoleOwnerServer(
      id: base.id,
      name: base.name,
      slug: base.slug,
      memberCount: count is num ? count.toInt() : 0,
    );
  }
}

/// A shared server whose subscription the person pays for: it ends with its
/// current period (null when the server has none on record).
class PaidServerEnding extends AccountDeletionServer {
  const PaidServerEnding({
    required super.id,
    required super.name,
    required super.slug,
    required this.periodEnd,
  });
  final String? periodEnd;

  static PaidServerEnding? parse(Object? value) {
    final base = AccountDeletionServer.parse(value);
    if (base == null) return null;
    return PaidServerEnding(
      id: base.id,
      name: base.name,
      slug: base.slug,
      periodEnd: _string((value as Map)['periodEnd']),
    );
  }
}

/// What happens to one of the person's agents.
enum AgentOutcome {
  transferToOwner('transfer_to_owner'),
  archivePersonalAssistant('archive_personal_assistant'),
  closesWithServer('closes_with_server');

  const AgentOutcome(this.wire);
  final String wire;

  static AgentOutcome? parse(Object? value) {
    for (final outcome in values) {
      if (outcome.wire == value) return outcome;
    }
    return null;
  }
}

class AccountDeletionAgent {
  const AccountDeletionAgent({
    required this.id,
    required this.name,
    required this.server,
    required this.outcome,
    required this.toUser,
  });
  final String id, name;
  final AccountDeletionServer server;
  final AgentOutcome outcome;

  /// Who a `transfer_to_owner` agent goes to; null while the person is still
  /// that server's only owner.
  final ({String id, String name})? toUser;

  static AccountDeletionAgent? parse(Object? value) {
    final m = _map(value);
    final outcome = AgentOutcome.parse(m?['outcome']);
    final server = AccountDeletionServer.parse(m?['server']);
    if (m == null || m['id'] is! String || outcome == null || server == null) {
      return null;
    }
    final to = _map(m['toUser']);
    return AccountDeletionAgent(
      id: m['id'] as String,
      name: m['name'] is String ? m['name'] as String : m['id'] as String,
      server: server,
      outcome: outcome,
      toUser: to != null && to['id'] is String && to['name'] is String
          ? (id: to['id'] as String, name: to['name'] as String)
          : null,
    );
  }
}

/// Another member's agent on one of the person's computers: it holds the
/// deletion up until its owner moves it. The same fields in GET's
/// `computers[].agents[]` (with the computer around them) and in the 409's
/// `agents`.
class AccountDeletionOthersAgent {
  const AccountDeletionOthersAgent({
    required this.id,
    required this.name,
    required this.owner,
    required this.ownerNotifiedAt,
    required this.ownerNextNotifyAt,
    required this.personalAssistant,
    required this.server,
    required this.computer,
  });
  final String id, name;

  /// Who created it; null when no person did (nobody to notify).
  final ({String id, String name})? owner;
  final String? ownerNotifiedAt, ownerNextNotifyAt;
  final bool personalAssistant;
  final AccountDeletionServer server;
  final ({String id, String name}) computer;
}

({String id, String name})? _owner(Object? value) {
  final m = _map(value);
  if (m == null || m['id'] is! String) return null;
  return (id: m['id'] as String, name: _string(m['name']) ?? m['id'] as String);
}

/// An agent bound to one of the person's computers.
class AccountDeletionBoundAgent {
  const AccountDeletionBoundAgent({
    required this.id,
    required this.name,
    required this.ownedByMe,
    this.owner,
    this.ownerNotifiedAt,
    this.ownerNextNotifyAt,
    this.personalAssistant = false,
  });
  final String id, name;
  final bool ownedByMe;
  final ({String id, String name})? owner;
  final String? ownerNotifiedAt, ownerNextNotifyAt;
  final bool personalAssistant;
}

/// One of the person's computers still attached to a server, with the agents
/// bound to it. It is deleted on the deletion date.
class AccountDeletionComputer {
  const AccountDeletionComputer({
    required this.id,
    required this.name,
    required this.server,
    required this.agents,
  });
  final String id, name;
  final AccountDeletionServer server;
  final List<AccountDeletionBoundAgent> agents;

  static AccountDeletionComputer? parse(Object? value) {
    final m = _map(value);
    final server = AccountDeletionServer.parse(m?['server']);
    if (m == null || m['id'] is! String || server == null) return null;
    final bound = <AccountDeletionBoundAgent>[];
    if (m['agents'] is List) {
      for (final entry in m['agents'] as List) {
        final a = _map(entry);
        if (a == null || a['id'] is! String) continue;
        // An older server doesn't say whose it is: then it's the person's.
        final ownedByMe = a['ownedByMe'] != false;
        final id = a['id'] as String;
        final name = a['name'] is String ? a['name'] as String : id;
        bound.add(
          ownedByMe
              ? AccountDeletionBoundAgent(id: id, name: name, ownedByMe: true)
              : AccountDeletionBoundAgent(
                  id: id,
                  name: name,
                  ownedByMe: false,
                  owner: _owner(a['owner']),
                  ownerNotifiedAt: _time(a['ownerNotifiedAt']),
                  ownerNextNotifyAt: _time(a['ownerNextNotifyAt']),
                  personalAssistant: a['personalAssistant'] == true,
                ),
        );
      }
    }
    return AccountDeletionComputer(
      id: m['id'] as String,
      name: m['name'] is String ? m['name'] as String : m['id'] as String,
      server: server,
      agents: bound,
    );
  }
}

/// The checklist's facts. Every list is optional on the wire: an older
/// server sends none of them. `soleOwnerServers`, `agents` and `computers`
/// stay null when absent; the others read as empty.
class AccountDeletionChecklist {
  const AccountDeletionChecklist({
    this.soleMemberServers = const [],
    this.soleOwnerServers,
    this.paidServersEndingAtPeriodEnd = const [],
    this.agents,
    this.computers,
    this.graceDays,
  });
  final List<AccountDeletionServer> soleMemberServers;
  final List<SoleOwnerServer>? soleOwnerServers;
  final List<PaidServerEnding> paidServersEndingAtPeriodEnd;
  final List<AccountDeletionAgent>? agents;
  final List<AccountDeletionComputer>? computers;

  /// How long a request made now would wait; null from an older server.
  final int? graceDays;

  static List<T> _list<T>(Object? value, T? Function(Object?) parse) => [
    if (value is List)
      for (final entry in value) ?parse(entry),
  ];

  static AccountDeletionChecklist parse(Map<String, dynamic> m) =>
      AccountDeletionChecklist(
        soleMemberServers: _list(
          m['soleMemberServers'],
          AccountDeletionServer.parse,
        ),
        soleOwnerServers: m['soleOwnerServers'] is List
            ? _list(m['soleOwnerServers'], SoleOwnerServer.parse)
            : null,
        paidServersEndingAtPeriodEnd: _list(
          m['paidServersEndingAtPeriodEnd'],
          PaidServerEnding.parse,
        ),
        agents: m['agents'] is List
            ? _list(m['agents'], AccountDeletionAgent.parse)
            : null,
        computers: m['computers'] is List
            ? _list(m['computers'], AccountDeletionComputer.parse)
            : null,
        graceDays: m['graceDays'] is int && (m['graceDays'] as int) > 0
            ? m['graceDays'] as int
            : null,
      );
}

/// What cancelling did to the person's subscription.
enum SubscriptionRestoration {
  restored,
  notRestored,
  unknown;

  static SubscriptionRestoration parse(Object? value) => switch (value) {
    'restored' => restored,
    'not_restored' => notRestored,
    _ => unknown,
  };
}

final _requestIdPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// GET (and POST) `/me/account/deletion`: nothing scheduled, or scheduled.
class AccountDeletionStatus {
  const AccountDeletionStatus({
    required this.checklist,
    required this.scheduled,
    this.requestId,
    this.requestedAt = '',
    this.scheduledFor,
    this.subscriptionCancellationUnconfirmed = false,
    this.subscriptionRestoration = SubscriptionRestoration.unknown,
  });
  final AccountDeletionChecklist checklist;
  final bool scheduled;

  /// Only a request id in the server's shape (a UUID) counts: Cancel Deletion
  /// is bound to it.
  final String? requestId;
  final String requestedAt;
  final String? scheduledFor;
  final bool subscriptionCancellationUnconfirmed;

  /// Of `status: none`.
  final SubscriptionRestoration subscriptionRestoration;

  /// Throws a [RaftApiException] for a body that is neither (Web `statusOf`).
  static AccountDeletionStatus parse(Object? data) {
    final m = _map(data) ?? const <String, dynamic>{};
    final status = m['status'];
    if (status != 'none' && status != 'scheduled') {
      throw const RaftApiException(
        'Account deletion status could not be confirmed',
      );
    }
    final checklist = AccountDeletionChecklist.parse(m);
    if (status == 'scheduled') {
      if (m['scheduledFor'] is! String) {
        throw const RaftApiException(
          'Account deletion status could not be confirmed',
        );
      }
      final id = m['requestId'];
      return AccountDeletionStatus(
        checklist: checklist,
        scheduled: true,
        requestId: id is String && _requestIdPattern.hasMatch(id) ? id : null,
        requestedAt: m['requestedAt'] is String
            ? m['requestedAt'] as String
            : '',
        scheduledFor: m['scheduledFor'] as String,
        subscriptionCancellationUnconfirmed:
            m['subscriptionCancellationUnconfirmed'] == true,
      );
    }
    return AccountDeletionStatus(
      checklist: checklist,
      scheduled: false,
      subscriptionRestoration: SubscriptionRestoration.parse(
        m['subscriptionRestoration'],
      ),
    );
  }
}

/// What the request carries to prove it is the person: nothing for the first
/// try (the server answers with the methods it wants), or one of these.
class AccountDeletionProof {
  const AccountDeletionProof._(this.body);
  static const none = AccountDeletionProof._({});
  AccountDeletionProof.secondFactor(StepUpAnswer answer)
    : body = {'secondFactor': answer.body};
  AccountDeletionProof.password(String password)
    : body = {'password': password};
  AccountDeletionProof.emailCode(String code) : body = {'emailCode': code};
  final Map<String, Object?> body;
}

/// How the request dialog asks the person to prove it is them, from the
/// `methods` the server listed.
sealed class AccountDeletionReauth {
  const AccountDeletionReauth();

  /// Web `accountDeletionReauthFor`: two-step methods first, then password,
  /// then an emailed code; null when none is listed.
  static AccountDeletionReauth? of(Object? methods) {
    final secondFactor = parseSecondFactorMethods(methods);
    if (secondFactor.isNotEmpty)
      return AccountDeletionSecondFactor(secondFactor);
    final listed = methods is List ? methods : const [];
    if (listed.contains('password')) return const AccountDeletionPassword();
    if (listed.contains('email_code')) return const AccountDeletionEmailCode();
    return null;
  }
}

class AccountDeletionSecondFactor extends AccountDeletionReauth {
  const AccountDeletionSecondFactor(this.methods);
  final List<SecondFactorMethod> methods;
}

class AccountDeletionPassword extends AccountDeletionReauth {
  const AccountDeletionPassword();
}

class AccountDeletionEmailCode extends AccountDeletionReauth {
  const AccountDeletionEmailCode();
}

/// A refusal the request turns into its own step; anything else is shown
/// where it happened.
sealed class AccountDeletionRefusal {
  const AccountDeletionRefusal();

  /// Web `accountDeletionRefusalOf`.
  static AccountDeletionRefusal? of(Object? error) {
    if (error is! RaftApiException) return null;
    final code = error.code, status = error.status;
    if (status == 409 && code == 'sole_owner_servers') {
      return AccountDeletionSoleOwner([
        if (error.details['servers'] is List)
          for (final server in error.details['servers'] as List)
            ?SoleOwnerServer.parse(server),
      ]);
    }
    // Checked after sole_owner_servers: other members' agents still on the
    // person's computers.
    if (status == 409 && code == 'others_agents_on_computers') {
      return AccountDeletionOthersAgentsRefused([
        if (error.details['agents'] is List)
          for (final agent in error.details['agents'] as List)
            ?accountDeletionOthersAgentOf(agent),
      ]);
    }
    if (status == 403 && code == 'session_family_required') {
      return const AccountDeletionSignInAgain();
    }
    // 403 reauth_required; 409 email_code_not_available lists the methods to
    // use instead.
    if (status == 403 && code == 'reauth_required' ||
        status == 409 && code == 'email_code_not_available') {
      final reauth = AccountDeletionReauth.of(error.details['methods']);
      return reauth == null ? null : AccountDeletionReauthRefused(reauth);
    }
    return null;
  }
}

class AccountDeletionReauthRefused extends AccountDeletionRefusal {
  const AccountDeletionReauthRefused(this.reauth);
  final AccountDeletionReauth reauth;
}

class AccountDeletionSoleOwner extends AccountDeletionRefusal {
  const AccountDeletionSoleOwner(this.servers);
  final List<SoleOwnerServer> servers;
}

class AccountDeletionOthersAgentsRefused extends AccountDeletionRefusal {
  const AccountDeletionOthersAgentsRefused(this.agents);
  final List<AccountDeletionOthersAgent> agents;
}

class AccountDeletionSignInAgain extends AccountDeletionRefusal {
  const AccountDeletionSignInAgain();
}

/// One entry of the 409's `agents`; null without server and computer.
AccountDeletionOthersAgent? accountDeletionOthersAgentOf(Object? value) {
  final m = _map(value);
  if (m == null || m['id'] is! String) return null;
  final server = AccountDeletionServer.parse(m['server']);
  final machine = _map(m['computer']);
  if (server == null || machine == null || machine['id'] is! String) {
    return null;
  }
  return AccountDeletionOthersAgent(
    id: m['id'] as String,
    name: m['name'] is String ? m['name'] as String : m['id'] as String,
    owner: _owner(m['owner']),
    ownerNotifiedAt: _time(m['ownerNotifiedAt']),
    ownerNextNotifyAt: _time(m['ownerNextNotifyAt']),
    personalAssistant: m['personalAssistant'] == true,
    server: server,
    computer: (
      id: machine['id'] as String,
      name: machine['name'] is String
          ? machine['name'] as String
          : machine['id'] as String,
    ),
  );
}

/// Other members' agents on the person's computers (GET's `computers`), each
/// a Needs action row until its owner moves it: by server, computer, name.
List<AccountDeletionOthersAgent> accountDeletionOthersAgents(
  AccountDeletionChecklist? checklist,
) {
  final seen = <String>{};
  final out = <AccountDeletionOthersAgent>[];
  for (final computer in checklist?.computers ?? const []) {
    for (final agent in computer.agents) {
      if (agent.ownedByMe || !seen.add(agent.id)) continue;
      out.add(
        AccountDeletionOthersAgent(
          id: agent.id,
          name: agent.name,
          owner: agent.owner,
          ownerNotifiedAt: agent.ownerNotifiedAt,
          ownerNextNotifyAt: agent.ownerNextNotifyAt,
          personalAssistant: agent.personalAssistant,
          server: computer.server,
          computer: (id: computer.id, name: computer.name),
        ),
      );
    }
  }
  return out..sort(accountDeletionOthersAgentOrder);
}

int _byName(({String name, String id}) a, ({String name, String id}) b) {
  final byName = a.name.compareTo(b.name);
  return byName != 0 ? byName : a.id.compareTo(b.id);
}

int accountDeletionOthersAgentOrder(
  AccountDeletionOthersAgent a,
  AccountDeletionOthersAgent b,
) {
  final server = a.server.name.compareTo(b.server.name);
  if (server != 0) return server;
  final serverId = a.server.id.compareTo(b.server.id);
  if (serverId != 0) return serverId;
  final computer = _byName(a.computer, b.computer);
  if (computer != 0) return computer;
  return _byName((name: a.name, id: a.id), (name: b.name, id: b.id));
}

/// Someone who can become an Owner of a server the person is the only owner of.
class TransferCandidate {
  const TransferCandidate({required this.userId, required this.name});
  final String userId, name;
}

const _base = '/me/account/deletion';

/// POST `{agentIds}`: asks each blocking agent's owner to move it (once per
/// agent per 24 hours; the app's shared notify call batches and parses it).
const accountDeletionNotifyPath = '$_base/notify-agent-owners';

extension AccountDeletionApi on RaftClient {
  /// GET `/me/account/deletion` (account scoped: the pending page has no
  /// server). With [requestId] the server answers about that request.
  Future<AccountDeletionStatus> accountDeletionStatus({
    String? requestId,
  }) async => AccountDeletionStatus.parse(
    requestId == null
        ? await getForAccount(_base)
        : await request('GET', _base, query: {'requestId': requestId}),
  );

  /// 200: scheduled, and every sign-in (this one too) is signed out.
  ///
  /// [forceAgentIds] (Force Unbind and Request Deletion): exactly the other
  /// people's agents the person confirmed. In one transaction the server
  /// re-reads: any other agent now bound answers 409
  /// `others_agents_on_computers` and nothing happens; otherwise it unbinds
  /// those agents, takes the computers offline and goes on with the request.
  Future<AccountDeletionStatus> requestAccountDeletion(
    AccountDeletionProof proof, {
    List<String>? forceAgentIds,
  }) async => AccountDeletionStatus.parse(
    await post(
      _base,
      data: {
        ...proof.body,
        if (forceAgentIds != null) 'forceAgentIds': forceAgentIds,
      },
    ),
  );

  /// DELETE `/me/account/deletion/requests/:id`: the request-bound cancel
  /// (an older rolling-release backend refuses it rather than ignoring a
  /// query and cancelling a newer request).
  Future<SubscriptionRestoration> cancelAccountDeletion(
    String requestId,
  ) async {
    if (requestId.isEmpty) {
      throw const RaftApiException(
        'The deletion request has not been confirmed',
      );
    }
    final data = await delete(
      '$_base/requests/${Uri.encodeComponent(requestId)}',
    );
    if (data is! Map || data['status'] != 'none') {
      throw const RaftApiException(
        'Account deletion cancellation could not be confirmed',
      );
    }
    // Missing billing evidence is unknown; never infer a restoration.
    return data['subscriptionNotResumed'] == true
        ? SubscriptionRestoration.notRestored
        : SubscriptionRestoration.parse(data['subscriptionRestoration']);
  }

  /// POST `/me/account/deletion/email-code`: only for a person with neither a
  /// password nor two-step verification (a 6-digit code, 10 minutes).
  Future<void> sendAccountDeletionEmailCode() =>
      post('$_base/email-code', data: const {});

  /// The server's people who can take it over: GET /servers/:id/members,
  /// addressed to that server, without the person and without guests.
  Future<List<TransferCandidate>> accountDeletionTransferCandidates(
    String serverId,
    String? selfUserId,
  ) async {
    final data = await getForServer(
      serverId,
      '/servers/${Uri.encodeComponent(serverId)}/members',
    );
    if (data is! List) return const [];
    return [
      for (final entry in data)
        if (entry is Map &&
            entry['userId'] is String &&
            entry['userId'] != selfUserId &&
            entry['role'] != 'guest')
          TransferCandidate(
            userId: entry['userId'] as String,
            name: switch ((entry['displayName'], entry['name'])) {
              (final String d, _) when d.trim().isNotEmpty => d,
              (_, final String n) => n,
              _ => entry['userId'] as String,
            },
          ),
    ];
  }

  /// PATCH /servers/:id/members/:userId `{role: owner}`, addressed to that
  /// server (what Settings > Administration > Admins sends).
  Future<void> makeServerOwner(
    String serverId,
    String userId,
  ) => requestForServer(
    'PATCH',
    serverId,
    '/servers/${Uri.encodeComponent(serverId)}/members/${Uri.encodeComponent(userId)}',
    data: const {'role': 'owner'},
  );

  /// Archives one of the person's agents from Delete Account: the DELETE
  /// every Archive sends (the workspace kept), addressed to that agent's
  /// server.
  Future<void> archiveAgentForDeletion(String serverId, String agentId) =>
      requestForServer(
        'DELETE',
        serverId,
        '/agents/${Uri.encodeComponent(agentId)}',
        data: const {'workspace': 'keep'},
      );
}
