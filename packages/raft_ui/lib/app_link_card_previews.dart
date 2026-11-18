import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'raft_ui.dart';

@Preview(name: 'App link block card, light')
Widget appLinkCardLightPreview() => _appLinkCardPreview(Brightness.light);

@Preview(name: 'App link block card, dark')
Widget appLinkCardDarkPreview() => _appLinkCardPreview(Brightness.dark);

Widget _appLinkCardPreview(Brightness brightness) => MaterialApp(
  theme: raftTheme(dark: brightness == Brightness.dark),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: RaftAppLinkCard(
        title: 'Printer ticket',
        appName: 'Tickets',
        domain: 'tickets.example.org',
        icon: const RaftIcon(RaftGlyph.link, size: 16),
        onOpen: () {},
        body: const Text('Printer on the second floor'),
        actions: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: RaftButton(label: 'Resolve', onPressed: () {}),
        ),
      ),
    ),
  ),
);
