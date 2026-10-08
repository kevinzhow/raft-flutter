// Official cases owned by this group (default selection):
//   screens.auth.login.signing
//   screens.auth.profile-setup
//   screens.members.agent-detail.profile
//   screens.members.agent-detail.profile.computer-offline
//   screens.members.agent-detail.profile.computer-missing
//   screens.members.agent-detail.profile.no-computer
//   screens.members.agent-detail.profile.long-machine-name
//   screens.members.agent-detail.profile.daemon-only
//   screens.members.agent-detail.profile.no-membership
//   screens.members.agent-detail.profile.loading-state
//   screens.members.agent-detail.reminders
//   screens.members.agent-detail.workspace
//   screens.members.agent-detail.apps
//   screens.members.agent-detail.activity
//   screens.members.human.profile
//   screens.settings.server-danger-modal
//   screens.home.loading
//
// Builders render the real Flutter app/raft_ui widgets for each case, laid
// out like the React render host fixture for the same case id. Cases the
// Flutter app cannot show go to [screenUncovered] with an honest reason.
import '../parity_harness.dart';

final Map<String, ParityCase> screenCases = {};

final Map<String, ParityUncovered> screenUncovered = {};
