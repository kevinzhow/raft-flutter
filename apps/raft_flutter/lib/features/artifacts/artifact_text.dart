// The words an Artifact surface shows: its facts, who did what when, where it
// lives. Source: packages/web/src/apps/artifacts/{artifactFacts,
// artifactHomeWords,ArtifactScopeLabel,ArtifactVersionHistory}.ts(x) at
// v1.24.0-source.1.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../icu_message.dart';
import '../resource_cards.dart' show resourceRelativeTime;
import 'artifact_models.dart';

/// The kind's file badge (Web `ARTIFACT_KIND_BADGE`).
String? artifactKindBadge(ArtifactKind kind) => switch (kind) {
  ArtifactKind.html => 'HTML',
  ArtifactKind.markdown => 'MD',
  ArtifactKind.text => 'TXT',
  ArtifactKind.csv => 'CSV',
  ArtifactKind.image => 'IMG',
  ArtifactKind.pdf => 'PDF',
  ArtifactKind.video => 'VIDEO',
  ArtifactKind.other => null,
};

/// The kind's icon where the design system has one (no Artifact glyph yet).
RaftGlyph artifactKindGlyph(ArtifactKind kind) => switch (kind) {
  ArtifactKind.html => RaftGlyph.code,
  ArtifactKind.image => RaftGlyph.image,
  ArtifactKind.video => RaftGlyph.video,
  ArtifactKind.csv => RaftGlyph.table,
  _ => RaftGlyph.fileText,
};

String _number(BuildContext context, num value, {int fraction = 0}) {
  final fixed = value.toStringAsFixed(fraction);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return parts.length > 1 ? '$whole.${parts[1]}' : whole;
}

/// `formatBytes`: B under a KiB, KB (rounded) under a MiB, else MB (one decimal).
String artifactBytes(BuildContext context, int bytes) {
  if (bytes < 1024) {
    return raftFormat(context, '{value} B', {'value': _number(context, bytes)});
  }
  if (bytes < 1024 * 1024) {
    return raftFormat(context, '{value} KB', {
      'value': _number(context, (bytes / 1024).round()),
    });
  }
  return raftFormat(context, '{value} MB', {
    'value': _number(context, bytes / 1024 / 1024, fraction: 1),
  });
}

/// The card's fact line (`formatArtifactFacts`); null for pages (HTML and
/// Markdown say nothing about their size).
String? artifactFactsLine(BuildContext context, ArtifactCard card) {
  final kind = card.kind, facts = card.facts;
  if (kind == ArtifactKind.html || kind == ArtifactKind.markdown) return null;
  final parts = <String>[];
  if (kind == ArtifactKind.text && facts.lines != null) {
    parts.add(
      icuText(context, '{count, plural, one {# line} other {# lines}}', {
        'count': facts.lines,
      }),
    );
  }
  if (kind == ArtifactKind.csv && facts.rows != null) {
    parts.add(
      facts.columns != null
          ? icuText(
              context,
              '{rows, plural, one {# row} other {# rows}} × {columns, plural, one {# column} other {# columns}}',
              {'rows': facts.rows, 'columns': facts.columns},
            )
          : icuText(context, '{count, plural, one {# row} other {# rows}}', {
              'count': facts.rows,
            }),
    );
  }
  if (kind == ArtifactKind.csv && facts.columnNames.isNotEmpty) {
    parts.add(
      facts.columnNames.reduce(
        (list, name) =>
            raftFormat(context, '{list}, {name}', {'list': list, 'name': name}),
      ),
    );
  }
  if (kind == ArtifactKind.image &&
      (facts.width ?? 0) > 0 &&
      (facts.height ?? 0) > 0) {
    parts.add(
      raftFormat(context, '{width} × {height}', {
        'width': facts.width,
        'height': facts.height,
      }),
    );
  }
  if (kind == ArtifactKind.pdf && facts.pages != null) {
    parts.add(
      icuText(context, '{count, plural, one {# page} other {# pages}}', {
        'count': facts.pages,
      }),
    );
  }
  if (parts.isEmpty) parts.add(artifactBytes(context, facts.sizeBytes));
  return parts.join(' · ');
}

/// An actor's name, or what is gone (`artifactActorName`).
String artifactActorName(BuildContext context, ArtifactActor actor) =>
    actor.shownName(
      deletedAgent: raftText(context, 'Deleted agent'),
      deletedUser: raftText(context, 'Deleted user'),
      system: raftText(context, 'System'),
    );

/// How long ago, as the Web's `formatRelativeTime` says it.
String artifactRelativeTime(BuildContext context, DateTime? at) => at == null
    ? ''
    : resourceRelativeTime(
        at.toIso8601String(),
        chinese: Localizations.maybeLocaleOf(context)?.languageCode == 'zh',
      );

/// "Developer updated 2 days ago" (`formatArtifactUpdated`).
String artifactUpdatedLine(BuildContext context, ArtifactCard card) {
  final name = artifactActorName(context, card.author);
  final time = artifactRelativeTime(context, card.updatedAt);
  return time.isEmpty
      ? name
      : raftFormat(context, '{name} updated {time}', {
          'name': name,
          'time': time,
        });
}

/// "Deleted by Developer 2 days ago" (`formatArtifactDeleted`).
String artifactDeletedLine(BuildContext context, ArtifactDeleted deleted) {
  final actor = deleted.deletedBy;
  final name = actor.displayName.trim().isNotEmpty
      ? actor.displayName
      : actor.name.trim().isNotEmpty
      ? actor.name
      : null;
  final time = artifactRelativeTime(context, deleted.deletedAt);
  if (name != null && time.isNotEmpty) {
    return raftFormat(context, 'Deleted by {name} {time}', {
      'name': name,
      'time': time,
    });
  }
  if (name != null) {
    return raftFormat(context, 'Deleted by {name}', {'name': name});
  }
  if (time.isNotEmpty) {
    return raftFormat(context, 'Deleted {time}', {'time': time});
  }
  return raftText(context, 'Deleted');
}

/// Where it lives, in words (`scopeText` / `conversationName`): "#general",
/// a DM's peer, "Everyone in Dev Workspace", "Anyone with the link", or
/// "From another server" for another server's public Artifact.
String artifactScopeLabel(
  BuildContext context,
  ArtifactHome home, {
  bool fromAnotherServer = false,
  String? serverName,
}) {
  if (fromAnotherServer && home.kind == 'public') {
    return raftText(context, 'From another server');
  }
  switch (home.kind) {
    case 'public':
      return raftText(context, 'Anyone with the link');
    case 'conversation':
      final peer = home.peerDisplayName;
      return peer != null && peer.isNotEmpty ? peer : home.conversationName;
    default:
      return serverName == null || serverName.isEmpty
          ? raftText(context, 'Everyone in this server')
          : raftFormat(context, 'Everyone in {server}', {'server': serverName});
  }
}

/// The scope's icon (`homeIcon`).
RaftGlyph artifactScopeGlyph(ArtifactHome home) => switch (home.kind) {
  'server' => RaftGlyph.users,
  'public' => RaftGlyph.globe,
  _ => switch (home.conversationType) {
    'private' => RaftGlyph.lock,
    'dm' => RaftGlyph.messageCircle,
    _ => RaftGlyph.hash,
  },
};

/// "v3", or "v3 · latest v5" for a pinned card behind the latest.
String artifactVersionLabel(BuildContext context, int version, [int? latest]) =>
    latest != null && latest > version
    ? raftFormat(context, 'v{version} · latest v{latest}', {
        'version': version,
        'latest': latest,
      })
    : raftFormat(context, 'v{version}', {'version': version});

/// The changed files of a version, at most eight named (`useChangedFiles`).
String? artifactChangedFiles(BuildContext context, ArtifactVersion version) {
  if (version.changedPaths.isEmpty) return null;
  final files = version.changedPaths.take(8).join(raftText(context, ', '));
  final more = version.changedPaths.length - 8;
  return more > 0
      ? raftFormat(context, 'Changed: {files}, +{count} more', {
          'files': files,
          'count': more,
        })
      : raftFormat(context, 'Changed: {files}', {'files': files});
}
