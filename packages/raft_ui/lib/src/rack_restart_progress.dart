import 'package:flutter/widgets.dart';

import 'theme.dart';
import 'raft/ui_tokens.dart';
import 'tokens/tokens.dart' show RaftTypeScale;
import 'localization.dart';

/// RackRowAction's restart progress (`font-mono text-mono-meta`, warning
/// colour on error, muted otherwise): replaces the row's action while a
/// restart runs and for the moment it ends.
class RaftRackRestartProgress extends StatelessWidget {
  const RaftRackRestartProgress({
    super.key,
    required this.text,
    this.error = false,
  });
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final color = error
        ? t.colors['warning-strong']!
        : t.colors['foreground-muted']!;
    return Text(
      raftText(context, text),
      style: t.scale(RaftTypeScale.monoMeta, color: color),
    );
  }
}
