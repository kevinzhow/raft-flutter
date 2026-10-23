// Web `PreviewCommentModeContext` (attachmentPreviewSurfaces.tsx): the preview
// shell, the comments panel and the preview body share one comment session:
// whether comment mode is on (the panel is open), the anchor the next comment
// will carry, and how a comment's anchor jumps back into the preview.
import 'package:flutter/widgets.dart';

/// `{type, data}` as the comment API stores it (Web `CommentAnchor`):
/// `lines` / `csv-rows` (`start`, `end`, `quote`), `html-region`
/// (`x y w h viewportWidth documentWidth documentHeight quote`) and
/// `video-timestamp` (`time`).
typedef RaftCommentAnchor = Map<String, dynamic>;

/// Anchors carry a short context quote, never document content: the server
/// caps the anchor at 4 KB (Web `MAX_QUOTE_LENGTH`).
const raftCommentQuoteLimit = 400;

/// Web `trimQuote`: null for blank text, else at most 400 characters.
String? raftCommentQuote(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.length > raftCommentQuoteLimit
      ? '${trimmed.substring(0, raftCommentQuoteLimit)}…'
      : trimmed;
}

class RaftAttachmentCommentState extends ChangeNotifier {
  bool _commentMode = false;
  RaftCommentAnchor? _pending;

  /// Set by the shell: opens the comments panel (a pushed anchor opens it).
  VoidCallback? openPanel;

  /// Set by the preview body that can show an anchor's location; returns
  /// whether the location was found (Web `jumpToAnchor`).
  bool Function(RaftCommentAnchor anchor)? jumpHandler;

  /// Comment mode keeps the panel open and live-captures anchors in the
  /// preview; closing the panel ends it (the typed draft survives, only WHERE
  /// dies).
  bool get commentMode => _commentMode;
  set commentMode(bool value) {
    if (_commentMode == value && (value || _pending == null)) return;
    _commentMode = value;
    if (!value) _pending = null;
    notifyListeners();
  }

  /// The anchor the next comment carries, or null.
  RaftCommentAnchor? get pendingAnchor => _pending;

  /// Web `pushAnchor`: capture [anchor] and open the panel.
  void pushAnchor(RaftCommentAnchor anchor) {
    _pending = anchor;
    openPanel?.call();
    notifyListeners();
  }

  void clearAnchor() {
    if (_pending == null) return;
    _pending = null;
    notifyListeners();
  }

  bool jump(RaftCommentAnchor anchor) => jumpHandler?.call(anchor) ?? false;
}

class RaftAttachmentCommentScope
    extends InheritedNotifier<RaftAttachmentCommentState> {
  const RaftAttachmentCommentScope({
    super.key,
    required RaftAttachmentCommentState state,
    required super.child,
  }) : super(notifier: state);

  /// The session of the nearest preview shell, listening to it.
  static RaftAttachmentCommentState? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<RaftAttachmentCommentScope>()
      ?.notifier;

  /// The same, without rebuilding when it changes.
  static RaftAttachmentCommentState? read(BuildContext context) => context
      .getInheritedWidgetOfExactType<RaftAttachmentCommentScope>()
      ?.notifier;
}
