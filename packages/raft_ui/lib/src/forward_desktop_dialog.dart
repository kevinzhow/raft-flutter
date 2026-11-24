// Presentational pieces of Web ForwardComposerDesktop
// (packages/web/src/components/message/ForwardComposerDesktop.tsx): the
// two-pane dialog card. The app owns targets, search and sending.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'dialog_surface.dart';
import 'error_presentation.dart' show RaftErrorBanner;
import 'form_controls.dart' show RaftPrefixedInput;
import 'icons.dart';
import 'panel_layout.dart' show RaftCssText;
import 'raft/ui_tokens.dart';
import 'raft_underline.dart';
import 'recipes/input_group.g.dart' show RaftInputGroupRecipeVariant;
import 'space.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;

Color _seam(RaftTokens t) => t.ui.lineSeam;

/// `Card h-[min(clamp(30rem,72dvh,46rem),100dvh-2rem)]
/// w-[min(clamp(48rem,60vw,60rem),100vw-2rem)]` with the header, the
/// `clamp(19rem,24vw,22rem)` destination column and the preview / note column.
class RaftForwardDesktopDialog extends StatelessWidget {
  const RaftForwardDesktopDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.close,
    required this.search,
    required this.selectedLabel,
    required this.rows,
    required this.preview,
    required this.noteLabel,
    required this.note,
    this.clearLabel,
    this.onClear,
    this.showClear = false,
    this.error,
    this.warnings = const [],
  });

  final String title, subtitle, selectedLabel, noteLabel;
  final String? clearLabel, error;

  /// Banners above the preview (Web `{warnings}`: join, Joint Channel).
  final List<Widget> warnings;

  /// The header close action.
  final Widget close;

  /// The destination search field ([RaftForwardDesktopSearch]).
  final Widget search;

  /// Whether the "Clear" link shows; [onClear] null renders it inert.
  final bool showClear;
  final VoidCallback? onClear;

  /// Destination rows.
  final List<Widget> rows;

  /// The forwarded-bundle preview.
  final Widget preview;

  /// The note editor: Web mounts `MessageInput variant="compact"`, which
  /// carries its own send button.
  final Widget note;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = math.min(
      size.width - 32,
      (size.width * .6).clamp(768.0, 960.0),
    );
    final height = math.min(
      size.height - 32,
      (size.height * .72).clamp(480.0, 736.0),
    );
    final side = (size.width * .24).clamp(304.0, 352.0);
    final seam = _seam(t);
    final desktopFine = t.desktop && size.width >= 768;
    final eyebrowStyle = t.scale(
      RaftTypeScale.caption,
      weight: FontWeight.w600,
      color: t.ui.foregroundHint,
    );
    final clearStyle = t.scale(
      RaftTypeScale.caption,
      weight: FontWeight.w500,
      color: t.ui.foregroundMuted,
    );
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          key: const ValueKey('forward-dialog'),
          width: width,
          height: height,
          child: RaftDialogSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  constraints: BoxConstraints(minHeight: desktopFine ? 44 : 56),
                  padding: EdgeInsets.symmetric(
                    horizontal: RaftSpace.x4,
                    vertical: desktopFine ? 0 : RaftSpace.x2,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: seam,
                        width: RaftSpace.hairline,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: desktopFine
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                spacing: RaftSpace.x2,
                                children: [
                                  RaftCssText(
                                    title,
                                    style: t.scale(
                                      RaftTypeScale.headline,
                                      weight: FontWeight.w700,
                                      color: t.ui.foreground,
                                    ),
                                  ),
                                  if (subtitle.isNotEmpty)
                                    Expanded(
                                      child: RaftCssText(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: t.scale(
                                          RaftTypeScale.caption,
                                          color: t.ui.foregroundHint,
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  RaftCssText(
                                    title,
                                    style: t.scale(
                                      RaftTypeScale.headline,
                                      weight: FontWeight.w700,
                                      color: t.ui.foreground,
                                    ),
                                  ),
                                  if (subtitle.isNotEmpty)
                                    RaftCssText(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: t.scale(
                                        RaftTypeScale.caption,
                                        color: t.ui.foregroundHint,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(width: RaftSpace.x3),
                      close,
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: side,
                        padding: const EdgeInsets.all(RaftSpace.x3),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: seam,
                              width: RaftSpace.hairline,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            search,
                            const SizedBox(height: RaftSpace.x2),
                            SizedBox(
                              height: 24,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: RaftSpace.x1,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    RaftCssText(
                                      selectedLabel,
                                      key: const ValueKey(
                                        'forward-selected-count',
                                      ),
                                      style: eyebrowStyle,
                                    ),
                                    if (showClear)
                                      GestureDetector(
                                        onTap: onClear,
                                        child: RaftUnderlinedText(
                                          clearLabel ?? '',
                                          style: clearStyle,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: RaftSpace.x1),
                            Expanded(
                              child: ListView(
                                padding: EdgeInsets.zero,
                                children: [
                                  for (final (i, row) in rows.indexed) ...[
                                    if (i > 0)
                                      const SizedBox(height: RaftSpace.half),
                                    row,
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(RaftSpace.x3),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (final warning in warnings)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: RaftSpace.x3,
                                        ),
                                        child: warning,
                                      ),
                                    preview,
                                  ],
                                ),
                              ),
                            ),
                            _NoteBar(
                              noteLabel: noteLabel,
                              note: note,
                              error: error,
                            ),
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
      ),
    );
  }
}

/// Web `COMPOSER_DOCK_CLASS`: `shrink-0 border-t border-line-seam p-3` with a
/// `Field` (`FieldLabel size="sm"` above the compact composer).
class _NoteBar extends StatelessWidget {
  const _NoteBar({required this.noteLabel, required this.note, this.error});
  final String noteLabel;
  final Widget note;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(RaftSpace.x3),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _seam(t), width: RaftSpace.hairline),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: RaftSpace.x1_5,
        children: [
          RaftCssText(
            noteLabel,
            style: t.scale(
              RaftTypeScale.footnote,
              weight: FontWeight.w500,
              color: t.ui.foregroundMuted,
            ),
          ),
          if (error != null) RaftErrorBanner(error!, small: true, bold: true),
          note,
        ],
      ),
    );
  }
}

/// raft-ui `InputGroup` around a 14px Search icon addon and an
/// `InputGroupInput` with `autoFocus`, so the group shows its focus state as
/// soon as the dialog opens.
class RaftForwardDesktopSearch extends StatelessWidget {
  const RaftForwardDesktopSearch({
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
  Widget build(BuildContext context) => RaftPrefixedInput(
    prefix: '',
    leadingIcon: RaftGlyph.search,
    controller: controller,
    focusNode: focusNode,
    hintText: placeholder,
    semanticLabel: placeholder,
    autofocus: true,
    onChanged: onChanged,
    controlWeight: FontWeight.w700,
    variant: RaftInputGroupRecipeVariant.default_,
  );
}
