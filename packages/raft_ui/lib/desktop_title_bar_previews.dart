import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Desktop title strip', size: Size(640, 200))
Widget desktopTitleStripPreview() =>
    const RaftDesktopTitleBar(height: 28, child: _TitleBarContent());

@RaftPreviews('Desktop native caption rule', size: Size(640, 200))
Widget desktopTitleRulePreview() => Builder(
  builder: (context) => RaftDesktopTitleBar(
    height: RaftTitleBarRecipe(RaftTokens.of(context)).ruleWidth,
    child: const _TitleBarContent(),
  ),
);

@RaftPreviews('Desktop title bar fullscreen', size: Size(640, 200))
Widget desktopTitleFullscreenPreview() => const RaftDesktopTitleBar(
  height: 28,
  fullscreen: true,
  child: _TitleBarContent(),
);

class _TitleBarContent extends StatelessWidget {
  const _TitleBarContent();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: RaftTokens.of(context).canvas,
    child: const Center(child: Text('Workspace')),
  );
}
