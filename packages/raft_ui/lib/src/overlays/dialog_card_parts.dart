part of 'dialog.dart';

class _CardDialogParts extends StatefulWidget {
  const _CardDialogParts({required this.dialog});
  final RaftDialog dialog;
  @override
  State<_CardDialogParts> createState() => _CardDialogPartsState();
}

class _CardDialogPartsState extends State<_CardDialogParts> {
  final _body = GlobalKey(debugLabel: 'dialog body');
  final _footer = GlobalKey(debugLabel: 'dialog footer');
  final _actions = GlobalKey(debugLabel: 'dialog actions');

  @override
  Widget build(BuildContext context) {
    final d = widget.dialog;
    final t = RaftTokens.of(context), tokens = t.recipeTokens;
    final states = t.recipeStates();
    final product = RaftWebDialogCardRecipe.resolve(
      states: states,
      tokens: tokens,
    );
    final root = product.root;
    final header = product.header;
    final title = product.title;
    final body = KeyedSubtree(key: _body, child: d.child!);
    final footer = d.footer == null
        ? null
        : KeyedSubtree(key: _footer, child: d.footer!);
    final actions = d.cardActions == null
        ? null
        : KeyedSubtree(key: _actions, child: d.cardActions!);
    if (RaftFormFrame.sheetOf(context)) {
      return RaftFormSheet(
        title: raftText(context, d.title! as String),
        onClose: d.closeEnabled ? d.onClose : null,
        titleGlyph: d.titleGlyph,
        body: body,
        footer: footer ?? actions,
      );
    }
    final base = RaftDialogSurfaceRecipe.resolve(
      states: states,
      tokens: tokens,
    ).root;
    final combined = base.copyWith(
      properties: {...base.properties, ...root.properties},
    );
    final media = MediaQuery.of(context);
    final maxWidth = math.min(
      d.maxWidth ?? product.defaultWidth.maxWidth!,
      math.max(
        0.0,
        media.size.width - RaftSpace.x4 * 2 - media.padding.horizontal,
      ),
    );
    Widget titleContent = Text(
      raftText(context, d.title! as String),
      style: title.text(tokens, base: DefaultTextStyle.of(context).style),
    );
    if (d.titleGlyph case final glyph?) {
      titleContent = Row(
        spacing: header.columnGap ?? 0,
        children: [
          RaftIcon(glyph, size: product.glyph.width!),
          Expanded(child: titleContent),
        ],
      );
    }
    final card = Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      role: SemanticsRole.dialog,
      label: raftText(context, d.title! as String),
      child: Material(
        type: MaterialType.transparency,
        child: RaftTapSlopHost(
          child: SizedBox(
            width: maxWidth,
            child: RaftDialogSurface(
              key: d.contentKey,
              surfaceStyle: combined,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: header.margin.bottom),
                    child: Row(
                      spacing: header.columnGap ?? 0,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Semantics(header: true, child: titleContent),
                        ),
                        RaftDialogClose._product(
                          onPressed: raftGuardedClose(context, d.onClose),
                          enabled: d.closeEnabled,
                        ),
                      ],
                    ),
                  ),
                  body,
                  if (footer != null) ...[
                    SizedBox(height: d.footerGap ?? header.margin.bottom),
                    footer,
                  ],
                  ?actions,
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // Web Modal scrolls the entire natural-height card. An enclosing Modal or
    // form frame already supplies that scrollport; a bare dialog route needs
    // one here. Only the mobile sheet above pins its header and action row.
    return LayoutBuilder(
      builder: (context, box) => Align(
        widthFactor: 1,
        heightFactor: 1,
        child: box.hasBoundedHeight
            ? ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      (media.size.height -
                              RaftSpace.x4 * 2 -
                              media.padding.vertical -
                              media.viewInsets.bottom)
                          .clamp(0, double.infinity),
                ),
                child: SingleChildScrollView(child: card),
              )
            : card,
      ),
    );
  }
}
