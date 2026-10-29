import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Button variants', size: Size(980, 640))
Widget buttonVariantsPreview() => const _ButtonPreview();

@RaftPreviews('Button compact and input', size: Size(390, 844))
Widget buttonCompactPreview() => const _ButtonPreview();

class _ButtonPreview extends StatefulWidget {
  const _ButtonPreview();
  @override
  State<_ButtonPreview> createState() => _ButtonPreviewState();
}

class _ButtonPreviewState extends State<_ButtonPreview> {
  var count = 0;
  var busy = false;
  void activateAction() => setState(() => count++);
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final variant in RaftButtonVariant.values)
              RaftButton(
                label: variant.css,
                uiVariant: variant,
                glyph: RaftGlyph.plus,
                onPressed: activateAction,
              ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final size in RaftButtonSize.values)
              RaftButton(
                label: size.isIcon ? '' : size.css,
                uiSize: size,
                glyph: RaftGlyph.plus,
                tooltip: size.isIcon ? 'Add' : null,
                onPressed: activateAction,
              ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            const RaftButton(label: 'Disabled'),
            RaftButton(
              label: 'Save changes',
              busy: busy,
              onPressed: activateAction,
            ),
            RaftButton(
              label: busy ? 'Stop loading' : 'Show loading',
              uiVariant: RaftButtonVariant.outline,
              onPressed: () => setState(() => busy = !busy),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Semantics(liveRegion: true, child: Text('Activated $count')),
        const SizedBox(height: 24),
        RaftListRowAction(
          onPressed: activateAction,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Composed row action'),
          ),
        ),
      ],
    ),
  );
}
