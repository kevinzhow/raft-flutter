// Workspace Artifacts payloads, as Raft Web v1.24 reads them.
//
// Source: packages/shared/src/workspaceArtifacts.ts, webArtifactsContract.ts,
// webObjectsContract.ts and artifactShortId.ts / artifactRef.ts at
// v1.24.0-source.1 (1d689caf). Every reader is lenient the way Web is: an
// unknown kind or status is read as the safe one (`other`, `none`,
// `unavailable`), and a malformed row is dropped rather than thrown.

/// How an Artifact's entry file is shown (shared `ArtifactKind`).
enum ArtifactKind {
  html,
  markdown,
  text,
  csv,
  image,
  pdf,
  video,
  other;

  static ArtifactKind parse(Object? value) =>
      values.where((kind) => kind.name == value).firstOrNull ?? other;

  /// Shown in a frame on the content origin (shared `ARTIFACT_FRAMED_KINDS`).
  bool get framed => this == html || this == markdown || this == pdf;
}

String _string(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;
String? _stringOrNull(Object? value) => value is String ? value : null;
int _int(Object? value, [int fallback = 0]) =>
    value is int ? value : (value is num ? value.toInt() : fallback);
int? _intOrNull(Object? value) =>
    value is int ? value : (value is num ? value.toInt() : null);
Map<String, Object?> _map(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const {};

/// A person or agent as an Artifact payload names them (`ArtifactShownActor`:
/// no `id` for a reader outside the Artifact's server).
class ArtifactActor {
  const ArtifactActor({
    required this.type,
    this.id,
    required this.name,
    required this.displayName,
    this.avatarUrl,
    this.gone,
  });

  factory ArtifactActor.fromJson(Object? json) {
    final map = _map(json);
    return ArtifactActor(
      type: map['type'] == 'agent' ? 'agent' : 'user',
      id: _stringOrNull(map['id']),
      name: _string(map['name']),
      displayName: _string(map['displayName']),
      avatarUrl: _stringOrNull(map['avatarUrl']),
      gone: _stringOrNull(map['gone']),
    );
  }

  final String type;
  final String? id;
  final String name, displayName;
  final String? avatarUrl;

  /// `deleted` or `system` when no one stands behind the id any more.
  final String? gone;

  /// The name a line shows (Web `artifactAuthorText`): the display name, the
  /// handle, or what is gone.
  String shownName({
    required String deletedAgent,
    required String deletedUser,
    required String system,
  }) {
    if (gone == 'system') return system;
    if (gone == 'deleted') return type == 'agent' ? deletedAgent : deletedUser;
    return displayName.isNotEmpty ? displayName : name;
  }
}

/// Where an Artifact lives (shared `ArtifactHome`).
class ArtifactHome {
  const ArtifactHome._(
    this.kind, {
    this.conversationId,
    this.conversationName = '',
    this.conversationType = 'channel',
    this.peerDisplayName,
  });

  const ArtifactHome.server() : this._('server');
  const ArtifactHome.public() : this._('public');

  factory ArtifactHome.fromJson(Object? json) {
    final map = _map(json);
    switch (map['kind']) {
      case 'public':
        return const ArtifactHome.public();
      case 'conversation':
        final conversation = _map(map['conversation']);
        return ArtifactHome._(
          'conversation',
          conversationId: _stringOrNull(conversation['id']),
          conversationName: _string(conversation['name']),
          conversationType: _string(conversation['type'], 'channel'),
          peerDisplayName: _stringOrNull(conversation['peerDisplayName']),
        );
      default:
        return const ArtifactHome.server();
    }
  }

  /// `conversation`, `server` or `public`.
  final String kind;
  final String? conversationId;
  final String conversationName;

  /// `channel`, `private`, `dm` or `joint`.
  final String conversationType;
  final String? peerDisplayName;
}

/// The raw counts of a card's fact line (shared `ArtifactFacts`).
class ArtifactFacts {
  const ArtifactFacts({
    this.sizeBytes = 0,
    this.fileCount = 0,
    this.pages,
    this.rows,
    this.columns,
    this.columnNames = const [],
    this.lines,
    this.width,
    this.height,
  });

  factory ArtifactFacts.fromJson(Object? json) {
    final map = _map(json);
    return ArtifactFacts(
      sizeBytes: _int(map['sizeBytes']),
      fileCount: _int(map['fileCount']),
      pages: _intOrNull(map['pages']),
      rows: _intOrNull(map['rows']),
      columns: _intOrNull(map['columns']),
      columnNames: [
        if (map['columnNames'] case final List names)
          for (final name in names)
            if (name is String) name,
      ],
      lines: _intOrNull(map['lines']),
      width: _intOrNull(map['width']),
      height: _intOrNull(map['height']),
    );
  }

  final int sizeBytes, fileCount;
  final int? pages, rows, columns, lines, width, height;
  final List<String> columnNames;
}

/// What a card shows of the Artifact (shared `ArtifactPreview`). A kind this
/// client doesn't know is `none`.
class ArtifactPreview {
  const ArtifactPreview._(this.kind, {this.text = '', this.path = ''});
  const ArtifactPreview.none() : this._('none');

  factory ArtifactPreview.fromJson(Object? json) {
    final map = _map(json);
    switch (map['kind']) {
      case 'excerpt' when map['text'] is String:
        return ArtifactPreview._('excerpt', text: map['text'] as String);
      case 'image' when map['path'] is String:
        return ArtifactPreview._('image', path: map['path'] as String);
      default:
        // `screenshot` covers come from core's object files; this client
        // draws the card without a cover for them (see docs/parity.md).
        return const ArtifactPreview.none();
    }
  }

  final String kind, text, path;
}

/// ArtifactCard `unseen`: others' changes past the reader's read position.
class ArtifactUnseen {
  const ArtifactUnseen({this.newerVersion = false, this.newComments = 0});
  final bool newerVersion;
  final int newComments;
}

/// What a card shows, wherever it is drawn (shared `ArtifactCard`).
class ArtifactCard {
  const ArtifactCard({
    required this.id,
    required this.url,
    required this.title,
    this.description,
    required this.kind,
    this.facts = const ArtifactFacts(),
    this.preview = const ArtifactPreview.none(),
    required this.version,
    this.pinned = false,
    required this.latestVersion,
    required this.author,
    required this.createdAt,
    required this.updatedAt,
    this.commentCount = 0,
    this.home = const ArtifactHome.server(),
    this.fromAnotherServer = false,
    this.unseen,
  });

  static ArtifactCard? fromJson(Object? json) {
    final map = _map(json);
    final id = map['id'];
    if (id is! String || parseArtifactId(id) == null) return null;
    final version = _int(map['version'], 1);
    final unseen = map['unseen'];
    return ArtifactCard(
      id: id,
      url: _string(map['url']),
      title: _string(map['title']),
      description: _stringOrNull(map['description']),
      kind: ArtifactKind.parse(map['kind']),
      facts: ArtifactFacts.fromJson(map['facts']),
      preview: ArtifactPreview.fromJson(map['preview']),
      version: version,
      pinned: map['pinned'] == true,
      latestVersion: _int(map['latestVersion'], version),
      author: ArtifactActor.fromJson(map['author']),
      createdAt: DateTime.tryParse(_string(map['createdAt'])),
      updatedAt: DateTime.tryParse(_string(map['updatedAt'])),
      commentCount: _int(map['commentCount']),
      home: ArtifactHome.fromJson(map['home']),
      fromAnotherServer: map['fromAnotherServer'] == true,
      unseen: unseen is Map
          ? ArtifactUnseen(
              newerVersion: unseen['newerVersion'] == true,
              newComments: _int(unseen['newComments']),
            )
          : null,
    );
  }

  final String id, url, title;
  final String? description;
  final ArtifactKind kind;
  final ArtifactFacts facts;
  final ArtifactPreview preview;
  final int version, latestVersion;
  final bool pinned;
  final ArtifactActor author;
  final DateTime? createdAt, updatedAt;
  final int commentCount;
  final ArtifactHome home;
  final bool fromAnotherServer;
  final ArtifactUnseen? unseen;

  ArtifactCard copyWith({String? title}) => ArtifactCard(
    id: id,
    url: url,
    title: title ?? this.title,
    description: description,
    kind: kind,
    facts: facts,
    preview: preview,
    version: version,
    pinned: pinned,
    latestVersion: latestVersion,
    author: author,
    createdAt: createdAt,
    updatedAt: updatedAt,
    commentCount: commentCount,
    home: home,
    fromAnotherServer: fromAnotherServer,
    unseen: unseen,
  );
}

/// A deleted Artifact as a viewer who could see it before sees a reference
/// to it (shared `ArtifactDeletedReference`).
class ArtifactDeleted {
  const ArtifactDeleted({
    required this.title,
    required this.deletedBy,
    this.deletedAt,
  });

  /// Null without a title (Web `artifactDeletedOf`: then it is unavailable).
  static ArtifactDeleted? fromJson(Object? json) {
    final map = _map(json);
    final title = map['title'];
    if (title is! String || title.trim().isEmpty) return null;
    return ArtifactDeleted(
      title: title,
      deletedBy: ArtifactActor.fromJson(map['deletedBy']),
      deletedAt: DateTime.tryParse(_string(map['deletedAt'])),
    );
  }

  final String title;
  final ArtifactActor deletedBy;
  final DateTime? deletedAt;
}

/// One file of a version (shared `ArtifactFile`).
class ArtifactFile {
  const ArtifactFile({
    required this.path,
    required this.kind,
    this.sizeBytes = 0,
    this.entry = false,
  });

  static ArtifactFile? fromJson(Object? json) {
    final map = _map(json);
    final path = map['path'];
    if (path is! String || path.isEmpty) return null;
    return ArtifactFile(
      path: path,
      kind: ArtifactKind.parse(map['kind']),
      sizeBytes: _int(map['sizeBytes']),
      entry: map['entry'] == true,
    );
  }

  final String path;
  final ArtifactKind kind;
  final int sizeBytes;
  final bool entry;

  /// The last path segment (what a download is named).
  String get name => path.substring(path.lastIndexOf('/') + 1);
}

/// One published version (shared `ArtifactVersionSummary`).
class ArtifactVersion {
  const ArtifactVersion({
    required this.number,
    required this.publisher,
    this.createdAt,
    this.note,
    this.changedPaths = const [],
  });

  static ArtifactVersion? fromJson(Object? json) {
    final map = _map(json);
    final number = _intOrNull(map['number']);
    if (number == null || number < 1) return null;
    return ArtifactVersion(
      number: number,
      publisher: ArtifactActor.fromJson(map['publisher']),
      createdAt: DateTime.tryParse(_string(map['createdAt'])),
      note: _stringOrNull(map['note']),
      changedPaths: [
        if (map['changedPaths'] case final List paths)
          for (final path in paths)
            if (path is String) path,
      ],
    );
  }

  final int number;
  final ArtifactActor publisher;
  final DateTime? createdAt;
  final String? note;
  final List<String> changedPaths;
}

/// What the signed-in viewer may do (shared `ArtifactCapabilities`).
class ArtifactCapabilities {
  const ArtifactCapabilities({
    this.publish = false,
    this.comment = false,
    this.changeHome = false,
    this.unpublish = false,
    this.narrowHome = false,
    this.delete = false,
  });

  factory ArtifactCapabilities.fromJson(Object? json) {
    final map = _map(json);
    return ArtifactCapabilities(
      publish: map['publish'] == true,
      comment: map['comment'] == true,
      changeHome: map['changeHome'] == true,
      unpublish: map['unpublish'] == true,
      narrowHome: map['narrowHome'] == true,
      delete: map['delete'] == true,
    );
  }

  final bool publish, comment, changeHome, unpublish, narrowHome, delete;
}

/// Where the Artifact entered a conversation (shared `ArtifactOrigin`).
class ArtifactOrigin {
  const ArtifactOrigin({
    required this.messageId,
    required this.conversationId,
    this.threadRootId,
    this.via = 'link',
  });

  static ArtifactOrigin? fromJson(Object? json) {
    final map = _map(json);
    final message = map['messageId'], conversation = map['conversationId'];
    if (message is! String || conversation is! String) return null;
    return ArtifactOrigin(
      messageId: message,
      conversationId: conversation,
      threadRootId: _stringOrNull(map['threadRootId']),
      via: _string(map['via'], 'link'),
    );
  }

  final String messageId, conversationId;
  final String? threadRootId;
  final String via;
}

/// Everything the viewer needs for one version (shared `ArtifactViewerData`).
class ArtifactViewerData {
  const ArtifactViewerData({
    required this.card,
    this.files = const [],
    this.versions = const [],
    this.capabilities = const ArtifactCapabilities(),
    this.following = false,
    this.origin,
    this.frame,
  });

  static ArtifactViewerData? fromJson(Object? json) {
    final map = _map(json);
    final card = ArtifactCard.fromJson(map['card']);
    if (card == null) return null;
    final frame = map['frame'];
    return ArtifactViewerData(
      card: card,
      files: [
        if (map['files'] case final List files)
          for (final file in files) ?ArtifactFile.fromJson(file),
      ],
      versions: [
        if (map['versions'] case final List versions)
          for (final version in versions) ?ArtifactVersion.fromJson(version),
      ],
      capabilities: ArtifactCapabilities.fromJson(map['capabilities']),
      following: map['following'] == true,
      origin: ArtifactOrigin.fromJson(map['origin']),
      frame: frame is Map ? frame.cast<String, Object?>() : null,
    );
  }

  final ArtifactCard card;
  final List<ArtifactFile> files;

  /// Newest first.
  final List<ArtifactVersion> versions;
  final ArtifactCapabilities capabilities;
  final bool following;
  final ArtifactOrigin? origin;

  /// The viewer route's own frame answer for the shown version: its ticket
  /// opens once within 60 seconds, so only the first mount may use it (Web
  /// `takeViewerFrame`). Never logged or kept.
  final Map<String, Object?>? frame;

  ArtifactFile? get entry =>
      files.where((file) => file.entry).firstOrNull ?? files.firstOrNull;

  ArtifactViewerData copyWith({bool? following, ArtifactCard? card}) =>
      ArtifactViewerData(
        card: card ?? this.card,
        files: files,
        versions: versions,
        capabilities: capabilities,
        following: following ?? this.following,
        origin: origin,
      );
}

/// An Artifact destination, optionally pinned to a version or focused on news.
class ArtifactLinkTarget {
  const ArtifactLinkTarget(this.id, [this.version])
    : commentId = null,
      reviewId = null;

  const ArtifactLinkTarget.activity(
    this.id,
    this.version, {
    this.commentId,
    this.reviewId,
  });

  final String id;
  final int? version;
  final String? commentId, reviewId;

  @override
  bool operator ==(Object other) =>
      other is ArtifactLinkTarget &&
      other.id == id &&
      other.version == version &&
      other.commentId == commentId &&
      other.reviewId == reviewId;

  @override
  int get hashCode => Object.hash(id, version, commentId, reviewId);

  @override
  String toString() => version == null ? id : '$id@v$version';
}

/// A reference to an Artifact as this reader sees it: the object summaries'
/// answer for one link (Web `ArtifactLink`).
sealed class ArtifactLinkState {
  const ArtifactLinkState(this.target);
  final ArtifactLinkTarget target;
}

class ArtifactLinkLoading extends ArtifactLinkState {
  const ArtifactLinkLoading(super.target);
}

class ArtifactLinkOk extends ArtifactLinkState {
  const ArtifactLinkOk(super.target, this.card);
  final ArtifactCard card;
}

class ArtifactLinkDeleted extends ArtifactLinkState {
  const ArtifactLinkDeleted(super.target, this.deleted);
  final ArtifactDeleted deleted;
}

/// No access, not found, revoked, or a read that failed: the link in the text
/// is all this reader gets (F11).
class ArtifactLinkUnavailable extends ArtifactLinkState {
  const ArtifactLinkUnavailable(super.target, {this.error = false});
  final bool error;
}

// --- ids and links (shared artifactShortId.ts, artifactRef.ts) ---

const _alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
final _idPattern = RegExp(r'^pt_[A-Za-z0-9-]{1,64}$');
final _uuidId = RegExp(
  r'^pt_([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$',
);
final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);
final _short = RegExp(r'^[1-9A-HJ-NP-Za-km-z]{22}$');
final _versionPattern = RegExp(r'^[1-9]\d{0,8}$');

/// The 22-character base58 form of a uuid (`encodeArtifactShortId`).
String encodeArtifactShortId(String uuid) {
  if (!_uuid.hasMatch(uuid)) throw RangeError('not a uuid');
  final hex = uuid.replaceAll('-', '');
  final digits = List<int>.filled(22, 0);
  for (var at = 0; at < hex.length; at += 2) {
    var carry = int.parse(hex.substring(at, at + 2), radix: 16);
    for (var i = 21; i >= 0; i--) {
      carry += digits[i] * 256;
      digits[i] = carry % 58;
      carry ~/= 58;
    }
  }
  return digits.map((digit) => _alphabet[digit]).join();
}

/// The uuid of a short id, or null (`decodeArtifactShortId`).
String? decodeArtifactShortId(String value) {
  if (!_short.hasMatch(value)) return null;
  final bytes = List<int>.filled(16, 0);
  for (final char in value.split('')) {
    var carry = _alphabet.indexOf(char);
    for (var i = 15; i >= 0; i--) {
      carry += bytes[i] * 58;
      bytes[i] = carry & 0xff;
      carry >>= 8;
    }
    if (carry != 0) return null;
  }
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// `pt_…` or a short id, as an Artifact id (`parseArtifactId`).
String? parseArtifactId(String value) {
  if (_idPattern.hasMatch(value)) return value;
  final uuid = decodeArtifactShortId(value);
  return uuid == null ? null : 'pt_$uuid';
}

/// The id a link carries (`artifactLinkId`): the short form of a uuid id.
String artifactLinkId(String id) {
  final uuid = _uuidId.firstMatch(id)?.group(1);
  return uuid == null ? id : encodeArtifactShortId(uuid);
}

/// `/artifacts/<short id>[/v/<n>]` (`artifactPagePath`).
String artifactPagePath(String id, [int? version]) =>
    '/artifacts/${artifactLinkId(id)}${version == null ? '' : '/v/$version'}';

/// The Artifact's one address on [webOrigin] (Web `artifactUrl`).
Uri artifactUrl(Uri webOrigin, String id, [int? version]) =>
    Uri.parse('${webOrigin.origin}${artifactPagePath(id, version)}');

/// The Artifact a link names, on one of [appHosts] (`/artifacts/<id>`,
/// `/s/<slug>/artifacts/<id>`, `/v/<n>`), on `artifacts.raft.build`, or on a
/// `a-pt-<uuid>.raftusercontent.com` page (shared `parseArtifactRef`'s `id`
/// answers). Legacy raft-artifacts.com links name no workspace Artifact.
ArtifactLinkTarget? artifactLinkTarget(String link, List<String> appHosts) {
  final value = link.trim();
  if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(value)) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) return null;
  final List<String> segments;
  try {
    segments = [
      for (final segment in uri.path.split('/'))
        if (segment.isNotEmpty) Uri.decodeComponent(segment),
    ];
  } on ArgumentError {
    return null;
  }
  final host = uri.host.toLowerCase();
  final content = RegExp(
    r'^a-pt-([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.raftusercontent\.com$',
  ).firstMatch(host);
  if (content != null) return ArtifactLinkTarget('pt_${content.group(1)}');
  ArtifactLinkTarget? withVersion(List<String> rest) {
    if (rest.isEmpty) return null;
    final id = parseArtifactId(rest[0]);
    if (id == null) return null;
    if (rest.length >= 3 && rest[1] == 'v') {
      return _versionPattern.hasMatch(rest[2])
          ? ArtifactLinkTarget(id, int.parse(rest[2]))
          : null;
    }
    return ArtifactLinkTarget(id);
  }

  if (host == 'artifacts.raft.build') return withVersion(segments);
  if (const {
    'raft-artifacts.com',
    'www.raft-artifacts.com',
    'artifact-share.botiverse.dev',
  }.contains(host)) {
    return null;
  }
  if (!appHosts.any((appHost) => appHost.toLowerCase() == host)) return null;
  if (segments.isNotEmpty && segments[0] == 'artifacts') {
    return withVersion(segments.sublist(1));
  }
  if (segments.length > 2 && segments[0] == 's' && segments[2] == 'artifacts') {
    return withVersion(segments.sublist(3));
  }
  return null;
}
