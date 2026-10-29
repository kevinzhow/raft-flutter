import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/banned_apis.dart';
import 'src/rules.dart';

/// Analyzer plugin entry point (loaded by the analysis server; see
/// analysis_options.yaml at the repository root).
final plugin = RaftLintsPlugin();

class RaftLintsPlugin extends Plugin {
  @override
  String get name => 'raft_lints';

  @override
  void register(PluginRegistry registry) {
    registry.registerLintRule(AvoidRenderIndexAssertion());
    registry.registerLintRule(AvoidRenderSingle());
    registry.registerLintRule(AvoidRenderWhereWithoutOrElse());
    registry.registerLintRule(AvoidCaughtExceptionText());
    registry.registerLintRule(AvoidImperativeNoticeState());
    registry.registerLintRule(AvoidUnreleasedResource());
    registry.registerLintRule(AvoidTextScaleFactor());
    registry.registerLintRule(AvoidFixedHeightText());
    registry.registerLintRule(AvoidPixelTextHeight());
    registry.registerLintRule(OffGridSpacing());
    for (final api in bannedApis) {
      registry.registerLintRule(BannedApiRule(api));
    }
  }
}
