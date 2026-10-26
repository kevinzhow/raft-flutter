// The frozen Elegant and Brutal paint of the labelled select (a57b9dab): a Material `DropdownButtonFormField` under
// an `InputDecoration` label, as the pre-theme sidebar settings drew it. The Raft look never reaches this file:
// `RaftLabeledSelect` paints a `RaftField` around the canonical `RaftSelectField`. Delete the file with the legacy
// looks; do not add to it.
part of 'select_field.dart';

Widget _frozenLabeledSelect<T>(
  BuildContext context,
  RaftLabeledSelect<T> select,
) => DropdownButtonFormField<T>(
  key: select.fieldKey,
  initialValue: select.value,
  decoration: InputDecoration(labelText: raftText(context, select.label)),
  items: [
    for (final item in select.items)
      DropdownMenuItem<T>(
        value: item.value,
        enabled: item.enabled,
        child: item.child,
      ),
  ],
  onChanged: select.onChanged,
);

extension _FrozenSelectTrigger<T> on _RaftSelectFieldState<T> {
  /// The pre-theme trigger: the Button outline md box merged with the select `trigger` slot of the frozen recipes, with
  /// the pack's type and elevation tokens on top.
  Widget _frozenTrigger(
    BuildContext context,
    RaftTokens t,
    RaftInteractionState st, {
    required bool enabled,
    required bool fieldChrome,
    required RaftSelectItem<T>? selected,
    required bool hasValue,
  }) {
    final rt = t.recipeTokens;
    final states = t.recipeStates(
      hovered: st.hovered,
      pressed: st.pressed,
      focusVisible: st.focusVisible,
      disabled: !enabled,
      extra: [if (open) 'data-popup-open', if (widget.invalid) 'data-invalid'],
    );
    final edge = t.option('control.edge', or: 'ring');
    final sheen = t.option('control.sheen', or: 'none') == 'gradient';
    // One base supplies only the layout, ring and sheen. Elevation is
    // independent data; a motion choice cannot select its paint recipe.
    const recipeTheme = RaftRecipeTheme.elegant;
    final button = RaftButtonRecipe.resolve(
      theme: recipeTheme,
      variant: RaftButtonRecipeVariant.outline,
      size: RaftButtonRecipeSize.md,
      states: states,
      tokens: rt,
    ).root;
    final sel = RaftSelectRecipe.resolve(
      theme: recipeTheme,
      chrome: widget.chrome,
      states: states,
      tokens: rt,
    );
    final merged = raftMergeSlots(button, sel.trigger);
    final shadows = <CssValue>[];
    for (final layer in merged.boxShadow) {
      if (layer is! RaftLiteralShadow) continue;
      if (layer.inset ? sheen : edge == 'ring') {
        shadows.add(
          _selectShadow(
            RaftCssShadow(
              inset: layer.inset,
              offset: layer.offset,
              blur: layer.blur,
              spread: layer.spread,
              color: layer.color.resolve(rt),
            ),
          ),
        );
      }
    }
    final shadowRole = st.focusVisible && enabled
        ? 'shadow.selectFocus'
        : st.hovered && enabled
        ? 'shadow.selectHover'
        : st.pressed && enabled
        ? 'shadow.selectPressed'
        : 'shadow.select';
    shadows.addAll(t.shadowLayers(shadowRole).map(_selectShadow));
    // Read the old cascade's transforms only; its other properties never
    // decide this control's fill, edge, sheen or elevation.
    final motion = t.option('press.effect', or: 'overlay');
    final motionTheme = motion == 'offsetShadow'
        ? RaftRecipeTheme.brutal
        : RaftRecipeTheme.elegant;
    final motionStyle = raftMergeSlots(
      RaftButtonRecipe.resolve(
        theme: motionTheme,
        variant: RaftButtonRecipeVariant.outline,
        size: RaftButtonRecipeSize.md,
        states: states,
        tokens: rt,
      ).root,
      RaftSelectRecipe.resolve(
        theme: motionTheme,
        chrome: widget.chrome,
        states: states,
        tokens: rt,
      ).trigger,
    );
    final s = RaftSlotStyle(
      {
        ...merged.properties,
        'font-size': CssNum(
          t.size(
            fieldChrome ? 'type.field.size' : 'type.selectValue.size',
            fallback: 14,
          ),
          'px',
        ),
        'letter-spacing': CssNum(
          t.size('type.selectValue.tracking', fallback: -.005),
          'em',
        ),
        'line-height': CssNum(
          fieldChrome ? t.size('type.field.line', fallback: 20) : 20,
          'px',
        ),
        'color': CssVar(
          '--foreground-select',
          null,
          !hasValue
              ? 'foregroundSelectPlaceholder'
              : !enabled
              ? 'foregroundSelectDisabled'
              : 'foregroundSelect',
        ),
        'background-color': CssVar(
          '--layer-select',
          null,
          !enabled
              ? 'layerSelectDisabled'
              : st.hovered
              ? 'layerSelectHover'
              : 'layerSelect',
        ),
        if (!enabled)
          'opacity': CssNum(t.size('opacity.selectDisabled', fallback: .4)),
        'box-shadow': CssList(shadows),
        for (final name in ['transform', 'scale', 'translate'])
          name: motion != 'overlay'
              ? motionStyle.properties[name] ?? const CssKeyword('none')
              : const CssKeyword('none'),
      },
      {
        for (final entry in merged.targets.entries)
          if (entry.key != '::before' || sheen) entry.key: entry.value,
      },
      merged.classes,
      merged.tokens,
    );
    return RaftRecipeBox(
      style: s,
      tokens: rt,
      // `w-full` (brutal trigger slot); elegant stays content-sized but
      // these callers stretch it in a column.
      width: double.infinity,
      height:
          widget.height ??
          t.size('size.selectTrigger', fallback: s.height ?? 32),
      padding: EdgeInsets.fromLTRB(
        t.size('space.selectTriggerStart', fallback: 12),
        0,
        12,
        0,
      ),
      decorationOverride: (d) => d.copyWith(
        border: edge == 'inkBorder'
            ? Border.all(
                color:
                    t.colors[widget.invalid
                        ? 'danger-strong'
                        : enabled
                        ? 'line-select'
                        : 'line-select-disabled']!,
                // CSS at the source capture DPR floors its authored 1.5.
                width: t.size('stroke.control', fallback: 1).floorToDouble(),
              )
            : d.border,
        borderRadius: BorderRadius.circular(
          t.size('radius.control', fallback: 6),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Builder(
              builder: (context) => DefaultTextStyle.merge(
                style: TextStyle(
                  fontWeight:
                      FontWeight.values[((fieldChrome
                                      ? t.size(
                                          'type.field.weight',
                                          fallback: 400,
                                        )
                                      : !hasValue
                                      ? t.size(
                                          'type.selectPlaceholder.weight',
                                          fallback: 500,
                                        )
                                      : t.size(
                                          'type.selectValue.weight',
                                          fallback: 500,
                                        )) /
                                  100 -
                              1)
                          .round()
                          .clamp(0, 8)],
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                child:
                    selected?.child ??
                    Text(
                      hasValue ? widget.unmatchedLabel! : widget.placeholder,
                    ),
              ),
            ),
          ),
          SizedBox(width: sel.trigger.columnGap ?? 6),
          Opacity(
            opacity: sel.icon.opacity ?? 1,
            child: Builder(
              builder: (context) => RaftIcon(
                RaftGlyph.chevronDown,
                size: t.size('size.selectChevron', fallback: 14),
                strokeWidth: t.size('stroke.selectChevron', fallback: 1.5),
                color: DefaultTextStyle.of(context).style.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
