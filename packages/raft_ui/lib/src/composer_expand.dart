import 'package:flutter/material.dart';

import 'composer_recipe.dart';
import 'composer_tool_button.dart';
import 'design_primitives.dart';
import 'dialog_card.dart'
    show RaftRecipeButton, RaftRecipeCard, RaftRecipeSegmentedControl;
import 'icons.dart';
import 'localization.dart';
import 'markdown_editing.dart';
import 'message_body.dart';
import 'presentation.dart';
import 'sheet.dart';
import 'recipes/button_variants.g.dart';
import 'settings_layout.dart' show RaftSpace;
import 'text_scaling.dart' show RaftScaled;
import 'tap_slop.dart';
import 'theme.dart';

// The expandable composer: the expand button on the inline editor, the
// Markdown toolbar, and the expanded editor (desktop dialog / phone page).

/// Frames the inline editor: from [expandAtLines] lines on, a small expand
/// button sits at the editor's top-right and the text keeps clear of it.
///
/// The line count is always measured with the button's slot reserved, so
/// showing the button never changes whether it is shown (no flicker at the
/// threshold). The editor stays at the same position in the tree whether or
/// not the button is shown, so focus and the IME connection survive.
class RaftComposerExpandable extends StatelessWidget {
  const RaftComposerExpandable({
    super.key,
    required this.text,
    required this.recipe,
    required this.onExpand,
    required this.builder,
    this.editorInset,
  });

  /// Lines at which the expand button appears ("more than two lines").
  static const expandAtLines = 3;

  final String text;
  final RaftComposerRecipe recipe;

  /// The authored input inset after allocating a CSS negative action margin.
  /// Counting lines and placing the input must use the same available width.
  final EdgeInsets? editorInset;
  final VoidCallback? onExpand;

  /// Builds the editor with the inset it must use.
  final Widget Function(EdgeInsets inset) builder;

  static const _face = RaftMetrics.buttonXs;
  static const _slot = _face + RaftSpace.x1;

  static int lineCount(
    String text,
    TextStyle style,
    double width,
    TextScaler scaler,
  ) {
    if (text.isEmpty || width <= 0) return 1;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: width);
    final lines = painter.computeLineMetrics().length;
    painter.dispose();
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final base = editorInset ?? recipe.editorInset;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - base.horizontal - _slot;
        final show =
            lineCount(text, recipe.editorText, width, scaler) >= expandAtLines;
        final inset = show ? base.copyWith(right: base.right + _slot) : base;
        return Stack(
          children: [
            builder(inset),
            if (show)
              Positioned(
                top: (base.top - RaftSpace.x1).clamp(0.0, double.infinity),
                right: (base.right - RaftSpace.x1).clamp(0.0, double.infinity),
                child: RaftComposerToolButton(
                  key: const ValueKey('composer-expand'),
                  glyph: RaftGlyph.maximize2,
                  tooltip: 'Expand Editor',
                  face: _face,
                  framed: true,
                  prominent: true,
                  onPressed: onExpand,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The expanded editor's spacing. One inner padding and one vertical beat,
/// shared by every row of the card, so the toolbar, the editor text, the
/// preview and the action row line up on the left and the right, and the gaps
/// between rows are equal. Both come from the raft_ui spacing scale; nothing
/// in the expanded editor adds its own number.
abstract final class RaftComposerExpandedLayout {
  /// Left and right padding inside the card: toolbar, text, preview, actions.
  static const pad = RaftSpace.x3;

  /// The vertical beat: above and below the toolbar, above the text, below it,
  /// and below the action row.
  static const gap = RaftSpace.x2;

  /// The toolbar button face (the edge that must meet [pad]).
  static const toolFace = RaftMetrics.buttonSm;
}

/// The Markdown toolbar: only styles the message renderer draws. Each button
/// edits the draft through [RaftMarkdownFormat] and leaves the editor focused.
class RaftComposerFormatToolbar extends StatelessWidget {
  const RaftComposerFormatToolbar({
    super.key,
    required this.controller,
    this.preview,
    this.onPreview,
  });
  final TextEditingController controller;

  /// Desktop only: whether the preview pane is showing, and its toggle.
  final bool? preview;
  final VoidCallback? onPreview;

  void _apply(TextEditingValue Function(TextEditingValue) op) {
    final v = controller.value;
    // An IME composition is the input method's until it commits.
    if (v.composing.isValid && !v.composing.isCollapsed) return;
    controller.value = op(v);
  }

  @override
  Widget build(BuildContext context) {
    final line = _ruleColor(RaftTokens.of(context));
    Widget sep() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x1_5),
      child: SizedBox(
        width: 1,
        height: RaftSpace.x4,
        child: ColoredBox(color: line),
      ),
    );
    Widget b(
      RaftGlyph glyph,
      String tooltip,
      TextEditingValue Function(TextEditingValue) op,
    ) => RaftComposerToolButton(
      glyph: glyph,
      tooltip: tooltip,
      onPressed: () => _apply(op),
    );
    const gap = SizedBox(width: RaftSpace.half);
    return Semantics(
      container: true,
      label: raftText(context, 'Formatting'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RaftComposerExpandedLayout.pad,
          vertical: RaftComposerExpandedLayout.gap,
        ),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    b(
                      RaftGlyph.bold,
                      'Bold',
                      (v) => RaftMarkdownFormat.wrap(v, '**'),
                    ),
                    gap,
                    b(
                      RaftGlyph.italic,
                      'Italic',
                      (v) => RaftMarkdownFormat.wrap(v, '*'),
                    ),
                    gap,
                    b(
                      RaftGlyph.strikethrough,
                      'Strikethrough',
                      (v) => RaftMarkdownFormat.wrap(v, '~~'),
                    ),
                    sep(),
                    b(RaftGlyph.heading, 'Heading', RaftMarkdownFormat.heading),
                    gap,
                    b(
                      RaftGlyph.textQuote,
                      'Quote',
                      (v) => RaftMarkdownFormat.linePrefix(v, '> '),
                    ),
                    gap,
                    b(
                      RaftGlyph.list,
                      'Bulleted List',
                      (v) => RaftMarkdownFormat.linePrefix(v, '- '),
                    ),
                    gap,
                    b(
                      RaftGlyph.listOrdered,
                      'Numbered List',
                      (v) => RaftMarkdownFormat.linePrefix(
                        v,
                        '1. ',
                        ordered: true,
                      ),
                    ),
                    gap,
                    b(
                      RaftGlyph.listChecks,
                      'Task List',
                      (v) => RaftMarkdownFormat.linePrefix(v, '- [ ] '),
                    ),
                    sep(),
                    b(
                      RaftGlyph.code,
                      'Inline Code',
                      (v) =>
                          RaftMarkdownFormat.wrap(v, '`', placeholder: 'code'),
                    ),
                    gap,
                    b(
                      RaftGlyph.terminal,
                      'Code Block',
                      RaftMarkdownFormat.codeBlock,
                    ),
                    gap,
                    b(RaftGlyph.link, 'Link', RaftMarkdownFormat.link),
                    gap,
                    b(
                      RaftGlyph.table,
                      'Table',
                      (v) => RaftMarkdownFormat.insert(
                        v,
                        RaftMarkdownFormat.table,
                      ),
                    ),
                    gap,
                    b(
                      RaftGlyph.minus,
                      'Divider',
                      (v) =>
                          RaftMarkdownFormat.insert(v, RaftMarkdownFormat.rule),
                    ),
                    sep(),
                    b(
                      RaftGlyph.atSign,
                      'Mention',
                      (v) => RaftMarkdownFormat.trigger(v, '@'),
                    ),
                    gap,
                    b(
                      RaftGlyph.hash,
                      'Channel or Task',
                      (v) => RaftMarkdownFormat.trigger(v, '#'),
                    ),
                  ],
                ),
              ),
            ),
            if (preview != null) ...[
              const SizedBox(width: RaftSpace.x2),
              RaftComposerToolButton(
                key: const ValueKey('composer-preview-toggle'),
                glyph: preview! ? RaftGlyph.eye : RaftGlyph.eyeOff,
                tooltip: preview! ? 'Hide Preview' : 'Show Preview',
                on: preview!,
                onPressed: onPreview,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _ruleColor(RaftTokens t) => t.colors['line-muted']!;

class _Rule extends StatelessWidget {
  const _Rule({super.key, this.vertical = false});
  final bool vertical;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final w = 1.0;
    return vertical
        ? SizedBox(
            width: w,
            child: ColoredBox(color: _ruleColor(t)),
          )
        : SizedBox(
            height: w,
            child: ColoredBox(color: _ruleColor(t)),
          );
  }
}

/// The expanded editor, in whatever form the window has (see
/// [RaftPresentationPolicy.editor]). [RaftSurfaceForm.dialog]: the card of a
/// centered dialog with the editor and a live preview side by side. Any other
/// form (the phone's bottom sheet): a Write / Preview switch above the card and
/// the toolbar under the text, riding above the keyboard.
///
/// It borrows everything from the composer that opened it: [editor] is that
/// composer's own text field (same controller, so the draft, selection and
/// mentions are shared), [footer] its action row, [frameEditor] wraps the field
/// for the @ / # suggestions. The editor keeps its state when the form changes.
class RaftComposerExpandedView extends StatefulWidget {
  const RaftComposerExpandedView({
    super.key,
    this.form = RaftSurfaceForm.dialog,
    required this.title,
    required this.controller,
    required this.editor,
    required this.footer,
    required this.onCollapse,
    this.attachments,
    this.previewBuilder,
  });
  final RaftSurfaceForm form;
  final String title;
  final TextEditingController controller;

  /// The composer's text field, built for the expanded editor.
  final Widget editor;

  /// Builds the action row (attach, task, send) for the given recipe.
  final Widget Function(RaftComposerRecipe recipe) footer;
  final VoidCallback onCollapse;
  final Widget? attachments;

  /// Renders the Markdown as it will be sent; defaults to [RaftMessageBody].
  final Widget Function(BuildContext context, String content)? previewBuilder;

  static const dialogMaxWidth = 1040.0, dialogMaxHeight = 760.0;

  @override
  State<RaftComposerExpandedView> createState() =>
      _RaftComposerExpandedViewState();
}

class _RaftComposerExpandedViewState extends State<RaftComposerExpandedView> {
  // Each layout remembers its own preview choice, so a resize across the
  // breakpoint never hides the editor: the dialog shows the preview beside the
  // text by default, the sheet shows Write first.
  bool sidePreview = true, pagePreview = false;

  // Keeps the editor's state (focus, IME connection, caret) when the layout
  // moves it: preview on or off, dialog to sheet.
  final editorKey = GlobalKey(debugLabel: 'expanded editor');

  bool get compact => widget.form != RaftSurfaceForm.dialog;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final phone = compact;
    final recipe = RaftComposerRecipe(t, desktop: !phone, bottomSafeInset: 0);
    const pad = RaftComposerExpandedLayout.pad;
    const gap = RaftComposerExpandedLayout.gap;
    final text = widget.controller.text.trim();

    final editor = Padding(
      padding: const EdgeInsets.fromLTRB(pad, gap, pad, gap),
      child: KeyedSubtree(key: editorKey, child: widget.editor),
    );
    final previewPane = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(pad, gap, pad, 0),
          child: Text(
            raftText(context, 'Preview · as sent'),
            style: RaftTypography.body(
              t,
              size: 11,
              line: 16,
              weight: FontWeight.w700,
              color: t.colors['foreground-placeholder'],
            ).copyWith(letterSpacing: .6),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('composer-preview'),
            padding: const EdgeInsets.fromLTRB(pad, gap, pad, gap),
            child: text.isEmpty
                ? Text(
                    raftText(context, 'Nothing to preview yet.'),
                    style: recipe.placeholder,
                  )
                : (widget.previewBuilder?.call(context, text) ??
                      RaftMessageBody(content: text)),
          ),
        ),
      ],
    );
    final toolbar = RaftComposerFormatToolbar(
      controller: widget.controller,
      preview: phone ? null : sidePreview,
      onPreview: phone
          ? null
          : () => setState(() => sidePreview = !sidePreview),
    );
    final Widget body = phone
        ? (pagePreview ? previewPane : editor)
        : (sidePreview
              ? Row(
                  children: [
                    Expanded(child: editor),
                    const _Rule(vertical: true),
                    Expanded(child: previewPane),
                  ],
                )
              : editor);

    final card = DecoratedBox(
      key: const ValueKey('composer-expanded-card'),
      decoration: recipe.shellDecoration(focused: true),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(recipe.shellRadius),
        // The whole card, padding included, is the field's: on desktop a
        // click outside a field's tap region unfocuses it, and the platform
        // commits a composition before the toolbar button even runs.
        child: TapRegion(
          groupId: EditableText,
          behavior: HitTestBehavior.opaque,
          child: RaftTapSlopHost(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Desktop: toolbar above the text. Phone: between the text and
                // the action row, so it rides directly above the keyboard.
                if (!phone) ...[
                  toolbar,
                  const _Rule(key: ValueKey('composer-toolbar-rule')),
                ],
                Expanded(child: body),
                if (phone && !pagePreview) ...[
                  const _Rule(key: ValueKey('composer-toolbar-rule')),
                  toolbar,
                ],
                if (widget.attachments != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(pad, 0, pad, gap),
                    child: widget.attachments!,
                  ),
                widget.footer(recipe),
              ],
            ),
          ),
        ),
      ),
    );

    final grows = RaftScaled.grows(context);
    final title = Text(
      widget.title,
      maxLines: grows ? null : 1,
      overflow: grows ? TextOverflow.clip : TextOverflow.ellipsis,
      style: RaftTypography.heading(t, size: 18, line: 28, color: t.ink),
    );
    final collapse = RaftRecipeButton(
      key: const ValueKey('composer-collapse'),
      variant: RaftButtonRecipeVariant.ghost,
      size: RaftButtonRecipeSize.iconSm,
      glyph: RaftGlyph.minimize2,
      tooltip: raftText(context, 'Collapse Editor'),
      onPressed: widget.onCollapse,
      foreground: t.colors['foreground-muted'],
    );

    if (!phone) {
      return Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: widget.title,
        child: RaftRecipeCard(
          dialog: true,
          maxWidth: RaftComposerExpandedView.dialogMaxWidth,
          padding: const EdgeInsets.all(RaftSpace.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                spacing: RaftSpace.x4,
                children: [
                  Expanded(child: title),
                  collapse,
                ],
              ),
              const SizedBox(height: RaftSpace.x4),
              Flexible(child: card),
            ],
          ),
        ),
      );
    }
    // Larger text reflows: the Write / Preview switch drops under the title.
    Widget switcher({
      required Widget collapse,
      required Widget title,
      required Widget segmented,
    }) => grows
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: RaftSpace.x2,
            children: [
              Row(
                spacing: RaftSpace.x2,
                children: [
                  collapse,
                  Expanded(child: title),
                ],
              ),
              segmented,
            ],
          )
        : Row(
            spacing: RaftSpace.x2,
            children: [
              collapse,
              Expanded(child: title),
              segmented,
            ],
          );
    // The sheet supplies the scrim, the handle, the safe areas and the keyboard
    // inset; this is its content: the header, then the card with the editor.
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: widget.title,
      child: RaftSheet.fixed(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(pad, 0, pad, gap),
              child: switcher(
                collapse: collapse,
                title: title,
                segmented: RaftRecipeSegmentedControl<bool>(
                  value: pagePreview,
                  items: [
                    (false, null, raftTextZh(context, 'Write', '编辑')),
                    (true, RaftGlyph.eye, 'Preview'),
                  ],
                  onChanged: (v) => setState(() => pagePreview = v),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(pad, 0, pad, pad),
                child: card,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Layout of the dialog route: centered, capped, with the dialog's inset. The
/// route frame ([RaftDialogFrame]) does the same for the real editor; this is
/// for previews that draw the dialog without a route.
class RaftComposerExpandedDialog extends StatelessWidget {
  const RaftComposerExpandedDialog({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => RaftDialogFrame(
    maxWidth: RaftComposerExpandedView.dialogMaxWidth,
    maxHeight: RaftComposerExpandedView.dialogMaxHeight,
    fillsHeight: true,
    child: child,
  );
}
