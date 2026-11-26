import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

enum SourceChannelFileGlyph { image, video, pdf, archive, other, jump, more }

/// Maps channel file glyphs to shared raft-ui icons.
class ChannelFileGlyph extends StatelessWidget {
  const ChannelFileGlyph(this.glyph, {super.key, this.size = 18, this.color});
  final SourceChannelFileGlyph glyph;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink =
        color ?? IconTheme.of(context).color ?? RaftTokens.of(context).strong;
    final shared = switch (glyph) {
      SourceChannelFileGlyph.image => RaftGlyph.image,
      SourceChannelFileGlyph.video => RaftGlyph.video,
      SourceChannelFileGlyph.pdf => RaftGlyph.fileText,
      SourceChannelFileGlyph.archive => RaftGlyph.archive,
      SourceChannelFileGlyph.other => RaftGlyph.file,
      SourceChannelFileGlyph.jump => RaftGlyph.mapPin,
      SourceChannelFileGlyph.more => RaftGlyph.ellipsisVertical,
    };
    return RaftIcon(shared, size: size, color: ink);
  }
}
