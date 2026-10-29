import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/rail_side_preference.dart';
import '../platform/native_notifications.dart';
import 'notification_activation_banner.dart';

/// Shares the native opt-in service with both responsive workspace branches.
/// The existing rail-side ownership stays outside individual chat composers.
class NotificationActivationWorkspace extends StatelessWidget {
  const NotificationActivationWorkspace({
    super.key,
    required this.service,
    required this.mobileRoutePage,
    required this.railSide,
    required this.builder,
  });
  final NativeNotificationService? service;
  final bool mobileRoutePage;
  final RailSideStore railSide;
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) => NotificationActivationHost(
    service: service,
    child: mobileRoutePage
        ? Builder(builder: builder)
        : ListenableBuilder(
            listenable: railSide,
            builder: (context, _) => RaftRailSideScope(
              side: railSide.side,
              child: Builder(builder: builder),
            ),
          ),
  );
}
