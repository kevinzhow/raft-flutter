import 'dart:convert';

import 'package:raft_client/raft_client.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart' show WorkspaceController;
import '../platform/content_links.dart';
import 'public_avatar_url.dart';

/// "Login with Raft" for third-party apps, the logic of Web
/// `HumanLoginSetupPage.tsx` (`/login-with-raft/setup`, pinned v1.21.23):
/// the setup URL's parameters, the client lookup, the authorization request
/// and the return URL. The page and sheet that draw it are
/// `human_login_sheet.dart`.

/// App.tsx routes: the current path and the two legacy aliases.
const humanLoginSetupPaths = {
  '/login-with-raft/setup',
  '/login-with-slock/setup',
  '/login-with-slock-human/setup',
};

/// True when [uri] is the Login with Raft setup page of the Raft Web app at
/// [webOrigin] (same scheme, host and port; query and hash do not matter).
bool isHumanLoginSetupUri(Uri uri, Uri webOrigin) {
  if (uri.userInfo.isNotEmpty || webOrigin.userInfo.isNotEmpty) return false;
  if (!_sameOrigin(uri, webOrigin)) return false;
  final path = uri.path.length > 1 && uri.path.endsWith('/')
      ? uri.path.substring(0, uri.path.length - 1)
      : uri.path;
  return humanLoginSetupPaths.contains(path);
}

bool _sameOrigin(Uri a, Uri b) =>
    a.scheme.toLowerCase() == b.scheme.toLowerCase() &&
    a.host.toLowerCase() == b.host.toLowerCase() &&
    _port(a) == _port(b);

int _port(Uri uri) => uri.hasPort
    ? uri.port
    : uri.scheme.toLowerCase() == 'https'
    ? 443
    : 80;

/// `@botiverse/raft-shared` `isSafeOAuthReturnUrl`: browser OAuth callbacks
/// must be navigable web URLs. Local HTTP callbacks remain available for
/// development and installed-client loopback listeners.
bool isSafeOAuthReturnUrl(String value) {
  final url = _parseWhatwg(value);
  if (url == null) return false;
  final loopback =
      url.host == 'localhost' || url.host == '127.0.0.1' || url.host == '::1';
  return (url.scheme == 'https' || (url.scheme == 'http' && loopback)) &&
      url.userInfo.isEmpty &&
      url.fragment.isEmpty;
}

/// `@botiverse/raft-shared` `appendOAuthAuthorizationParams`: the callback with
/// `code` (and `state`, when there is one) set as query parameters. Other query
/// parameters of the registered callback are kept, in order.
String appendOAuthAuthorizationParams(
  String returnTo,
  String code, [
  String? state,
]) {
  if (!isSafeOAuthReturnUrl(returnTo)) {
    throw const FormatException('Invalid OAuth returnUrl');
  }
  final url = _parseWhatwg(returnTo)!;
  final pairs = _parseQuery(url.query);
  _setParam(pairs, 'code', code);
  if (state != null && state.isNotEmpty) _setParam(pairs, 'state', state);
  final port = url.hasPort && url.port != (url.scheme == 'https' ? 443 : 80)
      ? ':${url.port}'
      : '';
  final host = url.host.contains(':') ? '[${url.host}]' : url.host;
  final path = url.path.isEmpty ? '/' : url.path;
  return '${url.scheme}://$host$port$path?${_serializeQuery(pairs)}';
}

/// `new URL(value)` for the shapes an OAuth callback can take: leading and
/// trailing control characters and spaces are trimmed, tab and newline are
/// removed anywhere, the scheme and host are lowercased.
Uri? _parseWhatwg(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'^[\u0000- ]+|[\u0000- ]+$'), '')
      .replaceAll(RegExp(r'[\t\n\r]'), '');
  final Uri uri;
  try {
    uri = Uri.parse(cleaned);
  } on FormatException {
    return null;
  }
  if (!uri.hasScheme || uri.host.isEmpty) return null;
  // `https:/host` and `https:host` are authority-less in Dart; WHATWG accepts
  // them for special schemes, but a callback must name its authority.
  if (!RegExp('^[A-Za-z]+://').hasMatch(cleaned)) return null;
  return uri;
}

List<MapEntry<String, String>> _parseQuery(String query) {
  final pairs = <MapEntry<String, String>>[];
  for (final part in query.split('&')) {
    if (part.isEmpty) continue;
    final at = part.indexOf('=');
    final name = at < 0 ? part : part.substring(0, at);
    final value = at < 0 ? '' : part.substring(at + 1);
    pairs.add(MapEntry(_formDecode(name), _formDecode(value)));
  }
  return pairs;
}

String _formDecode(String value) {
  final bytes = <int>[];
  final text = value.replaceAll('+', ' ');
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (c == 0x25 &&
        i + 2 < text.length &&
        RegExp(r'^[0-9A-Fa-f]{2}$').hasMatch(text.substring(i + 1, i + 3))) {
      bytes.add(int.parse(text.substring(i + 1, i + 3), radix: 16));
      i += 2;
    } else if (c < 0x80) {
      bytes.add(c);
    } else {
      bytes.addAll(utf8.encode(String.fromCharCode(c)));
    }
  }
  return utf8.decode(bytes, allowMalformed: true);
}

void _setParam(List<MapEntry<String, String>> pairs, String name, String v) {
  final first = pairs.indexWhere((p) => p.key == name);
  if (first < 0) {
    pairs.add(MapEntry(name, v));
    return;
  }
  pairs[first] = MapEntry(name, v);
  for (var i = pairs.length - 1; i > first; i--) {
    if (pairs[i].key == name) pairs.removeAt(i);
  }
}

/// application/x-www-form-urlencoded, as `URLSearchParams.toString()`.
String _serializeQuery(List<MapEntry<String, String>> pairs) =>
    pairs.map((p) => '${_formEncode(p.key)}=${_formEncode(p.value)}').join('&');

String _formEncode(String value) {
  final out = StringBuffer();
  for (final byte in utf8.encode(value)) {
    final unreserved =
        (byte >= 0x30 && byte <= 0x39) ||
        (byte >= 0x41 && byte <= 0x5a) ||
        (byte >= 0x61 && byte <= 0x7a) ||
        byte == 0x2a ||
        byte == 0x2d ||
        byte == 0x2e ||
        byte == 0x5f;
    if (unreserved) {
      out.writeCharCode(byte);
    } else if (byte == 0x20) {
      out.write('+');
    } else {
      out.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
    }
  }
  return out.toString();
}

/// What the setup URL asks for: the parameters Web reads from
/// `window.location.search`.
class HumanLoginRequest {
  const HumanLoginRequest({
    required this.clientId,
    required this.returnUrl,
    required this.state,
    required this.scopes,
    required this.serverHint,
    this.oidc = false,
    this.nonce = '',
    this.codeChallenge = '',
    this.codeChallengeMethod = '',
  });

  factory HumanLoginRequest.fromSetupUri(Uri uri) {
    final q = uri.queryParametersAll;
    // URLSearchParams.get: the first value of a repeated name.
    String? get(String name) => q[name]?.firstOrNull;
    String first(List<String> names) {
      for (final name in names) {
        final value = get(name);
        if (value != null && value.isNotEmpty) return value;
      }
      return '';
    }

    final raw = first(const ['scope']);
    return HumanLoginRequest(
      clientId: first(const ['client_id']),
      returnUrl: first(const ['return_to', 'redirect_uri']),
      state: first(const ['state']),
      scopes: [
        for (final s in (raw.isEmpty ? 'openid profile' : raw).split(
          RegExp(r'\s+'),
        ))
          if (s.trim().isNotEmpty) s.trim(),
      ],
      serverHint: first(const ['server']),
      oidc: get('flow') == 'oidc',
      nonce: first(const ['nonce']),
      codeChallenge: first(const ['code_challenge']),
      codeChallengeMethod: first(const ['code_challenge_method']),
    );
  }

  final String clientId, returnUrl, state, serverHint;
  final List<String> scopes;
  final bool oidc;
  final String nonce, codeChallenge, codeChallengeMethod;

  /// The `POST /oauth/authorize/human` body of Web `authorizeWithClient`.
  Map<String, Object?> authorizeBody({
    required String clientId,
    required String serverId,
  }) => {
    'clientId': clientId,
    'serverId': serverId,
    'returnUrl': returnUrl,
    'scopes': scopes,
    if (oidc) ...{
      'oidc': true,
      if (nonce.isNotEmpty) 'nonce': nonce,
      if (codeChallenge.isNotEmpty) 'codeChallenge': codeChallenge,
      if (codeChallengeMethod.isNotEmpty)
        'codeChallengeMethod': codeChallengeMethod,
      if (serverHint.isNotEmpty) 'server': serverHint,
    },
  };
}

/// A Raft server the account belongs to, as Web's `Server` store entry.
class HumanLoginServer {
  const HumanLoginServer({
    required this.id,
    required this.slug,
    required this.name,
    this.avatarUrl,
  });
  final String id, slug, name;
  final String? avatarUrl;

  String get label => '$name ($slug)';
}

/// `LoginClientSummary`: the answer of `GET /oauth/clients/lookup`.
class HumanLoginClient {
  const HumanLoginClient({
    required this.clientId,
    required this.name,
    this.id,
    this.description,
    this.homepageUrl,
    this.logoUrl,
    this.setupUrl,
    this.setupDescription,
    this.marketplace = false,
    this.installRequired = false,
    this.canInstall = false,
    this.disallowedScopes = const [],
    this.scopeReason,
  });

  factory HumanLoginClient.fromJson(Map<dynamic, dynamic> json) {
    String? text(String key) {
      final value = json[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    final validation = json['scopeValidation'];
    final installation = json['installation'];
    return HumanLoginClient(
      id: text('id'),
      clientId: text('clientId') ?? '',
      name: text('name') ?? '',
      description: text('description'),
      homepageUrl: text('homepageUrl'),
      logoUrl: text('logoUrl'),
      setupUrl: text('setupUrl'),
      setupDescription: text('setupDescription'),
      marketplace: json['marketplace'] == true,
      installRequired: json['availability'] == 'install_required',
      // Only an app waiting for an install carries `installation`; a ready
      // one is never installed twice.
      canInstall:
          json['availability'] == 'install_required' &&
          installation is Map &&
          installation['canInstall'] == true,
      disallowedScopes:
          validation is Map && validation['disallowedScopes'] is List
          ? [
              for (final s in validation['disallowedScopes'] as List)
                if (s is String) s,
            ]
          : const [],
      scopeReason: validation is Map && validation['reason'] is String
          ? validation['reason'] as String
          : null,
    );
  }

  final String clientId, name;
  final String? id,
      description,
      homepageUrl,
      logoUrl,
      setupUrl,
      setupDescription,
      scopeReason;
  final bool marketplace, installRequired, canInstall;
  final List<String> disallowedScopes;

  /// The same app once it is installed on the server: Web sets
  /// `availability: "ready"` and drops `installation`.
  HumanLoginClient get installed => HumanLoginClient(
    id: id,
    clientId: clientId,
    name: name,
    description: description,
    homepageUrl: homepageUrl,
    logoUrl: logoUrl,
    setupUrl: setupUrl,
    setupDescription: setupDescription,
    // It was a Marketplace app; installing it does not change that.
    marketplace: true,
    disallowedScopes: disallowedScopes,
    scopeReason: scopeReason,
  );

  /// Web `initialsForApp`.
  String get initials {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final first = parts.firstOrNull;
    if (first == null) return 'A';
    final second = parts.length > 1 ? parts.elementAt(1) : null;
    return (second != null
            ? '${first.substring(0, 1)}${second.substring(0, 1)}'
            : first.substring(0, first.length < 2 ? first.length : 2))
        .toUpperCase();
  }
}

/// One server the app is available on (or could be installed on).
class HumanLoginChoice {
  const HumanLoginChoice(this.server, this.client);
  final HumanLoginServer server;
  final HumanLoginClient client;

  /// Web `marketplaceServerRank`: ready first, then installable, then admin.
  int get rank => !client.installRequired
      ? 0
      : client.canInstall
      ? 1
      : 2;
}

/// One server the person can pick: the lookup's answer for it, or none when
/// the lookup failed for that server (Web lists it as "Unavailable").
class HumanLoginRow {
  const HumanLoginRow(this.server, [this.client]);
  final HumanLoginServer server;
  final HumanLoginClient? client;

  HumanLoginChoice? get choice =>
      client == null ? null : HumanLoginChoice(server, client!);

  /// Web `marketplaceServerRank`; a server without an answer is last.
  int get rank => choice?.rank ?? 3;
}

/// What Web's lookup effect leaves: every candidate server in picker order,
/// and the ones that answered.
class HumanLoginLookup {
  const HumanLoginLookup(this.rows);

  /// Every candidate server: ready first, then installable, then admin
  /// needed, then those that did not answer; by name within a group.
  final List<HumanLoginRow> rows;

  List<HumanLoginChoice> get choices => [for (final row in rows) ?row.choice];

  /// Web `isMarketplaceApp`: some server lists it as a Marketplace app or
  /// waiting for an install.
  bool get isMarketplace =>
      choices.any((c) => c.client.marketplace || c.client.installRequired);

  /// Web `marketplaceClient ?? client`: the app shown in the details card.
  HumanLoginClient? detailsClient(String selectedServerId) {
    final all = choices;
    final market = all
        .where((c) => c.client.marketplace || c.client.installRequired)
        .firstOrNull;
    if (market != null) return market.client;
    return all
        .where((c) => c.server.id == selectedServerId)
        .firstOrNull
        ?.client;
  }

  HumanLoginLookup replaced(HumanLoginChoice choice) => HumanLoginLookup([
    for (final row in rows)
      row.server.id == choice.server.id
          ? HumanLoginRow(choice.server, choice.client)
          : row,
  ]);
}

/// A failure the sheet shows as text.
class HumanLoginException implements Exception {
  const HumanLoginException(this.text);

  /// English source text (a Web message, or the server's own words).
  final String text;
  @override
  String toString() => 'HumanLoginException';
}

/// What the flow needs from the signed-in app: its servers and its
/// authenticated API client.
abstract interface class HumanLoginApi {
  List<HumanLoginServer> get servers;

  /// The Raft Web app origin (`<web>/login-with-raft/setup`).
  Uri get webOrigin;

  /// The Web origins bound to this session's coordinator, including reviewed
  /// official production aliases. Other servers keep their exact frontend.
  List<Uri> get loginWebOrigins;

  /// "Signed in as ...", or null.
  String? get signedInAs;

  /// `GET /oauth/clients/lookup` for [serverId].
  Future<dynamic> lookup(String serverId, Map<String, String> query);

  /// `POST /oauth/authorize/human`.
  Future<dynamic> authorize(Map<String, Object?> body);

  /// `POST /integrations/marketplace/<id>/install` on [serverId] (Web sends
  /// `X-Server-Id`): installs the Marketplace app there as the signed-in
  /// person, who must own or administer that server.
  Future<dynamic> installMarketplaceApp(String serverId, String appId);
}

/// The production [HumanLoginApi] over the app's session client. The server
/// list is read when asked, so a directory refreshed after the app opened is
/// what the lookup sees.
class ClientHumanLoginApi implements HumanLoginApi {
  ClientHumanLoginApi({
    required this.client,
    required this.webOrigin,
    required this.directory,
  });
  final RaftClient client;
  @override
  final Uri webOrigin;
  final Iterable<RaftRecord> Function() directory;

  @override
  List<Uri> get loginWebOrigins =>
      ContentLinks.loginWebOriginsFor(client.origin, webOrigin);

  @override
  List<HumanLoginServer> get servers => [
    for (final s in directory())
      if (s.id.isNotEmpty)
        HumanLoginServer(
          id: s.id,
          slug: s.string('slug'),
          name: s.firstNonEmpty(const ['name', 'slug'], s.id),
          avatarUrl: raftPublicAvatarUrl(client.origin, s.string('avatarUrl')),
        ),
  ];

  /// Web `SignedInAs`: always the email.
  @override
  String? get signedInAs => client.user?.string('email');

  @override
  Future<dynamic> lookup(String serverId, Map<String, String> query) =>
      client.getForServer(serverId, '/oauth/clients/lookup', query: query);

  @override
  Future<dynamic> authorize(Map<String, Object?> body) =>
      client.post('/oauth/authorize/human', data: body);

  @override
  Future<dynamic> installMarketplaceApp(String serverId, String appId) =>
      client.postForServer(
        serverId,
        '/integrations/marketplace/${Uri.encodeComponent(appId)}/install',
      );
}

/// The signed-in session's side of Login with Raft; null while signed out.
HumanLoginApi? humanLoginFor(
  RaftClient? client,
  WorkspaceController? workspace,
) => client == null || client.user == null
    ? null
    : ClientHumanLoginApi(
        client: client,
        webOrigin: ContentLinks.originFor(client.origin),
        directory: () => workspace?.servers ?? const [],
      );

/// The English text of Web's `pages.humanLogin.*` errors (the catalog has the
/// Chinese; the sheet localizes with `raftText`).
class HumanLoginMessages {
  const HumanLoginMessages._();
  static const noServerAccess = 'You do not have access to any Raft Servers.';
  static const notRegisteredForAny =
      'This app is not registered for any Raft Server you can access.';
  static const missingClientId =
      'This service is missing a registered client id.';
  static const missingReturnUrl =
      'This service is missing a configured return URL.';
  static const continueFailed = 'Failed to continue with Raft.';
  static const installFailed = 'Failed to install this Marketplace app.';
}

/// The servers [request] may use: the one its `server` parameter names (id or
/// slug), else all of the account's (Web `candidateServers`).
List<HumanLoginServer> humanLoginCandidates(
  HumanLoginRequest request,
  List<HumanLoginServer> servers,
) => request.serverHint.isEmpty
    ? servers
    : [
        for (final s in servers)
          if (s.id == request.serverHint || s.slug == request.serverHint) s,
      ];

/// Web's lookup effect: every candidate server is asked for the client; a
/// server that answers an error is kept as "unavailable" (Web lists it in the
/// Marketplace picker). Throws [HumanLoginException] with Web's text when no
/// server has the app.
Future<HumanLoginLookup> lookupHumanLoginClient(
  HumanLoginApi api,
  HumanLoginRequest request,
) async {
  if (request.clientId.trim().isEmpty) {
    throw const HumanLoginException(HumanLoginMessages.missingClientId);
  }
  final candidates = humanLoginCandidates(request, api.servers);
  if (candidates.isEmpty) {
    throw const HumanLoginException(HumanLoginMessages.noServerAccess);
  }
  final rows = await Future.wait([
    for (final server in candidates)
      api
          .lookup(server.id, {
            'client_id': request.clientId,
            'server_id': server.id,
            'scope': request.scopes.join(' '),
          })
          .then<HumanLoginRow>(
            (data) => data is Map
                ? HumanLoginRow(server, HumanLoginClient.fromJson(data))
                : HumanLoginRow(server),
          )
          .catchError((Object _) => HumanLoginRow(server)),
  ]);
  rows.sort(
    (a, b) => a.rank != b.rank
        ? a.rank.compareTo(b.rank)
        : a.server.name.toLowerCase().compareTo(b.server.name.toLowerCase()),
  );
  if (rows.every((r) => r.client == null)) {
    throw const HumanLoginException(HumanLoginMessages.notRegisteredForAny);
  }
  return HumanLoginLookup(rows);
}

/// Web `OAuthScopeTier` (`lib/oauthScopePresentation.ts`).
enum OAuthScopeTier { identity, agentDirectory, agentMessaging }

/// Web `OAUTH_SCOPE_PRESENTATION`: the tier and the sentence (English source
/// text of the `oauth.scope.*.copy` messages, pinned v1.21.23) of each scope
/// the consent screen can describe.
const _scopePresentation = <String, (OAuthScopeTier, String)>{
  'openid': (
    OAuthScopeTier.identity,
    'Signs you in with Raft and issues a stable identity token. Authentication only.',
  ),
  'profile': (
    OAuthScopeTier.identity,
    'Reads your basic profile fields (display name and similar). No access to messages, files, or agents.',
  ),
  'email': (
    OAuthScopeTier.identity,
    'Reads your verified Raft account email address. No access to messages, files, or agents.',
  ),
  'identity': (
    OAuthScopeTier.identity,
    "Reads who you are \u2014 human or agent, your Raft subject, and which server/principal you're acting as. No content access.",
  ),
  'agent:read': (
    OAuthScopeTier.agentDirectory,
    'Read the IDs, handles, display names and avatars of agents in the Server you authorize. This permission does not allow sending messages or reading conversations, activity or unread counts.',
  ),
  'agent:event:write': (
    OAuthScopeTier.agentMessaging,
    'Sends structured event messages to the one agent you authorize.',
  ),
  'agent:notification:write': (
    OAuthScopeTier.agentMessaging,
    'Sends notification messages to the one agent you authorize.',
  ),
};

OAuthScopeTier oauthScopeTier(String scope) => _scopePresentation[scope]!.$1;

String oauthScopeCopy(String scope) => _scopePresentation[scope]!.$2;

String oauthTierLabel(OAuthScopeTier tier) => switch (tier) {
  OAuthScopeTier.identity => 'Identity',
  OAuthScopeTier.agentDirectory => 'Agent directory',
  OAuthScopeTier.agentMessaging => 'Agent messaging',
};

/// Web `normalizeVisibleOAuthScopes`: the scopes the consent screen can
/// describe, once each, in request order.
List<String> normalizeVisibleOAuthScopes(Iterable<String> scopes) => [
  for (final scope in scopes.toSet())
    if (_scopePresentation.containsKey(scope)) scope,
];

/// Web `agent-inbound` scopes: a person cannot grant them here.
const agentInboundScopes = {'agent:event:write', 'agent:notification:write'};

bool hasAgentInboundScope(Iterable<String> scopes) =>
    scopes.any(agentInboundScopes.contains);

/// Web `canContinue` for the chosen server: the client is ready (not waiting
/// for an install), has a return URL, and asks for nothing a person cannot or
/// may not grant.
bool humanLoginCanContinue(
  HumanLoginRequest request,
  HumanLoginChoice choice,
) =>
    !choice.client.installRequired &&
    request.returnUrl.trim().isNotEmpty &&
    !hasAgentInboundScope(request.scopes) &&
    choice.client.disallowedScopes.isEmpty;

/// Web `canInstallAndContinue` for the chosen server: the app waits for an
/// install the person may do, and the request itself could be authorized once
/// it is installed.
bool humanLoginCanInstall(HumanLoginRequest request, HumanLoginChoice choice) =>
    choice.client.installRequired &&
    choice.client.canInstall &&
    (choice.client.id ?? '').isNotEmpty &&
    request.returnUrl.trim().isNotEmpty &&
    !hasAgentInboundScope(request.scopes) &&
    choice.client.disallowedScopes.isEmpty;

/// A server's refusal as text: its `error_description`, else its `error`
/// (Web: `error_description || error || fallback`), else [fallback].
HumanLoginException _refused(
  RaftApiException error,
  String fallback,
  String where,
) {
  final description = error.details['error_description'];
  return HumanLoginException(
    description is String && isDisplayableServerMessage(description)
        ? description.trim()
        : userErrorText(error, fallback: fallback, where: where),
  );
}

/// Web `installMarketplaceApp`: installs the app on the chosen server and
/// returns the choice as Web leaves it, ready. Authorizes nothing. Throws
/// [HumanLoginException] with the server's own words, else Web's text.
Future<HumanLoginChoice> installHumanLoginApp(
  HumanLoginApi api,
  HumanLoginChoice choice,
) async {
  final id = choice.client.id;
  if (!choice.client.canInstall || id == null || id.isEmpty) {
    throw const HumanLoginException(HumanLoginMessages.installFailed);
  }
  try {
    await api.installMarketplaceApp(choice.server.id, id);
  } on RaftApiException catch (error) {
    throw _refused(
      error,
      HumanLoginMessages.installFailed,
      'login-with-raft install',
    );
  } on Object {
    throw const HumanLoginException(HumanLoginMessages.installFailed);
  }
  return HumanLoginChoice(choice.server, choice.client.installed);
}

/// Web `authorizeWithClient`: asks for the code and builds the URL the
/// browser goes to. Throws [HumanLoginException] with the server's own
/// `error_description` or `error` when it refuses, else Web's generic text.
/// The code is returned only inside the URL and is never logged.
Future<Uri> authorizeHumanLogin(
  HumanLoginApi api,
  HumanLoginRequest request,
  HumanLoginChoice choice,
) async {
  final Object? data;
  try {
    data = await api.authorize(
      request.authorizeBody(
        clientId: choice.client.clientId,
        serverId: choice.server.id,
      ),
    );
  } on RaftApiException catch (error) {
    // Web: `error_description || error || continueFailed`.
    throw _refused(
      error,
      HumanLoginMessages.continueFailed,
      'login-with-raft authorize',
    );
  } on Object {
    throw const HumanLoginException(HumanLoginMessages.continueFailed);
  }
  try {
    final map = data as Map;
    return Uri.parse(
      appendOAuthAuthorizationParams(
        map['returnUrl'] as String,
        map['code'] as String,
        request.state,
      ),
    );
  } on Object {
    throw const HumanLoginException(HumanLoginMessages.continueFailed);
  }
}
