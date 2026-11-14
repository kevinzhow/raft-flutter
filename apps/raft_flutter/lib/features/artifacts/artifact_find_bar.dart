// Find in a framed page: the host draws the bar, the frame finds and
// highlights (Porthole `find`, P131).
//
// Source: packages/web/src/apps/artifacts/{ArtifactFindBar.tsx,
// artifactFind.ts} at v1.24.0-source.1: the query is sent after a 300 ms
// pause, at most 256 characters; Enter / Shift+Enter step, Escape closes;
// the count reads "2/5" ("2/1000+" when capped).
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'artifact_frame_view.dart';

/// Web `FIND_QUERY_PAUSE_MS` / `FIND_QUERY_MAX`.
const artifactFindPause = Duration(milliseconds: 300);
const artifactFindQueryMax = 256;

class ArtifactFindBar extends StatefulWidget {
  const ArtifactFindBar({
    super.key,
    required this.frame,
    required this.onClose,
  });

  final ArtifactFrameController frame;
  final VoidCallback onClose;

  @override
  State<ArtifactFindBar> createState() => _ArtifactFindBarState();
}

class _ArtifactFindBarState extends State<ArtifactFindBar> {
  final query = TextEditingController();
  final focus = FocusNode();
  Timer? pause;

  @override
  void initState() {
    super.initState();
    widget.frame.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(ArtifactFindBar old) {
    super.didUpdateWidget(old);
    if (old.frame != widget.frame) {
      old.frame.removeListener(_changed);
      widget.frame.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _typed(String value) {
    pause?.cancel();
    if (value.trim().isEmpty) {
      unawaited(widget.frame.clearFind());
      return;
    }
    pause = Timer(artifactFindPause, () {
      unawaited(widget.frame.find(value));
    });
  }

  void _step(String direction) {
    final value = query.text;
    if (value.trim().isEmpty) return;
    pause?.cancel();
    unawaited(widget.frame.find(value, direction: direction));
  }

  void _clear() {
    query.clear();
    _typed('');
    focus.requestFocus();
  }

  void _close() {
    pause?.cancel();
    unawaited(widget.frame.clearFind());
    widget.onClose();
  }

  @override
  void dispose() {
    pause?.cancel();
    widget.frame.removeListener(_changed);
    query.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    final t = RaftTokens.of(context);
    final answer = query.text.trim().isEmpty ? null : widget.frame.findAnswer;
    final moves = answer != null && answer.total > 0;
    final count = answer == null
        ? ''
        : raftFormat(
            context,
            answer.capped ? '{active}/{total}+' : '{active}/{total}',
            {'active': answer.active, 'total': answer.total},
          );
    Widget step(String key, RaftGlyph glyph, String label, String direction) =>
        RaftButton(
          key: ValueKey(key),
          glyph: glyph,
          tooltip: label,
          semanticLabel: label,
          tone: RaftButtonRecipeVariant.ghost,
          size: RaftButtonRecipeSize.iconMd,
          onPressed: moves ? () => _step(direction) : null,
        );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.enter): () => _step('next'),
        const SingleActivator(LogicalKeyboardKey.enter, shift: true): () =>
            _step('prev'),
      },
      child: Padding(
        key: const ValueKey('artifact-find-bar'),
        padding: const EdgeInsets.symmetric(
          horizontal: RaftSpace.x3,
          vertical: RaftSpace.x2,
        ),
        child: Row(
          spacing: RaftSpace.x1,
          children: [
            Expanded(
              child: RaftSearchInput(
                key: const ValueKey('artifact-find-input'),
                controller: query,
                focusNode: focus,
                hint: tr('Find in page'),
                clearLabel: tr('Clear search'),
                onClear: _clear,
                onChanged: (value) {
                  if (value.length > artifactFindQueryMax) {
                    query.text = value.substring(0, artifactFindQueryMax);
                  }
                  _typed(query.text);
                  setState(() {});
                },
              ),
            ),
            if (count.isNotEmpty)
              Text(
                count,
                key: const ValueKey('artifact-find-count'),
                style: RaftTypography.mono(
                  t,
                  size: 12,
                  line: 16,
                ).copyWith(color: t.ui.foregroundMuted),
              ),
            step(
              'artifact-find-previous',
              RaftGlyph.chevronUp,
              tr('Previous match'),
              'prev',
            ),
            step(
              'artifact-find-next',
              RaftGlyph.chevronDown,
              tr('Next match'),
              'next',
            ),
            RaftButton(
              key: const ValueKey('artifact-find-close'),
              glyph: RaftGlyph.x,
              tooltip: tr('Close find'),
              semanticLabel: tr('Close find'),
              tone: RaftButtonRecipeVariant.ghost,
              size: RaftButtonRecipeSize.iconMd,
              onPressed: _close,
            ),
          ],
        ),
      ),
    );
  }
}
