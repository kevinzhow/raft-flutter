// Presentational pieces of Web ForwardComposerMobile
// (packages/web/src/components/message/ForwardComposerMobile.tsx,
// ForwardComposerTargetList.tsx). The app owns targets, search and sending.
import 'raft/checkbox.dart' show RaftCheckbox;
import 'text_selection_toolbar.dart';
import 'hover_region.dart';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'raft_underline.dart';
import 'attachment_card.dart';
import 'attachment_transfer.dart';
import 'avatar_content.dart';
import 'components.dart';
import 'design_primitives.dart';
import 'error_presentation.dart' show RaftErrorBanner;
import 'form_controls.dart' show RaftTextInput, RaftLegacyInput;
import 'icons.dart';

import 'localization.dart';
import 'message_body.dart';
import 'mounted_avatar_recipe.dart';
import 'rich_card_tokens.dart';
import 'system_inset.dart';
import 'status_bar.dart';
import 'theme.dart';

/// `fixed inset-0 z-40 flex flex-col bg-layer-canvas text-foreground-strong`.
///
/// Edge to edge: only the top (and sides) are safe-area padded. The list and
/// footer pad themselves by [raftBottomInset] (`pb-[max(12px, inset)]`), and the
/// page sits above the keyboard, so the inset is 0 while it is open.
class RaftForwardPage extends StatelessWidget {
  const RaftForwardPage({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final canvas = RaftTokens.of(context).colors['layer-canvas']!;
    // The status bar shows the page's own header colour (a RaftPanelHeaderBar
    // child publishes it), else the canvas.
    return RaftStatusBarHost(
      fallback: canvas,
      expand: true,
      child: Material(
        color: canvas,
        child: DefaultTextHeightBehavior(
          textHeightBehavior: raftCssTextHeightBehavior,
          child: Padding(
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: MediaQuery(
              data: media.removeViewInsets(removeBottom: true),
              child: SafeArea(bottom: false, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// `flex min-h-14 items-center gap-3 border-b px-3 py-2`; brutal
/// `border-b-2 border-black`, elegant `border-line-hairline`. Title
/// `text-base font-bold`, subtitle `truncate text-xs font-mono
/// text-foreground-muted`.
class RaftForwardPageHeader extends StatelessWidget {
  const RaftForwardPageHeader({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final Widget leading;
  final String title, subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    // The header paints the page canvas; it publishes that colour so the status
    // bar band above it matches (docs/status-bar.md).
    return RaftStatusBarSource(
      color: t.colors['layer-canvas']!,
      child: _page(t),
    );
  }

  Widget _page(RaftTokens t) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.colors['line-hairline']!)),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: t.headingFont,
                    fontSize: 16,
                    height: 24 / 16,
                    fontWeight: FontWeight.w700,
                    color: t.strong,
                    leadingDistribution: TextLeadingDistribution.even,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: t.monoFont,
                    fontSize: 12,
                    height: 16 / 12,
                    color: t.colors['foreground-muted'],
                    leadingDistribution: TextLeadingDistribution.even,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// raft-ui `Button size="icon-sm"` (28px, 14px glyph, no touch expansion).
class RaftForwardIconAction extends StatelessWidget {
  const RaftForwardIconAction({
    super.key,
    required this.glyph,
    required this.tooltip,
    this.onPressed,
    this.accent = false,
  });
  final RaftGlyph glyph;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool accent;
  @override
  Widget build(BuildContext context) => RaftIconButton(
    glyph: glyph,
    visualSize: 28,
    minimumTargetSize: 28,
    glyphSize: 14,
    variant: accent ? RaftControlVariant.accent : RaftControlVariant.outline,
    tooltip: tooltip,
    onPressed: onPressed,
  );
}

/// raft-ui `Button size="sm" variant="outline"` (h-7 px-2.5).
class RaftForwardTextAction extends StatelessWidget {
  const RaftForwardTextAction({
    super.key,
    required this.label,
    this.onPressed,
    this.selected = false,
  });
  final String label;
  final VoidCallback? onPressed;

  /// The chosen option of a chip row: `variant="accent"` instead of outline.
  final bool selected;
  @override
  Widget build(BuildContext context) => RaftControl(
    variant: selected ? RaftControlVariant.accent : RaftControlVariant.outline,
    visualHeight: 28,
    minimumTargetSize: 28,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    onPressed: onPressed,
    child: Text(label),
  );
}

/// Targets step body: `flex flex-col p-3`, the search input (`mb-3`), the
/// `mb-2 flex h-6 justify-between text-xs font-bold` label row, and the
/// `space-y-1.5 overflow-y-auto pb-2` list.
class RaftForwardTargetsBody extends StatelessWidget {
  const RaftForwardTargetsBody({
    super.key,
    required this.search,
    required this.label,
    this.rows = const [],
    this.itemBuilder,
    this.itemCount,
    this.labelAction,
    this.leading = const [],
  });

  /// Share mode only: the progress bar and server chip row above the search,
  /// each followed by `mb-3`.
  final List<Widget> leading;
  final Widget search;
  final String label;
  final Widget? labelAction;
  final List<Widget> rows;
  final IndexedWidgetBuilder? itemBuilder;
  final int? itemCount;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final labelStyle = TextStyle(
      fontFamily: t.headingFont,
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w700,
      color: t.strong,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in leading)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: item),
          Padding(padding: const EdgeInsets.only(bottom: 12), child: search),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              height: 24,
              child: DefaultTextStyle.merge(
                style: labelStyle,
                child: Row(
                  children: [
                    Expanded(child: Text(label, style: labelStyle)),
                    ?labelAction,
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              // 12 (body padding) + 8, plus the system inset: the list runs
              // under the bar and the last row scrolls clear of it.
              padding: raftScrollPadding(
                context,
                const EdgeInsets.only(bottom: 20),
              ),
              itemCount: itemCount ?? rows.length,
              itemBuilder: itemBuilder ?? (_, index) => rows[index],
              separatorBuilder: (_, _) => const SizedBox(height: 6),
            ),
          ),
        ],
      ),
    );
  }
}

/// `underline underline-offset-2` text button in the label row ("Clear").
class RaftForwardLinkAction extends StatelessWidget {
  const RaftForwardLinkAction({super.key, required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) =>
      GestureDetector(onTap: onTap, child: RaftUnderlinedText(label));
}

/// Search-mode placeholder rows: spinner, failure (+ retry), or no results
/// (`py-4 text-center text-xs font-bold text-foreground-hint`).
class RaftForwardSearchStatus extends StatelessWidget {
  const RaftForwardSearchStatus({
    super.key,
    this.loading = false,
    this.message,
    this.retryLabel,
    this.onRetry,
  });
  final bool loading;
  final String? message, retryLabel;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final hint = TextStyle(
      fontFamily: t.headingFont,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: onRetry != null
          ? t.colors['foreground-muted']
          : t.colors['foreground-hint'] ?? t.colors['foreground-muted'],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: loading
          ? const Center(child: RaftSpinner())
          : Column(
              children: [
                Text(message ?? '', textAlign: TextAlign.center, style: hint),
                if (onRetry != null) ...[
                  const SizedBox(height: 8),
                  RaftControl(
                    variant: RaftControlVariant.outline,
                    visualHeight: 24,
                    minimumTargetSize: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: onRetry,
                    child: Text(retryLabel ?? ''),
                  ),
                ],
              ],
            ),
    );
  }
}

/// `flex shrink-0 items-center gap-1 text-[10px] font-bold
/// text-foreground-hint` with a 10px glyph ("Not joined" / "New DM").
class RaftForwardTargetBadge extends StatelessWidget {
  const RaftForwardTargetBadge({
    super.key,
    required this.glyph,
    required this.label,
  });
  final RaftGlyph glyph;
  final String label;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final color = t.colors['foreground-hint'] ?? t.colors['foreground-muted'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RaftIcon(glyph, size: 10, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: t.headingFont,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Target icon: `AvatarSlot context="compact-list"` for people, Hash / Lock
/// / GitBranch 14 for channels.
Widget raftForwardTargetIcon({
  required String name,
  String type = 'channel',
  bool agent = false,
  String? pixelKey,
  String? uploadedUrl,
  String? gravatarUrl,
}) {
  if (type == 'dm' || type == 'human' || type == 'agent') {
    final isAgent = agent || type == 'agent';
    return RaftAvatar(
      name: name,
      size: 20,
      kind: isAgent ? RaftAvatarKind.agent : RaftAvatarKind.human,
      mountedContext: RaftMountedAvatarContext.compactList,
      // AvatarSlot compact-list: the peer's pixel / uploaded / Gravatar
      // artwork; an agent without one wears the default robot.
      content: RaftAvatarContent(
        name: name,
        kind: isAgent
            ? RaftAvatarContentKind.agent
            : RaftAvatarContentKind.human,
        pixelKey: isAgent ? pixelKey ?? 'robot' : null,
        uploadedUrl: uploadedUrl,
        gravatarUrl: gravatarUrl,
        fallback: RaftMountedAvatarFallback(
          avatarContext: RaftMountedAvatarContext.compactList,
          identity: isAgent
              ? RaftMountedAvatarIdentity.agent
              : RaftMountedAvatarIdentity.human,
          gravatar: gravatarUrl != null,
        ),
      ),
    );
  }
  return RaftIcon(
    type == 'joint'
        ? RaftGlyph.gitBranch
        : type == 'private'
        ? RaftGlyph.lock
        : RaftGlyph.hash,
    size: 14,
  );
}

/// The note editor (Web mounts MessageInput variant="compact",
/// maxLength 4000) as a themed multi-line field.
class RaftForwardNoteField extends StatelessWidget {
  const RaftForwardNoteField({
    super.key,
    required this.controller,
    this.hint,
    this.enabled = true,
    this.autofocus = false,
  });
  final TextEditingController controller;
  final String? hint;
  final bool enabled, autofocus;
  @override
  Widget build(BuildContext context) => TextField(
    contextMenuBuilder: RaftTextSelectionToolbar.editableText,
    autofillHints: null,
    controller: controller,
    autofocus: autofocus,
    enabled: enabled,
    maxLength: 4000,
    minLines: 1,
    maxLines: 5,
    decoration: InputDecoration(hintText: hint, counterText: ''),
  );
}

/// Preview step: scrolling `p-3` body ("Message preview" + bundle) and the
/// `border-t bg-layer-panel p-3` note bar (brutal `border-t-2 border-black
/// bg-white`) with the "Optional note" label, editor and send action.
class RaftForwardPreviewStep extends StatelessWidget {
  const RaftForwardPreviewStep({
    super.key,
    required this.previewLabel,
    required this.preview,
    this.noteLabel,
    this.note,
    this.send,
    this.action,
    this.warnings = const [],
    this.hint,
    this.error,
  }) : assert(action != null || (noteLabel != null && note != null));
  final String previewLabel;
  final String? noteLabel, hint;
  final Widget preview;
  final Widget? note, send;

  /// Share mode: the bar holds this one full-width action ("Continue")
  /// instead of the optional-note editor and the send icon.
  final Widget? action;

  /// Banners above the preview (Web `{warnings}`).
  final List<Widget> warnings;
  final String? error;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final label = TextStyle(
      fontFamily: t.headingFont,
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w700,
      color: t.strong,
      leadingDistribution: TextLeadingDistribution.even,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            // The footer below owns the inset; the list ends above it.
            padding: const EdgeInsets.all(12),
            children: [
              for (final warning in warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: warning,
                ),
              // `mb-2`, less the 4px the bundle / share card keeps above itself.
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(previewLabel, style: label),
              ),
              preview,
              if (hint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    hint!,
                    style: label.copyWith(
                      color:
                          t.colors['foreground-hint'] ??
                          t.colors['foreground-muted'],
                    ),
                  ),
                ),
            ],
          ),
        ),
        RaftBottomInsetSurface(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.colors['layer-panel'],
            border: Border(top: BorderSide(color: t.colors['line-hairline']!)),
          ),
          child: action != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error != null) ...[
                      RaftErrorBanner(error!, small: true, bold: true),
                      const SizedBox(height: 8),
                    ],
                    action!,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(noteLabel!, style: label),
                    const SizedBox(height: 6),
                    // Web MessageInput's own error row (`density="sm" font-bold`).
                    if (error != null) ...[
                      RaftErrorBanner(error!, small: true, bold: true),
                      const SizedBox(height: 8),
                    ],
                    // With no [send] the editor carries its own submit (the
                    // compact MessageInput, as on Web).
                    if (send == null)
                      note!
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: note!),
                          const SizedBox(width: 8),
                          send!,
                        ],
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Target row: `flex w-full items-center gap-2 rounded-md border
/// border-line-muted px-2 py-2 text-sm font-bold` / brutal `rounded-none
/// border-2 border-black`; fill white / `bg-layer-panel`, selected
/// `bg-soft-signal` / `bg-primary-soft`, hover `brutal-cyan/15` / fill-muted.
class RaftForwardTargetRow extends StatefulWidget {
  const RaftForwardTargetRow({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.checkbox,
    this.checkboxDisabled = false,
    this.unavailable = false,
    this.trailing,
    this.onTap,
  });
  final Widget icon;
  final String label;
  final bool selected, checkbox, unavailable;

  /// Web `<Checkbox disabled>`: an unchecked row once ten are chosen.
  final bool checkboxDisabled;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  State<RaftForwardTargetRow> createState() => _RaftForwardTargetRowState();
}

class _RaftForwardTargetRowState extends State<RaftForwardTargetRow> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final fill = widget.unavailable
        ? t.colors['fill-muted']!.withValues(
            alpha: t.colors['fill-muted']!.a * .4,
          )
        : widget.selected
        ? (t.colors['primary-soft']!)
        : hovered
        ? (t.colors['fill-muted']!)
        : (t.colors['layer-panel']!);
    return Semantics(
      button: !widget.checkbox,
      checked: widget.checkbox ? widget.selected : null,
      enabled: widget.onTap != null,
      label: widget.label,
      excludeSemantics: true,
      child: RaftHoverRegion(
        cursor: widget.onTap == null
            ? SystemMouseCursors.forbidden
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Opacity(
            opacity: widget.unavailable ? .5 : 1,
            child: Container(
              // CSS `p-2` inside the border (Container adds the border inset).
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: fill,
                border: Border.all(color: t.colors['line-muted']!),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  if (widget.checkbox) ...[
                    // raft-ui `Checkbox` (14px), pointer-events-none in the row.
                    ExcludeSemantics(
                      child: IgnorePointer(
                        // Never `disabled` unless the limit is reached: the
                        // row owns the tap (`pointer-events-none`).
                        child: RaftCheckbox(
                          value: widget.selected,
                          onChanged: widget.checkboxDisabled ? null : (_) {},
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  widget.icon,
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: t.headingFont,
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w700,
                        color: t.strong,
                        leadingDistribution: TextLeadingDistribution.even,
                      ),
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 8),
                    widget.trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// raft-ui `Input` with `pl-9 placeholder:text-foreground-placeholder` and the
/// absolutely positioned 14px Search icon at `left-3`.
class RaftForwardSearchInput extends StatelessWidget {
  const RaftForwardSearchInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.onChanged,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => RaftTextInput(
    controller: controller,
    focusNode: focusNode,
    hintText: placeholder,
    onChanged: onChanged,
    // `autoFocus`.
    autofocus: true,
    leadingGlyph: RaftGlyph.search,
    legacy: RaftLegacyInput.recipe,
  );
}

/// Share mode: the server switch. Web's forward page has no server picker (the
/// destination list is the current server's), so the chips reuse its own
/// `Button size="sm"` (`h-7 px-2.5`): outline, `accent` for the chosen server,
/// in a horizontally scrolling `gap-1.5` row.
class RaftForwardServerChips extends StatelessWidget {
  const RaftForwardServerChips({
    super.key,
    required this.semanticLabel,
    required this.names,
    required this.selected,
    required this.onSelected,
  });
  final String semanticLabel;

  /// Chip label by server id, in display order.
  final Map<String, String> names;
  final String selected;

  /// Null while a hand-off is running: the chips stay but are inert.
  final ValueChanged<String>? onSelected;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: semanticLabel,
    child: SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: names.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, index) {
          final id = names.keys.elementAt(index);
          return RaftForwardTextAction(
            key: ValueKey('forward-server-$id'),
            // ignore: raft_lints/avoid_render_index_assertion -- `id` is taken from names.keys in the same builder.
            label: names[id]!,
            selected: id == selected,
            onPressed: onSelected == null ? null : () => onSelected!(id),
          );
        },
      ),
    ),
  );
}

/// Where one shared file is in the copy into the app's private inbox.
enum RaftForwardShareFileState {
  /// Copied (or nothing to wait for): the plain chip.
  ready,

  /// Queued behind an earlier file.
  waiting,

  /// Bytes are being copied; [RaftForwardShareFile.transfer] carries them.
  copying,

  /// The file cannot be added; [RaftForwardShareFile.error] says why.
  failed,
}

/// One shared file in [RaftForwardSharePreview].
class RaftForwardShareFile {
  const RaftForwardShareFile({
    required this.filename,
    required this.mimeType,
    this.sizeBytes,
    this.state = RaftForwardShareFileState.ready,
    this.transfer,
    this.error,
  });
  final String filename, mimeType;
  final int? sizeBytes;
  final RaftForwardShareFileState state;

  /// Copied bytes of this file. The status line listens to it itself, so the
  /// card is not rebuilt per update.
  final ValueListenable<RaftTransferProgress?>? transfer;

  /// Reason shown under a [RaftForwardShareFileState.failed] chip.
  final String? error;
}

/// Status under one shared file's chip while it is copied: the inline transfer
/// bar of the attachment download design (Option A) with `1.2 / 3.4 MB · 36%`,
/// a quiet "Waiting" line for a queued file, or the red bar and the reason.
class RaftForwardShareFileStatus extends StatelessWidget {
  const RaftForwardShareFileStatus({super.key, required this.file});
  final RaftForwardShareFile file;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftTransferRecipe(t);
    final mono = RaftTypography.mono(t, size: 11, line: 14, color: t.muted);
    Widget line(String text, {Color? color}) => Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: color == null ? mono : mono.copyWith(color: color),
    );
    switch (file.state) {
      case RaftForwardShareFileState.ready:
        return const SizedBox.shrink();
      case RaftForwardShareFileState.waiting:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RaftTransferBar(value: 0, style: RaftTransferBarStyle.inline),
            const SizedBox(height: 4),
            line(raftText(context, 'Waiting')),
          ],
        );
      case RaftForwardShareFileState.copying:
        final transfer = file.transfer;
        Widget bar(RaftTransferProgress? value) => RaftTransferBar(
          value: (value ?? RaftTransferProgress.connecting)
              .withFallbackTotal(file.sizeBytes)
              .fraction,
          style: RaftTransferBarStyle.inline,
        );
        String label(RaftTransferProgress? value) {
          final resolved = (value ?? RaftTransferProgress.connecting)
              .withFallbackTotal(file.sizeBytes);
          final fraction = resolved.fraction;
          return resolved.waiting
              ? raftText(context, 'Preparing…')
              : fraction == null
              ? resolved.sizeLabel
              : '${resolved.sizeLabel} · ${(fraction * 100).floor()}%';
        }

        if (transfer == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [bar(null), const SizedBox(height: 4), line(label(null))],
          );
        }
        return ValueListenableBuilder<RaftTransferProgress?>(
          valueListenable: transfer,
          builder: (context, value, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              bar(value),
              const SizedBox(height: 4),
              line(label(value)),
            ],
          ),
        );
      case RaftForwardShareFileState.failed:
        return Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RaftTransferBar(
                failed: true,
                style: RaftTransferBarStyle.inline,
              ),
              const SizedBox(height: 4),
              line(file.error ?? '', color: recipe.dangerText),
            ],
          ),
        );
    }
  }
}

/// Share mode: what is being added, in the frame of Web's `ForwardedBundleCard`
/// (the "Message preview" element of the note page): the same bordered card,
/// header strip (glyph, label, count), text body and attachment chips. The
/// card shows no author or timestamp row because the content is not a message.
class RaftForwardSharePreview extends StatelessWidget {
  const RaftForwardSharePreview({
    super.key,
    required this.header,
    this.count,
    this.text,
    this.files = const [],
  });
  final String header;
  final String? count, text;
  final List<RaftForwardShareFile> files;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = ForwardedSnapshotRecipe(
      t,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    final viewportWidth = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: recipe.maxWidth),
        child: Container(
          decoration: recipe.decoration,
          padding: recipe.inset,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: recipe.headerDecoration,
                padding: recipe.headerInset(viewportWidth),
                child: Row(
                  children: [
                    RaftIcon(
                      RaftGlyph.share2,
                      size: 12,
                      color: recipe.header.color,
                    ),
                    const SizedBox(width: 4),
                    Text(header, style: recipe.header),
                    if (count != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          count!,
                          // Same 16.5px header line as the note page's bundle.
                          style: recipe.count.copyWith(height: 16.5 / 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              DecoratedBox(
                decoration: recipe.contentDecoration,
                child: Padding(
                  padding: recipe.itemInset,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (text != null && text!.isNotEmpty)
                        // Long text is cut like the bundle's collapsed body.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: recipe.collapsedHeight,
                          ),
                          child: SingleChildScrollView(
                            primary: false,
                            physics: const NeverScrollableScrollPhysics(),
                            child: RaftMessageBody(
                              content: text!,
                              foregroundColor: recipe.semantic.prose,
                              exportMode: true,
                            ),
                          ),
                        ),
                      if (files.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(
                            top: text != null && text!.isNotEmpty ? 6 : 0,
                          ),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final file in files)
                                SizedBox(
                                  width: RaftAttachmentRecipe(t).size.width,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      RaftAttachmentCard(
                                        onOpen: null,
                                        filename: file.filename,
                                        // A shared image is not readable here
                                        // until it is staged, so it is listed
                                        // as a file chip rather than as an
                                        // empty image box.
                                        mimeType:
                                            file.mimeType.startsWith('image/')
                                            ? 'application/octet-stream'
                                            : file.mimeType,
                                        sizeBytes: file.sizeBytes,
                                        exportMode: true,
                                      ),
                                      if (file.state !=
                                          RaftForwardShareFileState.ready) ...[
                                        const SizedBox(height: 4),
                                        RaftForwardShareFileStatus(file: file),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What Continue is waiting for, shown above the button (Option A): the inline
/// transfer bar, a `Preparing 2 of 3 files · 12.3 / 30.1 MB` line and Cancel,
/// the same bar / size line / Cancel arrangement as the file download panel.
class RaftForwardWait {
  const RaftForwardWait({
    required this.label,
    this.progress,
    this.onCancel,
    this.failed = false,
  });

  /// Localized status line, e.g. "Preparing 2 of 3 files".
  final String label;

  /// Bytes copied so far; null draws the indeterminate sweep (a check or the
  /// hand-off itself is the wait, not a copy).
  final ValueListenable<RaftTransferProgress?>? progress;
  final VoidCallback? onCancel;
  final bool failed;
}

/// Share mode: the note page's send action as one full-width accent button
/// (Web's send is the accent `Button`; its label here is "Continue").
///
/// While [busy] the button keeps its size and shows a spinner with
/// [busyLabel] instead of looking untouched; [wait] adds the progress block
/// above it.
class RaftForwardContinueAction extends StatelessWidget {
  const RaftForwardContinueAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.busyLabel,
    this.wait,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final String? busyLabel;
  final RaftForwardWait? wait;
  @override
  Widget build(BuildContext context) {
    final control = LayoutBuilder(
      builder: (context, box) => RaftControl(
        variant: RaftControlVariant.accent,
        visualWidth: box.maxWidth,
        busy: busy,
        onPressed: onPressed,
        semanticLabel: busy ? busyLabel ?? label : null,
        child: busy
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const RaftSpinner(),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      busyLabel ?? label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : Text(label),
      ),
    );
    final wait = this.wait;
    if (wait == null) return control;
    final t = RaftTokens.of(context);
    final recipe = RaftTransferRecipe(t);
    final mono = RaftTypography.mono(
      t,
      size: 12,
      line: 16,
      color: wait.failed ? recipe.dangerText : t.muted,
    );
    Widget bar(RaftTransferProgress? value) => RaftTransferBar(
      failed: wait.failed,
      value: value?.fraction,
      style: RaftTransferBarStyle.inline,
    );
    Widget text(RaftTransferProgress? value) => Text(
      value == null || value.waiting
          ? wait.label
          : '${wait.label} · ${value.sizeLabel}',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: mono,
    );
    final progress = wait.progress;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: progress == null
              ? bar(null)
              : ValueListenableBuilder<RaftTransferProgress?>(
                  valueListenable: progress,
                  builder: (context, value, _) => bar(value),
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: progress == null
                  ? text(null)
                  : ValueListenableBuilder<RaftTransferProgress?>(
                      valueListenable: progress,
                      builder: (context, value, _) => text(value),
                    ),
            ),
            if (wait.onCancel != null)
              RaftTextButton(
                label: raftText(context, 'Cancel'),
                glyph: RaftGlyph.x,
                onPressed: wait.onCancel,
                visualHeight: 32,
              ),
          ],
        ),
        const SizedBox(height: 8),
        control,
      ],
    );
  }
}
