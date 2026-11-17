// The Apps a person signed in to with their Raft account (account-mode Login
// with Raft, RFC 079 phase 3a): Web features/settings/account/appLoginsApi.ts
// over server v1.24.0 routes/me.ts.
import 'client.dart';

/// One row of `GET /me/app-logins`.
class AppLogin {
  const AppLogin({
    required this.id,
    required this.clientId,
    required this.name,
    required this.logoUrl,
    required this.scopes,
    required this.grantedAt,
  });

  final String id;

  /// The App's public client key: what `DELETE /me/app-logins/:clientId` takes.
  final String clientId;
  final String name;
  final String? logoUrl;
  final List<String> scopes;

  /// When the person signed in; null when the server sent no readable time.
  final DateTime? grantedAt;

  /// A row, or null when it names no App (Web trusts the array as it comes;
  /// a row without a client key could not be revoked anyway).
  static AppLogin? parse(Object? value) {
    if (value is! Map) return null;
    final clientId = value['clientId'];
    if (clientId is! String || clientId.isEmpty) return null;
    final name = value['name'], logo = value['logoUrl'];
    final granted = value['grantedAt'], scopes = value['scopes'];
    return AppLogin(
      id: value['id'] is String ? value['id'] as String : clientId,
      clientId: clientId,
      name: name is String ? name : '',
      logoUrl: logo is String && logo.isNotEmpty ? logo : null,
      scopes: [
        if (scopes is List)
          for (final scope in scopes)
            if (scope is String) scope,
      ],
      grantedAt: granted is String
          ? DateTime.tryParse(granted)?.toLocal()
          : null,
    );
  }
}

extension RaftAppLogins on RaftClient {
  /// The person's account-mode App logins, newest first. A body that is not an
  /// array reads as none (Web `listAppLogins`).
  Future<List<AppLogin>> listAppLogins() async {
    final data = await get('/me/app-logins');
    return [
      if (data is List)
        for (final row in data)
          if (AppLogin.parse(row) case final login?) login,
    ];
  }

  /// Revokes everything the App holds of the person. The server answers 204
  /// for a known App or not, so it tells nobody which Apps exist.
  Future<void> revokeAppLogin(String clientId) =>
      delete('/me/app-logins/${Uri.encodeComponent(clientId)}');
}
