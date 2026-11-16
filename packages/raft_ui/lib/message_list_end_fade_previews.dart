import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/message_list_end_fade.dart';
import 'src/theme.dart';

@RaftPreviews('Message list end fade', size: Size(390, 160))
Widget messageListEndFadePreview() => Builder(
  builder: (context) {
    final t = RaftTokens.of(context);
    return ColoredBox(
      color: t.colors['layer-canvas']!,
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              for (var i = 0; i < 8; i++)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Message $i', style: TextStyle(color: t.ink)),
                ),
            ],
          ),
          const RaftMessageListEndFade(),
        ],
      ),
    );
  },
);
