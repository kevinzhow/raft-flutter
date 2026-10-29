import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('App icon choices', size: Size(412, 460))
Widget appIconChoicesPreview() => const _IconPreview();

@RaftPreviews('App icon failure', size: Size(412, 520))
Widget appIconFailurePreview() => const _IconPreview(error: true);

class _IconPreview extends StatefulWidget {
  const _IconPreview({this.error = false});
  final bool error;
  @override
  State<_IconPreview> createState() => _IconPreviewState();
}

class _IconPreviewState extends State<_IconPreview> {
  var selected = RaftAppIconPalette.yellow;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(RaftSpace.x4),
    child: RaftAppIconChoices(
      selected: selected,
      onChanged: (value) => setState(() => selected = value),
      error: widget.error ? 'The icon could not be changed. Try again.' : null,
    ),
  );
}
