import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/media_failure.dart';

/// What a failed audio or video card offers beside its message.
///
/// Each action answers the cause: a proxy that does not answer is fixed in
/// Settings > Network; a dropped connection or an expired link is retried
/// (which signs the link again); an undecodable file is only downloaded.
class MediaFailureActions {
  const MediaFailureActions({this.retry = false, this.networkSettings = false});
  final bool retry, networkSettings;

  static MediaFailureActions of(MediaFailure? failure) =>
      switch (failure?.kind ?? MediaFailureKind.unknown) {
        MediaFailureKind.proxyUnreachable ||
        MediaFailureKind.proxyAuth ||
        MediaFailureKind.network => const MediaFailureActions(
          retry: true,
          networkSettings: true,
        ),
        MediaFailureKind.expired ||
        MediaFailureKind.unknown => const MediaFailureActions(retry: true),
        // A missing or undecodable file fails the same way again.
        MediaFailureKind.notFound ||
        MediaFailureKind.unsupported => const MediaFailureActions(),
      };
}

/// The localized message for [failure]: the cause in words, never the raw
/// player text. A proxy is named by host:port (never credentials).
String mediaFailureMessage(
  BuildContext context,
  MediaFailure? failure, {
  required bool video,
}) {
  final proxy = failure?.proxy;
  var kind = failure?.kind ?? MediaFailureKind.unknown;
  // A proxy failure that names no proxy cannot say which one to check.
  if ((kind == MediaFailureKind.proxyUnreachable ||
          kind == MediaFailureKind.proxyAuth) &&
      (proxy == null || proxy.isEmpty)) {
    kind = MediaFailureKind.network;
  }
  return raftFormat(
    context,
    switch (kind) {
      MediaFailureKind.proxyUnreachable =>
        'Cannot reach the proxy {proxy}. Check Network settings, then try again.',
      MediaFailureKind.proxyAuth =>
        'The proxy {proxy} needs a username and password. Check Network settings.',
      MediaFailureKind.network =>
        'Cannot reach the server. Check your connection and try again.',
      MediaFailureKind.expired =>
        'This link has expired or access was denied. Try again.',
      MediaFailureKind.notFound => 'This file is no longer available.',
      MediaFailureKind.unsupported when video =>
        'This video may use a codec this browser cannot preview.',
      MediaFailureKind.unsupported =>
        'This audio may use a codec this app cannot play.',
      MediaFailureKind.unknown => 'The media could not be played.',
    },
    {'proxy': proxy ?? ''},
  );
}
