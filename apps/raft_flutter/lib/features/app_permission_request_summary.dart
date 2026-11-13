import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_notifications_catalog.dart';
import 'management_support.dart';

/// AppNotificationRequestSummary (AppNotificationsControls.tsx) in the
/// marketplace listing detail. While a permission update waits for review the
/// requested (pending) data groups and events replace the approved ones.
/// There is no reviewer action: server v1.24.0 removed
/// `POST /integrations/clients/:id/app-notifications/permissions/review` and
/// Web 1.24 only shows the request.
class AppPermissionRequestSummary extends StatelessWidget {
  const AppPermissionRequestSummary({
    super.key,
    required this.listing,
    required this.groupLabel,
  });
  final Map<String, dynamic> listing;
  final String Function(String group) groupLabel;

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    final pending = listing['appNotificationReviewPending'] == true;
    final groups = managementStrings(
      pending
          ? listing['appNotificationPendingGroups']
          : listing['appNotificationGroups'],
    );
    final events = managementStrings(
      pending
          ? listing['appNotificationPendingEvents']
          : listing['appNotificationEvents'],
    );
    return RaftAppPermissionsSummary(
      description: tr(
        pending
            ? 'Additional App permissions are pending review. Existing approved access remains available.'
            : 'App permissions requested for this installation. Reading data does not require login or webhook delivery.',
      ),
      badge: pending
          ? RaftConnectedAppBadge.warning(
              tr('Permission update pending review'),
            )
          : null,
      columns: [
        (
          tr(pending ? 'Requested data groups' : 'Data groups'),
          [for (final g in groups) groupLabel(g)],
          // appNotifications.noDataAccess: 无数据访问 (noDataAccessEmpty, the
          // approved-data row, keeps the catalog's 无数据访问权限).
          raftTextZh(context, 'No data access', '无数据访问'),
        ),
        (
          tr(pending ? 'Requested notification events' : 'Notification events'),
          [for (final e in events) tr(appNotificationEventLabels[e] ?? e)],
          tr('No events'),
        ),
      ],
    );
  }
}
