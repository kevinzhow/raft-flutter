import 'package:flutter/widgets.dart';

import 'banner.dart';
import 'design_primitives.dart' show RaftTypography;
import 'dialog_card.dart';
import 'icons.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftCssText;
import 'recipes/button_variants.g.dart';
import 'recipes/toast_styles.g.dart' show RaftToastRecipeTone;
import 'theme.dart';
import 'toast.dart';

// The one error presentation layer. Every user-visible failure goes through
// one of these, mirroring the Web surfaces:
//
//   Web                                        raft_ui
//   toast.error / showToast({type:"error"})    [showRaftToast] (tone error)
//   <Banner intent="warning" font-bold>{err}   [RaftErrorBanner]
//   <Banner ... density="sm">{err}             [RaftErrorBanner] size sm
//   FormField error= (FieldError, role=alert)  RaftFormField(error:)
//   "{error}" + outline sm Retry button        [RaftLoadError]
//   err.response.data.error || fallback        [raftErrorMessage]
//
// Copy discipline: an error shown to a user is either text the Raft server
// sent (Web shows `response.data.error` verbatim), or the call site's Web
// fallback message. A raw exception (`FormatException`, `DioException`, a
// socket error, a stack trace, a URL) never reaches the screen; the app's
// mapper logs it instead.

/// An error whose [message] was written for the user (an English Web catalog
/// source string; the display layer localizes it with [raftText]). Throw it
/// from UI-facing code that wants its text shown; any other exception type is
/// replaced by the call site's fallback copy.
class RaftUserError implements Exception {
  const RaftUserError(this.message, {this.suffix = ''});
  final String message;

  /// Text appended after [message] is localized (a technical code the Web
  /// copy writes as `message (CODE)`); [raftErrorMessage] adds it.
  final String suffix;
  @override
  String toString() => message;
}

/// Web `common.confirm.somethingWentWrong`: the copy when an error carries
/// nothing displayable and the call site names no more specific fallback.
const raftGenericErrorText = 'Could not complete that. Try again.';

/// Maps a caught [error] to the English source string to show (the display
/// layer localizes it). Never returns exception text.
typedef RaftErrorFormatter = String Function(Object error, {String? fallback});

/// The formatter used when no [RaftErrorScope] is installed: only
/// [RaftUserError] text is displayable.
String raftDefaultErrorText(Object error, {String? fallback}) {
  if (error is RaftUserError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }
  return fallback ?? raftGenericErrorText;
}

/// Installs the app's error mapper (it knows the API client's exception type,
/// which raft_ui does not depend on).
class RaftErrorScope extends InheritedWidget {
  const RaftErrorScope({super.key, required this.format, required super.child});
  final RaftErrorFormatter format;

  static RaftErrorFormatter of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RaftErrorScope>()?.format ??
      raftDefaultErrorText;

  @override
  bool updateShouldNotify(RaftErrorScope old) => format != old.format;
}

/// Localized, displayable text for [error] (English source through [raftText]).
String raftErrorMessage(
  BuildContext context,
  Object error, {
  String? fallback,
}) =>
    raftText(context, RaftErrorScope.of(context)(error, fallback: fallback)) +
    (error is RaftUserError ? error.suffix : '');

/// Web `<Banner intent="warning" className="font-bold">{error}</Banner>`: the
/// error row of dialogs, forms and settings panels. [small] is
/// `density="sm"`. [onRetry] adds the trailing outline `sm` button
/// (`BannerAction`).
class RaftErrorBanner extends StatelessWidget {
  const RaftErrorBanner(
    this.message, {
    super.key,
    this.small = false,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.bold = false,
  });
  final String message;
  final bool small;
  final VoidCallback? onRetry;
  final String retryLabel;

  /// Callsite `font-bold` on the description span.
  final bool bold;

  @override
  Widget build(BuildContext context) => RaftBanner(
    status: RaftBannerRecipeStatus.warning,
    size: small ? RaftBannerRecipeSize.sm : RaftBannerRecipeSize.md,
    description: message,
    descriptionWeight: bold ? FontWeight.w700 : null,
    action: onRetry == null
        ? null
        : RaftRecipeButton(
            label: raftText(context, retryLabel),
            variant: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.sm,
            onPressed: onRetry,
          ),
  );
}

/// Web page-level load failure (AgentSkills, ThreadPanel, MessageSearchPage):
/// a centred column, `gap-3`, the message in `text-sm text-foreground-muted
/// font-mono` (brutal `text-black/60`) and an outline `sm` Button with a
/// `RefreshCw` icon and the surface's Retry copy.
class RaftLoadError extends StatelessWidget {
  const RaftLoadError(
    this.message, {
    super.key,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.expand = true,
    this.onDark = false,
    this.actions = const [],
  });
  final String message;

  /// More outline buttons beside Retry (a failed video offers Network
  /// settings and Download); each says what it does and does it.
  final List<RaftLoadErrorAction> actions;

  /// On the black video stage: light text instead of the page's muted one.
  final bool onDark;
  final VoidCallback? onRetry;
  final String retryLabel;

  /// `flex flex-1 ... justify-center` (fills the host) vs `px-5 py-4` embedded.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: RaftCssText(
            raftText(context, message),
            textAlign: TextAlign.center,
            style: RaftTypography.mono(
              t,
              size: 14,
              line: 20,
              color: onDark
                  // ds-allow: text on the black video stage
                  ? const Color(0xBFFFFFFF)
                  : t.muted,
            ),
          ),
        ),
        if (onRetry != null || actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onRetry != null)
                RaftRecipeButton(
                  label: raftText(context, retryLabel),
                  glyph: RaftGlyph.refreshCw,
                  glyphSize: 12,
                  variant: RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.sm,
                  onPressed: onRetry,
                ),
              for (final action in actions)
                RaftRecipeButton(
                  key: action.key,
                  label: raftText(context, action.label),
                  glyph: action.glyph,
                  glyphSize: 12,
                  variant: RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.sm,
                  onPressed: action.onPressed,
                ),
            ],
          ),
        ],
      ],
    );
    return expand
        ? Center(child: body)
        : Padding(
            // `px-5 py-4` block: the height hugs the message and button.
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Center(heightFactor: 1, child: body),
          );
  }
}

/// One more action under a [RaftLoadError] message.
class RaftLoadErrorAction {
  const RaftLoadErrorAction({
    required this.label,
    required this.onPressed,
    this.glyph,
    this.key,
  });

  /// English source string (localized by the display layer).
  final String label;
  final RaftGlyph? glyph;
  final VoidCallback? onPressed;
  final Key? key;
}

/// App-wide toast owner: Web `LocalizedToastProvider` + `toastBridge`. Place it
/// once above the router. Surfaces report through [showRaftToast]; with no host
/// mounted the call does nothing (like Web's `showToast`).
class RaftToastHost extends StatefulWidget {
  const RaftToastHost({super.key, required this.child, this.controller});
  final Widget child;

  /// Test seam: observe or pre-seed the host's controller.
  final RaftToastController? controller;

  /// The host's controller, or null outside a host.
  static RaftToastController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_RaftToastScope>()?.controller;

  @override
  State<RaftToastHost> createState() => _RaftToastHostState();
}

class _RaftToastHostState extends State<RaftToastHost> {
  late final RaftToastController _own = RaftToastController();
  RaftToastController get controller => widget.controller ?? _own;

  /// One entry for the host's lifetime. `Overlay.initialEntries` is read once,
  /// so building a fresh entry per rebuild left every later one un-inserted
  /// and never disposed.
  late final OverlayEntry _portal = OverlayEntry(
    builder: (_) => RaftToastPortal(controller: controller),
  );

  @override
  void didUpdateWidget(RaftToastHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) _portal.markNeedsBuild();
  }

  @override
  void dispose() {
    // The Overlay below is already gone; it never clears its entries itself.
    _portal
      ..remove()
      ..dispose();
    _own.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _RaftToastScope(
    controller: controller,
    child: Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        // The toast viewport sits above route overlays (dialogs, sheets), like
        // Web's portal. The Overlay only paints the toast.
        Positioned.fill(child: Overlay(initialEntries: [_portal])),
      ],
    ),
  );
}

class _RaftToastScope extends InheritedWidget {
  const _RaftToastScope({required this.controller, required super.child});
  final RaftToastController controller;
  @override
  bool updateShouldNotify(_RaftToastScope old) => controller != old.controller;
}

/// Web `toast.error(...)` / `showToast({ title, type: "error" })`. [title] is
/// an English source string and is localized here. Returns false when no
/// [RaftToastHost] is mounted.
bool showRaftToast(
  BuildContext context,
  String title, {
  RaftToastRecipeTone tone = RaftToastRecipeTone.error,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final host = RaftToastHost.maybeOf(context);
  if (host == null) return false;
  host.show(
    raftText(context, title),
    tone: tone,
    actionLabel: actionLabel == null ? null : raftText(context, actionLabel),
    onAction: onAction,
  );
  return true;
}

/// Shows [error] as an error toast through the installed mapper.
bool showRaftErrorToast(
  BuildContext context,
  Object error, {
  String? fallback,
}) => showRaftToast(
  context,
  RaftErrorScope.of(context)(error, fallback: fallback),
);
