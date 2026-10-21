import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_notifications_catalog.dart';
import 'management_support.dart';

/// `POST /integrations/clients/:id/app-notifications/permissions/review`.
/// The approval is bound to the revision the reviewer saw: the server answers
/// 409 when the publisher replaced the request meanwhile.
String appPermissionReviewPath(String id) =>
    '/integrations/clients/$id/app-notifications/permissions/review';

Map<String, Object?>? appPermissionReviewBody(Map<String, dynamic> listing) {
  final revision = listing['appNotificationPendingRevisionId'];
  return revision is String && revision.isNotEmpty
      ? {'expected_revision_id': revision}
      : null;
}

/// AppNotificationRequestSummary (AppNotificationsControls.tsx) in the
/// marketplace listing detail. While a permission update waits for review the
/// requested (pending) data groups and events replace the approved ones; a
/// marketplace reviewer also gets the "Approve update" action.
class AppPermissionRequestSummary extends StatelessWidget {
  const AppPermissionRequestSummary({
    super.key,
    required this.listing,
    required this.groupLabel,
    required this.reviewing,
    required this.onApprove,
  });
  final Map<String, dynamic> listing;
  final String Function(String group) groupLabel;
  final bool reviewing;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    final pending = listing['appNotificationReviewPending'] == true;
    final canReview = listing['canReviewAppNotifications'] == true;
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
    final summary = RaftAppPermissionsSummary(
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
          tr('No data access'),
        ),
        (
          tr(pending ? 'Requested notification events' : 'Notification events'),
          [for (final e in events) tr(appNotificationEventLabels[e] ?? e)],
          tr('No events'),
        ),
      ],
    );
    if (!pending || !canReview) return summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        summary,
        const SizedBox(height: RaftSpace.x3),
        RaftAppPermissionsApproval(
          key: const ValueKey('app-notifications-review-action'),
          notice: tr(
            'A marketplace reviewer can approve this permission update.',
          ),
          groups: const [],
          action: RaftSettingsRecipeButton(
            key: const ValueKey('app-notifications-review-approve'),
            label: reviewing ? tr('Approving...') : tr('Approve update'),
            variant: RaftButtonRecipeVariant.accent,
            size: RaftButtonRecipeSize.sm,
            // Without the displayed revision id the approval cannot be bound
            // to what the reviewer saw (the server would answer 400).
            onPressed: reviewing || appPermissionReviewBody(listing) == null
                ? null
                : onApprove,
          ),
        ),
      ],
    );
  }
}
