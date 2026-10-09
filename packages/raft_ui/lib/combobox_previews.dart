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
