// Administration › Onboarding (Web v1.24.0
// features/settings/administration/OnboardingAgentSection.tsx): the onboarding
// agent's Select and the greeting's Switch each save when changed, roll back
// on failure and say so under the control; no Save button. "Server setup"
// appears when the server's setup projection asks for it.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'administration_immediate.dart';
import 'administration_support.dart';
import 'management_support.dart' show managementMap, pageIdentity;
import 'server_setup_gate.dart' show refreshServerSetup;

/// `isAgentInMemberLists` (store/agentStore.ts): not deleted, not an App Bot
/// removed from its App, and never a personal assistant.
bool isAgentInMemberLists(Map<String, dynamic> agent) =>
    agent['deletedAt'] == null &&
    agent['inMemberLists'] != false &&
    agent['assistantOwnerUserId'] == null;

class AdminOnboardingSection extends StatefulWidget {
  const AdminOnboardingSection({super.key, required this.w});
  final WorkspaceController w;
  @override
  State<AdminOnboardingSection> createState() => _OnboardingState();
}

class _OnboardingState extends State<AdminOnboardingSection>
    with AdminSectionLoad<AdminOnboardingSection> {
  @override
  WorkspaceController get w => widget.w;
  @override
  String get snapshotKey => 'admin:onboarding';
  late final agentSave = ImmediateSave(_changed);
  late final greetingSave = ImmediateSave(_changed);
  String agentId = '';
  bool greeting = true;
  bool loading = true, openingSetup = false;
  Map<String, dynamic>? projection;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the settings load again or Finish setup starts (Web setError('')); the section is remounted on server/account change.
  String? error;

  @override
  Map<String, Object?> captureSnapshot() => {
    'agentId': agentId,
    'greeting': greeting,
    'projection': projection,
  };

  String get base => '/servers/${w.server!.id}';

  void adopt(Object? settings) {
    final onboard = managementMap(
      managementMap(managementMap(settings)['settings'])['onboardSettings'],
    );
    agentId = onboard['onboardingAgentId'] is String
        ? onboard['onboardingAgentId'] as String
        : '';
    greeting = onboard['agentAllChannelGreetingEnabled'] != false;
  }

  @override
  void initState() {
    super.initState();
    w.services.entityDirectory.addListener(_changed);
    w.services.entityDirectory.ensure(const [WorkspaceEntityKind.agents]);
    final snapshot = readSnapshot();
    if (snapshot != null) {
      agentId = snapshot['agentId'] as String;
      greeting = snapshot['greeting'] as bool;
      projection = snapshot['projection'] as Map<String, dynamic>?;
      loading = false;
    }
    load(
      () => Future.wait<Object?>([
        w.query('$base/settings'),
        w.query('$base/setup-projection').catchError((_) => null),
      ]),
      (values) {
        final settings = managementMap(values[0])['settings'];
        if (managementMap(managementMap(settings)['onboardSettings']).isEmpty) {
          throw StateError('Server settings unavailable');
        }
        adopt(values[0]);
        projection = values[1] is Map
            ? Map<String, dynamic>.from(values[1] as Map)
            : null;
        error = null;
      },
      failed: (_) => error = 'Failed to load onboarding settings',
      done: () => loading = false,
    );
  }

  @override
  void dispose() {
    w.services.entityDirectory.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// `saveOnboardingSettings`: the changed field alone, then the server's
  /// settings again.
  Future<void> saveSettings(Map<String, Object?> patch) async {
    final identity = pageIdentity(w);
    await w.command('PATCH', '$base/onboarding-settings', data: patch);
    await w.query('$base/settings');
    if (mounted && identity == pageIdentity(w)) saveSnapshot();
  }

  void changeAgent(String value) {
    if (value == agentId) return;
    final previous = agentId;
    setState(() => agentId = value);
    unawaited(
      agentSave.run(
        () => saveSettings({
          'onboardingAgentId': value.isEmpty ? null : value,
        }).catchError((Object e) {
          if (mounted) setState(() => agentId = previous);
          throw e;
        }),
        (e) => adminApiError(e, 'Failed to save onboarding agent'),
      ),
    );
  }

  void changeGreeting(bool checked) {
    setState(() => greeting = checked);
    unawaited(
      greetingSave.run(
        () => saveSettings({'agentAllChannelGreetingEnabled': checked})
            .catchError((Object e) {
              if (mounted) setState(() => greeting = !checked);
              throw e;
            }),
        (e) => adminApiError(e, 'Failed to save the new agent greeting'),
      ),
    );
  }

  Future<void> finishSetup() async {
    if (openingSetup) return;
    setState(() {
      openingSetup = true;
      error = null;
    });
    try {
      final data = await w.command(
        'POST',
        '$base/setup-transition',
        data: {'action': 'start'},
      );
      if (!mounted) return;
      if (data is Map) projection = Map<String, dynamic>.from(data);
      // Tell the setup gate: the reopened setup shows its modal.
      refreshServerSetup(w);
    } catch (e) {
      if (mounted) {
        setState(() => error = adminApiError(e, 'Failed to reopen server setup'));
      }
    } finally {
      if (mounted) setState(() => openingSetup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The server's greeter is one of its member agents: never a personal
    // assistant (anyone's) or a removed App Bot.
    final agents = [
      for (final a in w.services.entityDirectory.authorAgents)
        if (isAgentInMemberLists(a) && a['id'] is String)
          (
            a['id'] as String,
            '@${a['name']}${a['displayName'] is String && (a['displayName'] as String).isNotEmpty ? ' (${a['displayName']})' : ''}',
          ),
    ];
    final p = projection;
    // The server's projection alone decides whether setup is offered.
    final showSetup =
        p != null && p['phase'] != 'complete' && p['surface'] != 'none';
    return RaftAdminSection(
      regionKey: adminRegion('onboarding'),
      label: 'Onboarding',
      glyph: RaftGlyph.bot,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftAdminOnboardingRows(
            agentId: agentId,
            agents: agents,
            onAgent: changeAgent,
            greeting: greeting,
            onGreeting: changeGreeting,
            agentDisabled: agentSave.saving || loading,
            greetingDisabled: greetingSave.saving || loading,
            agentFailure: agentSave.failure,
            greetingFailure: greetingSave.failure,
            showSetup: showSetup,
            openingSetup: openingSetup,
            onFinishSetup: finishSetup,
          ),
          if (error case final error?) ...[
            const SizedBox(height: RaftSpace.x3),
            RaftErrorBanner(error, small: true),
          ],
        ],
      ),
    );
  }
}
