// Typed reads of the wire fields Raft server v1.24.0 added to rows the app
// already holds as JSON maps. Parse only: no surface reads them yet, each
// feature package adopts the ones it shows. Every reader takes an older
// server's row (the field absent) and answers what Web does for it.
//
// Source: packages/web/src/store/{agentStore,channelStore,machineStore,
// serverStore,taskStore,threadStore,authStore}.ts,
// packages/web/src/hooks/useChannelMembers.ts, packages/shared/src/{index,
// readiness,actionCards,externalProjection,raftThemes,appsumoPlans}.ts at
// v1.24.0-source.1.

String? _string(Object? value) => value is String ? value : null;

/// A string that means something only when it is not empty.
String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
bool? _bool(Object? value) => value is bool ? value : null;
int? _int(Object? value) => switch (value) {
  final int v => v,
  final double v when v.isFinite && v == v.roundToDouble() => v.toInt(),
  _ => null,
};
DateTime? _time(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
DateTime? _epochMs(Object? value) {
  final ms = _int(value);
  return ms == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}

Map<String, dynamic>? _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;
List<Map<String, dynamic>> _maps(Object? value) =>
    value is List ? [for (final row in value) ?_map(row)] : const [];
List<String>? _strings(Object? value) =>
    value is List ? [for (final v in value) ?_string(v)] : null;
String? _oneOf(Object? value, Set<String> known) =>
    value is String && known.contains(value) ? value : null;

/// `"default" | "all" | "mentions" | "none"` on a channel or a followed
/// thread (contract §2.2). Absent or null: the server default.
enum RaftNotificationLevel {
  byDefault('default'),
  all('all'),
  mentions('mentions'),
  none('none');

  const RaftNotificationLevel(this.wire);
  final String wire;
  static RaftNotificationLevel? parse(Object? value) {
    for (final level in values) {
      if (level.wire == value) return level;
    }
    return null;
  }
}

/// Server `CreatorSummary` (agents' and Computers' creator / owner). Its
/// `gravatarHash` is retired (always empty); nothing reads it.
extension type RaftCreatorSummary(Map<String, dynamic> json) {
  String get type => _string(json['type']) ?? '';
  String get id => _string(json['id']) ?? '';
  String get name => _text(json['displayName']) ?? _string(json['name']) ?? '';
  String? get avatarUrl => _text(json['avatarUrl']);
}

/// One readiness fact (`shared/readiness.ts` ReadinessFact). [code] may be
/// one this build does not know: [behaviour] says what to do with it.
extension type RaftReadinessFact(Map<String, dynamic> json) {
  /// `server`, `computer`, `runtime`, `login`, `login_window`, `model`, `agent`.
  String get resourceKind => _string(_map(json['resource'])?['kind']) ?? '';
  Map<String, dynamic> get resource => _map(json['resource']) ?? const {};
  String get code => _string(json['code']) ?? '';

  /// `blocked`, `waiting` or `advisory`.
  String get behaviour => _string(json['behaviour']) ?? '';
  DateTime? get since => _epochMs(json['since']);
  DateTime? get until => _epochMs(json['until']);
  Map<String, dynamic> get params => _map(json['params']) ?? const {};
}

/// `Readiness` (agent rows) and `ComputerReadiness` (machine rows): the
/// conclusion for one dependency chain, trimmed for this viewer.
extension type RaftReadiness(Map<String, dynamic> json) {
  static const behaviours = {'blocked', 'waiting', 'advisory'};

  /// `ready`, or the first broken link's behaviour. A shape this build does
  /// not know reads as ready, like a row from an older server.
  String get state => _oneOf(json['state'], behaviours) ?? 'ready';
  bool get ready => state == 'ready';

  /// Null when ready, or for a viewer who may not see the reason.
  RaftReadinessFact? get primary => switch (_map(json['primary'])) {
    final Map<String, dynamic> fact => RaftReadinessFact(fact),
    null => null,
  };

  /// `server`, `computer` or `agent`.
  String? get scope =>
      _oneOf(json['scope'], const {'server', 'computer', 'agent'});

  /// `server_admin`, `computer_owner` or `agent_owner`.
  String? get actor => _oneOf(json['actor'], const {
    'server_admin',
    'computer_owner',
    'agent_owner',
  });
  String? get actorName => _text(json['actorName']);

  /// `sign_in`, `verify_account`, `update_computer` or `fix`.
  String? get action => _oneOf(json['action'], const {
    'sign_in',
    'verify_account',
    'update_computer',
    'fix',
  });
  List<RaftReadinessFact> get also => [
    for (final fact in _maps(json['also'])) RaftReadinessFact(fact),
  ];

  /// ComputerReadiness only: each runtime's chain on the Computer.
  Map<String, RaftReadiness> get runtimes => {
    for (final MapEntry(:key, :value)
        in (_map(json['runtimes']) ?? const {}).entries)
      if (_map(value) case final Map<String, dynamic> chain)
        key: RaftReadiness(chain),
  };
}

/// `AgentRuntimeErrorState` (`agent.lastRuntimeError`).
extension type RaftAgentRuntimeError(Map<String, dynamic> json) {
  static const codes = {
    'usage_limit',
    'billing',
    'model_unavailable',
    'auth_required',
    'network_timeout',
    'input_too_large',
    'message_too_large',
  };

  /// For a viewer who does not manage the agent, the code's fixed sentence.
  String get message => _string(json['message']) ?? '';

  /// Null: no common-case code applies, or one this build does not know.
  String? get code => _oneOf(json['code'], codes);
  DateTime? get at => _time(json['at']);
  String? get launchId => _text(json['launchId']);
  bool get actionRequired => json['actionRequired'] == true;

  /// `user_reauth` or `user_model_access`.
  String? get requiredAction => _oneOf(json['requiredAction'], const {
    'user_reauth',
    'user_model_access',
  });
  String? get occurrenceId => _text(json['occurrenceId']);
  String? get daemonInstanceId => _text(json['daemonInstanceId']);
  int? get clientSeq => _int(json['clientSeq']);
  String? get recoveryLaunchId => _text(json['recoveryLaunchId']);
}

/// The v1.24 fields of an agent row (`Agent`, web store/agentStore.ts).
extension type RaftAgentFields(Map<String, dynamic> json) {
  /// A personal assistant (RFC 075): the person it belongs to.
  String? get assistantOwnerUserId => _text(json['assistantOwnerUserId']);
  bool get personalAssistant => assistantOwnerUserId != null;
  DateTime? get assistantPausedAt => _time(json['assistantPausedAt']);

  /// Sent to the owner and server owners/admins only.
  ({String id, String name})? get assistantPausedBy => switch (_map(
    json['assistantPausedBy'],
  )) {
    {'id': final String id, 'name': final String name} => (id: id, name: name),
    _ => null,
  };

  /// `computer_version_unsupported`, `computer_version_unknown` or
  /// `computer_access_revoked`: the agent list says it is not run. A reason
  /// this build does not know is kept (Web shows its generic blocked copy).
  String? get blockedReason => _text(json['blockedReason']);

  /// Agent list only: the first broken link of its readiness.
  RaftReadiness? get readiness => switch (_map(json['readiness'])) {
    final Map<String, dynamic> value => RaftReadiness(value),
    null => null,
  };

  /// Built-in custom gateway agents only: the current session reported a
  /// Raft default limit. Null: unknown.
  bool? get modelDefaultsReported =>
      _bool(_map(json['modelLimits'])?['defaultsReported']);
  String? get managedByAppInstallId => _text(json['managedByAppInstallId']);

  /// Detail payloads only: the app that owns this bot.
  ({
    String clientId,
    String name,
    String? logoUrl,
    String? description,
    String? botStatusText,
  })?
  get managedByApp => switch (_map(json['managedByApp'])) {
    {'clientId': final String clientId, 'name': final String name} &&
        final app =>
      (
        clientId: clientId,
        name: name,
        logoUrl: _text(app['logoUrl']),
        description: _text(app['description']),
        botStatusText: _text(app['botStatusText']),
      ),
    _ => null,
  };

  /// Web `isAgentInMemberLists`: not deleted, not a Bot removed from its
  /// App, and not a personal assistant.
  bool get inMemberLists =>
      json['deletedAt'] == null &&
      json['inMemberLists'] != false &&
      !personalAssistant;
  RaftAgentRuntimeError? get lastRuntimeError =>
      switch (_map(json['lastRuntimeError'])) {
        final Map<String, dynamic> error => RaftAgentRuntimeError(error),
        null => null,
      };
}

/// The v1.24 fields of a channel roster person (`ChannelHuman`).
extension type RaftChannelHumanFields(Map<String, dynamic> json) {
  /// Null for another server's person in a joint channel: their roles stay
  /// with their organization and they read as a plain member.
  String? get role => _text(json['role']);
  String? get serverRole => _text(json['serverRole']);
  String? get channelRole => _text(json['channelRole']);

  /// Joint rosters only: the person belongs to the viewed server.
  bool? get inViewerServer => _bool(json['inViewerServer']);

  /// Absent from older servers, which leave the decision to the client.
  bool? get canRemoveFromChannel => _bool(json['canRemoveFromChannel']);
}

/// `ServerMember.roster`: a channel roster's person as a member row.
extension type RaftServerMemberFields(Map<String, dynamic> json) {
  ({
    String? serverId,
    String? serverName,
    String? serverSlug,
    List<({String id, String name, String slug})> servers,
    bool? inViewerServer,
  })?
  get roster => switch (_map(json['roster'])) {
    final Map<String, dynamic> roster => (
      serverId: _text(roster['serverId']),
      serverName: _text(roster['serverName']),
      serverSlug: _text(roster['serverSlug']),
      servers: [
        for (final server in _maps(roster['servers']))
          if (server case {
            'id': final String id,
            'name': final String name,
            'slug': final String slug,
          })
            (id: id, name: name, slug: slug),
      ],
      inViewerServer: _bool(roster['inViewerServer']),
    ),
    null => null,
  };
}

/// The Raft Design System themes (shared/raftThemes.ts RAFT_THEME_IDS).
const raftThemeIds = {
  'raft',
  'boring',
  'bots',
  'critters',
  'space',
  'desk',
  'food',
  'quest',
  'weather',
  'plants',
  'spooky',
};

/// The v1.24 fields of a `GET /servers` row (`Server`).
extension type RaftServerFields(Map<String, dynamic> json) {
  /// The member's own theme on this server; null = Raft Yellow, also for an
  /// id this build does not know.
  String? get theme => _oneOf(json['theme'], raftThemeIds);

  /// The member shows the theme's pixel art on the frame.
  bool get themeDecor => json['themeDecor'] == true;
}

/// One stored keyboard shortcut (shared/shortcutOverrides.ts).
typedef RaftShortcutCombo = ({
  String key,
  bool mod,
  bool ctrl,
  bool alt,
  bool shift,
});

/// The v1.24 fields of the signed-in user (`User`, web store/authStore.ts).
extension type RaftUserFields(Map<String, dynamic> json) {
  /// How the message box sends: `mod_enter`, else `enter` (null, absent or
  /// unknown is the default; shared normalizeComposerSendKey).
  String get composerSendKey =>
      json['composerSendKey'] == 'mod_enter' ? 'mod_enter' : 'enter';
  List<String>? get railTabOrder => _strings(json['railTabOrder']);

  /// Changed shortcuts per command id; null = all defaults.
  Map<String, List<RaftShortcutCombo>>? get shortcutOverrides =>
      switch (_map(json['shortcutOverrides'])) {
        final Map<String, dynamic> overrides => {
          for (final MapEntry(:key, :value) in overrides.entries)
            key: [
              for (final combo in _maps(value))
                if (_text(combo['key']) case final String k)
                  (
                    key: k,
                    mod: combo['mod'] == true,
                    ctrl: combo['ctrl'] == true,
                    alt: combo['alt'] == true,
                    shift: combo['shift'] == true,
                  ),
            ],
        },
        null => null,
      };
  String? get assistantOtterShortcut => _text(json['assistantOtterShortcut']);
  bool get usedDesktopAppRecently => json['usedDesktopAppRecently'] == true;
}

/// The v1.24 fields of a task row (`Task`, web store/taskStore.ts) and of a
/// message's `taskInfo` (`TaskInfo`, shared/index.ts): task v2 conversations
/// and the task's source message.
extension type RaftTaskFields(Map<String, dynamic> json) {
  /// The chat message the task hangs under, if any.
  String? get sourceMessageId => _text(json['sourceMessageId']);

  /// False: no real source ("Not recorded"); null from older servers.
  bool? get sourceRecorded => _bool(json['sourceRecorded']);

  /// `user`, `agent` or `external_projection`.
  String? get sourceSenderType => _oneOf(json['sourceSenderType'], const {
    'user',
    'agent',
    'external_projection',
  });
  String? get sourceSenderId => _text(json['sourceSenderId']);
  int get conversationReplyCount => _int(json['conversationReplyCount']) ?? 0;

  /// The task's own conversation exists (false for a pre-v2 task until
  /// something is first written there).
  bool get conversationAnchored => json['conversationAnchored'] == true;

  /// The task conversation's canonical channel id; null until it exists.
  String? get conversationChannelId => _text(json['conversationChannelId']);

  /// Whether the reader follows the task's conversation; null with task v2
  /// off (the server leaves it out).
  bool? get conversationFollowed => _bool(json['conversationFollowed']);

  /// The real pre-v2 host message; null for a task v2 task.
  String? get hostMessageId => _text(json['hostMessageId']);
  DateTime? get lastActivityAt => _time(json['lastActivityAt']);

  /// `lastActivityAt ?? updatedAt`: what the Tasks page shows and sorts by.
  DateTime? get activityAt =>
      _time(json['activityAt']) ?? lastActivityAt ?? _time(json['updatedAt']);

  /// TaskInfo only: the creator's handle.
  String? get createdByHandle => _text(json['createdByHandle']);
}

/// The v1.24 fields of a `GET /channels/threads/followed` row.
extension type RaftFollowedThreadFields(Map<String, dynamic> json) {
  /// `task` for a followed task conversation (no parent message), else
  /// `thread`.
  String get conversationKind =>
      json['conversationKind'] == 'task' ? 'task' : 'thread';
  RaftNotificationLevel? get notificationLevel =>
      RaftNotificationLevel.parse(json['notificationLevel']);

  /// Inside the plan's history window; null from older servers.
  bool? get parentInHistory => _bool(json['parentInHistory']);
  bool? get repliesInHistory => _bool(json['repliesInHistory']);
  String? get taskTitle => _text(json['taskTitle']);
  String? get sourceMessageId => _text(json['sourceMessageId']);
  DateTime? get sourceMessageCreatedAt => _time(json['sourceMessageCreatedAt']);
}

/// The v1.24 fields of a message's `actionMetadata` (`ActionCardMetadata`).
/// `action` became `StoredActionCardAction`, a superset: `seats:add`,
/// `agent:approve_call`, `question:ask` and the assistant-owner actions are
/// new card types, drawn by the generic presentation card until their own
/// renderer exists.
extension type RaftActionCardFields(Map<String, dynamic> json) {
  String get actionType => _string(_map(json['action'])?['type']) ?? '';

  /// Who asked for a person-requested card.
  String? get requesterUserId => _text(json['requesterUserId']);
  String? get requesterAgentId => _text(json['requesterAgentId']);

  /// `seats:add`: what the owner's approval did (`invites`, `promoted`,
  /// `ready`); the rest of the outcome stays in [seatOutcomeJson].
  String? get seatOutcomeKind => _text(_map(json['seatOutcome'])?['kind']);
  Map<String, dynamic>? get seatOutcomeJson => _map(json['seatOutcome']);

  /// Past it the card shows as expired; the server still decides.
  DateTime? get expiresAt => _time(json['expiresAt']);
  DateTime? get withdrawnAt => _time(json['withdrawnAt']);

  /// `presentation.card`: the card as data (`action-card.v1`); a client
  /// that cannot read it uses the presentation fields beside it.
  Map<String, dynamic>? get presentationCard =>
      _map(_map(json['presentation'])?['card']);
}

/// The v1.24 fields of a message's `externalAuthor`
/// (`ExternalMessageAuthorProjection`).
extension type RaftExternalAuthorFields(Map<String, dynamic> json) {
  /// `provider_actor`, or `anonymous` (no provider user, not addressable).
  String get identityKind =>
      json['identityKind'] == 'anonymous' ? 'anonymous' : 'provider_actor';

  /// The verified external bot's current profile, while still authorized.
  String? get profileDisplayName => _text(json['profileDisplayName']);
  String? get profileAvatarUrl => _text(json['profileAvatarUrl']);

  /// The external App that owns the bot, when known.
  String? get appName => _text(json['appName']);

  /// The profile was unavailable after the bounded recovery wait.
  bool get profileUnresolved => json['profileFallback'] == 'unresolved';
}

/// The v1.24 fields of a machine row (`Machine`, web store/machineStore.ts).
extension type RaftMachineFields(Map<String, dynamic> json) {
  /// The machine row's owner (`machines.userId`), who may differ from who
  /// attached the Computer.
  String? get userId => _text(json['userId']);

  /// Computer owner v1: who Raft records as its owner; null = a Public
  /// Computer (also from older servers).
  String? get ownerUserId => _text(json['ownerUserId']);
  RaftCreatorSummary? get owner => switch (_map(json['owner'])) {
    final Map<String, dynamic> owner => RaftCreatorSummary(owner),
    null => null,
  };

  /// Plain strings: a value this build does not know draws the fallback.
  String? get hostProvider => _text(json['hostProvider']);
  String? get osRelease => _text(json['osRelease']);
  String? get deviceClass => _text(json['deviceClass']);

  /// Same-physical-machine label; compare only, never display.
  String? get sameMachineGroup => _text(json['sameMachineGroup']);

  /// Sent to the owner only: when an agent may have read the current key.
  DateTime? get credentialExposureFoundAt =>
      _time(json['credentialExposureFoundAt']);

  /// Latest memory report while online (same shape as `diskStatus`).
  ({int availableBytes, int totalBytes})? get memoryStatus =>
      switch (_map(json['memoryStatus'])) {
        {'availableBytes': final Object? a, 'totalBytes': final Object? t}
            when (_int(a) ?? -1) >= 0 &&
                (_int(t) ?? 0) > 0 &&
                _int(a)! <= _int(t)! =>
          (availableBytes: _int(a)!, totalBytes: _int(t)!),
        _ => null,
      };

  /// The installer's repair hint (`unrecovered_operation`); null when absent,
  /// malformed or a reason this build does not know
  /// (shared parseComputerInstallerRepairHint).
  String? get installerRepairHint => _oneOf(
    _map(json['installerRepairHint'])?['reason'],
    const {'unrecovered_operation'},
  );

  /// The version floor verdict; null at or above the floor.
  ({String reason, String minVersion, DateTime? enforcedAt, bool enforced})?
  get versionGate => switch (_map(json['versionGate'])) {
    {'reason': final String reason, 'minVersion': final String minVersion} &&
        final gate =>
      (
        reason: reason,
        minVersion: minVersion,
        enforcedAt: _time(gate['enforcedAt']),
        enforced: gate['enforced'] == true,
      ),
    _ => null,
  };
  RaftReadiness? get readiness => switch (_map(json['readiness'])) {
    final Map<String, dynamic> value => RaftReadiness(value),
    null => null,
  };

  /// What waits on this Computer's readiness (`ReadinessAttention`).
  ({int count, int waitingAgents, DateTime? waitingUntil})? get attention =>
      switch (_map(json['attention'])) {
        final Map<String, dynamic> a => (
          count: _int(a['count']) ?? 0,
          waitingAgents: _int(a['waitingAgents']) ?? 0,
          waitingUntil: _epochMs(a['waitingUntil']),
        ),
        null => null,
      };
}

/// `BillingEntitlementProjection.appsumo` / `.prepaid`.
extension type RaftBillingEntitlementFields(Map<String, dynamic> json) {
  /// Present only for an active AppSumo license bound to this server.
  String? get appsumoTier => _text(_map(json['appsumo'])?['tier']);

  /// Present only when prepaid Pro time is what makes this server Pro.
  ({DateTime endsAt, DateTime graceEndsAt, bool inGrace, int seatQuantity})?
  get prepaid => switch (_map(json['prepaid'])) {
    final Map<String, dynamic> p
        when _time(p['endsAt']) != null && _time(p['graceEndsAt']) != null =>
      (
        endsAt: _time(p['endsAt'])!,
        graceEndsAt: _time(p['graceEndsAt'])!,
        inGrace: p['inGrace'] == true,
        seatQuantity: _int(p['seatQuantity']) ?? 0,
      ),
    _ => null,
  };
}
