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
        icon: const RaftAppLinkLogo(name: 'Tickets'),
        onOpen: () {},
        body: const Text('Printer on the second floor'),
        actions: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: RaftButton(
            label: 'Resolve',
            uiVariant: RaftButtonVariant.standard,
            onPressed: () {},
          ),
        ),
      ),
    ),
  ),
);

@Preview(name: 'App link authorization, dark retry')
Widget appLinkAuthorizationPreview() => MaterialApp(
  theme: raftTheme(dark: true),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: RaftMessageEmbedFrame(
        size: RaftMessageEmbedSize.item,
        child: RaftAppLinkAuthorizationCard(
          titleTemplate: '{app} wants to show link previews here',
          appName: 'Tickets',
          detail:
              'Couldn’t allow Tickets. Check your connection and try again.',
          logo: const RaftAppLinkLogo(name: 'Tickets', large: true),
          allowLabel: 'Retry',
          declineLabel: 'Don’t allow',
          allowingLabel: 'Allowing…',
          decliningLabel: 'Saving…',
          failed: true,
          onAllow: () {},
          onDecline: () {},
        ),
      ),
    ),
  ),
);

@Preview(name: 'App link authorization, loading')
Widget appLinkSkeletonPreview() => MaterialApp(
  theme: raftTheme(),
  home: const Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: RaftMessageEmbedFrame(
        size: RaftMessageEmbedSize.item,
        child: RaftAppLinkSkeleton(label: 'Loading link preview'),
      ),
    ),
  ),
);
