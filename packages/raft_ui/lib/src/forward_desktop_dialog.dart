// Presentational pieces of Web ForwardComposerDesktop
// (packages/web/src/components/message/ForwardComposerDesktop.tsx): the
// two-pane dialog card. The app owns targets, search and sending.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'raft_underline.dart';
import 'design_primitives.dart';
import 'error_presentation.dart' show RaftErrorBanner;
import 'form_controls.dart' show RaftPrefixedInput;
import 'icons.dart';
import 'recipes/input_group.g.dart' show RaftInputGroupRecipeVariant;
import 'theme.dart';

Color _rule(RaftTokens t) => t.brutal ? Colors.black : t.colors['line-muted']!;
Color _panel(RaftTokens t) =>
    t.brutal ? Colors.white : t.colors['layer-panel']!;

/// `text-xs font-bold` strong label (selected count, Clear, error).
TextStyle _label(RaftTokens t) => TextStyle(
  fontFamily: t.headingFont,
  fontSize: 12,
  height: 16 / 12,
  fontWeight: FontWeight.w700,
  color: t.strong,
  leadingDistribution: TextLeadingDistribution.even,
);

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
  });

  final String title, subtitle, selectedLabel, noteLabel;
  final String? clearLabel, error;

  /// The header close action.
  final Widget close;

  /// The destination search field ([RaftForwardDesktopSearch]).
  final Widget search;

  /// Whether the "Clear" link shows; [onClear] null renders it inert.
  final bool showClear;
  final VoidCallback? onClear;

  /// Destination rows (6px apart).
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
    final rule = _rule(t);
    final panel = _panel(t);
    final label = _label(t);
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          key: const ValueKey('forward-dialog'),
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: panel,
            border: Border.all(color: rule, width: t.brutal ? 2 : 1),
            borderRadius: BorderRadius.circular(t.brutal ? 0 : 8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: rule, width: 2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: RaftTypography.heading(
                              t,
                              size: 16,
                              line: 24,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: RaftTypography.mono(
                              t,
                              size: 12,
                              line: 16,
                              color: t.brutal
                                  ? Colors.black.withValues(alpha: .55)
                                  : t.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: rule, width: 2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          search,
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 24,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  selectedLabel,
                                  key: const ValueKey('forward-selected-count'),
                                  style: label,
                                ),
                                if (showClear)
                                  GestureDetector(
                                    onTap: onClear,
                                    child: RaftUnderlinedText(
                                      clearLabel ?? '',
                                      style: label,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                for (final (i, row) in rows.indexed) ...[
                                  if (i > 0) const SizedBox(height: 6),
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
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [preview],
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
    );
  }
}

/// `border-t-2 bg-layer-panel p-3` with a `Field`: the "Optional note" label
/// above the compact composer.
class _NoteBar extends StatelessWidget {
  const _NoteBar({required this.noteLabel, required this.note, this.error});
  final String noteLabel;
  final Widget note;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel(t),
        border: Border(top: BorderSide(color: _rule(t), width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Text(noteLabel, style: _label(t)),
          // Web MessageInput's own error row: `Banner intent="warning"
          // density="sm" font-bold` above the editor.
          if (error != null) RaftErrorBanner(error!, small: true, bold: true),
          note,
        ],
      ),
    );
  }
}

/// raft-ui `InputGroup` (v1.21.12) around a 14px Search icon addon and a
/// bold `text-sm` `InputGroupInput` with `autoFocus`, so the group shows its
/// focus state as soon as the dialog opens.
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
