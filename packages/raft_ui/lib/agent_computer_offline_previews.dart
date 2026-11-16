import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

// Web AgentComputerOfflineCard (v1.24.0): the profile's card while the agent's
// Computer is offline.

@RaftPreviews('Agent Computer offline card', size: Size(390, 340))
Widget agentComputerOfflinePreview() => RaftAgentComputerOfflineCard(
  title: const RaftAgentOfflineSentence('', ' has been offline since 09:30'),
  computerName: 'Studio Mac',
  onOpenComputer: () {},
  owner: 'Bea',
  powerStep: const RaftAgentOfflineSentence(
    "Turn on ",
    "'s computer Studio Mac and keep it from sleeping",
  ),
  runStep: 'On that computer, open Raft Desktop or run:',
  command: 'raft-computer restart /acme',
);
