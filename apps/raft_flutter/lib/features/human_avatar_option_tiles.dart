import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

// Web HumanAvatarBuilderDialog metrics: options are fixed 72px columns (`w-18`),
// a swatch's tile is the 44px touch target around its 32px dot.
const double _tileWidth = 72, _swatchTarget = 44, _swatchDot = 32;
const double _dotBorder = 1.5, _circle = 999;

/// The builder's five tabs (Web `TABS`).
enum HumanAvatarTab {
  background('Background'),
  skin('Skin'),
  hair('Hair'),
  expression('Expression'),
  accessories('Accessories');

  const HumanAvatarTab(this.label);
  final String label;
}

/// The English name of each option (Web `OPTION_LABEL`), localised at the
/// call site by raftText. Skin tones have none: "Tone {n}".
String humanAvatarOptionLabel(
  BuildContext context,
  RaftHumanAvatarField field,
  String id,
) {
  final name = switch ((field, id)) {
    (RaftHumanAvatarField.background, 'yellow') => 'Yellow',
    (RaftHumanAvatarField.background, 'pink') => 'Pink',
    (RaftHumanAvatarField.background, 'sky') => 'Sky',
    (RaftHumanAvatarField.background, 'mint') => 'Mint',
    (RaftHumanAvatarField.background, 'lilac') => 'Lilac',
    (RaftHumanAvatarField.background, 'cream') => 'Cream',
    (RaftHumanAvatarField.hair, 'short') => 'Short',
    (RaftHumanAvatarField.hair, 'side') => 'Side part',
    (RaftHumanAvatarField.hair, 'long') => 'Long',
    (RaftHumanAvatarField.hair, 'bun') => 'Bun',
    (RaftHumanAvatarField.hair, 'curly') => 'Curly',
    (RaftHumanAvatarField.hair, 'buzz') => 'Buzz',
    (RaftHumanAvatarField.hairColor, 'ink') => 'Black',
    (RaftHumanAvatarField.hairColor, 'brown') => 'Brown',
    (RaftHumanAvatarField.hairColor, 'blonde') => 'Blonde',
    (RaftHumanAvatarField.hairColor, 'ginger') => 'Ginger',
    (RaftHumanAvatarField.hairColor, 'grey') => 'Grey',
    (RaftHumanAvatarField.expression, 'wink') => 'Wink',
    (RaftHumanAvatarField.expression, 'grin') => 'Grin',
    (RaftHumanAvatarField.expression, 'oh') => 'Oh',
    (RaftHumanAvatarField.expression, 'smirk') => 'Smirk',
    (RaftHumanAvatarField.expression, 'happy') => 'Happy',
    (RaftHumanAvatarField.expression, 'calm') => 'Calm',
    (RaftHumanAvatarField.expression, 'blush') => 'Blush',
    (RaftHumanAvatarField.head, 'none') ||
    (RaftHumanAvatarField.face, 'none') => 'None',
    (RaftHumanAvatarField.head, 'cap') => 'Cap',
    (RaftHumanAvatarField.head, 'beanie') => 'Beanie',
    (RaftHumanAvatarField.head, 'headphones') => 'Headphones',
    (RaftHumanAvatarField.face, 'glasses') => 'Glasses',
    _ => null,
  };
  if (name == null) {
    return raftFormat(context, 'Tone {n}', {'n': id});
  }
  // Web's zh spells the two background names the app-icon picker already
  // maps (黄色 / 粉色) as 黄 / 粉.
  if (field == RaftHumanAvatarField.background && id == 'yellow') {
    return raftTextZh(context, name, '黄');
  }
  if (field == RaftHumanAvatarField.background && id == 'pink') {
    return raftTextZh(context, name, '粉');
  }
  return raftText(context, name);
}

/// The panel of one tab (Web `TabsPanel`s).
class HumanAvatarTabPanel extends StatelessWidget {
  const HumanAvatarTabPanel({
    super.key,
    required this.tab,
    required this.recipe,
    required this.disabled,
    required this.onPick,
  });
  final HumanAvatarTab tab;
  final RaftHumanAvatarRecipe recipe;
  final bool disabled;
  final void Function(RaftHumanAvatarField field, String id) onPick;

  Widget _tiles(
    BuildContext context,
    RaftHumanAvatarField field, {
    required String label,
    bool showLabels = true,
    bool withoutHead = false,
  }) => HumanAvatarOptionTiles(
    field: field,
    recipe: recipe,
    label: label,
    showLabels: showLabels,
    withoutHead: withoutHead,
    disabled: disabled,
    onPick: onPick,
  );

  Widget _group(BuildContext context, String title, Widget child) {
    final t = RaftTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: RaftSpace.x1_5,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: t
                .scale(RaftTypeScale.footnote, weight: FontWeight.w600)
                .copyWith(color: t.colors['foreground-muted']),
          ),
        ),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    return Padding(
      padding: const EdgeInsets.only(top: RaftSpace.x3),
      child: switch (tab) {
        HumanAvatarTab.background => _tiles(
          context,
          RaftHumanAvatarField.background,
          label: tr('Background'),
          showLabels: false,
        ),
        HumanAvatarTab.skin => _tiles(
          context,
          RaftHumanAvatarField.skin,
          label: tr('Skin'),
          showLabels: false,
        ),
        HumanAvatarTab.hair => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: RaftSpace.x3,
          children: [
            _group(
              context,
              tr('Style'),
              _tiles(
                context,
                RaftHumanAvatarField.hair,
                label: tr('Style'),
                withoutHead: true,
              ),
            ),
            _group(
              context,
              tr('Color'),
              HumanAvatarHairColorSwatches(
                recipe: recipe,
                label: tr('Color'),
                disabled: disabled,
                onPick: onPick,
              ),
            ),
          ],
        ),
        HumanAvatarTab.expression => _tiles(
          context,
          RaftHumanAvatarField.expression,
          label: tr('Expression'),
        ),
        HumanAvatarTab.accessories => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: RaftSpace.x3,
          children: [
            _group(
              context,
              tr('On the head'),
              _tiles(
                context,
                RaftHumanAvatarField.head,
                label: tr('On the head'),
              ),
            ),
            _group(
              context,
              tr('On the face'),
              _tiles(
                context,
                RaftHumanAvatarField.face,
                label: tr('On the face'),
              ),
            ),
          ],
        ),
      },
    );
  }
}

/// A radio group whose items are the tiles themselves: arrow keys move and
/// select (wrapping), only the chosen one is in the tab order (Web raft-ui
/// `RadioGroup` with `appearance="none"` items).
class _TileGroup extends StatefulWidget {
  const _TileGroup({
    required this.label,
    required this.ids,
    required this.chosen,
    required this.disabled,
    required this.onPick,
    required this.tile,
    required this.spacing,
    required this.runSpacing,
  });
  final String label;
  final List<String> ids;
  final String chosen;
  final bool disabled;
  final ValueChanged<String> onPick;
  final Widget Function(
    String id,
    bool chosen,
    FocusNode focus,
    VoidCallback pick,
  )
  tile;
  final double spacing, runSpacing;
  @override
  State<_TileGroup> createState() => _TileGroupState();
}

class _TileGroupState extends State<_TileGroup> {
  final nodes = <String, FocusNode>{};
  @override
  void dispose() {
    for (final n in nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  FocusNode node(String id) => nodes.putIfAbsent(id, FocusNode.new);

  void move(int delta) {
    if (widget.disabled) return;
    final at = widget.ids.indexOf(widget.chosen);
    final next = widget.ids[(at + delta) % widget.ids.length];
    widget.onPick(next);
    node(next).requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => move(1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => move(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => move(-1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => move(-1),
      },
      child: Semantics(
        role: SemanticsRole.radioGroup,
        label: widget.label,
        container: true,
        child: Wrap(
          spacing: widget.spacing,
          runSpacing: widget.runSpacing,
          children: [
            for (final id in widget.ids)
              widget.tile(
                id,
                id == widget.chosen,
                node(id)..skipTraversal = id != widget.chosen,
                () => widget.onPick(id),
              ),
          ],
        ),
      ),
    );
  }
}

/// Each option of one field, drawn as the current look wearing it.
///
/// Options are fixed 72px columns packed from the start of the row, 8px apart
/// (12px between rows). A tile is the avatar at `lg` (51px, the DS scale) with
/// its caption 4px under it. A chosen option is a value, so its mark is ink: a
/// 2px ink ring round the avatar and a bold caption. Hover and press add the
/// medium overlay to an unchosen tile; keyboard focus rings the whole tile.
class HumanAvatarOptionTiles extends StatelessWidget {
  const HumanAvatarOptionTiles({
    super.key,
    required this.field,
    required this.recipe,
    required this.label,
    required this.showLabels,
    required this.disabled,
    required this.onPick,
    this.withoutHead = false,
  });
  final RaftHumanAvatarField field;
  final RaftHumanAvatarRecipe recipe;
  final String label;
  final bool showLabels, disabled, withoutHead;
  final void Function(RaftHumanAvatarField field, String id) onPick;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    // `rounded-control`.
    final tile = raftRoundedBorder(t.size('radius.control', fallback: 6));
    return _TileGroup(
      label: label,
      ids: field.ids,
      chosen: recipe[field],
      disabled: disabled,
      onPick: (id) => onPick(field, id),
      spacing: RaftSpace.x2,
      runSpacing: RaftSpace.x3,
      tile: (id, chosen, focus, pick) {
        final base = withoutHead
            ? recipe.withOption(RaftHumanAvatarField.head, 'none')
            : recipe;
        final look = base.withOption(field, id).serialize();
        final name = humanAvatarOptionLabel(context, field, id);
        return RaftInteractive(
          key: ValueKey('human-avatar-option-${field.name}-$id'),
          focusNode: focus,
          semanticLabel: name,
          button: false,
          checked: chosen,
          inMutuallyExclusiveGroup: true,
          onPressed: disabled ? null : pick,
          builder: (context, state) {
            final overlay = !chosen && (state.hovered || state.pressed)
                ? t.colors['fill-medium']
                : null;
            return CustomPaint(
              foregroundPainter: RaftCssFocusOutline(
                enabled: state.focusVisible,
                color: t.colors['line-strong']!,
                radius: tile,
                offset: 0,
              ),
              child: Container(
                width: _tileWidth,
                padding: const EdgeInsets.symmetric(vertical: RaftSpace.x1_5),
                decoration: BoxDecoration(color: overlay, borderRadius: tile),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: RaftSpace.x1,
                  children: [
                    ExcludeSemantics(
                      child: _Ring(
                        chosen: chosen,
                        child: RaftAvatarSlot(
                          name: '',
                          agent: false,
                          slot: RaftAvatarSlotContext.profileTile,
                          sizeOverride: 51,
                          avatarUrl: look,
                        ),
                      ),
                    ),
                    if (showLabels)
                      ExcludeSemantics(
                        child: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: t
                              .scale(
                                RaftTypeScale.caption,
                                weight: chosen
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              )
                              .copyWith(
                                color:
                                    t.colors[chosen
                                        ? 'foreground'
                                        : 'foreground-muted'],
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// The chosen mark: a 2px ring (`outline-2 outline-offset-2`) in the
/// foreground ink round the avatar; transparent when not chosen so the tile
/// never shifts.
class _Ring extends StatelessWidget {
  const _Ring({required this.chosen, required this.child});
  final bool chosen;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return CustomPaint(
      foregroundPainter: RaftCssFocusOutline.rounded(
        enabled: chosen,
        color: t.colors['foreground']!,
        radius: t.option('avatar.shape', or: 'circle') == 'square'
            ? t.size('radius.avatar', fallback: 4)
            : _circle,
      ),
      child: child,
    );
  }
}

/// The hair colours as round swatches of the art's own palette: a swatch's
/// tile is the 44px touch target, the 32px dot centred in it.
class HumanAvatarHairColorSwatches extends StatelessWidget {
  const HumanAvatarHairColorSwatches({
    super.key,
    required this.recipe,
    required this.label,
    required this.disabled,
    required this.onPick,
  });
  final RaftHumanAvatarRecipe recipe;
  final String label;
  final bool disabled;
  final void Function(RaftHumanAvatarField field, String id) onPick;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    const field = RaftHumanAvatarField.hairColor;
    return _TileGroup(
      label: label,
      ids: field.ids,
      chosen: recipe[field],
      disabled: disabled,
      onPick: (id) => onPick(field, id),
      spacing: RaftSpace.x1,
      runSpacing: 4,
      tile: (id, chosen, focus, pick) {
        final name = humanAvatarOptionLabel(context, field, id);
        final color = raftHumanAvatarHairColor(id);
        return RaftTooltip(
          message: name,
          child: RaftInteractive(
            key: ValueKey('human-avatar-option-${field.name}-$id'),
            focusNode: focus,
            semanticLabel: name,
            button: false,
            checked: chosen,
            inMutuallyExclusiveGroup: true,
            onPressed: disabled ? null : pick,
            builder: (context, state) => CustomPaint(
              foregroundPainter: RaftCssFocusOutline.rounded(
                enabled: state.focusVisible,
                color: t.colors['line-strong']!,
                radius: _swatchTarget / 2,
                offset: 0,
              ),
              child: Container(
                width: _swatchTarget,
                height: _swatchTarget,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: !chosen && (state.hovered || state.pressed)
                      ? t.colors['fill-medium']
                      : null,
                ),
                child: CustomPaint(
                  foregroundPainter: RaftCssFocusOutline.rounded(
                    enabled: chosen,
                    color: t.colors['foreground']!,
                    radius: _swatchDot / 2,
                  ),
                  child: Container(
                    width: _swatchDot,
                    height: _swatchDot,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(
                        color: t.ui.stickerInk,
                        width: _dotBorder,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
