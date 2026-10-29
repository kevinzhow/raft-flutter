import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

const _body =
    'Open channels, threads and tasks side by side. Press `Cmd K` to jump '
    'anywhere.\n\n'
    '- Drag tabs between editor groups\n'
    '- Threads open next to their channel\n\n'
    '[Read the release notes](https://raft.build)';

@RaftPreviews('Announcement modal', size: Size(900, 640))
Widget announcementModalPreview() => RaftAnnouncementModal(
  title: "What's new in Raft",
  body: _body,
  onDismiss: () {},
);

@RaftPreviews('Announcement modal with a call to action', size: Size(900, 640))
Widget announcementModalCtaPreview() => RaftAnnouncementModal(
  title: 'Joint channels are here',
  label: 'Release',
  body: 'Connect a channel with another server and talk in one place.',
  ctaLabel: 'Create a joint channel',
  onCta: () {},
  onDismiss: () {},
);
