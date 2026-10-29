// The /members/graph page (Web MainLayout `MemberGraphRoute` +
// settings/MemberGraphSection.tsx): GET /servers/:id/member-graph, the
// Graph header (Experimental) and RaftMemberGraphView with a profile hover card
// on every node. Guests are sent home like the Web route does.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';

import 'package:raft_ui/recipes.dart';

import '../data/raft_location.dart';
import '../data/raft_navigation_history.dart';
import '../data/workspace_controller.dart';
import 'management_support.dart'
    show pageIdentity, readPageSnapshot, writePageSnapshot;
import 'profile_preview.dart';
import 'sender_avatar_projection.dart';

/// `layout.memberGraph.*` page: header, scrolling body and the section.
class MemberGraphPage extends StatefulWidget {
  const MemberGraphPage({
    super.key,
    required this.controller,
    this.onBack,
    this.sectionLabel = 'Connections',
  });
  final WorkspaceController controller;

  /// The mobile back chevron (`useMobileBack`): back to the members list.
  final VoidCallback? onBack;
  final String sectionLabel;
  @override
  State<MemberGraphPage> createState() => _MemberGraphPageState();
}

class _MemberGraphPageState extends State<MemberGraphPage> {
  WorkspaceController get w => widget.controller;
  RaftMemberGraphData? data;
  bool loading = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Clears when a load starts (Retry) and on server change; stale tickets are ignored.
  String? error;
  int request = 0;
  late String openedServer = w.server?.id ?? '';

  static const snapshotKey = 'member-graph';

  bool get guest => w.server?.string('role') == 'guest';

  @override
  void initState() {
    super.initState();
    w.addListener(serverChanged);
    // Revisit: the last accepted graph renders at once and revalidates.
    final cached = readPageSnapshot(w, snapshotKey)?['graph'];
    if (cached != null) data = _parse(cached);
    if (guest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => leaveForGuest());
    } else {
      unawaited(load());
    }
  }

  @override
  void dispose() {
    w.removeListener(serverChanged);
    super.dispose();
  }

  /// `<Navigate to={serverSlug ? `/s/${serverSlug}` : "/"} replace />`.
  void leaveForGuest() {
    if (!mounted || !guest) return;
    w.navigation.navigate(
      RaftLocation.at(serverSlug: w.location.serverSlug, route: RaftRoute.home),
      kind: RaftNavigationKind.replace,
    );
    w.notifyListeners();
  }

  /// `useEffect(..., [current?.id])`: a new workspace reloads the graph.
  void serverChanged() {
    final id = w.server?.id ?? '';
    if (id == openedServer) return;
    openedServer = id;
    request++;
    setState(() {
      data = null;
      error = null;
      loading = false;
    });
    if (guest) {
      leaveForGuest();
    } else if (id.isNotEmpty) {
      unawaited(load());
    }
  }

  Future<void> load() async {
    final server = w.server;
    if (server == null) return;
    final ticket = ++request, identity = pageIdentity(w);
    setState(() {
      // Only a cold open shows the loading state; a revalidation keeps the
      // graph on screen.
      loading = data == null;
      error = null;
    });
    try {
      final value = await w.client.get('/servers/${server.id}/member-graph');
      if (!mounted || ticket != request) return;
      setState(() => data = _parse(value));
      writePageSnapshot(w, snapshotKey, identity, {'graph': value});
    } catch (e) {
      if (!mounted || ticket != request) return;
      // A failed revalidation keeps the graph already shown.
      if (data == null) {
        setState(
          () => error = raftText(
            context,
            userErrorText(
              e,
              fallback: 'Failed to load member graph',
              where: 'member graph',
            ),
          ),
        );
      }
    } finally {
      if (mounted && ticket == request) setState(() => loading = false);
    }
  }

  static RaftMemberGraphData _parse(Object? value) {
    if (value is! Map) return const RaftMemberGraphData();
    List<T> rows<T>(String key, T Function(Map<String, dynamic>) make) => [
      for (final row in value[key] as List? ?? const [])
        if (row is Map) make(Map<String, dynamic>.from(row)),
    ];
    return RaftMemberGraphData(
      humans: rows('humans', RaftGraphMember.fromJson),
      agents: rows('agents', RaftGraphMember.fromJson),
      channels: rows('channels', RaftGraphChannel.fromJson),
    );
  }

  /// `AvatarSlot` of a graph member: uploaded / Gravatar / pixel artwork with
  /// the user / bot glyph as fallback.
  Widget avatar(
    BuildContext context,
    RaftGraphMember member, {
    required bool compact,
  }) {
    final row = {
      'id': member.id,
      'userId': member.id,
      'avatarUrl': member.avatarUrl,
      'gravatarHash': member.gravatarHash.isEmpty ? null : member.gravatarHash,
    };
    final projection = projectSenderAvatar(
      origin: w.client.origin,
      senderId: member.id,
      senderType: member.agent ? 'agent' : 'user',
      agents: member.agent ? [row] : const [],
      members: member.agent ? const [] : [row],
      requestSize: compact ? 20 : 36,
    );
    final t = RaftTokens.of(context);
    // The Avatar recipe's placeholder fill and glyph colour (`bg-fill-muted`
    // / `text-foreground-placeholder` in Elegant, the brutal swatches there).
    final recipe = RaftAvatarRecipe.resolve(
      theme: t.recipeTheme,
      type_: member.agent
          ? RaftAvatarRecipeType.agent
          : RaftAvatarRecipeType.human,
      size: RaftAvatarRecipeSize.xl,
      states: t.recipeStates(),
      tokens: t.recipeTokens,
    );
    final glyph = RaftIcon(
      member.agent ? RaftGlyph.bot : RaftGlyph.user,
      size: compact ? 12 : 18,
      color: recipe.fallback.color?.resolve(t.recipeTokens),
    );
    final content = RaftAvatarContent(
      name: member.label,
      kind: member.agent
          ? RaftAvatarContentKind.agent
          : RaftAvatarContentKind.human,
      uploadedUrl: projection.uploadedUrl,
      gravatarUrl: projection.gravatarUrl,
      pixelKey: projection.pixelKey,
      fallback: Center(child: glyph),
    );
    return compact
        ? RaftAvatarSlot(
            name: member.label,
            agent: member.agent,
            avatarUrl: member.avatarUrl,
            slot: RaftAvatarSlotContext.compactList,
            content: content,
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: recipe.root.decoration(t.recipeTokens).color,
            ),
            child: content,
          );
  }

  /// Hover-card avatar (`mention-card` slot) through the same projection as the
  /// graph node: relative uploaded avatars resolve against the API origin and
  /// humans fall back to Gravatar (`humanAvatar.ts`).
  Widget hoverAvatar(RaftGraphMember member) {
    final row = {
      'id': member.id,
      'userId': member.id,
      'avatarUrl': member.avatarUrl,
      'gravatarHash': member.gravatarHash.isEmpty ? null : member.gravatarHash,
    };
    final projection = projectSenderAvatar(
      origin: w.client.origin,
      senderId: member.id,
      senderType: member.agent ? 'agent' : 'user',
      agents: member.agent ? [row] : const [],
      members: member.agent ? const [] : [row],
      requestSize: 48,
    );
    return RaftAvatarSlot(
      name: member.label,
      agent: member.agent,
      avatarUrl: member.avatarUrl,
      slot: RaftAvatarSlotContext.mentionCard,
      content: RaftAvatarContent(
        name: member.label,
        kind: member.agent
            ? RaftAvatarContentKind.agent
            : RaftAvatarContentKind.human,
        uploadedUrl: projection.uploadedUrl,
        gravatarUrl: projection.gravatarUrl,
        pixelKey: projection.pixelKey,
        fallback: Center(
          child: RaftIcon(
            member.agent ? RaftGlyph.bot : RaftGlyph.user,
            size: 24,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (guest) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 768;
    final headerFill = t.colors['layer-canvas-muted']!;
    return RaftPanelTextScope(
      child: Column(
        key: const ValueKey('member-graph-page'),
        children: [
          // PanelHeader: GitBranch 18, `bg-primary-soft theme-brutal:bg-soft-signal`
          // (Elegant `border-0 bg-fill-muted`), `Badge.Experimental` suffix.
          RaftStatusBarSource(
            // The header's own fill continues up through the status bar band.
            color: headerFill,
            child: Container(
              color: headerFill,
              child: RaftPanelHeaderBar(
                title: raftText(context, 'Graph'),
                onBack: narrow ? widget.onBack : null,
                backTooltip: raftText(context, 'Back'),
                backKey: const ValueKey('member-graph-mobile-back'),
                titleSuffix: Transform.translate(
                  offset: const Offset(0, -1),
                  // `<Badge.Experimental>`: solid success variant.
                  child: RaftRecipeBadge(
                    // Web `Badge.Experimental` is untranslated English.
                    'Experimental',
                    appearance: RaftBadgeRecipeAppearance.solid,
                    variant: RaftBadgeRecipeVariant.success,
                  ),
                ),
                iconSlot: RaftPanelHeaderIconTile(
                  glyph: RaftGlyph.gitBranch,
                  background: t.colors['fill-muted']!,
                  borderless: true,
                ),
              ),
            ),
          ),
          Expanded(
            child: RaftMemberGraphPageBody(
              child: RaftMemberGraphView(
                data: data,
                loading: loading,
                error: error,
                sectionLabel: widget.sectionLabel,
                avatar: avatar,
                onRefresh: () => unawaited(load()),
                nodeWrapper: (context, member, node) => ProfilePreviewHoverCard(
                  controller: w,
                  agent: member.agent,
                  id: member.id,
                  avatar: hoverAvatar(member),
                  child: node,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
