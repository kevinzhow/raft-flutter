// Presentational pieces of Web ForwardComposerMobile
// (packages/web/src/components/message/ForwardComposerMobile.tsx,
// ForwardComposerTargetList.tsx). The app owns targets, search and sending.
import 'package:flutter/material.dart';

import 'components.dart';
import 'design_primitives.dart';
import 'icons.dart';
import 'mounted_avatar_recipe.dart';
import 'recipes/input.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart';
import 'theme.dart';

/// `fixed inset-0 z-40 flex flex-col bg-layer-canvas text-foreground-strong`.
class RaftForwardPage extends StatelessWidget {
  const RaftForwardPage({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: RaftTokens.of(context).colors['layer-canvas'],
    child: DefaultTextHeightBehavior(
      textHeightBehavior: raftCssTextHeightBehavior,
      child: SafeArea(child: child),
    ),
  );
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
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: t.brutal
              ? const BorderSide(color: Colors.black, width: 2)
              : BorderSide(color: t.colors['line-hairline']!),
        ),
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
  const RaftForwardTextAction({super.key, required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => RaftControl(
    variant: RaftControlVariant.outline,
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
    required this.rows,
    this.labelAction,
  });
  final Widget search;
  final String label;
  final Widget? labelAction;
  final List<Widget> rows;
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
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            child: ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  rows[i],
                ],
              ],
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
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Text(
      label,
      style: const TextStyle(decoration: TextDecoration.underline),
    ),
  );
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

/// `flex shrink-0 items-center gap-1 text-[10px] font-bold uppercase
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
          label.toUpperCase(),
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
}) {
  if (type == 'dm' || type == 'human' || type == 'agent') {
    final isAgent = agent || type == 'agent';
    return RaftAvatar(
      name: name,
      size: 20,
      kind: isAgent ? RaftAvatarKind.agent : RaftAvatarKind.human,
      mountedContext: RaftMountedAvatarContext.compactList,
      content: RaftMountedAvatarFallback(
        avatarContext: RaftMountedAvatarContext.compactList,
        identity: isAgent
            ? RaftMountedAvatarIdentity.agent
            : RaftMountedAvatarIdentity.human,
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
    required this.noteLabel,
    required this.note,
    required this.send,
    this.error,
  });
  final String previewLabel, noteLabel;
  final Widget preview, note, send;
  final String? error;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final label = TextStyle(
      fontFamily: t.headingFont,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: t.strong,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (error != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(error!),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(previewLabel, style: label),
              ),
              preview,
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.brutal ? Colors.white : t.colors['layer-panel'],
            border: Border(
              top: t.brutal
                  ? const BorderSide(color: Colors.black, width: 2)
                  : BorderSide(color: t.colors['line-hairline']!),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(noteLabel, style: label),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: note),
                  const SizedBox(width: 8),
                  send,
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
    this.unavailable = false,
    this.trailing,
    this.onTap,
  });
  final Widget icon;
  final String label;
  final bool selected, checkbox, unavailable;
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
        ? (t.brutal
              ? t.colors['color-soft-signal']!
              : t.colors['primary-soft']!)
        : hovered
        ? (t.brutal
              ? t.colors['color-brutal-cyan']!.withValues(alpha: .15)
              : t.colors['fill-muted']!)
        : (t.brutal ? Colors.white : t.colors['layer-panel']!);
    return Semantics(
      button: !widget.checkbox,
      checked: widget.checkbox ? widget.selected : null,
      enabled: widget.onTap != null,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
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
                border: t.brutal
                    ? Border.all(color: Colors.black, width: 2)
                    : Border.all(color: t.colors['line-muted']!),
                borderRadius: BorderRadius.circular(t.brutal ? 0 : 6),
              ),
              child: Row(
                children: [
                  if (widget.checkbox) ...[
                    SizedBox.square(
                      dimension: 16,
                      child: Checkbox(
                        value: widget.selected,
                        onChanged: null,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
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
class RaftForwardSearchInput extends StatefulWidget {
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
  State<RaftForwardSearchInput> createState() => _RaftForwardSearchInputState();
}

class _RaftForwardSearchInputState extends State<RaftForwardSearchInput> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(changed);
    // `autoFocus`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.focusNode.requestFocus();
    });
  }

  void changed() => setState(() {});

  @override
  void dispose() {
    widget.focusNode.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final resolver = RaftRecipeTokens(t);
    final focused = widget.focusNode.hasFocus;
    final s = RaftInputRecipe.resolve(
      theme: t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant,
      states: RaftRecipeStates({
        if (focused) RaftRecipeStates.focus,
        if (focused) RaftRecipeStates.focusVisible,
      }),
      tokens: resolver,
    ).root;
    final text = s
        .textStyle(resolver)
        .copyWith(
          color: t.colors['foreground'],
          leadingDistribution: TextLeadingDistribution.even,
        );
    final border = s.borderWidth;
    return Container(
      decoration: s.decoration(resolver),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          TextField(
            autofillHints: null,
            controller: widget.controller,
            focusNode: widget.focusNode,
            onChanged: widget.onChanged,
            style: text,
            cursorColor: t.strong,
            decoration: InputDecoration(
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: widget.placeholder,
              hintStyle: text.copyWith(
                color: t.colors['foreground-placeholder'],
              ),
              contentPadding: EdgeInsets.fromLTRB(
                36,
                s.padding.top,
                s.padding.right,
                s.padding.bottom,
              ),
            ),
          ),
          Positioned(
            left: 12 - border.left,
            child: IgnorePointer(
              child: RaftIcon(
                RaftGlyph.search,
                size: 14,
                color: t.colors['foreground-muted'],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
