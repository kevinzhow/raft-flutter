import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/components.dart';
import 'src/delegated_face.dart';
import 'src/theme.dart';

/// raft-ui `MessageItemDelegatedAvatar` on an owner's md avatar: at rest, on
/// a hovered row fill, and for a deleted assistant.
@RaftPreviews('Delegated assistant face', size: Size(260, 90))
Widget delegatedFacePreview() => Builder(
  builder: (context) {
    final t = RaftTokens.of(context);
    Widget owner(Color fill, {bool deleted = false}) => RaftMessageRowFillScope(
      color: fill,
      child: ColoredBox(
        color: fill,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: RaftAvatar(
            name: 'Kai Owner',
            size: 35,
            corner: RaftDelegatedFace(
              deleted: deleted,
              agentAvatar: const RaftAvatar(
                name: 'Ottie',
                size: 19,
                kind: RaftAvatarKind.agent,
              ),
            ),
          ),
        ),
      ),
    );
    return ColoredBox(
      color: t.colors['layer-canvas']!,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          owner(Colors.transparent),
          owner(t.colors['fill-subtle']!),
          owner(Colors.transparent, deleted: true),
        ],
      ),
    );
  },
);
