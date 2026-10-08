// Official cases owned by this group (default selection):
//   components.members.create-agent.dialog
//   components.members.create-agent.dialog-error
//   components.members.create-agent.dialog-onboarding
//   components.members.create-agent.claude-dialog
//   components.members.create-agent.claude-custom-provider-dialog
//   components.members.agent-detail.profile
//   components.channel.settings.panel
//   components.channel.members.add-panel
//   components.settings.root.page
//   components.settings.account.page
//   components.settings.account.error-state
//   components.settings.server.profile
//   components.settings.appearance.page
//   components.settings.notifications.page
//   components.members.agent-lifecycle-actions
//   components.members.avatar-management
//   components.members.create-agent.dialog-no-computer
//   components.members.create-agent.dialog-empty
//   components.members.create-agent.builtin-provider-dialog
//   components.members.create-agent.pi-provider-dialog
//
// Builders render the real Flutter app/raft_ui widgets for each case, laid
// out like the React render host fixture for the same case id. Cases the
// Flutter app cannot show go to [membersSettingsUncovered] with an honest reason.
import '../parity_harness.dart';

final Map<String, ParityCase> membersSettingsCases = {};

final Map<String, ParityUncovered> membersSettingsUncovered = {};
