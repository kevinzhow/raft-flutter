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
