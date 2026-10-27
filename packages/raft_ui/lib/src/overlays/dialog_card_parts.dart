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
        closeButton: d.showClose
            ? RaftDialogClose._product(
                onPressed: raftGuardedClose(context, d.onClose),
                enabled: d.closeEnabled,
              )
            : const SizedBox.shrink(),
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
    final scrollPlatform = ScrollConfiguration.of(context).getPlatform(context);
    final desktopScrollbar = switch (scrollPlatform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    };
    final scrollbarTheme = ScrollbarTheme.of(context);
    final thickness = scrollbarTheme.thickness;
    final scrollbarGutter =
        [
          thickness?.resolve(<WidgetState>{}),
          thickness?.resolve({WidgetState.hovered}),
          thickness?.resolve({WidgetState.dragged}),
          thickness?.resolve({WidgetState.hovered, WidgetState.dragged}),
        ].whereType<double>().fold(12.0, math.max) +
        2 * math.max(0.0, scrollbarTheme.crossAxisMargin ?? 2);
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
    final heading = Padding(
      padding: EdgeInsets.only(bottom: header.margin.bottom),
      child: Row(
        spacing: header.columnGap ?? 0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Semantics(header: true, child: titleContent)),
          if (d.showClose)
            RaftDialogClose._product(
              onPressed: raftGuardedClose(context, d.onClose),
              enabled: d.closeEnabled,
            ),
        ],
      ),
    );
    Widget scrollingContent({
      required bool includeHeading,
      required bool includeFooter,
    }) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (includeHeading) heading,
        body,
        if (includeFooter && footer != null) ...[
          SizedBox(height: d.footerGap ?? header.margin.bottom),
          footer,
        ],
      ],
    );
    Widget card({required bool scaled, required double maxWidth}) => Semantics(
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
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (scaled) ...[
                      if (actions == null) heading,
                      Flexible(
                        child: SingleChildScrollView(
                          // Desktop scrollbars overlay the content. Leave room
                          // for their track so the edges of scaled actions
                          // remain clickable while scrolling.
                          padding: desktopScrollbar
                              ? EdgeInsetsDirectional.only(end: scrollbarGutter)
                              : null,
                          child: scrollingContent(
                            includeHeading: actions != null,
                            includeFooter: !d.pinFooterAtLargeText,
                          ),
                        ),
                      ),
                      if (d.pinFooterAtLargeText && footer != null) ...[
                        SizedBox(height: d.footerGap ?? header.margin.bottom),
                        footer,
                      ],
                    ] else ...[
                      heading,
                      body,
                      if (footer != null) ...[
                        SizedBox(height: d.footerGap ?? header.margin.bottom),
                        footer,
                      ],
                    ],
                    ?actions,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Web Modal scrolls the entire natural-height card. An enclosing Modal or
    // form frame already supplies that scrollport; a bare dialog route needs
    // one here. Above the default text size, cap the surface and scroll its
    // content: an explicit action row stays visible, otherwise the heading
    // does. Forms can also pin their footer for keyboard and submit access.
    return LayoutBuilder(
      builder: (context, box) {
        final hasOuterPadding =
            RaftFormFrame.framedOf(context) ||
            context.findAncestorWidgetOfExactType<RaftModalBackdrop>() != null;
        final horizontalMargin = hasOuterPadding
            ? 0.0
            : RaftSpace.x4 * 2 + media.padding.horizontal;
        final availableWidth = box.hasBoundedWidth
            ? box.maxWidth - horizontalMargin
            : media.size.width - RaftSpace.x4 * 2 - media.padding.horizontal;
        final maxWidth = math.min(
          d.maxWidth ?? product.defaultWidth.maxWidth!,
          math.max(0.0, availableWidth),
        );
        final scaled = RaftScaled.grows(context);
        final keyboard = media.viewInsets.bottom;
        if (!box.hasBoundedHeight) {
          if (!scaled) {
            return Align(
              widthFactor: 1,
              heightFactor: 1,
              child: card(scaled: false, maxWidth: maxWidth),
            );
          }
          final available =
              (media.size.height -
                      RaftSpace.x4 * 2 -
                      media.padding.vertical -
                      keyboard)
                  .clamp(0.0, double.infinity);
          return Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: available),
                child: card(scaled: true, maxWidth: maxWidth),
              ),
            ),
          );
        }
        // The presented form frame already supplies its outer safe-area and
        // 16px margins. A bare card supplies those margins itself.
        final margin = RaftFormFrame.framedOf(context)
            ? 0.0
            : RaftSpace.x4 * 2 + media.padding.vertical;
        final available = (box.maxHeight - margin - keyboard).clamp(
          0.0,
          double.infinity,
        );
        return Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: available),
              child: scaled
                  ? card(scaled: true, maxWidth: maxWidth)
                  : SingleChildScrollView(
                      child: card(scaled: false, maxWidth: maxWidth),
                    ),
            ),
          ),
        );
      },
    );
  }
}
