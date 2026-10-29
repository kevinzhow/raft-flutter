// Web SameAdminJointNotice (components/channel/SameAdminJointNotice.tsx): the
// info Banner shown when the inviter invites themselves on a server they
// administer. The connection is made directly, so the checkbox must be ticked
// before the invite is submitted (RFC 075 section 4.5).
import 'raft/checkbox.dart' show RaftCheckbox;

import 'package:flutter/material.dart';

import 'banner.dart';
import 'design_primitives.dart';
import 'localization.dart';
import 'theme.dart';

class RaftSameAdminJointNotice extends StatelessWidget {
  const RaftSameAdminJointNotice({
    super.key,
    required this.sourceServerName,
    required this.targetServerName,
    required this.confirmed,
    required this.onConfirmedChange,
  });
  final String sourceServerName, targetServerName;
  final bool confirmed;

  /// Null while the form is submitting (Web `disabled`).
  final ValueChanged<bool>? onConfirmedChange;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final label = raftText(
      context,
      'Connect directly as admin of both servers',
    );
    final onChanged = onConfirmedChange;
    return RaftBanner(
      key: const ValueKey('joint-same-admin-notice'),
      status: RaftBannerRecipeStatus.info,
      description: raftFormat(
        context,
        "You're an admin of both {source} and {target}. The connection will be made directly as admin of both, and no email will be sent.",
        {'source': sourceServerName, 'target': targetServerName},
      ),
      // `<label className="flex items-start gap-2 text-callout font-semibold">`
      footer: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onChanged == null ? null : () => onChanged(!confirmed),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: RaftCheckbox(
                  key: const ValueKey('joint-same-admin-confirm'),
                  value: confirmed,
                  onChanged: onChanged,
                  semanticLabel: label,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: RaftTypography.body(
                    t,
                    size: 14,
                    line: 20,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
