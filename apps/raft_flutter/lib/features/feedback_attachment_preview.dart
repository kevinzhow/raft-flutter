import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/attachment_files.dart';

/// Web `AboutFeedbackDialog` attachment lightbox: a feedback screenshot (sent
/// with a ticket, or picked and not sent yet) opens in a lightbox titled with
/// its file name, with Download and Close.
///
/// [bytes] are already in memory. Returns when the lightbox is closed.
Future<void> showFeedbackImage(
  BuildContext context, {
  required String filename,
  required String contentType,
  required Uint8List bytes,
  AttachmentFiles? files,
}) async {
  final zoom = TransformationController();
  final navigator = Navigator.of(context, rootNavigator: true);
  final host = navigator.context;
  final imageKey = GlobalKey();
  late final DialogRoute<void> route;
  void close() {
    if (route.isActive) route.navigator?.removeRoute(route);
  }

  Future<void> download() async {
    try {
      await (files ?? AttachmentFiles()).saveBytes(
        bytes: bytes,
        filename: filename,
        mimeType: contentType,
        authorized: () => route.isActive,
      );
    } catch (_) {
      if (route.isActive && host.mounted) {
        showRaftToast(host, 'Download failed. Try again.');
      }
    }
  }

  route = RaftFullBleedDialogRoute<void>(
    context: context,
    builder: (context) => RaftAttachmentLightbox(
      title: filename,
      titleBold: true,
      onResetZoom: () => zoom.value = Matrix4.identity(),
      onClose: close,
      actions: [
        RaftLightboxIconAction(
          glyph: RaftGlyph.download,
          label: raftText(context, 'Download'),
          onPressed: download,
        ),
      ],
      child: RaftLightboxStageTap(
        imageKey: imageKey,
        onClose: close,
        child: InteractiveViewer(
          transformationController: zoom,
          child: Center(
            child: RaftSizedImage.memory(
              bytes,
              key: imageKey,
              fit: BoxFit.contain,
              zoom: raftZoomableImageScale,
              evictOnDispose: true,
            ),
          ),
        ),
      ),
    ),
  );
  await navigator.push(route);
  zoom.dispose();
}
