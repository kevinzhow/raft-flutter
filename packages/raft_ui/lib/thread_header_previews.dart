import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'raft_ui.dart';

@Preview(name: 'Thread header, light')
Widget threadHeaderLightPreview() => _threadHeaderPreview(dark: false);

@Preview(name: 'Thread header, dark')
Widget threadHeaderDarkPreview() => _threadHeaderPreview(dark: true);

Widget _threadHeaderPreview({required bool dark}) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 400,
        child: RaftThreadHeader(
          presentation: RaftThreadPresentation.side,
          viewportWidth: 1280,
          threadLabel: 'Thread',
          parentLabel: '#design',
          replyCount: 200,
          jumpLabel: 'Scroll to first message',
          closeLabel: 'Close thread',
          backLabel: 'Back',
          onJumpToStart: () {},
          onViewParent: () {},
          onClose: () {},
          actions: [
            RaftThreadOverflowAction(label: 'Thread actions', onPressed: () {}),
          ],
        ),
      ),
    ),
  ),
);
