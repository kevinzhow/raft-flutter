import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'hover_card.dart';
import 'localization.dart';
import 'popover_surface.dart';
import 'recipe_surface.dart' show raftCssText;
import 'raft/ui_tokens.dart';
import 'theme.dart';
import 'icons.dart';

/// Mounted MessageItem.tsx reactions deliberately override generic RUI chips.
@immutable
class RaftMountedReactionRecipe extends RaftControlRecipe {
  const RaftMountedReactionRecipe(
    super.tokens, {
    this.reacted = false,
    this.failure = false,
    this.raft = false,
  }) : super(variant: RaftControlVariant.ghost, visualHeight: raft ? 24 : 20);
  final bool reacted, failure;

  /// raft-ui 0.7 `messageReaction` (`h-6 rounded-chip pl-1.5 pr-2 bg-fill-muted`).
  final bool raft;
  static bool raftOf(RaftTokens t) =>
      t.option('reaction.style', or: 'recipe') == 'raft';
  double get height => raft ? 24 : 20;
  @override
  bool get transformsOnInteraction => false;
  @override
  double get focusOutlineWidth => 2;
  @override
  double get focusOutlineOffset => 2;
  @override
  Color get focusRing => tokens.colors['line-strong']!;
  @override
  BorderRadius get radius =>
      BorderRadius.circular(raft ? tokens.size('radius.chip', fallback: 6) : 4);
  @override
  EdgeInsets get padding => raft
      ? const EdgeInsets.only(left: 6, right: 8)
      : const EdgeInsets.symmetric(horizontal: 6);
  @override
  Color get foreground => tokens.strong;
  @override
  Color foregroundFor({bool hovered = false}) => foreground;
  @override
  Color get background => backgroundFor();
  @override
  Color backgroundFor({bool hovered = false}) {
    if (raft) {
      final ui = tokens.ui;
      // `hover:press-overlay`, `data-pressed:bg-attention-soft`,
      // `has-[error]:bg-warning-soft`.
      final base = failure
          ? ui['warning-soft']
          : reacted
          ? ui['attention-soft']
          : ui.fillMuted;
      return hovered ? Color.alphaBlend(ui.fillPressed, base) : base;
    }
    if (hovered) {
      return reacted ? tokens.accentSoft : tokens.colors['fill-muted']!;
    }
    if (failure) return tokens.colors['warning']!.withValues(alpha: .3);
    if (reacted) return tokens.accentSoft;
    final fill = tokens.colors['fill-muted']!;
    return fill.withValues(alpha: fill.a * .4);
  }

  @override
  TextStyle get textStyle => TextStyle(
    fontFamily: tokens.headingFont,
    fontSize: 12,
    height: raft ? 16 / 12 : 1,
    fontWeight: FontWeight.w700,
    color: foreground,
  );
  @override
  BorderSide side({bool hovered = false}) =>
      const BorderSide(color: Colors.transparent, width: 0);
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => const [];
}

/// Controlled paint and permission. The adapter supplies current reactor label
/// and glyph asset. Read-only projection is a span, not a dimmed disabled button.
class RaftMountedReaction extends StatelessWidget {
  const RaftMountedReaction({
    super.key,
    required this.label,
    required this.glyph,
    required this.count,
    this.onPressed,
    this.reacted = false,
    this.failure = false,
  });
  final String label;
  final Widget glyph;
  final int count;
  final VoidCallback? onPressed;
  final bool reacted, failure;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final raft = RaftMountedReactionRecipe.raftOf(t);
    final recipe = RaftMountedReactionRecipe(
      t,
      reacted: reacted,
      failure: failure,
      raft: raft,
    );
    final content = ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 15px at least; a glyph keeps its own advance (a non-sprite emoji
          // such as Noto's rocket is wider than 15).
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 15,
              minHeight: 15,
              maxHeight: 15,
            ),
            child: glyph,
          ),
          const SizedBox(width: 4),
          RaftReactionCount(
            count: count,
            style: recipe.textStyle.copyWith(fontFamily: t.monoFont),
          ),
        ],
      ),
    );
    if (onPressed == null) {
      return Semantics(
        label: label,
        child: Container(
          height: recipe.height,
          padding: recipe.padding,
          decoration: BoxDecoration(
            color: recipe.background,
            borderRadius: recipe.radius,
          ),
          child: content,
        ),
      );
    }
    return RaftControl(
      onPressed: onPressed,
      semanticLabel: label,
      visualHeight: recipe.height,
      // Mounted MessageItem uses the same 20px flow/hit in both pointer modes.
      // Generic controls retain their independent native touch target policy.
      minimumTargetSize: recipe.height,
      shadow: true,
      padding: recipe.padding,
      recipe: recipe,
      child: content,
    );
  }
}

/// Actual source count bump, only on a changed value; reduced motion suppresses it.
class RaftReactionCount extends StatefulWidget {
  const RaftReactionCount({
    super.key,
    required this.count,
    required this.style,
  });
  final int count;
  final TextStyle style;
  @override
  State<RaftReactionCount> createState() => _RaftReactionCountState();
}

class _RaftReactionCountState extends State<RaftReactionCount>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  bool moving = false;
  @override
  void didUpdateWidget(covariant RaftReactionCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count &&
        !MediaQuery.disableAnimationsOf(context)) {
      moving = true;
      controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) && controller.isAnimating) {
      controller.stop();
      moving = false;
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final value = controller.value;
        final first = value < .45;
        final progress = const Cubic(
          .2,
          0,
          .2,
          1,
        ).transform(first ? value / .45 : (value - .45) / .55);
        final offset = !moving
            ? 0.0
            : first
            ? 1 - 2 * progress
            : -1 + progress;
        final scale = !moving
            ? 1.0
            : first
            ? .92 + .24 * progress
            : 1.16 - .16 * progress;
        final opacity = !moving || !first ? 1.0 : .7 + .3 * progress;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, offset),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: Text('${widget.count}', style: widget.style),
    );
  }
}

/// Mounted MessageItem mobile add-reaction button; source md:hidden controls
/// its placement. Paint, hit and flow are 20px, independent of generic buttons.
class RaftMountedReactionAdd extends StatelessWidget {
  const RaftMountedReactionAdd({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final raft = RaftMountedReactionRecipe.raftOf(t);
    return RaftControl(
      semanticLabel: label,
      tooltip: label,
      onPressed: onPressed,
      visualHeight: raft ? 24 : 20,
      minimumTargetSize: raft ? 24 : 20,
      recipe: _ReactionAddRecipe(t, raft: raft),
      child: ExcludeSemantics(
        // `addButton`: `px-1.5 [&_svg]:size-4` in `text-foreground-muted`.
        child: raft
            ? RaftIcon(RaftGlyph.plus, size: 16, color: t.ui.foregroundMuted)
            : const RaftIcon(RaftGlyph.plus, size: 13, strokeWidth: 2.5),
      ),
    );
  }
}

class _ReactionAddRecipe extends RaftMountedReactionRecipe {
  const _ReactionAddRecipe(super.tokens, {super.raft});
  @override
  EdgeInsets get padding =>
      raft ? const EdgeInsets.symmetric(horizontal: 6) : super.padding;
  @override
  Color backgroundFor({bool hovered = false}) =>
      super.backgroundFor(hovered: hovered);
  @override
  Color backgroundForInteraction({
    bool hovered = false,
    bool pressed = false,
  }) => backgroundFor(hovered: hovered || pressed);
}

/// MessageItem `showReactionPopover` names: legacy rosters (`reactorIds` +
/// `reactorNames`) or canonical `previewK` actors; the viewer reads "You"
/// first when they reacted; at most five names, the rest as "+N more".
({List<String> names, int hidden}) raftReactionReactors(
  BuildContext context,
  Map<String, dynamic> reaction, {
  String? viewerId,
  bool reacted = false,
}) {
  final actors = <(String?, String)>[];
  final ids = reaction['reactorIds'], names = reaction['reactorNames'];
  if (ids is List && names is List) {
    for (final (i, id) in ids.indexed) {
      final name = i < names.length ? names[i] : null;
      actors.add(('$id', name is String ? name : raftText(context, 'Unknown')));
    }
  } else if (reaction['previewK'] is List) {
    for (final actor in (reaction['previewK'] as List).whereType<Map>()) {
      final name = actor['displayName'] ?? actor['name'];
      if (name is String) actors.add((actor['id'] as String?, name));
    }
  }
  final all = reacted && viewerId != null
      ? [
          raftText(context, 'You'),
          for (final (id, name) in actors)
            if (id != viewerId) name,
        ]
      : [for (final (_, name) in actors) name];
  final visible = all.take(5).toList();
  final count = reaction['count'] is int ? reaction['count'] as int : 0;
  return (names: visible, hidden: (count - visible.length).clamp(0, count));
}

/// MessageItem `reaction-reactors-popover`: PopoverPopup `role="tooltip"`,
/// `pointer-events-none max-w-[280px] px-2 py-1.5 text-xs font-bold`, names
/// in a `max-w-60` wrap, each `max-w-28 truncate`, ", " separators in the
/// placeholder ink and "+N more" muted; no names shows the emoji itself.
class RaftReactionReactors extends StatelessWidget {
  const RaftReactionReactors({
    super.key,
    required this.emoji,
    required this.names,
    this.hiddenCount = 0,
  });
  final String emoji;
  final List<String> names;
  final int hiddenCount;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = raftCssText.merge(
      RaftTypography.body(
        t,
        size: 12,
        line: 20,
        weight: FontWeight.w700,
        color: t.colors['foreground-strong']!,
      ),
    );
    final Widget body;
    if (names.isEmpty) {
      body = Text(emoji, style: style);
    } else {
      body = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Wrap(
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final (i, name) in names.indexed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 112),
                    child: Text(
                      name,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                  if (i < names.length - 1 || hiddenCount > 0)
                    Text(
                      ', ',
                      style: style.copyWith(
                        color: t.colors['foreground-placeholder']!,
                      ),
                    ),
                ],
              ),
            if (hiddenCount > 0)
              Text(
                raftFormat(context, '+{count} more', {'count': hiddenCount}),
                style: style.copyWith(color: t.colors['foreground-muted']!),
              ),
          ],
        ),
      );
    }
    return Semantics(
      container: true,
      liveRegion: true,
      child: RaftPopoverSurface(
        key: const ValueKey('reaction-reactors-popover'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: body,
          ),
        ),
      ),
    );
  }
}

/// A reaction chip with its reactor names on hover / keyboard focus
/// (MessageItem `onMouseEnter` / `onFocus` → `showReactionPopover`): opens at
/// once below the chip's left edge (`rect.bottom + 4`), closes on leave or
/// click, never from a list scrolling under the pointer.
class RaftReactionReactorsHover extends StatelessWidget {
  const RaftReactionReactorsHover({
    super.key,
    required this.emoji,
    required this.names,
    required this.hiddenCount,
    required this.child,
  });
  final String emoji;
  final List<String> names;
  final int hiddenCount;
  final Widget child;
  @override
  Widget build(BuildContext context) => RaftHoverCard(
    delay: Duration.zero,
    closeDelay: Duration.zero,
    interactive: false,
    surface: false,
    width: null,
    sideOffset: 4,
    collisionPadding: 0,
    card: (_) => RaftReactionReactors(
      emoji: emoji,
      names: names,
      hiddenCount: hiddenCount,
    ),
    child: child,
  );
}
