import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/card.dart';
import 'src/card_parts.dart';
import 'src/icons.dart';

@RaftPreviews('Card parts', size: Size(420, 520))
Widget cardPartsPreview() => const _CardParts();

class _CardParts extends StatelessWidget {
  const _CardParts();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RaftCardSectionHeader(
                aboveContent: true,
                leading: RaftCardLeading(RaftIcon(RaftGlyph.bell, size: 16)),
                title: RaftCardTitle(Text('Notifications')),
                description: RaftCardDescription(Text('Choose what reaches you')),
                trailing: RaftCardTrailing(Text('Edit')),
              ),
              RaftCardContent(child: Text('Card content')),
              RaftCardFooter(children: [Text('Updated today')]),
            ],
          ),
        ),
        SizedBox(height: 16),
        RaftCard(
          variant: RaftCardRecipeVariant.option,
          child: RaftCardSectionHeader(
            title: RaftCardTitle(Text('Option card')),
            description: RaftCardDescription(Text('Field-scale title')),
          ),
        ),
      ],
    ),
  );
}
