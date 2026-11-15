// What an external agent is told to connect with (Web v1.24
// features/agent/externalAgentSetup.ts): the prompt for an existing agent's
// CLI login, and the SDK's install command and first lines. One agent
// credential serves both ways. Shared by the create dialog and the profile's
// connection card, which differ only in where they show it.

/// How the external agent connects: Web `ExternalSetupMethod`.
enum ExternalSetupMethod {
  existingAgent('existing_agent'),
  sdk('sdk');

  const ExternalSetupMethod(this.wire);

  /// The server's value (`PUT /agents/:id/external-setup-method`).
  final String wire;

  /// The method a status read names; anything else is the default, an
  /// existing agent.
  static ExternalSetupMethod of(Object? wire) =>
      wire == 'sdk' ? sdk : existingAgent;

  ExternalSetupMethod get other => this == sdk ? existingAgent : sdk;
}

/// The SDK's published docs (its README on npm).
const raftSdkDocsUrl = 'https://www.npmjs.com/package/@botiverse/raft-sdk';

/// How often an open setup asks whether the agent has signed in yet.
const externalStatusPollInterval = Duration(milliseconds: 3000);

/// The credential this page makes: the agent page replaces only its own
/// (`Create new credential`).
const pageCredentialName = 'Created on this page';

const sdkInstallCommand = 'npm install @botiverse/raft-sdk';

/// Web `externalProfileSlug`.
String externalProfileSlug(String name, String id) {
  final slug = name
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? id.substring(0, id.length < 8 ? id.length : 8) : slug;
}

/// Web `existingAgentPrompt`: install the CLI, sign in as this agent, ask for
/// the credential. [tr] localizes a catalog source with its values.
String existingAgentPrompt({
  required String name,
  required String id,
  required String serverUrl,
  required String Function(String source, [Map<String, Object?> values]) tr,
}) => [
  tr('Connect to Raft as {name}.', {'name': name}),
  '',
  tr('1. Install or update the Raft CLI:'),
  'npm i -g @botiverse/raft@latest',
  '',
  tr('2. Sign in as this agent:'),
  'raft agent login --server $serverUrl --agent $id --profile-slug ${externalProfileSlug(name, id)}',
  '',
  tr(
    'When it asks for the agent credential, ask me for it. Never put the credential in a command, a file or a message to anyone else.',
  ),
].join('\n');

/// Web `sdkStarterCode`.
String sdkStarterCode(String serverUrl) => [
  'import { createRaftClient } from "@botiverse/raft-sdk";',
  '',
  'const raft = createRaftClient({',
  '  serverUrl: "$serverUrl",',
  '  credential: process.env.RAFT_AGENT_CREDENTIAL!,',
  '});',
  'await raft.agent.context(); // now connected',
].join('\n');

/// What the agent page says about an external agent (Web
/// `ExternalConnectionState`): four states. Not signed in yet covers every
/// server state without a sign-in (no credential, one never used, an expired
/// CLI login token); once connected, presence says online or offline;
/// disconnected means it was connected and has no working credential left.
enum ExternalConnectionState { notSignedIn, online, offline, disconnected }

/// Web `externalConnectionState(setupState, isOnline)`.
ExternalConnectionState externalConnectionStateOf(
  String? setupState,
  bool isOnline,
) {
  if (setupState == 'connected') {
    return isOnline
        ? ExternalConnectionState.online
        : ExternalConnectionState.offline;
  }
  if (setupState == 'disconnected') return ExternalConnectionState.disconnected;
  return ExternalConnectionState.notSignedIn;
}

/// Whether the agent has signed in (Web: online or offline both).
bool externalConnected(ExternalConnectionState state) =>
    state == ExternalConnectionState.online ||
    state == ExternalConnectionState.offline;

/// The credential [name] reads as in the list: Web
/// `agent.externalCard.pageCredential` for the one this page made, else its
/// own name, else "Agent credential". Null: the caller's catalog text for the
/// page credential or the unnamed one (see [CredentialTitleKind]).
enum CredentialTitleKind { page, named, unnamed }

CredentialTitleKind credentialTitleKind(Object? name) {
  if (name == pageCredentialName) return CredentialTitleKind.page;
  return name is String && name.isNotEmpty
      ? CredentialTitleKind.named
      : CredentialTitleKind.unnamed;
}
