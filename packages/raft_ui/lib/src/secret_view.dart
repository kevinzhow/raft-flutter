import 'dart:async';

import 'package:flutter/material.dart';

import 'localization.dart';
import 'icons.dart';
import 'design_primitives.dart';

/// Displays a one-time credential only after an explicit reveal action.
/// Clipboard access belongs to the host application.
class RaftSecretView extends StatefulWidget {
  const RaftSecretView({
    super.key,
    required this.value,
    required this.onCopy,
    this.label = 'One-time credential',
  });
  final String value, label;
  final Future<void> Function(String) onCopy;
  @override
  State<RaftSecretView> createState() => _RaftSecretViewState();
}

class _RaftSecretViewState extends State<RaftSecretView> {
  bool visible = false, copying = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared two seconds after it is raised, when the next copy starts or when the credential value changes.
  String? notice;

  /// The copy result is a momentary confirmation, not a standing state.
  Timer? noticeTimer;

  void showNotice(String text) {
    noticeTimer?.cancel();
    setState(() => notice = text);
    noticeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => notice = null);
    });
  }

  void clearNotice() {
    noticeTimer?.cancel();
    notice = null;
  }

  @override
  void didUpdateWidget(RaftSecretView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      visible = false;
      clearNotice();
    }
  }

  @override
  void dispose() {
    noticeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        raftText(context, widget.label),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      if (visible)
        Semantics(
          label: widget.value,
          child: ExcludeSemantics(child: SelectableText(widget.value)),
        )
      else
        Text(
          raftText(context, 'Credential hidden'),
          key: const Key('credential-hidden'),
        ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        children: [
          RaftTextButton(
            variant: RaftControlVariant.ghost,
            glyph: visible ? RaftGlyph.eyeOff : RaftGlyph.eye,
            label: visible ? 'Hide Credential' : 'Reveal Credential',
            onPressed: () => setState(() => visible = !visible),
          ),
          RaftTextButton(
            variant: RaftControlVariant.ghost,
            glyph: RaftGlyph.copy,
            label: 'Copy Credential',
            onPressed: copying
                ? null
                : () async {
                    setState(() {
                      copying = true;
                      clearNotice();
                    });
                    try {
                      await widget.onCopy(widget.value);
                      if (mounted) showNotice('Copied');
                    } catch (_) {
                      if (mounted) showNotice('Could not copy. Try again.');
                    } finally {
                      if (mounted) setState(() => copying = false);
                    }
                  },
          ),
        ],
      ),
      if (notice != null)
        Semantics(liveRegion: true, child: Text(raftText(context, notice!))),
    ],
  );
}
