import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../platform/attachment_files.dart';
import '../platform/native_sharing.dart';
import 'attachment_view.dart';
import 'message_presentation.dart';
import 'message_selection.dart';
import 'private_route_guard.dart';

/// A reviewed full-content artifact is kept only in memory until the user
/// chooses a real save/share action. No signed capability enters the PNG.
Future<bool?> previewMessageImage(
  BuildContext context,
  WorkspaceController w, {
  required List<SelectedMessageRow> messages,
  required double width,
  List<RaftTextReference> references = const [],
  bool thread = false,
  AttachmentFiles? files,
  NativeSharing? sharing,
  String Function(DateTime)? clock,
}) async {
  if (messages.isEmpty || messages.length > MessageSelection.limit) {
    return false;
  }
  if (messages.fold<int>(0, (n, r) => n + r.message.content.length) > 50000) {
    throw const RaftApiException(
      'Select fewer or shorter messages to export an image.',
    );
  }
  String scope() => jsonEncode([
    w.client.generation,
    w.client.user?.id,
    w.server?.id,
    w.server?.string('role'),
    w.channel?.id,
  ]);
  final authority = scope(),
      channelAuthority = w.channel == null
          ? null
          : Map<String, dynamic>.from(
              jsonDecode(jsonEncode(w.channel!.json)) as Map,
            ),
      parentId = w.threadParent?.id,
      threadChannelId = w.threadChannelId;
  final snapshots = {
    for (final row in messages)
      row.message.id: selectedMessageFingerprint(row.message),
  };
  bool current() {
    if (!context.mounted || authority != scope()) return false;
    if (channelAuthorityReduced(channelAuthority, w.channel?.json)) {
      return false;
    }
    if (thread &&
        (parentId != w.threadParent?.id ||
            threadChannelId != w.threadChannelId)) {
      return false;
    }
    final rows = <String, RaftMessage>{
      for (final m in w.messages) m.id: m,
      for (final m in w.replies) m.id: m,
      if (w.threadParent != null) w.threadParent!.id: w.threadParent!,
      for (final m in w.messages)
        if (m.threadId != null)
          for (final row in w.ledger.messages(m.threadId!))
            '${row['id']}': RaftMessage(row),
    };
    return snapshots.entries.every(
      (e) =>
          rows[e.key] != null &&
          selectedMessageFingerprint(rows[e.key]!) == e.value,
    );
  }

  if (!current()) return false;
  final renderKey = GlobalKey();
  final ready = <Completer<void>>[];
  final revoked = Completer<void>();
  final displayWidth = width.clamp(240.0, 768.0);
  final theme = Theme.of(context), media = MediaQuery.of(context);
  final overlay = Overlay.of(context);
  OverlayEntry? entry;
  void revoke() {
    if (!current()) {
      if (!revoked.isCompleted) revoked.complete();
      entry?.remove();
      entry = null;
    }
  }

  w.addListener(revoke);
  Uint8List? png;
  try {
    final fontSize = switch (w.client.user?.string(
      'preferredMessageBodyFontSize',
    )) {
      'sm' => 12.0,
      'lg' => 16.0,
      _ => 14.0,
    };
    final children = <Widget>[];
    for (final row in messages) {
      final m = row.message;
      Widget attachment(Map<String, dynamic> metadata) {
        final loaded = Completer<void>();
        ready.add(loaded);
        return AttachmentView(
          controller: w,
          metadata: metadata,
          messageId: m.id,
          exportMode: true,
          onExportReady: () {
            if (!loaded.isCompleted) loaded.complete();
          },
        );
      }

      children.add(
        Padding(
          padding: EdgeInsets.only(left: row.isThreadChild ? 32 : 0),
          child: RaftMessageTile(
            author: m.author,
            content: m.content,
            timestamp: m.createdAt == null
                ? ''
                : clock?.call(m.createdAt!) ??
                      TimeOfDay.fromDateTime(m.createdAt!.toLocal())
                          .format(context),
            badge: m.string('senderType') == 'agent'
                ? raftText(context, 'Agent')
                : null,
            bodyFontSize: fontSize,
            body: MessagePresentation(
              controller: w,
              message: m,
              onExternalLink: (_) {},
              directoryReferences: references,
              exportMode: true,
              exportAttachmentBuilder: attachment,
              fontSize: fontSize,
            ),
            attachments:
                m.json['actionMetadata'] is Map &&
                    m.json['actionMetadata']['kind'] == 'forwarded-bundle'
                ? []
                : m.attachments,
            collapseLongMessages: false,
            reactedEmojis: w.reactionViewer.reacted(m.id) ?? const {},
            attachmentBuilder: attachment,
            reactions: m.json['reactions'] is List
                ? (m.json['reactions'] as List)
                      .whereType<Map>()
                      .map((r) => Map<String, dynamic>.from(r))
                      .toList()
                : const [],
          ),
        ),
      );
    }
    // The ancestor's opacity keeps the clone unobtrusive; its own boundary
    // retains the original opaque conversation surface for rasterization.
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 0,
        left: 0,
        width: displayWidth,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Opacity(
              opacity: .01,
              child: MediaQuery(
                data: media,
                child: Theme(
                  data: theme,
                  child: RepaintBoundary(
                    key: renderKey,
                    child: RaftMessageExportSurface(
                      width: displayWidth,
                      messages: children,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry!);
    await WidgetsBinding.instance.endOfFrame;
    if (!current() || entry == null) return false;
    await Future.any([Future.wait(ready.map((r) => r.future)), revoked.future])
        .timeout(const Duration(seconds: 10));
    if (!current() || entry == null) return false;
    await WidgetsBinding.instance.endOfFrame;
    if (!current() || entry == null) return false;
    bool decoded(Element root) {
      var pending = false;
      void visit(Element element) {
        if (element is RenderObjectElement &&
            element.renderObject is RenderImage &&
            (element.renderObject as RenderImage).image == null) {
          pending = true;
        }
        element.visitChildren(visit);
      }

      visit(root);
      return !pending;
    }

    for (
      var i = 0;
      i < 100 && !decoded(renderKey.currentContext! as Element);
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await WidgetsBinding.instance.endOfFrame;
      if (!current() || entry == null) return false;
    }
    if (!decoded(renderKey.currentContext! as Element)) {
      throw const RaftApiException(
        'Rendering the message image timed out. Try a smaller selection.',
      );
    }
    final boundary =
        renderKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    for (var i = 0; i < 5 && boundary.debugNeedsPaint; i++) {
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame;
      if (!current() || entry == null) return false;
    }
    if (boundary.debugNeedsPaint) {
      throw const RaftApiException('The message image could not be rendered.');
    }
    final ratio = math.min(3.0, math.max(2.0, media.devicePixelRatio));
    final size = boundary.size;
    if (size.height > 4096 ||
        size.width * size.height * ratio * ratio > 16000000) {
      throw const RaftApiException(
        'Select fewer or shorter messages to export an image.',
      );
    }
    final image = await boundary.toImage(pixelRatio: ratio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw const RaftApiException(
          'The message image could not be rendered.',
        );
      }
      png = data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
    entry?.remove();
    entry = null;
    if (!current() || !context.mounted) return false;
    final filename = AttachmentFiles.safeFilename(
      'raft-${w.channel?.name ?? 'export'}-${DateTime.now().toIso8601String().substring(0, 10)}.png',
    );
    return await showDialog<bool>(
      context: context,
      builder: (_) => MessageImageReview(
        controller: w,
        bytes: png!,
        filename: filename,
        authorized: current,
        files: files,
        sharing: sharing,
      ),
    );
  } on TimeoutException {
    throw const RaftApiException(
      'Rendering the message image timed out. Try a smaller selection.',
    );
  } finally {
    entry?.remove();
    w.removeListener(revoke);
    if (png != null) {
      await MemoryImage(png).evict();
      png.fillRange(0, png.length, 0);
    }
  }
}

class MessageImageReview extends StatefulWidget {
  const MessageImageReview({
    super.key,
    required this.controller,
    required this.bytes,
    required this.filename,
    required this.authorized,
    this.files,
    this.sharing,
  });
  final WorkspaceController controller;
  final Uint8List bytes;
  final String filename;
  final bool Function() authorized;
  final AttachmentFiles? files;
  final NativeSharing? sharing;
  @override
  State<MessageImageReview> createState() => _MessageImageReviewState();
}

class _MessageImageReviewState extends State<MessageImageReview> {
  late final files = widget.files ?? AttachmentFiles();
  late final sharing = widget.sharing ?? NativeSharing();
  SharedFileLease? lease;
  bool busy = false;
  String? error;
  bool get current => mounted && widget.authorized();
  void changed() {
    if (!current) {
      final route = ModalRoute.of(context);
      if (route?.isActive == true) route!.navigator?.removeRoute(route);
      unawaited(lease?.dispose() ?? Future<void>.value());
      lease = null;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(changed);
    unawaited(lease?.dispose() ?? Future<void>.value());
    lease = null;
    super.dispose();
  }

  Future<void> act(bool share) async {
    if (busy || !current) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (share) {
        if (lease == null || !await lease!.file.exists()) {
          lease = await sharing.prepareBytes(
            widget.bytes,
            filename: widget.filename,
            authorized: () => current,
          );
        }
        if (!current || lease == null) {
          await lease?.dispose();
          lease = null;
          return;
        }
        await sharing.shareFile(lease!, 'image/png');
        // Android chooser completion does not prove recipient delivery. Keep
        // the reviewed image and selection available on dismissal/cancellation.
      } else {
        final saved = await files.saveBytes(
          bytes: widget.bytes,
          filename: widget.filename,
          mimeType: 'image/png',
          authorized: () => current,
        );
        if (mounted &&
            saved != null &&
            current &&
            ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pop(context, true);
        }
      }
    } catch (_) {
      if (current) {
        setState(
          () => error = raftText(
            context,
            'The message image could not be exported.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Dialog.fullscreen(
      backgroundColor: RaftLightboxRecipe(RaftTokens.of(context)).backdrop,
      child: SafeArea(child: Center(child: SizedBox(
        width: 768,
        height: MediaQuery.sizeOf(context).height * .85,
        child: RaftImageReview(
          preview: Image.memory(
            widget.bytes,
            fit: BoxFit.contain,
            semanticLabel: raftText(context, 'Preview of selected messages'),
            gaplessPlayback: false,
          ),
          onClose: () => Navigator.pop(context, false),
          onSave: () => act(false),
          onShare: sharing.supported ? () => act(true) : null,
          busy: busy,
          error: error,
        ),
      ))),
    ),
  );
}
