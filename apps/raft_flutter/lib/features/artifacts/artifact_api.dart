// The Workspace Artifacts routes this client calls, and where its frames load.
//
// Source: packages/shared/src/webArtifactsContract.ts (`artifactWebPaths`),
// webObjectsContract.ts (`objectWebPaths`) and packages/web/src/apps/
// artifacts/{apiArtifactSource,artifactApi,artifactLinks,
// artifactContentDomain}.ts at v1.24.0-source.1 (1d689caf). Every call is
// server-scoped (X-Server-Id, the client's active server).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import '../../platform/content_links.dart';
import 'artifact_models.dart';

/// The Artifact routes, as Web's `artifactWebPaths` builds them (the client
/// adds the `/api` prefix itself).
abstract final class ArtifactPaths {
  static String _id(String id) => Uri.encodeComponent(id);
  static String _version(int? version) =>
      version == null ? '' : '?version=$version';

  static String viewer(String id, [int? version]) =>
      '/artifacts/${_id(id)}${_version(version)}';
  static String details(String id, [int? version]) =>
      '/artifacts/${_id(id)}/details${_version(version)}';
  static String frame(String id) => '/artifacts/${_id(id)}/frame';
  static String file(String id, String path, [int? version]) =>
      '/artifacts/${_id(id)}/files/${Uri.encodeComponent(path)}${_version(version)}';
  static String downloadZip(String id, [int? version]) =>
      '/artifacts/${_id(id)}/download.zip${_version(version)}';
  static String subscription(String id) => '/artifacts/${_id(id)}/subscription';
  static const saveAttachment = '/artifacts/save-attachment';
  static String attachmentSaves(List<String> ids) =>
      '/artifacts/attachment-saves?attachmentIds=${Uri.encodeComponent(ids.join(','))}';

  /// `objectWebPaths.summaries()`.
  static const objectSummaries = '/objects/summaries';
}

/// Web `ARTIFACT_ATTACHMENT_SAVES_MAX_IDS`.
const artifactAttachmentSavesMaxIds = 100;

/// Web `OBJECT_SUMMARIES_MAX_REFS`.
const objectSummariesMaxRefs = 50;

/// The code of a failed Artifact call (Web `artifactErrorCode`), or null.
String? artifactErrorCode(Object error) =>
    error is RaftApiException ? error.code : null;

/// Who reads Artifacts through one signed-in client.
class ArtifactApi {
  ArtifactApi(this.client);
  final RaftClient client;

  /// GET the viewer (with the shown version's one-time `frame`). Null for the
  /// one "can't open" answer (404 NOT_VISIBLE); other failures throw.
  Future<ArtifactViewerData?> viewer(ArtifactLinkTarget target) async {
    try {
      final body = await client.get(
        ArtifactPaths.viewer(target.id, target.version),
      );
      final data = ArtifactViewerData.fromJson(body);
      if (data == null) throw const RaftApiException('Unreadable Artifact.');
      return data;
    } on RaftApiException catch (error) {
      if (error.status == 404 && error.code == 'NOT_VISIBLE') return null;
      rethrow;
    }
  }

  /// POST the frame route: a new location for the shown version (every later
  /// mount, reload and retry; a ticket opens once).
  Future<Object?> frame(String id, {int? version, String? path}) => client.post(
    ArtifactPaths.frame(id),
    data: {'version': ?version, 'path': ?path},
  );

  /// The exact bytes of one file of a version.
  Future<Uint8List> fileBytes(String id, String path, int version) =>
      client.getBytes(ArtifactPaths.file(id, path, version));

  /// Every file of a version in one zip.
  Future<Uint8List> zipBytes(String id, int version) =>
      client.getBytes(ArtifactPaths.downloadZip(id, version));

  /// PUT / DELETE the reader's subscription; the server's answer wins.
  Future<bool> setFollowing(String id, bool following) async {
    final body = following
        ? await client.request('PUT', ArtifactPaths.subscription(id))
        : await client.delete(ArtifactPaths.subscription(id));
    return body is Map && body['following'] is bool
        ? body['following'] as bool
        : following;
  }

  /// POST save-attachment: the Artifact as the saver now sees it, and
  /// whether this save made it (false: it was saved before).
  Future<({ArtifactCard card, bool created})> saveAttachment(
    String attachmentId,
  ) async {
    final body = await client.post(
      ArtifactPaths.saveAttachment,
      data: {'attachmentId': attachmentId},
    );
    final map = body is Map ? body : const {};
    final card = ArtifactViewerData.fromJson(map['artifact'])?.card;
    if (card == null) throw const RaftApiException('Unreadable Artifact.');
    return (card: card, created: map['created'] != false);
  }

  /// GET attachment-saves: what each listed attachment was saved as. An id
  /// the answer leaves out was saved as nothing this reader may know of.
  Future<Map<String, ArtifactAttachmentSave>> attachmentSaves(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const {};
    final body = await client.get(ArtifactPaths.attachmentSaves(ids));
    final saves = body is Map ? body['saves'] : null;
    return {
      if (saves is List)
        for (final save in saves)
          if (save is Map && save['attachmentId'] is String)
            save['attachmentId'] as String: ArtifactAttachmentSave.fromJson(
              save['savedAs'],
            ),
    };
  }

  /// POST object summaries for up to [objectSummariesMaxRefs] Artifact
  /// references.
  Future<List<Object?>> objectSummaries(List<ArtifactLinkTarget> refs) async {
    final body = await client.post(
      ArtifactPaths.objectSummaries,
      data: {
        'kind': 'artifact',
        'refs': [
          for (final ref in refs) {'id': ref.id, 'version': ?ref.version},
        ],
      },
    );
    final summaries = body is Map ? body['summaries'] : null;
    return summaries is List ? summaries : const [];
  }
}

/// What one attachment was saved as (an `ArtifactReference`): a card this
/// reader may open, a deleted one they saw, or one they can't see (its line
/// then names no title).
class ArtifactAttachmentSave {
  const ArtifactAttachmentSave({this.card, this.deleted});

  factory ArtifactAttachmentSave.fromJson(Object? json) {
    final map = json is Map ? json : const {};
    return switch (map['status']) {
      'ok' => ArtifactAttachmentSave(card: ArtifactCard.fromJson(map['card'])),
      'deleted' => ArtifactAttachmentSave(
        deleted: ArtifactDeleted.fromJson(map),
      ),
      _ => const ArtifactAttachmentSave(),
    };
  }

  final ArtifactCard? card;
  final ArtifactDeleted? deleted;

  /// Saved as an Artifact this reader can't open now.
  bool get hidden => card == null;
}

/// Where Artifacts of the server behind [client] are framed and linked.
class ArtifactDeployment {
  const ArtifactDeployment({
    required this.webOrigin,
    required this.contentDomain,
    required this.appHosts,
  });

  /// The Web app's origin: the wrapper page's base URL (the content Worker's
  /// APP_ORIGIN) and the origin of every Artifact address.
  final Uri webOrigin;

  /// The content domain frames load from (`host[:port]`); null: this build
  /// knows none for the server, so Artifacts open in the browser.
  final String? contentDomain;

  /// The hosts an Artifact link may name (Web `artifactAppHosts`).
  final List<String> appHosts;

  /// The official deployment's content domain (Web's production build pins
  /// `VITE_ARTIFACTS_CONTENT_DOMAIN`; app.raft.build frames from
  /// `w-<uuid>.w.raftusercontent.com`).
  static const officialContentDomains = <String, String>{
    'https://app.raft.build': 'w.raftusercontent.com',
  };

  /// The build's content domain for the API it is bound to (`RAFT_ORIGIN`),
  /// as `RAFT_FRONTEND_ORIGIN` is: a local stack passes both.
  static const contentDomainDefine = String.fromEnvironment(
    'RAFT_ARTIFACTS_CONTENT_DOMAIN',
  );

  static const _boundApi = String.fromEnvironment(
    'RAFT_ORIGIN',
    defaultValue: 'https://api.raft.build',
  );

  static final _configs = Expando<Future<RaftClientConfig>>('client config');

  /// The deployment of [client]'s server: the client config is read once per
  /// client (it is the same for everyone on a deployment).
  static Future<ArtifactDeployment> of(RaftClient client) async {
    final config = await (_configs[client] ??= client.clientConfig());
    return resolve(client.origin, config.appHosts);
  }

  /// The deployment for the API [coordinator] with the hosts it published.
  static ArtifactDeployment resolve(
    String coordinator,
    List<String>? configuredHosts, {
    String define = contentDomainDefine,
    String boundApi = _boundApi,
  }) {
    final web = ContentLinks.originFor(coordinator);
    final bound =
        Uri.tryParse(boundApi)?.origin == Uri.tryParse(coordinator)?.origin;
    final domain = define.isNotEmpty && bound
        ? artifactContentDomainOf(define)
        : officialContentDomains[web.origin];
    final hosts = [
      ...?(configuredHosts?.isNotEmpty == true
          ? configuredHosts
          : const ['app.raft.build']),
    ];
    if (web.host.isNotEmpty && !hosts.contains(web.host)) hosts.add(web.host);
    return ArtifactDeployment(
      webOrigin: Uri.parse(web.origin),
      contentDomain: domain,
      appHosts: List.unmodifiable(hosts),
    );
  }
}

/// A content domain as `host[:port]`, lower case, or null when it is not a
/// bare host of at least two labels (Web `artifactsContentDomain`).
String? artifactContentDomainOf(String raw) {
  final domain = raw.trim().toLowerCase();
  if (domain.isEmpty) return null;
  final parsed = Uri.tryParse('https://$domain');
  if (parsed == null) return null;
  final host = parsed.hasPort ? '${parsed.host}:${parsed.port}' : parsed.host;
  if (host != domain || parsed.path.isNotEmpty || parsed.userInfo.isNotEmpty) {
    return null;
  }
  return parsed.host.split('.').length < 2 ? null : domain;
}
