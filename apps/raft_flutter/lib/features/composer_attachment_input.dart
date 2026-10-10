import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../platform/clipboard_attachments.dart';

// Web MessageInput file entry points other than the picker. All of them feed
// the same selection decision (`attachSelection`, Web `addFiles`):
//
// * drag-and-drop of OS files onto the composer root (desktop), with the
//   drop overlay while a drag is over it and the folder notices on drop;
// * Ctrl/Cmd+V of copied files or an image (`handlePaste`); text paste is
//   unaffected when the clipboard carries neither;
// * software-keyboard image insertion (Android IME commit content).

/// Captures the draft scope; a conversation switch meanwhile drops the files.
bool Function() _fence(
  WorkspaceController w,
  bool thread,
  bool Function() active,
) {
  final scope = w.draftScope(thread: thread), generation = w.ledger.generation;
  return () =>
      active() &&
      generation == w.ledger.generation &&
      scope == w.draftScope(thread: thread);
}

Future<void> _attach(
  BuildContext context,
  WorkspaceController w,
  List<ComposerFile> files, {
  required bool thread,
  required bool Function() current,
}) {
  if (files.isEmpty || !context.mounted || !current()) return Future.value();
  return w.attachSelection(
    files,
    thread: thread,
    text: (key, args) => raftFormat(context, key, args),
  );
}

/// Web `handlePaste`: resolves true when the clipboard carried files or an
/// image (they are attached and the text paste is skipped).
Future<bool> pasteComposerAttachments(
  BuildContext context,
  WorkspaceController w, {
  required bool thread,
  required bool Function() active,
  ClipboardAttachments clipboard = const ClipboardAttachments(),
}) async {
  if (!active()) return false;
  final current = _fence(w, thread, active);
  final files = await clipboard.read();
  if (files.isEmpty) return false;
  if (context.mounted) {
    await _attach(context, w, files, thread: thread, current: current);
  }
  return true;
}

/// Android keyboard image / GIF / sticker insertion.
void insertComposerContent(
  BuildContext context,
  WorkspaceController w,
  KeyboardInsertedContent content, {
  required bool thread,
  required bool Function() active,
}) {
  final bytes = content.data;
  if (!active() || bytes == null || bytes.isEmpty) return;
  _attach(
    context,
    w,
    [(name: insertedName(content), bytes: bytes)],
    thread: thread,
    current: _fence(w, thread, active),
  );
}

/// A keyboard-committed image keeps its URI file name, with the extension
/// implied by its MIME type when the name has none.
String insertedName(KeyboardInsertedContent content) {
  final segments = Uri.tryParse(content.uri)?.pathSegments ?? const [];
  final base = segments.where((s) => s.isNotEmpty).lastOrNull ?? 'image';
  if (base.contains('.')) return base;
  final subtype = content.mimeType.split('/').last.toLowerCase();
  final extension = switch (subtype) {
    'jpeg' => 'jpg',
    'svg+xml' => 'svg',
    '' => 'bin',
    _ => subtype,
  };
  return '$base.$extension';
}

/// Web MessageInput drag-and-drop over `ComposerRoot`: the overlay shows only
/// while an OS drag is over this composer; folders are skipped with Web's
/// notices; text/URL drags carry no local file and attach nothing.
class ComposerFileDropTarget extends StatefulWidget {
  const ComposerFileDropTarget({
    super.key,
    required this.controller,
    required this.thread,
    required this.active,
    required this.child,
    this.dropSupported,
  });
  final WorkspaceController controller;
  final bool thread;

  /// The composer is presented, current and enabled for this scope.
  final bool Function() active;
  final Widget child;

  /// OS file drops reach desktop windows only. Touch platforms never show the
  /// overlay (Web: touch fires no HTML5 drag events).
  final bool? dropSupported;
  @override
  State<ComposerFileDropTarget> createState() => _ComposerFileDropTargetState();
}

class _ComposerFileDropTargetState extends State<ComposerFileDropTarget> {
  WorkspaceController get w => widget.controller;
  bool dragging = false, enabled = false;

  bool get dropSupported =>
      widget.dropSupported ??
      (Platform.isLinux || Platform.isMacOS || Platform.isWindows);

  void setDragging(bool value) {
    if (dragging == value) return;
    // desktop_drop reports exits from didUpdateWidget while we build.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      dragging = value;
      return;
    }
    setState(() => dragging = value);
  }

  bool active() => mounted && enabled && widget.active();

  Future<void> drop(DropDoneDetails details) async {
    final thread = widget.thread;
    final current = _fence(w, thread, active);
    final bookmarks = [
      for (final item in details.files)
        if (Platform.isMacOS && (item.extraAppleBookmark?.isNotEmpty ?? false))
          item.extraAppleBookmark!,
    ];
    for (final bookmark in bookmarks) {
      await DesktopDrop.instance.startAccessingSecurityScopedResource(
        bookmark: bookmark,
      );
    }
    final ({List<ComposerFile> files, int folders}) read;
    try {
      read = await readLocalFileEntries([
        for (final item in details.files) item.path,
      ]);
    } finally {
      for (final bookmark in bookmarks) {
        await DesktopDrop.instance.stopAccessingSecurityScopedResource(
          bookmark: bookmark,
        );
      }
    }
    if (!mounted || !current()) return;
    // Web handleDrop: a drop of only folders uploads nothing; a mixed drop
    // notes the skip and the selection decision then owns the banner.
    if (read.folders > 0) {
      w.setComposerError(
        raftText(
          context,
          read.files.isEmpty
              ? "Folders can't be uploaded — drag individual files instead."
              : 'Folders were skipped — only individual files can be uploaded.',
        ),
        thread: thread,
      );
    }
    await _attach(context, w, read.files, thread: thread, current: current);
  }

  @override
  Widget build(BuildContext context) {
    // A covered route still receives desktop drop events (desktop_drop#2), so
    // only the current, visible route's composer is a target.
    final enabled = this.enabled =
        dropSupported &&
        widget.active() &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        Visibility.of(context);
    return DropTarget(
      enable: enabled,
      onDragEntered: (_) => setDragging(true),
      onDragExited: (_) => setDragging(false),
      onDragDone: (details) {
        setDragging(false);
        if (active()) drop(details);
      },
      child: Stack(
        children: [
          widget.child,
          if (enabled && dragging)
            const Positioned.fill(child: RaftComposerDropOverlay()),
        ],
      ),
    );
  }
}
