import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'management_support.dart';
import 'page_layout.dart';
import 'public_avatar_url.dart';

/// Current-authority HumanRoute/ProfilePanel fallback contract. Entity payloads
/// remain in this loader's memory and are cleared on role/principal/workspace
/// changes; the shell stores only the selected user id.
class MemberProfileView extends StatefulWidget {
  const MemberProfileView({
    super.key,
    required this.controller,
    required this.userId,
    required this.onClose,
    this.onMessage,
  });
  final WorkspaceController controller;
  final String userId;
  final VoidCallback onClose;
  final Future<void> Function()? onMessage;
  @override
  State<MemberProfileView> createState() => _MemberProfileViewState();
}

class _MemberProfileViewState extends ManagementState<MemberProfileView> {
  @override
  WorkspaceController get w => widget.controller;
  Map<String, dynamic> profile = {};
  @override
  String get authority =>
      '${super.authority}|${identityHashCode(w)}|${w.client.origin}|${widget.userId}|${w.can('viewMembers')}';
  @override
  void initState() {
    super.initState();
    startManagement();
  }

  @override
  void didUpdateWidget(MemberProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != w) {
      rebindManagementController();
    } else if (oldWidget.userId != widget.userId) {
      refreshAuthority();
    }
  }

  @override
  void clearData() => profile = {};
  @override
  Future<void> loadData(int request, int generation) async {
    if (w.server == null || !w.can('viewMembers')) {
      clearData();
      return;
    }
    final server = w.server!.id, id = widget.userId;
    final value = await w.query('/servers/$server/members/$id/profile');
    if (accepts(generation, request) && value is Map) {
      profile = Map<String, dynamic>.from(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final name = '${profile['displayName'] ?? profile['name'] ?? ''}';
    return Column(
      children: [
        RaftPageHeader(
          title: name,
          height: raftPageHeaderHeight(context),
          actions: [
            RaftIconButton(
              glyph: RaftGlyph.x,
              tooltip: 'Close profile',
              onPressed: widget.onClose,
            ),
          ],
        ),
        Expanded(
          child: loading
              ? Center(
                  child: Text(
                    raftText(context, 'Loading...'),
                    style: RaftTypography.mono(t, size: 14, line: 20),
                  ),
                )
              : error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(raftText(context, 'Profile could not be loaded.')),
                      RaftButton(label: 'Retry', onPressed: reload),
                    ],
                  ),
                )
              : profile.isEmpty
              ? RaftEmptyState(
                  title: raftText(context, 'Profile unavailable'),
                  detail: '',
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: RaftAvatar(
                        name: name,
                        size: 64,
                        imageUrl: raftPublicAvatarUrl(
                          w.client.origin,
                          profile['avatarUrl'] as String?,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: RaftTypography.heading(t, size: 20, line: 28),
                    ),
                    if (profile['description'] is String &&
                        (profile['description'] as String).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SelectableText(
                          profile['description'] as String,
                          style: RaftTypography.body(t),
                        ),
                      ),
                    if (profile['email'] is String)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SelectableText(profile['email'] as String),
                      ),
                    if (widget.userId != w.client.user?.id &&
                        widget.onMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: RaftButton(
                            label: 'Message',
                            busy: busy,
                            onPressed: () =>
                                run(widget.onMessage!, refresh: false),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
