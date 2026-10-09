import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/avatar_content.dart';
import 'src/mounted_avatar_recipe.dart';

@RaftPreviews('Mounted avatar: panel and compact identity/status')
Widget mountedAvatarPreview() => const _MountedAvatars();

@RaftPreviews('Withheld compact avatar slot', size: Size(80, 60))
Widget withheldAvatarSlotPreview() => const Center(child: RaftAvatarSpace());

class _MountedAvatars extends StatefulWidget {
  const _MountedAvatars();
  @override
  State<_MountedAvatars> createState() => _MountedAvatarsState();
}

class _MountedAvatarsState extends State<_MountedAvatars> {
  RaftAvatarActivity activity = RaftAvatarActivity.working;
  bool deactivated = false;
  bool muted = false;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final role in RaftMountedAvatarContext.values) ...[
          Text(role.name),
          const SizedBox(height: 8),
          Row(
            children: [
              RaftMountedAvatarFrame(
                name: 'Cindy',
                avatarContext: role,
                identity: RaftMountedAvatarIdentity.agent,
                presence:
                    role == RaftMountedAvatarContext.panelHeader ||
                        role == RaftMountedAvatarContext.compactList
                    ? RaftAvatarPresence(
                        activity: activity,
                        label: activity.name,
                      )
                    : null,
                deactivated: deactivated,
                muted: muted,
                child: const RaftAvatarContent(
                  name: 'Cindy',
                  kind: RaftAvatarContentKind.agent,
                  pixelKey: 'robot',
                ),
              ),
              const SizedBox(width: 16),
              RaftMountedAvatarFrame(
                name: 'artin',
                avatarContext: role,
                muted: muted,
              ),
              const SizedBox(width: 16),
              RaftMountedAvatarFrame(
                name: 'Gravatar fallback',
                avatarContext: role,
                muted: muted,
                child: RaftMountedAvatarFallback(
                  avatarContext: role,
                  gravatar: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          children: [
            for (final state in RaftAvatarActivity.values)
              TextButton(
                onPressed: () => setState(() => activity = state),
                child: Text(state.name),
              ),
            TextButton(
              onPressed: () => setState(() => deactivated = !deactivated),
              child: Text(deactivated ? 'Activate agent' : 'Deactivate agent'),
            ),
            TextButton(
              onPressed: () => setState(() => muted = !muted),
              child: Text(muted ? 'Joined channel' : 'Not in channel'),
            ),
          ],
        ),
        const Text(
          'Controlled artwork/status only; no network decode or authority proof.',
        ),
      ],
    ),
  );
}
