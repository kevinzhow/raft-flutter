import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/message_row_recipe.dart';
import 'src/message_toolbar_glyphs.dart';
import 'src/mounted_reaction_recipe.dart';

@RaftPreviews('Mounted message affordances: toolbar and count transition')
Widget messageAffordancePreview() => const _Affordances();

class _Affordances extends StatefulWidget {
  const _Affordances();
  @override
  State<_Affordances> createState() => _AffordancesState();
}

class _AffordancesState extends State<_Affordances> {
  int count = 2;
  String result = 'Ready';
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(40),
    child: Column(
      children: [
        RaftMessageRow(
          author: 'Cindy',
          timestamp: '14:30',
          content: const Text(
            'Hover or Tab to the exact source toolbar glyphs.',
          ),
          toolbar: RaftMessageToolbar(
            children: [
              RaftMessageToolbarAction(
                label: 'Reply in thread',
                icon: const RaftMessageThreadGlyph(),
                onPressed: () => setState(() => result = 'Thread callback'),
              ),
              RaftMessageToolbarAction(
                label: 'Add reaction',
                icon: const RaftMessageAddReactionGlyph(),
                onPressed: () =>
                    setState(() => result = 'Reaction picker callback'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Controlled reaction glyph slot (source sprite registration pending)',
        ),
        RaftMountedReaction(
          label: 'Public reaction count',
          glyph: const SizedBox(),
          count: count,
          onPressed: () => setState(() => count++),
        ),
        Text(result),
      ],
    ),
  );
}
