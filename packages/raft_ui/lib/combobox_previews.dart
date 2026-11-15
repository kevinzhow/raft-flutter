import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

@RaftPreviews('Combobox panel', size: Size(300, 320))
Widget comboboxPreview() => Padding(
  padding: const EdgeInsets.all(20),
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 220,
      child: RaftComboboxPanel(
        label: 'Channels',
        glyph: RaftGlyph.hash,
        options: const {'general': '#general', 'design': '#design'},
        onSelected: (_) {},
        onDismiss: () {},
      ),
    ),
  ),
);

@RaftPreviews('Combobox panel, unavailable rows', size: Size(300, 360))
Widget comboboxUnavailablePreview() => Padding(
  padding: const EdgeInsets.all(20),
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 260,
      child: RaftComboboxPanel.items(
        label: 'Models',
        currentId: 'gpt-5',
        items: const [
          RaftComboboxItem('gpt-5', 'GPT-5', hint: 'gpt-5'),
          RaftComboboxItem(
            'gpt-4',
            'GPT-4',
            group: 'Not available on this computer',
            description: 'This model is not installed on this computer, so it cannot be picked here.',
            enabled: false,
            wrapDescription: true,
          ),
        ],
        onSelected: (_) {},
        onDismiss: () {},
      ),
    ),
  ),
);
