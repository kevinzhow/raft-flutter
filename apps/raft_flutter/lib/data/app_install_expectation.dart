import 'package:raft_client/raft_client.dart';

import 'feature_flag_client_facts.dart';

/// Web v1.24.0 shared/src/oauthScopes.ts `RAFT_OAUTH_SCOPE_CATALOG`: the
/// scopes with `defaultAllowed: true`, what an app that declares none may ask
/// for (`RAFT_OAUTH_DEFAULT_ALLOWED_SCOPES`).
const raftOAuthDefaultAllowedScopes = ['openid', 'profile', 'identity'];

List<String> _strings(Object? raw) => raw is List
    ? [
        for (final value in raw)
          if (value is String && value.isNotEmpty) value,
      ]
    : const [];

String? _text(Object? raw) => raw is String && raw.isNotEmpty ? raw : null;

/// Web `effectiveAllowedOAuthScopes` (shared/src/oauthScopes.ts:72-74).
List<String> effectiveAllowedOAuthScopes(Object? allowedScopes) {
  final scopes = _strings(allowedScopes);
  return scopes.isEmpty ? [...raftOAuthDefaultAllowedScopes] : scopes;
}

/// What installing a Marketplace app confirms: the login scopes and data
/// groups the person was shown, and the prompt-text revision while
/// app_prompt_text_consent is on.
///
/// Server v1.24.0 routes/integrations.ts:1242-1246 refuses an install without
/// `expected_scopes` and `expected_groups` (400 EXPECTED_PERMISSIONS_REQUIRED,
/// services/appPermissionExpectation.ts:78-88) and one whose sets are not the
/// app's current ones (409 APP_PERMISSIONS_CHANGED, :105-120). Web builds the
/// body with `expectedAppPermissionsBody` (lib/appPermissionExpectation.ts) and
/// `expectedTextRevisionBody` (lib/appPromptText.ts:94-96).
class AppInstallExpectation {
  const AppInstallExpectation({
    required this.scopes,
    required this.groups,
    this.textRevisionId,
  });

  /// From an app record's `allowedScopes`, `appNotificationGroups` and
  /// `promptTextRevisionId`; the revision only when [promptTextConsent].
  factory AppInstallExpectation.of({
    required Object? allowedScopes,
    required Object? groups,
    required Object? textRevisionId,
    required bool promptTextConsent,
  }) => AppInstallExpectation(
    scopes: effectiveAllowedOAuthScopes(allowedScopes),
    groups: _strings(groups),
    textRevisionId: promptTextConsent ? _text(textRevisionId) : null,
  );

  final List<String> scopes, groups;
  final String? textRevisionId;

  Map<String, Object?> get body => {
    'expected_scopes': scopes,
    'expected_groups': groups,
    'expected_text_revision_id': ?textRevisionId,
  };
}

/// Web reads app_prompt_text_consent for the installing server
/// (HumanLoginSetupPage `readServerFeatureFlag(entry.server.id, …)`,
/// IntegrationsSection `promptTextConsent`). Off when it can't be read, as
/// Web's flag store before it loads; a server that needs the revision then
/// answers 400, which [appInstallRefusal] words.
Future<bool> appPromptTextConsent(RaftClient client, String serverId) async {
  const key = RaftFeatureFlags.appPromptTextConsent;
  try {
    final flags = await client.post(
      '/feature-flags/evaluate',
      data: featureFlagEvaluateBody(keys: const [key], serverId: serverId),
    );
    return flags is Map &&
        flags['evaluations'] is List &&
        (flags['evaluations'] as List).any(
          (f) => f is Map && f['key'] == key && f['enabled'] == true,
        );
  } on RaftApiException {
    return false;
  }
}

/// Web's text for an install the server refused because what was shown is
/// not current, else null. A 409 whose text revision differs from the one
/// sent ([sentTextRevisionId], Web `appTextChangedCurrent`) is a text change;
/// any other 409 a permission change, worded per surface ([permissionsChanged]).
String? appInstallRefusal(
  Object error, {
  required String? sentTextRevisionId,
  required String permissionsChanged,
}) {
  if (error is! RaftApiException) return null;
  final code = error.details['code'];
  if (error.status == 400 && code == 'EXPECTED_PERMISSIONS_REQUIRED') {
    return "This page is out of date. Reload it, review the app's "
        'permissions, then try again.';
  }
  if (error.status != 409 || code != 'APP_PERMISSIONS_CHANGED') return null;
  final revision = _text(error.details['current_text_revision_id']);
  return sentTextRevisionId != null &&
          revision != null &&
          revision != sentTextRevisionId
      ? 'The text this app adds to agent prompts just changed. Review the '
            'current text, then try again.'
      : permissionsChanged;
}

/// 409 APP_PERMISSIONS_CHANGED: what was shown is no longer the app's set
/// (Web `isAppPermissionsChangedError`).
bool isAppPermissionsChanged(Object error) =>
    error is RaftApiException &&
    error.status == 409 &&
    error.details['code'] == 'APP_PERMISSIONS_CHANGED';

/// The app's current set from a 409 APP_PERMISSIONS_CHANGED
/// (routes/integrations.ts:1212-1221), so the next press sends it; null for
/// any other error or an answer without both lists (Web
/// `appPermissionsChangedCurrentSet`).
({List<String> scopes, List<String> groups, String? textRevisionId})?
appPermissionsChangedCurrent(Object error) {
  if (error is! RaftApiException || !isAppPermissionsChanged(error)) {
    return null;
  }
  final scopes = error.details['current_scopes'];
  final groups = error.details['current_groups'];
  if (scopes is! List || groups is! List) return null;
  return (
    scopes: _strings(scopes),
    groups: _strings(groups),
    textRevisionId: _text(error.details['current_text_revision_id']),
  );
}
