import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'external_mentions.dart' show restoreExternalMentionProfile;
import 'public_avatar_url.dart';

/// Web `formatExternalProviderLabel`: Slack is named, any other provider
/// shows as sent; blank is none.
String? externalProviderLabel(BuildContext context, String? provider) {
  final value = provider?.trim();
  if (value == null || value.isEmpty) return null;
  return value.toLowerCase() == 'slack' ? raftText(context, 'Slack') : value;
}

/// Web `EXTERNAL_ACTOR_KIND_MESSAGE_IDS` (unknown kinds read as
/// "External participant").
String externalActorKindLabel(BuildContext context, String? kind) =>
    raftText(context, switch (kind) {
      'human' => 'Human',
      'guest' => 'Guest',
      'remote' => 'Remote participant',
      'bot' => 'App',
      _ => 'External participant',
    });

/// Web `message.externalIdentity.providerAndKind`, or just the kind.
String externalIdentitySubtitle(
  BuildContext context,
  String? provider,
  String? actorKind,
) {
  final kind = externalActorKindLabel(context, actorKind);
  final label = externalProviderLabel(context, provider);
  return label == null ? kind : '$label · $kind';
}

/// Web ExternalIdentityDetailPanel: the detail of a provider-owned message
/// author inside the profile side panel.
class ExternalIdentityDetailPanel extends StatelessWidget {
  const ExternalIdentityDetailPanel({
    super.key,
    required this.controller,
    required this.profile,
    required this.onClose,
    this.onBack,
    this.showCompactClose = false,
  });
  final WorkspaceController controller;
  final Map<String, dynamic> profile;
  final VoidCallback onClose;

  /// Page-stack back (phone); without it the desktop panel shows a close.
  final VoidCallback? onBack;
  final bool showCompactClose;

  @override
  Widget build(BuildContext context) {
    final postedName = profile['displayName'] as String? ?? '';
    final provider = profile['provider'] as String?;
    final actorKind = profile['actorKind'] as String?;
    final bot = actorKind == 'bot';
    final verifiedName = profile['profileDisplayName'] as String?;
    final name = bot && verifiedName != null && verifiedName.isNotEmpty
        ? verifiedName
        : postedName;
    final appName = bot ? profile['appName'] as String? : null;
    final knownApp = appName != null && appName.isNotEmpty;
    final providerLabel = externalProviderLabel(context, provider);
    final subtitle = knownApp
        ? externalActorKindLabel(context, actorKind)
        : externalIdentitySubtitle(context, provider, actorKind);
    final avatarUrl = raftPublicAvatarUrl(
      controller.client.origin,
      profile[bot && profile.containsKey('profileAvatarUrl')
              ? 'profileAvatarUrl'
              : 'avatarUrl']
          as String?,
    );
    Widget avatar(RaftAvatarSize size) => RaftStickerAvatar(
      size: size,
      type: RaftAvatarType.human,
      child: RaftAvatarContent(
        name: name,
        kind: RaftAvatarContentKind.app,
        uploadedUrl: avatarUrl,
        fallback: RaftAvatarInitials(
          name.trim().isEmpty ? 'A' : RaftExternalInitials.initials(name),
          size: size,
        ),
      ),
    );
    final t = RaftTokens.of(context);
    final wide = !RaftAdaptiveWorkspace.compactOf(context);
    return RaftPanelTextScope(
      sans: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftPanelHeaderBar(
            key: const Key('external-identity-header'),
            title: name,
            subtitle: subtitle,
            iconSlot: avatar(t.desktop ? RaftAvatarSize.sm : RaftAvatarSize.md),
            iconAlwaysVisible: true,
            profileBody: true,
            onBack: onBack,
            backKey: const Key('external-mobile-back'),
            backTooltip: raftText(context, 'Back'),
            actions: [
              if (wide || showCompactClose)
                RaftPanelIconButton(
                  glyph: RaftGlyph.x,
                  tooltip: raftText(context, 'Close'),
                  onPressed: onClose,
                ),
            ],
          ),
          Expanded(
            child: RaftExternalIdentityBody(
              name: name,
              subtitle: subtitle,
              projectionLabel: raftText(context, 'External identity'),
              postedAs: bot && name != postedName
                  ? raftFormat(context, 'Posted as {name}', {
                      'name': postedName,
                    })
                  : null,
              sourceLabel: knownApp && providerLabel != null
                  ? raftFormat(context, 'From {workspace}', {
                      'workspace': '$providerLabel · $appName',
                    })
                  : null,
              fromLabel: raftTextZh(context, 'From', '来自'),
              workspaceName: profile['workspaceName'] as String?,
              avatar: avatar(RaftAvatarSize.xl),
            ),
          ),
        ],
      ),
    );
  }
}

/// The attribution of an external author whose panel was restored from a
/// URL: the frozen payload when this session opened it, else the message's
/// own `externalAuthor` read back from its context window.
class ExternalProfileSource extends StatefulWidget {
  const ExternalProfileSource({
    super.key,
    required this.controller,
    required this.messageId,
    required this.channelId,
    required this.builder,
    required this.fallback,
    this.isMention = false,
  });
  final WorkspaceController controller;
  final String messageId, channelId;

  /// [messageId] is a projection id (`external-mention:`), read from the
  /// channel roster instead of a message.
  final bool isMention;
  final Widget Function(Map<String, dynamic> profile) builder;

  /// Shown while the message is read (or when it carries no attribution).
  final Widget Function(bool failed) fallback;

  @override
  State<ExternalProfileSource> createState() => _ExternalProfileSourceState();
}

class _ExternalProfileSourceState extends State<ExternalProfileSource> {
  Map<String, dynamic>? profile;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    profile = widget.controller.externalProfile(widget.messageId);
    if (profile == null) unawaited(load());
  }

  Future<void> load() async {
    final w = widget.controller;
    try {
      if (widget.isMention) {
        final author = await restoreExternalMentionProfile(
          w,
          widget.channelId,
          widget.messageId,
        );
        if (!mounted) return;
        if (author == null) return closeStale();
        setState(() => profile = author);
        return;
      }
      final data = await w.client.get(
        '/messages/context/${widget.messageId}',
        query: {'channelId': widget.channelId},
      );
      final rows = (data is Map ? data['messages'] as List? : null) ?? const [];
      final row = rows
          .whereType<Map>()
          .where((m) => m['id'] == widget.messageId)
          .firstOrNull;
      final author = row?['externalAuthor'];
      if (!mounted) return;
      setState(() {
        if (author is Map) {
          profile = Map<String, dynamic>.from(author);
        } else {
          failed = true;
        }
      });
    } catch (_) {
      if (!mounted) return;
      if (widget.isMention) return closeStale();
      setState(() => failed = true);
    }
  }

  /// Web `restoreExternalMentionProfileFromUrl`: a mention whose roster entry
  /// cannot be read (or is gone) closes the panel, but only while the address
  /// still names this profile.
  void closeStale() {
    final here = widget.controller.location.profile;
    if (here != null &&
        here.isMention &&
        here.id == widget.messageId &&
        here.channelId == widget.channelId) {
      widget.controller.closeProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return p == null ? widget.fallback(failed) : widget.builder(p);
  }
}
