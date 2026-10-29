import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Long dropdowns at the window edge', size: Size(390, 720))
Widget dropdownViewportPreview() => const DropdownViewportPreview();

/// Shared consumers with forty choices, positioned near the viewport edge.
class DropdownViewportPreview extends StatefulWidget {
  const DropdownViewportPreview({super.key});

  @override
  State<DropdownViewportPreview> createState() =>
      _DropdownViewportPreviewState();
}

class _DropdownViewportPreviewState extends State<DropdownViewportPreview> {
  String selected = '0';

  void choose(String? value) => setState(() => selected = value!);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Text('Selected: Choice $selected'),
        const Spacer(),
        RaftAgentSelect<String>(
          semanticLabel: 'Model',
          value: selected,
          options: [
            for (var i = 0; i < 40; i++)
              RaftAgentSelectOption('$i', 'Choice $i'),
          ],
          onChanged: choose,
        ),
        const SizedBox(height: 12),
        RaftSelectField<String>(
          value: selected,
          items: [
            for (var i = 0; i < 40; i++)
              RaftSelectItem(value: '$i', label: 'Choice $i'),
          ],
          onChanged: choose,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: RaftAdminPrincipalPicker(
                selectedKey: selected,
                candidates: [
                  for (var i = 0; i < 40; i++)
                    RaftAdminPrincipal(
                      key: '$i',
                      label: 'Choice $i',
                      agent: true,
                    ),
                ],
                onSelect: choose,
              ),
            ),
            RaftOverflowMenuButton(
              tooltip: 'Choose Action',
              entries: [
                for (var i = 0; i < 40; i++)
                  RaftMenuEntry(
                    label: 'Choice $i',
                    onPressed: () => choose('$i'),
                  ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}
