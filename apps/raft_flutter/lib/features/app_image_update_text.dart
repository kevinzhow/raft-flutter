import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_updater/raft_updater.dart';

/// What the Updates card says while a Linux AppImage updates itself in place.
/// Every failure names its cause and the next step; the release page is always
/// the fallback.

String appImageStageText(BuildContext context, AppImageUpdateStatus status) {
  final percent = (status.progress * 100).round();
  return switch (status.stage) {
    AppImageUpdateStage.downloading => raftFormat(
      context,
      'Downloading the changes… {percent}%',
      {'percent': percent},
    ),
    AppImageUpdateStage.verifying => raftText(context, 'Verifying the update…'),
    AppImageUpdateStage.installing => raftText(
      context,
      'Installing the update…',
    ),
    _ => raftText(context, 'Comparing with your current version…'),
  };
}

String appImageFailureText(
  BuildContext context,
  AppImageUpdateFailure failure,
) {
  final detail = failure.detail;
  return switch (failure.kind) {
    AppImageUpdateFailureKind.network => raftFormat(
      context,
      "Couldn't reach {host}. Check your connection and try again.",
      {'host': detail.isEmpty ? 'github.com' : detail},
    ),
    AppImageUpdateFailureKind.http => raftFormat(
      context,
      'The update server answered with an unexpected status ({status}). Try again later or download the update from the release page.',
      {'status': detail},
    ),
    AppImageUpdateFailureKind.noDeltaFile => raftText(
      context,
      'This release has no update file for in-place updates. Download the new AppImage from the release page.',
    ),
    AppImageUpdateFailureKind.releaseMismatch => raftText(
      context,
      "The update files don't match this release. Download the new AppImage from the release page.",
    ),
    AppImageUpdateFailureKind.rangesUnsupported => raftText(
      context,
      "The server doesn't support partial downloads. Download the new AppImage from the release page.",
    ),
    AppImageUpdateFailureKind.diskFull => raftFormat(
      context,
      'There is not enough free space in {folder} for the update.',
      {'folder': detail},
    ),
    AppImageUpdateFailureKind.notWritable => raftFormat(
      context,
      "Raft can't write to {folder}. Move the AppImage to a folder you own, or download the update from the release page.",
      {'folder': detail},
    ),
    AppImageUpdateFailureKind.missingChecksum => raftText(
      context,
      'This release has no checksum to verify the update against. Download it from the release page.',
    ),
    AppImageUpdateFailureKind.missingSignature => raftText(
      context,
      'This release has no signature to verify the update against. Download it from the release page.',
    ),
    AppImageUpdateFailureKind.badSignature => raftText(
      context,
      "The downloaded update isn't signed by Raft and was discarded. Your current version is unchanged. Download the update from the release page.",
    ),
    AppImageUpdateFailureKind.verification => raftText(
      context,
      'The downloaded update failed its integrity check and was discarded. Your current version is unchanged. Try again or download the update from the release page.',
    ),
    AppImageUpdateFailureKind.replace => raftText(
      context,
      "The new version couldn't be moved into place. Your current version is unchanged. Download the update from the release page.",
    ),
    AppImageUpdateFailureKind.cancelled => raftText(
      context,
      'The update was cancelled. Your current version is unchanged.',
    ),
    AppImageUpdateFailureKind.unexpected => raftText(
      context,
      'The update stopped unexpectedly. Your current version is unchanged. Download the update from the release page.',
    ),
  };
}
