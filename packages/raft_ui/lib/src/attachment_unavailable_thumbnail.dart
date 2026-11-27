import 'package:flutter/widgets.dart';
import 'package:flutter/widget_previews.dart';

import 'icons.dart';
import 'raft/ui_tokens.dart';
import 'theme.dart';

class RaftAttachmentUnavailableThumbnail extends StatelessWidget {
  const RaftAttachmentUnavailableThumbnail({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = RaftTokens.of(context).ui;
    return ColoredBox(
      color: colors.fillMuted,
      child: Center(
        child: RaftIcon(
          RaftGlyph.imageOff,
          size: 20,
          color: colors.foregroundHint,
        ),
      ),
    );
  }
}

@Preview(name: 'Attachment thumbnail unavailable')
Widget previewAttachmentUnavailableThumbnail() => const SizedBox(
  width: 200,
  height: 120,
  child: RaftAttachmentUnavailableThumbnail(),
);
