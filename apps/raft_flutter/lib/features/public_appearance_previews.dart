import 'package:flutter/material.dart';
import 'package:raft_ui/previews.dart';
import 'package:raft_ui/raft_ui.dart';

import 'appearance_section.dart';

@RaftPreviews('Public Appearance', size: Size(390, 844))
Widget publicAppearanceReferencePreview() => const _PublicAppearancePreview();

class _PublicAppearancePreview extends StatefulWidget {
  const _PublicAppearancePreview();
  @override
  State<_PublicAppearancePreview> createState() =>
      _PublicAppearancePreviewState();
}

class _PublicAppearancePreviewState extends State<_PublicAppearancePreview> {
  RaftAppearance? value;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return SingleChildScrollView(
      padding: RaftAppearanceSectionRecipe.inset,
      child: RaftAppearanceSection(
        appearance:
            value ??
            RaftAppearance(mode: t.dark ? ThemeMode.dark : ThemeMode.light),
        onAppearance: (next) => setState(() => value = next),
        presentation: null,
        publicSurface: true,
      ),
    );
  }
}
