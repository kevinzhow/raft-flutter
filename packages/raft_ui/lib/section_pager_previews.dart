import 'package:flutter/material.dart';

import 'previews.dart' show RaftPreviews;
import 'raft_ui.dart';

@RaftPreviews('Mobile section paging', size: Size(390, 600))
Widget sectionPagerPreview() => const SectionPagerPreview();

class SectionPagerPreview extends StatefulWidget {
  const SectionPagerPreview({super.key});
  @override
  State<SectionPagerPreview> createState() => _SectionPagerPreviewState();
}

class _SectionPagerPreviewState extends State<SectionPagerPreview> {
  String value = 'Chat';
  final sections = const ['Chat', 'Tasks', 'Files'];
  @override
  Widget build(BuildContext context) => Column(
    children: [
      RaftPanelTabBar<String>(
        value: value,
        tabs: const [
          RaftPanelTab('Chat', 'Chat', RaftGlyph.messageSquareText),
          RaftPanelTab('Tasks', 'Tasks', RaftGlyph.checkSquare),
          RaftPanelTab('Files', 'Files', RaftGlyph.paperclip),
        ],
        onChanged: (next) => setState(() => value = next),
      ),
      Expanded(
        child: RaftSectionPager<String>(
          sections: sections,
          value: value,
          onChanged: (next) => setState(() => value = next),
          builder: (context, section) => ListView(
            key: PageStorageKey(section),
            primary: false,
            padding: const EdgeInsets.all(16),
            children: [
              Text(section),
              if (section == 'Chat')
                const RaftTextInput(
                  fieldKey: Key('section-preview-draft'),
                  hintText: 'Draft',
                ),
              for (var i = 1; i <= 30; i++)
                ListTile(
                  title: Text('$section item $i'),
                  subtitle: section == 'Chat'
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: RaftMountedMessageTaskChip(
                            number: i,
                            status: RaftMessageTaskStatus.values[i % 5],
                            title: 'Preview task $i',
                            claimant: 'Alice',
                            openLabel: 'Open preview task $i',
                            onOpen: () {},
                          ),
                        )
                      : null,
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
