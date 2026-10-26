import 'message_type_scale.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../platform/attachment_files.dart';
import '../platform/image_clipboard.dart';
import '../platform/native_sharing.dart';
import 'attachment_view.dart';
import 'message_presentation.dart';
import 'message_selection.dart';
import 'message_share_artifact.dart';
import 'private_route_guard.dart';
import 'screenshot_budget.dart';

/// How long the render waits for its images; Web `SelectScreenshotTimeoutError`.
const _captureTimeout = Duration(seconds: 10);

/// Web `message.share.selectionTooLong`, `renderEmpty` and `renderTimedOut`.
const _tooLong = RaftUserError(
  'This selection is too long for one image. Select fewer messages and try again.',
);
const _renderEmpty = RaftUserError(
  'The image came out empty. Try again, or select fewer messages.',
);
const _renderTimedOut = RaftUserError('Rendering timed out after 10s');

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
  ImageClipboard? clipboard,
  Future<bool> Function(Uri)? openExternal,
  String Function(DateTime)? clock,
  bool Function()? authorized,
  Listenable? authorityChanges,
}) async {
  if (messages.isEmpty || messages.length > MessageSelection.limit) {
    return false;
  }
  if (messages.fold<int>(0, (n, r) => n + r.message.content.length) > 50000) {
    throw _tooLong;
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
      parentId = w.messageDomain.state.threadParent?.id,
      threadChannelId = w.threadChannelId;
  final snapshots = {
    for (final row in messages)
      row.message.id: selectedMessageFingerprint(row.message),
  };
  bool current() {
    if (!context.mounted ||
        authority != scope() ||
        (authorized != null && !authorized())) {
      return false;
    }
    if (channelAuthorityReduced(channelAuthority, w.channel?.json)) {
      return false;
    }
    if (thread &&
        (parentId != w.messageDomain.state.threadParent?.id ||
            threadChannelId != w.threadChannelId)) {
      return false;
    }
    final rows = <String, RaftMessage>{
      for (final m in w.messageDomain.messages) m.id: m,
      for (final m in w.replies) m.id: m,
      if (w.messageDomain.state.threadParent != null)
        w.messageDomain.state.threadParent!.id:
            w.messageDomain.state.threadParent!,
      for (final m in w.messageDomain.messages)
        if (m.threadId != null)
          for (final row in w.messageDomain.ledger.messages(m.threadId!))
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
      entry
        ?..remove()
        ..dispose();
      entry = null;
    }
  }

  w.addListener(revoke);
  authorityChanges?.addListener(revoke);
  Uint8List? png;
  try {
    final fontSize = messagePreferenceDisplaySize(context, switch (w.client.user
        ?.string('preferredMessageBodyFontSize')) {
      'sm' => 12.0,
      'lg' => 16.0,
      _ => 14.0,
    });
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
        .timeout(_captureTimeout);
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
      throw _renderTimedOut;
    }
    final boundary =
        renderKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    for (var i = 0; i < 5 && boundary.debugNeedsPaint; i++) {
      // ignore: raft_lints/avoid_unreviewed_idle_work -- Single request after a state change; nothing re-requests from the callback.
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame;
      if (!current() || entry == null) return false;
    }
    if (boundary.debugNeedsPaint) throw _renderEmpty;
    // Web screenshotBudget: the highest ratio that fits the pixel budget, and
    // no render at all when even 1x does not.
    final size = boundary.size;
    final ratio = planScreenshotPixelRatio(
      size.width,
      size.height,
      math.min(3.0, math.max(2.0, media.devicePixelRatio)),
    );
    if (ratio == null) throw _tooLong;
    final image = await boundary.toImage(pixelRatio: ratio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw _renderEmpty;
      png = data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
    try {
      validateScreenshotPng(png);
    } on ScreenshotInvalidOutputError {
      throw _renderEmpty;
    }
    entry
      ?..remove()
      ..dispose();
    entry = null;
    if (!current() || !context.mounted) return false;
    final filename = AttachmentFiles.safeFilename(
      'raft-${w.channel?.name ?? 'export'}-${DateTime.now().toIso8601String().substring(0, 10)}.png',
    );
    return await showRaftDialog<bool>(
      legacyMaterial: true,
      context: context,
      builder: (_) => MessageImageReview(
        controller: w,
        bytes: png!,
        filename: filename,
        authorized: current,
        authorityChanges: authorityChanges,
        files: files,
        sharing: sharing,
        clipboard: clipboard,
        openExternal: openExternal,
        shareChannelId: thread
            ? w.threadChannelId ?? w.channel?.id
            : w.channel?.id,
      ),
    );
  } on TimeoutException {
    throw _renderTimedOut;
  } finally {
    entry?.remove();
    w.removeListener(revoke);
    authorityChanges?.removeListener(revoke);
    if (png != null) {
      await raftEvictMemoryImage(png);
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
    this.authorityChanges,
    this.files,
    this.sharing,
    this.clipboard,
    this.openExternal,
    this.shareChannelId,
  });
  final WorkspaceController controller;
  final Uint8List bytes;
  final String filename;
  final bool Function() authorized;
  final Listenable? authorityChanges;
  final AttachmentFiles? files;
  final NativeSharing? sharing;
  final ImageClipboard? clipboard;
  final Future<bool> Function(Uri)? openExternal;

  /// The conversation the share page is created for (Web: the selection's
  /// channel); without one "Share to X" is not offered.
  final String? shareChannelId;
  @override
  State<MessageImageReview> createState() => _MessageImageReviewState();
}

class _MessageImageReviewState extends State<MessageImageReview> {
  late final files = widget.files ?? AttachmentFiles();
  late final sharing = widget.sharing ?? NativeSharing();
  late final clipboard = widget.clipboard ?? const ImageClipboard();
  SharedFileLease? lease;
  bool busy = false, copying = false, copied = false, sharingLink = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Export dialog error: cleared when the next save/share starts; the dialog closes on authority loss.
  String? error;
  bool get current => mounted && widget.authorized();
  void changed() {
    if (!current) {
      void closeOwnedReview() {
        if (!mounted || current) return;
        final route = ModalRoute.of(context);
        if (route?.isActive == true) route!.navigator?.removeRoute(route);
      }

      if (WidgetsBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) => closeOwnedReview());
      } else {
        closeOwnedReview();
      }
      unawaited(lease?.dispose() ?? Future<void>.value());
      lease = null;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(changed);
    widget.authorityChanges?.addListener(changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(changed);
    widget.authorityChanges?.removeListener(changed);
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

  /// Web `handleCopyImage`: the PNG on the clipboard; the button then reads
  /// "Copied" until the next attempt.
  Future<void> copyImage() async {
    if (busy || !current) return;
    setState(() {
      busy = copying = true;
      copied = false;
      error = null;
    });
    try {
      await clipboard.copyPng(widget.bytes);
      if (mounted && current) setState(() => copied = true);
    } catch (e) {
      logUserError(e, where: 'copy message image');
      if (mounted && current) {
        setState(
          () => error = raftText(
            context,
            "Couldn't copy the image. Use Download instead.",
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = copying = false;
        });
      }
    }
  }

  /// Web `createShareArtifactAndNavigateToX`: upload the reviewed PNG as a
  /// share artifact, open the X intent for its page, and leave the review
  /// (the selection ends, like Save).
  Future<void> shareToX() async {
    final channelId = widget.shareChannelId;
    if (busy || !current || channelId == null) return;
    setState(() {
      busy = sharingLink = true;
      error = null;
    });
    try {
      final artifact = await createMessageSelectionShareArtifact(
        widget.controller,
        png: widget.bytes,
        channelId: channelId,
      );
      if (!mounted || !current) return;
      final intent = shareArtifactXIntentUrl(
        artifact.url,
        raftText(context, 'via Raft'),
      );
      await (widget.openExternal?.call(intent) ??
          launchUrl(intent, mode: LaunchMode.externalApplication));
      if (mounted && current && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted && current) {
        setState(
          () => error = raftText(
            context,
            userErrorText(
              e,
              fallback: 'Share failed',
              where: 'share message image',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = sharingLink = false;
        });
      }
    }
  }

  void close() {
    if (!busy) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    // Web Lightbox: Escape (the route handles it), Ctrl/Cmd+W and a press on
    // the backdrop close it; none of them while the export runs.
    child: CallbackShortcuts(
      bindings: {
        SingleActivator(
          LogicalKeyboardKey.keyW,
          control: !usesCommandShortcuts(),
          meta: usesCommandShortcuts(),
        ): close,
      },
      child: Focus(
        autofocus: true,
        child: Dialog.fullscreen(
          backgroundColor: RaftLightboxRecipe(RaftTokens.of(context)).backdrop,
          child: GestureDetector(
            key: const ValueKey('image-export-backdrop'),
            behavior: HitTestBehavior.opaque,
            onTap: close,
            child: SafeArea(
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: SizedBox(
                    width: 768,
                    height: MediaQuery.sizeOf(context).height * .85,
                    child: RaftImageReview(
                      preview: RaftSizedImage.memory(
                        widget.bytes,
                        fit: BoxFit.contain,
                        evictOnDispose: true,
                        semanticLabel: raftText(
                          context,
                          'Preview of selected messages',
                        ),
                        gaplessPlayback: false,
                      ),
                      onClose: () => Navigator.pop(context, false),
                      onSave: () => act(false),
                      onShare: sharing.supported ? () => act(true) : null,
                      onCopy: clipboard.supported ? copyImage : null,
                      onShareLink: widget.shareChannelId == null
                          ? null
                          : shareToX,
                      copying: copying,
                      copied: copied,
                      sharingLink: sharingLink,
                      busy: busy,
                      error: error,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
