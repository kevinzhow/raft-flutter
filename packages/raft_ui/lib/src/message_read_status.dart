import 'package:flutter/material.dart';

import 'icons.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftCssText;
import 'raft/ui_tokens.dart';
import 'text_scaling.dart';
import 'theme.dart';
import 'tokens/tokens.dart';

/// Web MessageItem `dm-read-status`: a separate right-aligned line below the
/// last DM message's footer and inline replies. Visibility belongs to the app.
class RaftMessageReadStatus extends StatelessWidget {
  const RaftMessageReadStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final label = raftText(context, 'Read');
    final style = t.scale(t.typeSlot('caption'), color: t.ui.foregroundHint);
    return Padding(
      padding: EdgeInsets.only(top: RaftScale.space(1)),
      child: KeyedSubtree(
        key: const ValueKey('dm-read-status'),
        child: RaftScaled.lineBox(
          context,
          height: RaftScale.space(5),
          child: Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              container: true,
              label: label,
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RaftIcon(
                      RaftGlyph.checkCircle,
                      size: RaftScale.space(3),
                      color: t.ui.foregroundHint,
                    ),
                    SizedBox(width: RaftScale.space(1)),
                    RaftCssText(label, style: style),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
