import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/quick_reaction_picker.dart';

@RaftPreviews('Controlled seven-reaction picker: source glyph slot pending')
Widget quickReactionPickerPreview() => const _Picker();

class _Picker extends StatefulWidget {
  const _Picker();
  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  bool open = true;
  String state = 'Ready';
  final opener = FocusNode();
  @override
  void dispose() {
    opener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButton(
        focusNode: opener,
        onPressed: () => setState(() => open = true),
        child: const Text('Open reactions'),
      ),
      if (open)
        RaftQuickReactionPicker(
          glyphBuilder: (_) => const SizedBox(),
          labelBuilder: (value) => 'React with $value',
          returnFocusNode: opener,
          onSelect: (value) => setState(() {
            state = 'Selected $value';
            open = false;
          }),
          onDismiss: () => setState(() {
            state = 'Dismissed';
            open = false;
          }),
        ),
      Text(state),
      const Text(
        'Original public sprite is staged separately; empty glyph slots do not claim visual parity.',
      ),
    ],
  );
}
