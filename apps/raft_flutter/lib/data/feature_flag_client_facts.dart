import 'package:flutter/foundation.dart';

/// Build number reported to feature-flag `client` rules. Release pipelines pass
/// the same value as `--build-number` via `--dart-define=RAFT_BUILD_NUMBER=<n>`;
/// without it the fact is not reported and `minClientBuild` rules fail closed
/// (`featureFlagClientRules.ts:111-125`).
const int raftBuildNumber = int.fromEnvironment(
  'RAFT_BUILD_NUMBER',
  defaultValue: -1,
);

/// `platform` for `POST /feature-flags/evaluate` (`routes/featureFlags.ts:60-66`
/// accepts `web | mobile`): native Android and iOS builds are `mobile`, desktop
/// builds are `web` (the Web client contract, `serverFeatureFlags.ts:140-146`).
String featureFlagPlatform([TargetPlatform? platform]) =>
    switch (platform ?? defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => 'mobile',
      _ => 'web',
    };

/// Client facts (`FeatureFlagClientFacts`, `featureFlagClientRules.ts:131-143`):
/// `os` is `android | ios` (`ohos` is never produced by this build), `buildType`
/// is `release | debug` (profile builds are not a shipping type and stay
/// unreported) and `buildNumber` is a non-negative integer. Unknown values are
/// omitted: the server treats missing facts as "not reported".
Map<String, Object> featureFlagClientFacts({
  TargetPlatform? platform,
  int? buildNumber,
  bool? release,
  bool? debug,
}) {
  final os = switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => null,
  };
  final build = buildNumber ?? raftBuildNumber;
  final isRelease = release ?? kReleaseMode;
  final isDebug = debug ?? kDebugMode;
  final buildType = isRelease ? 'release' : (isDebug ? 'debug' : null);
  return {
    'os': ?os,
    if (build >= 0) 'buildNumber': build,
    'buildType': ?buildType,
  };
}

/// Request body for `POST /feature-flags/evaluate`: every call site shares this
/// so the platform and client facts cannot drift between surfaces.
Map<String, Object?> featureFlagEvaluateBody({
  required List<String> keys,
  String? serverId,
  TargetPlatform? platform,
  int? buildNumber,
  bool? release,
  bool? debug,
}) => {
  'keys': keys,
  'serverId': ?serverId,
  'platform': featureFlagPlatform(platform),
  ...featureFlagClientFacts(
    platform: platform,
    buildNumber: buildNumber,
    release: release,
    debug: debug,
  ),
};

/// Feature-flag keys Web v1.24.0 reads that v1.21.23 did not, for the packages
/// that port the features behind them (each evaluates its own with
/// [featureFlagEvaluateBody]). Source: `packages/shared/src/featureFlags.ts`
/// and `packages/web/src/store/serverFeatureFlags.ts` at v1.24.0-source.1;
/// the two server-only keys from `packages/server/src/services`.
abstract final class RaftFeatureFlags {
  /// featureFlags.ts:23. External channels; also the gate a channel
  /// conversion under way follows (see `channelConversionFlag`).
  static const externalChannels = 'external_channels_v1';

  /// featureFlags.ts:50.
  static const agentContextView = 'agent_context_view_v0';

  /// featureFlags.ts:56.
  static const computerVersionEnforcement = 'computer_version_enforcement';

  /// featureFlags.ts:67.
  static const appPromptTextConsent = 'app_prompt_text_consent';

  /// featureFlags.ts:77.
  static const workspaceArtifacts = 'workspace_artifacts_v0';

  /// featureFlags.ts:85.
  static const interactiveLinkCards = 'interactive_link_cards';

  /// featureFlags.ts:93.
  static const proSeatAdd = 'pro_seat_add';

  /// featureFlags.ts:102.
  static const proPrepaid = 'pro_prepaid';

  /// featureFlags.ts:116.
  static const mobileInboxInplace = 'mobile_inbox_inplace_v0';

  /// featureFlags.ts:162, serverFeatureFlags.ts:87.
  static const taskV2Conversations = 'task_v2_conversations_v0';

  /// featureFlags.ts:174.
  static const continuationsPilot = 'continuations_pilot_v0';

  /// featureFlags.ts:193.
  static const agentReadProgress = 'agent_read_progress_v0';

  /// featureFlags.ts:205.
  static const channelThreadSort = 'channel_thread_sort_v0';

  /// featureFlags.ts:217.
  static const agentInboxItems = 'agent_inbox_items_v0';

  /// featureFlags.ts:230.
  static const agentReactionNotices = 'agent_reaction_notices_v0';

  /// featureFlags.ts:240.
  static const agentUsage = 'agent_usage_v0';

  /// featureFlags.ts:256.
  static const channelAnnouncement = 'channel_announcement_v0';

  /// featureFlags.ts:279.
  static const humanAvatarBuilder = 'human_avatar_builder_v0';

  /// featureFlags.ts:291.
  static const claudeLimitReset = 'claude_limit_reset';

  /// serverFeatureFlags.ts:78.
  static const personalAssistant = 'personal_assistant';

  /// serverFeatureFlags.ts:96.
  static const deepLinks = 'deep_links_v1';

  /// serverFeatureFlags.ts:104.
  static const draftsSection = 'drafts_section_v0';

  /// serverFeatureFlags.ts:114.
  static const webPreview = 'web_preview_v0';

  /// serverFeatureFlags.ts:125.
  static const desktopWebPreviewView = 'desktop_web_preview_view_v0';

  /// featureFlags.ts:30, serverFeatureFlags.ts:133.
  static const agentLounge = 'agent_lounge_v0';

  /// serverFeatureFlags.ts:145.
  static const inboxReadInplace = 'inbox_read_inplace_v1';

  /// Server-only: services/featureFlagService.ts:295 (enterprise SSO).
  static const serverSso = 'server_sso_v1';

  /// Server-only operations switch: services/legacyMobileOAuthUpgrade.ts:23
  /// (the old mobile OAuth answers "upgrade required").
  static const legacyMobileOAuthUpgradeRequired =
      'legacy_mobile_oauth_upgrade_required_v0';
}
