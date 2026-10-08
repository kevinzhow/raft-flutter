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
  String? notice;
  @override
  void didUpdateWidget(RaftSecretView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      visible = false;
      notice = null;
    }
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
            label: visible ? 'Hide credential' : 'Reveal credential',
            onPressed: () => setState(() => visible = !visible),
          ),
          RaftTextButton(
            variant: RaftControlVariant.ghost,
            glyph: RaftGlyph.copy,
            label: 'Copy credential',
            onPressed: copying
                ? null
                : () async {
                    setState(() {
                      copying = true;
                      notice = null;
                    });
                    try {
                      await widget.onCopy(widget.value);
                      if (mounted) setState(() => notice = 'Copied');
                    } catch (_) {
                      if (mounted)
                        setState(() => notice = 'Could not copy. Try again.');
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
