import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';

import '../platform/content_links.dart';

/// The private-App invitation route, bound to the current coordinator's Web
/// origins. It never supplies a coordinator or changes an account's authority.
class PrivateAppInviteLink {
  const PrivateAppInviteLink(this.token);
  final String token;
  String get identity => sha256.convert(utf8.encode(token)).toString();
  Uri get location => Uri(pathSegments: ['', 'integration-invites', token]);

  static PrivateAppInviteLink? parse(Uri uri, String coordinator) {
    if (uri.toString().length > 2048 ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.hasQuery) {
      return null;
    }
    if (uri.hasScheme || uri.hasAuthority) {
      final native = uri.scheme == 'raft' && uri.host == 'v1' && !uri.hasPort;
      if (!native) {
        if (!const {'http', 'https'}.contains(uri.scheme) ||
            !uri.hasAuthority) {
          return null;
        }
        final frontend = ContentLinks.originFor(coordinator);
        if (!ContentLinks.loginWebOriginsFor(
          coordinator,
          frontend,
        ).any((origin) => origin.origin == uri.origin)) {
          return null;
        }
      }
    }
    final p = uri.pathSegments;
    if (p.length != 2 ||
        p.first != 'integration-invites' ||
        !RegExp(r'^[A-Za-z0-9_-]{1,256}$').hasMatch(p.last)) {
      return null;
    }
    return PrivateAppInviteLink(p.last);
  }
}

/// Every in-app link uses the root navigation owner; rejected origins retain
/// the ordinary external-browser fallback.
class PrivateAppInviteScope extends InheritedWidget {
  const PrivateAppInviteScope({
    super.key,
    required this.coordinator,
    required this.onOpen,
    required super.child,
  });
  final String coordinator;
  final Future<void> Function(Uri) onOpen;

  static Future<bool> open(BuildContext context, Uri uri) async {
    final scope = context
        .getInheritedWidgetOfExactType<PrivateAppInviteScope>();
    if (scope == null) return false;
    final link = PrivateAppInviteLink.parse(uri, scope.coordinator);
    if (link == null) return false;
    // Keep the scope's coordinator binding until the root revalidates it;
    // the root may have changed accounts before this old element unmounts.
    await scope.onOpen(
      ContentLinks.originFor(scope.coordinator)
          .resolve(link.location.toString()),
    );
    return true;
  }

  @override
  bool updateShouldNotify(PrivateAppInviteScope oldWidget) =>
      oldWidget.coordinator != coordinator || oldWidget.onOpen != onOpen;
}

class PrivateAppInstallServer {
  const PrivateAppInstallServer({
    required this.id,
    required this.name,
    required this.slug,
    required this.installed,
  });
  final String id, name, slug;
  final bool installed;
}

/// Only presentation and server-authorized installation choices are retained.
class PrivateAppInvite {
  const PrivateAppInvite(this.app, this.expiresAt, this.servers);
  final Map<String, dynamic> app;
  final String? expiresAt;
  final List<PrivateAppInstallServer> servers;
  String get id => app['id'] as String;
  String get name => app['name'] as String;
  List<String> get scopes => switch (app['allowedScopes']) {
    final List values when values.isNotEmpty =>
      values.whereType<String>().toList(),
    _ => const ['openid', 'profile', 'identity'],
  };

  static PrivateAppInvite parse(Object? raw) {
    if (raw is! Map ||
        raw['client'] is! Map ||
        raw['link'] is! Map ||
        raw['manageableServers'] is! List) {
      throw const FormatException('Invalid private app invite');
    }
    final app = Map<String, dynamic>.from(raw['client'] as Map);
    if (app['id'] is! String ||
        (app['id'] as String).isEmpty ||
        app['name'] is! String ||
        (app['name'] as String).isEmpty) {
      throw const FormatException('Invalid private app');
    }
    for (final key in [
      'clientId',
      'description',
      'homepageUrl',
      'returnUrl',
      'publisherName',
      'sourceServerName',
      'setupUrl',
      'setupDescription',
    ]) {
      if (app[key] != null && app[key] is! String) {
        throw const FormatException('Invalid private app details');
      }
    }
    final scopes = app['allowedScopes'];
    if (scopes != null &&
        (scopes is! List || scopes.any((s) => s is! String))) {
      throw const FormatException('Invalid private app scopes');
    }
    final servers = <PrivateAppInstallServer>[];
    final ids = <String>{};
    for (final row in raw['manageableServers'] as List) {
      if (row is! Map ||
          !const {'owner', 'admin'}.contains(row['role']) ||
          row['id'] is! String ||
          (row['id'] as String).isEmpty ||
          row['name'] is! String ||
          row['slug'] is! String ||
          (row['slug'] as String).isEmpty ||
          !ids.add(row['id'] as String) ||
          (row['installedAt'] != null &&
              (row['installedAt'] is! String ||
                  DateTime.tryParse(row['installedAt'] as String) == null))) {
        throw const FormatException('Invalid private app install target');
      }
      servers.add(
        PrivateAppInstallServer(
          id: row['id'] as String,
          name: row['name'] as String,
          slug: row['slug'] as String,
          installed: row['installedAt'] is String,
        ),
      );
    }
    final expiry = (raw['link'] as Map)['expiresAt'];
    if (expiry != null &&
        (expiry is! String || DateTime.tryParse(expiry) == null)) {
      throw const FormatException('Invalid private app invite expiry');
    }
    return PrivateAppInvite(app, expiry as String?, servers);
  }
}
