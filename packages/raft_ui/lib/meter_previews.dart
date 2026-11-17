import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

@RaftPreviews('Meter', size: Size(420, 420))
Widget meterPreview() => const Padding(
  padding: EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RaftMeter(label: 'Seats', used: 1.5, max: 3, valueText: '1.5 of 3 used'),
      SizedBox(height: 20),
      RaftMeter(
        label: 'File uploads this month',
        used: 500,
        max: 500,
        valueText: 'Used up · resets Jul 1',
        warning: true,
      ),
      SizedBox(height: 20),
      RaftMeter(label: 'People', used: 0, max: 5, valueText: '0 of 5 used'),
      SizedBox(height: 20),
      RaftMeter(
        label: 'Small',
        used: 2,
        max: 5,
        valueText: '2 of 5 used',
        size: RaftMeterRecipeSize.sm,
      ),
      SizedBox(height: 20),
      RaftDescriptionList(
        inline: true,
        entries: [
          RaftDescriptionEntry('People', '1 · 1 seat'),
          RaftDescriptionEntry('Agents', '5 · 0.5 seats'),
        ],
      ),
    ],
  ),
);
