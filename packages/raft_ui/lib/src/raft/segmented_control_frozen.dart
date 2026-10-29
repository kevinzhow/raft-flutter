// The frozen Elegant and Brutal paint of the segmented control: the loose tab buttons, the task filter buttons and
// the row painted from the frozen `segmentedControl` recipe. The Raft look never reaches this file. Delete it with
// the legacy looks; do not add to it.
part of 'segmented_control.dart';

extension _FrozenSegmented<T> on _RaftSegmentedControlState<T> {
  Widget _frozenTaskViews(BuildContext context) => Wrap(
    spacing: 4,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (final item in widget.items)
        RaftTouchTargetExpander(
          minSize: const Size.square(RaftMetrics.touchTarget),
          child: RaftTaskFilterButton(
            selected: item.value == widget.value,
            onPressed: _press(item),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                if (item.glyph != null) RaftIcon(item.glyph!, size: 14),
                Text(item.label),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _frozenTabs(BuildContext context) => Wrap(
    spacing: 2,
    runSpacing: 2,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (final item in widget.items)
        RaftTabButton(
          key: item.itemKey,
          label: item.label,
          glyph: item.glyph,
          tooltip: item.tooltip,
          height: widget.visualHeight,
          selected: item.value == widget.value,
          onPressed: _press(item),
        ),
    ],
  );

  Widget _frozenRecipe(BuildContext context) =>
      _FrozenRecipeSegmentedControl<T>(
        value: widget.value,
        items: [
          for (final item in widget.items) (item.value, item.glyph, item.label),
        ],
        counts: {
          for (final item in widget.items)
            if (item.count != null) item.value: item.count!,
        },
        onChanged: widget.onChanged == null || widget.disabled
            ? null
            : widget.onChanged,
      );
}

/// raft-ui `SegmentedControl` + `SegmentedControlItem` (+ leading Lucide icon
/// and `SegmentedControlLabel`) painted from the generated
/// `segmentedControl` recipe: `root` lays items out with its gap, `item`
/// carries border/padding/type and its `data-checked`/`hover` states.
class _FrozenRecipeSegmentedControl<T> extends StatelessWidget {
  const _FrozenRecipeSegmentedControl({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.counts = const {},
  });
  final T value;
  final List<(T, RaftGlyph?, String)> items;
  final ValueChanged<T>? onChanged;
  final String? label;

  /// `SegmentedControlCount` per item value (omitted values render none).
  final Map<T, String> counts;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final root = RaftSegmentedControlRecipe.resolve(
      theme: raftRecipeThemeOf(t),
      tokens: RaftRecipeTokens(t),
    ).root;
    // raft-ui 0.7.0: the items sit in a muted track (`rounded-[11px]
    // bg-fill-muted p-[3px]`); the frozen looks have no track.
    final tokens = RaftRecipeTokens(t);
    final track = !usesLegacyRecipes(tokens);
    return Semantics(
      label: label,
      container: true,
      child: _FillWhenWrapped(
        child: Container(
          padding: track ? root.padding : null,
          decoration: track ? root.decoration(tokens) : null,
          child: Wrap(
            spacing: root.columnGap ?? 0,
            runSpacing: root.rowGap ?? 0,
            children: [
              for (final (v, glyph, text) in items)
                _RecipeSegment(
                  checked: v == value,
                  glyph: glyph,
                  label: raftText(context, text),
                  count: counts[v],
                  onTap: onChanged == null ? null : () => onChanged!(v),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The `inline-flex flex-wrap max-w-full` root of the Web SegmentedControl:
/// content width while the items fit on one line, the full available width
/// once they wrap (Flutter's `Wrap` would shrink to its widest run).
class _FillWhenWrapped extends SingleChildRenderObjectWidget {
  const _FillWhenWrapped({required Widget child}) : super(child: child);
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFillWhenWrapped();
}

class _RenderFillWhenWrapped extends RenderProxyBox {
  @override
  void performLayout() {
    final child = this.child!;
    child.layout(constraints.loosen(), parentUsesSize: true);
    final wrapped =
        constraints.hasBoundedWidth &&
        child.getMaxIntrinsicWidth(double.infinity) > constraints.maxWidth;
    size = constraints.constrain(
      Size(
        wrapped ? constraints.maxWidth : child.size.width,
        child.size.height,
      ),
    );
  }
}

class _RecipeSegment extends StatefulWidget {
  const _RecipeSegment({
    required this.checked,
    required this.glyph,
    required this.label,
    required this.onTap,
    this.count,
  });
  final bool checked;
  final RaftGlyph? glyph;
  final String label;
  final String? count;
  final VoidCallback? onTap;
  @override
  State<_RecipeSegment> createState() => _RecipeSegmentState();
}

class _RecipeSegmentState extends State<_RecipeSegment> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = RaftRecipeTokens(t);
    final recipe = RaftSegmentedControlRecipe.resolve(
      theme: raftRecipeThemeOf(t),
      disabled: widget.onTap == null,
      states: RaftRecipeStates({
        if (t.dark) RaftRecipeStates.dark,
        if (hovered && widget.onTap != null) RaftRecipeStates.hover,
        widget.checked ? 'data-checked' : 'data-unchecked',
        if (widget.checked) 'group/segmented-control-item:data-checked',
        if (widget.count != null) 'has:data-slot=segmented-control-count',
      }),
      tokens: tokens,
    );
    final item = recipe.item;
    // Inherited `font-display` (main.font-display) supplies the family.
    final text = item
        .textStyle(tokens)
        .copyWith(
          fontFamily: item.fontFamily ?? t.headingFont,
          leadingDistribution: TextLeadingDistribution.even,
        );
    final color = text.color ?? t.ink;
    final svg = item.target("& svg:not([class*='size-'])");
    final stroke = item.target('& svg');
    return Semantics(
      button: true,
      selected: widget.checked,
      label: widget.label,
      excludeSemantics: true,
      child: RaftHoverRegion(
        cursor: widget.onTap == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Opacity(
            opacity: item.opacity ?? 1,
            child: Container(
              padding: item.padding,
              decoration: item.decoration(tokens),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.glyph != null) ...[
                    RaftIcon(
                      widget.glyph!,
                      size: svg?.width ?? 14,
                      color: color,
                      strokeWidth:
                          (stroke?['stroke-width'] as CssNum?)?.value
                              .toDouble() ??
                          2,
                    ),
                    SizedBox(width: item.columnGap ?? 0),
                  ],
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.copyWith(color: color),
                  ),
                  if (widget.count != null) ...[
                    SizedBox(width: item.columnGap ?? 0),
                    Text(
                      widget.count!,
                      maxLines: 1,
                      style: recipe.count.text(
                        tokens,
                        base: text.copyWith(color: color),
                      ),
                    ),
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
