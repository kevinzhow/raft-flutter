import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

const _draft = '## Plan\n\n**Ship** Friday\n- tests\n- 中文';

@RaftPreviews('Composer expand button', size: Size(640, 260))
Widget composerExpandButtonPreview() => Align(
  alignment: Alignment.bottomCenter,
  child: RaftComposer(
    initialDraft:
        'Review the composer crop before release.\nIt grows with the '
        'text.\nFrom the third line an expand button shows at the top right.\n',
    onImagePick: () {},
    onAttach: () {},
    onSend: (_) async => false,
  ),
);

@RaftPreviews('Expanded composer desktop', size: Size(1100, 820))
Widget expandedComposerDesktopPreview() => const _ExpandedPreview(phone: false);

@RaftPreviews('Expanded composer phone', size: Size(412, 860))
Widget expandedComposerPhonePreview() => const _ExpandedPreview(phone: true);

class _ExpandedPreview extends StatefulWidget {
  const _ExpandedPreview({required this.phone});
  final bool phone;
  @override
  State<_ExpandedPreview> createState() => _ExpandedPreviewState();
}

class _ExpandedPreviewState extends State<_ExpandedPreview> {
  final controller = RaftMarkdownEditingController(text: _draft)..styled = true;
  final focus = FocusNode();

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = RaftComposerExpandedView(
      form: widget.phone ? RaftSurfaceForm.sheet : RaftSurfaceForm.dialog,
      title: 'Message #general',
      controller: controller,
      onCollapse: () {},
      editor: TextField(
        controller: controller,
        focusNode: focus,
        expands: true,
        maxLines: null,
        decoration: const InputDecoration.collapsed(hintText: 'Message'),
      ),
      footer: (recipe) => RaftComposerActionRow(
        recipe: recipe,
        onImagePick: () {},
        onAttach: () {},
        onSend: () {},
        hint: widget.phone ? null : 'Enter adds a line · Ctrl+Enter sends',
      ),
    );
    return widget.phone
        ? RaftSheetSurface(height: 800, child: view)
        : RaftComposerExpandedDialog(child: view);
  }
}
