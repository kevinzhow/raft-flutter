// What the viewer's menu does: download a file or all of them, copy the
// link, follow, open in the browser.
//
// Source: packages/web/src/apps/artifacts/{artifactDownloads.ts,
// ArtifactViewerMenu.tsx} at v1.24.0-source.1.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../platform/attachment_files.dart';
import 'artifact_api.dart';
import 'artifact_models.dart';

/// `Title v3.zip`, safe for any file system (Web `artifactZipName`).
String artifactZipName(String title, int version) {
  final safe = title
      .replaceAll(RegExp(r'[^A-Za-z0-9 ._-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceFirst(RegExp(r'^\.+'), '');
  final cut = (safe.length > 80 ? safe.substring(0, 80) : safe).trim();
  return '${cut.isEmpty ? 'artifact' : cut} v$version.zip';
}

/// Why a zip wasn't made, in Web's words (`zipRefusal`).
String artifactZipRefusal(String? code) => switch (code) {
  'DOWNLOAD_TOO_LARGE' =>
    'These files are too large to download as one zip. Download them one by one from Files.',
  'BUSY' || 'RATE_LIMITED' =>
    'Too many downloads are being prepared right now. Wait a few seconds, then try again.',
  _ => 'Couldn\'t download the files. Try again.',
};

/// A content type for a saved file, from its name.
String artifactMimeType(String name) {
  final dot = name.lastIndexOf('.');
  final extension = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return switch (extension) {
    'html' || 'htm' => 'text/html',
    'md' || 'markdown' => 'text/markdown',
    'txt' => 'text/plain',
    'csv' => 'text/csv',
    'json' => 'application/json',
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'svg' => 'image/svg+xml',
    'mp4' => 'video/mp4',
    'zip' => 'application/zip',
    _ => 'application/octet-stream',
  };
}

/// Saves bytes where the person picks. Tests replace it.
typedef ArtifactSaveBytes =
    Future<String?> Function(Uint8List bytes, String filename, String mime);

Future<String?> _platformSave(Uint8List bytes, String filename, String mime) =>
    AttachmentFiles().saveBytes(
      bytes: bytes,
      filename: filename,
      mimeType: mime,
      authorized: () => true,
    );

class ArtifactViewerActions {
  ArtifactViewerActions({
    required this.api,
    required this.webOrigin,
    required this.current,
    ArtifactSaveBytes? save,
    Future<bool> Function(Uri)? openExternal,
  }) : save = save ?? _platformSave,
       openExternal =
           openExternal ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

  final ArtifactApi api;
  final Uri webOrigin;

  /// False once the viewer closed or the account / server changed: nothing
  /// is saved or shown for a request started before.
  final bool Function() current;
  final ArtifactSaveBytes save;
  final Future<bool> Function(Uri) openExternal;

  /// The Artifact's address: pinned when the card is (Web `artifactUrl`).
  Uri addressOf(ArtifactCard card) =>
      artifactUrl(webOrigin, card.id, card.pinned ? card.version : null);

  /// Downloads one file of the shown version.
  Future<void> downloadFile(
    BuildContext context,
    ArtifactCard card,
    ArtifactFile file,
  ) async {
    try {
      final bytes = await api.fileBytes(card.id, file.path, card.version);
      if (!current()) return;
      await save(bytes, file.name, artifactMimeType(file.name));
    } catch (_) {
      if (current() && context.mounted) {
        showRaftToast(
          context,
          raftText(context, 'Couldn\'t download the file. Try again.'),
        );
      }
    }
  }

  /// Download (one file) or Download all (a zip of every file).
  Future<void> download(BuildContext context, ArtifactViewerData data) async {
    final card = data.card;
    if (data.files.length > 1) {
      try {
        final bytes = await api.zipBytes(card.id, card.version);
        if (!current()) return;
        await save(
          bytes,
          artifactZipName(card.title, card.version),
          'application/zip',
        );
      } catch (error) {
        if (current() && context.mounted) {
          showRaftToast(
            context,
            raftText(context, artifactZipRefusal(artifactErrorCode(error))),
          );
        }
      }
      return;
    }
    final entry = data.entry;
    if (entry != null) await downloadFile(context, card, entry);
  }

  Future<void> copyLink(BuildContext context, ArtifactCard card) async {
    await Clipboard.setData(ClipboardData(text: addressOf(card).toString()));
    if (context.mounted) {
      showRaftToast(
        context,
        raftText(context, 'Link copied.'),
        tone: RaftToastRecipeTone.success,
      );
    }
  }

  Future<void> openInBrowser(ArtifactCard card) =>
      openExternal(addressOf(card));

  /// Follow / Unfollow; the server's answer wins. A failure changes
  /// nothing and says nothing (Web drops it).
  Future<bool?> setFollowing(ArtifactCard card, bool following) async {
    try {
      return await api.setFollowing(card.id, following);
    } catch (_) {
      return null;
    }
  }
}
