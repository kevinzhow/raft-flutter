// Official cases owned by this group (default selection):
//   components.auth.register.inputs
//   components.navigation.tabbar.states
//   components.home.titlebar.states
//   components.home.notification-center.states
//   components.home.search.results
//   components.home.search.channel-dropdown
//   components.home.saved.results
//   components.home.activity.results
//   components.tasks.panel.states
//   components.tasks.status-menu
//   components.home.create-channel.dialog
//
// Builders render the real Flutter app/raft_ui widgets for each case, laid
// out like the React render host fixture for the same case id. Cases the
// Flutter app cannot show go to [homeTaskUncovered] with an honest reason.
import '../parity_harness.dart';

final Map<String, ParityCase> homeTaskCases = {};

final Map<String, ParityUncovered> homeTaskUncovered = {};
