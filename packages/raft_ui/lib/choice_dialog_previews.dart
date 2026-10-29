import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

@RaftPreviews('Native chooser · typed selection', size: Size(390, 600))
Widget choiceDialogPreview() => const _ChoicePreview();

@RaftPreviews('Native chooser · large text', size: Size(390, 700))
Widget largeChoiceDialogPreview() => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(3.1)),
    child: const _ChoicePreview(),
  ),
);

enum _Destination { current, unavailable, other }

class _ChoicePreview extends StatefulWidget {
  const _ChoicePreview();

  @override
  State<_ChoicePreview> createState() => _ChoicePreviewState();
}

class _ChoicePreviewState extends State<_ChoicePreview> {
  _Destination selected = _Destination.current;
  String outcome = 'No action taken';

  Future<void> open() async {
    final result = await showRaftDialog<_Destination>(
      context: context,
      builder: (context) => RaftChoiceDialog<_Destination>(
        title: 'Switch Server',
        options: [
          RaftChoiceDialogOption(
            value: _Destination.current,
            label: 'Current workspace',
            selected: selected == _Destination.current,
          ),
          const RaftChoiceDialogOption(
            value: _Destination.unavailable,
            label: 'Unavailable workspace',
            enabled: false,
          ),
          RaftChoiceDialogOption(
            value: _Destination.other,
            label: 'Another workspace with a longer display name',
            selected: selected == _Destination.other,
          ),
        ],
        onSelected: (value) => Navigator.pop(context, value),
        onClose: () => Navigator.pop(context),
      ),
    );
    if (!mounted) return;
    setState(() {
      if (result != null) selected = result;
      outcome = result == null ? 'Canceled' : 'Selected ${result.name}';
    });
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RaftButton(label: 'Choose workspace', onPressed: open),
        Text(outcome),
      ],
    ),
  );
}
