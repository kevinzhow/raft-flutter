import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

// Web v1.24 CreateExternalAgentDialog step 1, ExternalAgentConnectionCard and
// its credential list: the states the create dialog and the agent page show.

const _sdkCode = '''import { createRaftClient } from "@botiverse/raft-sdk";

const raft = createRaftClient({
  serverUrl: "https://raft.example",
  credential: process.env.RAFT_AGENT_CREDENTIAL!,
});
await raft.agent.context(); // now connected''';

const _prompt = '''Connect to Raft as Nathan.

1. Install or update the Raft CLI:
npm i -g @botiverse/raft@latest

2. Sign in as this agent:
raft agent login --server https://raft.example --agent 6f2c --profile-slug Nathan

When it asks for the agent credential, ask me for it.''';

@RaftPreviews('Create external agent form', size: Size(390, 560))
Widget externalAgentCreateFormPreview() => const _CreateForm();

class _CreateForm extends StatefulWidget {
  const _CreateForm();
  @override
  State<_CreateForm> createState() => _CreateFormState();
}

class _CreateFormState extends State<_CreateForm> {
  final name = TextEditingController(text: 'Nathan');
  final description = TextEditingController();
  RaftExternalMethod method = RaftExternalMethod.existingAgent;

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: RaftExternalCreateForm(
      name: name,
      description: description,
      method: method,
      onMethod: (value) => setState(() => method = value),
    ),
  );
}

@RaftPreviews('External agent: waiting, existing agent', size: Size(390, 760))
Widget externalAgentWaitingPreview() => SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: RaftExternalConnectionSection(
    status: const RaftExternalStatusCard(
      light: RaftExternalLight.attention,
      title: 'Waiting for Nathan to connect…',
      hint: 'This updates by itself when Nathan signs in.',
    ),
    switchLabel: 'Build it with the SDK instead',
    onSwitch: () {},
    steps: RaftExternalSetupSteps(
      method: RaftExternalMethod.existingAgent,
      name: 'Nathan',
      promptText: _prompt,
      installCommand: 'npm install @botiverse/raft-sdk',
      starterCode: _sdkCode,
      onOpenSdkGuide: () {},
      credentialStep: const RaftExternalCredentialStep(
        name: 'Nathan',
        secret: 'sk_agent_example-not-a-key',
      ),
    ),
  ),
);

@RaftPreviews(
  'External agent: online, SDK steps and credentials',
  size: Size(390, 900),
)
Widget externalAgentOnlinePreview() => SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: RaftExternalConnectionSection(
    method: RaftExternalMethod.sdk,
    status: RaftExternalStatusCard(
      light: RaftExternalLight.online,
      title: 'Online',
      hint: 'Active 3 minutes ago',
      toggleLabel: 'How it connects',
      expanded: true,
      onToggle: () {},
    ),
    steps: RaftExternalSetupSteps(
      method: RaftExternalMethod.sdk,
      name: 'Nathan',
      promptText: _prompt,
      installCommand: 'npm install @botiverse/raft-sdk',
      starterCode: _sdkCode,
      onOpenSdkGuide: () {},
    ),
    below: [
      RaftExternalCredentialList(
        loading: false,
        listError: false,
        disabled: false,
        onReplace: (_) {},
        onRevoke: (_) {},
        credentials: const [
          RaftExternalCredentialRow(
            id: 'c1',
            title: 'MacBook-Pro',
            subtitle: 'Created Nov 15, 2026 · last used 3 minutes ago',
            canReplace: false,
          ),
          RaftExternalCredentialRow(
            id: 'c2',
            title: 'Created on this page',
            subtitle: 'Created Nov 15, 2026 · not used yet',
            canReplace: true,
          ),
        ],
      ),
    ],
  ),
);

@RaftPreviews(
  'External agent: offline, create credential',
  size: Size(390, 520),
)
Widget externalAgentOfflinePreview() => SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 16,
    children: [
      const RaftExternalStatusCard(
        light: RaftExternalLight.offline,
        title: 'Offline · last seen 3 hours ago',
        hint: "Still connected. Messages wait until it's back.",
        titleTooltip: 'Nov 15, 2026, 9:41 AM',
        toggleLabel: 'How it connects',
      ),
      const RaftExternalStatusCard(
        light: RaftExternalLight.attention,
        title: 'Nathan is disconnected',
        hint: 'Its credentials were revoked. Create a new one and give it to Nathan to reconnect.',
      ),
      RaftExternalCredentialStep(
        name: 'Nathan',
        showShownBefore: true,
        createError: true,
        onCreate: () {},
      ),
      const RaftExternalCredentialList(
        loading: true,
        listError: false,
        disabled: false,
        onReplace: _noop,
        onRevoke: _noop,
        credentials: [],
      ),
    ],
  ),
);

void _noop(String _) {}
