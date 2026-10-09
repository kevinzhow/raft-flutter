import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

@RaftPreviews(
  'Legacy Source input · focus and caller states',
  size: Size(360, 300),
)
Widget legacyInputPreview() => const LegacyInputPreview();

/// Live input with the Source legacy chrome and explicit invalid/padding states.
class LegacyInputPreview extends StatefulWidget {
  const LegacyInputPreview({super.key});
  @override
  State<LegacyInputPreview> createState() => _LegacyInputPreviewState();
}

class _LegacyInputPreviewState extends State<LegacyInputPreview> {
  final text = TextEditingController(text: 'Draft');
  bool invalid = false, compact = false;
  String submitted = 'Ready';
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftField(
          label: 'Name',
          required: true,
          child: RaftTextInput(
            controller: text,
            chrome: RaftInputChrome.legacy,
            semanticLabel: 'Name',
            invalid: invalid,
            padding: compact
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                : null,
            onSubmitted: (value) => setState(() => submitted = value),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            RaftButton(
              label: invalid ? 'Clear invalid' : 'Mark invalid',
              onPressed: () => setState(() => invalid = !invalid),
            ),
            RaftButton(
              label: compact ? 'Default inset' : 'Caller inset',
              onPressed: () => setState(() => compact = !compact),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(submitted),
      ],
    ),
  );
}
