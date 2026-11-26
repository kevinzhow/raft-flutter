// What is open beside a conversation, and how it opens and closes (Web v1.24
// ChatPanel `tasksCardOpen`, `closeCard`, `toggleTasksCard`, `headerMobileBack`).
// The cards are the person's (ChannelSideStore): they follow them from
// conversation to conversation. An old `?chatTab=tasks|files` link opens its
// card; closing the card clears the query.
import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_location.dart';
import '../data/raft_navigation_history.dart';
import '../data/workspace_controller.dart';
import 'channel_artifact_place.dart';
import 'channel_side_flags.dart';
import 'channel_side_layout.dart';
import 'channel_side_store.dart';
import 'channel_side_web_preview.dart';
import 'workspace_channel_access.dart';

abstract final class ChannelSideCards {
  static int latestDesktopOpen(WorkspaceController w) {
    if (!desktopBrowserAvailable(w)) return 0;
    final conversation = w.channel?.id;
    final browser = WebPreviewStore.of(w).browserTabs
        .forConversation(conversation);
    final artifact = ChannelArtifactPlace.of(w).forConversation(conversation);
    final browserOpened = browser?.frontAt ?? 0;
    final artifactOpened = artifact?.openedAt ?? 0;
    return browserOpened > artifactOpened ? browserOpened : artifactOpened;
  }

  static int desktopPlaceOpenedAt(WorkspaceController w) {
    if (!desktopBrowserAvailable(w)) return 0;
    final conversation = w.channel?.id;
    final browser = WebPreviewStore.of(w).browserTabs
        .forConversation(conversation);
    final artifact = ChannelArtifactPlace.of(w).forConversation(conversation);
    return browser != null &&
            (artifact == null || browser.inFrontOf(artifact.openedAt))
        ? browser.frontAt
        : artifact?.openedAt ?? 0;
  }

  static bool hasDesktopPlace(WorkspaceController w) =>
      desktopPlaceOpenedAt(w) != 0;

  static String desktopPlaceTitle(BuildContext context, WorkspaceController w) {
    final conversation = w.channel?.id;
    final browser = WebPreviewStore.of(w).browserTabs
        .forConversation(conversation);
    final artifact = ChannelArtifactPlace.of(w).forConversation(conversation);
    return browser != null &&
            (artifact == null || browser.inFrontOf(artifact.openedAt))
        ? raftText(context, 'Browser')
        : artifact?.title ?? raftText(context, 'Artifact');
  }

  /// The conversation currently shown inside `ChannelSideArea`, or null when
  /// the active route does not show a channel or DM conversation.
  static RaftChannel? conversation(WorkspaceController w) {
    final channel = w.channel;
    if (channel == null || channel.type == 'thread') return null;
    if (WorkspaceChannelAccess.forChannel(w, channel.id) != null) return null;
    final section = w.section;
    if (section == 'chat') return channel;
    if (section == 'activity' || section == 'search') {
      final content = w.location.content;
      if (content != null &&
          (content.kind == RaftContentKind.channel ||
              content.kind == RaftContentKind.dm) &&
          content.id == channel.id) {
        return channel;
      }
    }
    return null;
  }

  /// Task v2 on and a conversation that can have cards (not a thread).
  static bool enabled(WorkspaceController w) =>
      conversation(w) != null && ChannelSideFlags.of(w).taskV2;

  static bool isOpen(WorkspaceController w, ChannelSideCard card) =>
      enabled(w) &&
      (ChannelSideStore.of(w).cardOpen(card) ||
          w.location.chatTab == card.name);

  static List<ChannelSideCard> open(WorkspaceController w) => [
    for (final card in ChannelSideCard.values)
      if (isOpen(w, card)) card,
  ];

  static void close(WorkspaceController w, ChannelSideCard card) {
    ChannelSideStore.of(w).setCardOpen(card, false);
    if (w.server != null && w.location.chatTab == card.name) {
      w.navigation.navigate(
        w.location.withQuery({'chatTab': null}),
        kind: RaftNavigationKind.replace,
      );
      w.notifyListeners();
    }
  }

  static void toggle(WorkspaceController w, ChannelSideCard card) {
    if (isOpen(w, card)) {
      close(w, card);
    } else {
      ChannelSideStore.of(w).setCardOpen(card, true);
    }
  }

  /// Header toggle press against the panel's rendered visibility: close if
  /// actually on screen, otherwise open and bring to front.
  static void press(
    WorkspaceController w,
    ChannelSideCard card, {
    required bool shown,
  }) {
    if (shown) {
      close(w, card);
    } else {
      ChannelSideStore.of(w).revealCard(card);
    }
  }

  /// A phone's header Back (Web `headerMobileBack`): the web page, or the open
  /// cards, cover the conversation, so they close before the conversation
  /// does. With both, the one on top (opened or picked last) goes first; a
  /// card closes with its sibling. True when something closed.
  static bool closeCovering(WorkspaceController w) {
    final cards = open(w);
    final preview = WebPreviewStore.of(w);
    final page = preview.pageFor(w.channel?.id);
    final desktop = hasDesktopPlace(w);
    final onTop =
        (page != null || desktop) &&
        (cards.isEmpty ||
            ChannelSideStore.of(w).activeCard([
                  for (final card in cards) card.name,
                  appCardKey,
                ]) ==
                appCardKey);
    if (onTop) {
      closeArtifact(w);
      return true;
    }
    if (cards.isEmpty) return false;
    for (final card in cards) {
      close(w, card);
    }
    return true;
  }

  /// Closes what stands in the Artifact's place for this conversation and
  /// nothing else: the browser or the artifact, whichever is in front, else
  /// the legacy single page. The phone's Back ([closeCovering]) and the side
  /// stack's Back (`closeChannelSideSection`) both come through here, so the
  /// stack can close the Artifact without taking Tasks and Files with it.
  static void closeArtifact(WorkspaceController w) {
    final preview = WebPreviewStore.of(w);
    if (!hasDesktopPlace(w)) {
      preview.close();
      return;
    }
    final conversation = w.channel!.id;
    final browser = preview.browserTabs.forConversation(conversation);
    final artifact = ChannelArtifactPlace.of(w).forConversation(conversation);
    if (browser != null &&
        (artifact == null || browser.inFrontOf(artifact.openedAt))) {
      preview.browserTabs.close(conversation);
    } else {
      ChannelArtifactPlace.of(w).close(conversation);
    }
  }

  /// The side area's key for the web page in the store's focus order.
  static const appCardKey = 'app';
}

/// The Tasks and Files buttons between Search and Settings (Web
/// `useChannelHeadToggles`): pressed while their card is open. Empty without
/// Task v2 or for a thread.
List<Widget> channelSideToggles(BuildContext context, WorkspaceController w) {
  if (!ChannelSideCards.enabled(w)) return const [];
  final shown = ChannelSideStore.of(w).renderedShown;
  final tasks = shown != null
      ? shown.contains(ChannelSideSection.tasks)
      : ChannelSideCards.isOpen(w, ChannelSideCard.tasks);
  final files = shown != null
      ? shown.contains(ChannelSideSection.files)
      : ChannelSideCards.isOpen(w, ChannelSideCard.files);
  return [
    raftConversationHeaderToggle(
      key: const Key('channel-tasks-toggle'),
      glyph: RaftGlyph.listTodo,
      label: raftText(context, tasks ? 'Close Tasks' : 'Open Tasks'),
      pressed: tasks,
      onPressed: () =>
          ChannelSideCards.press(w, ChannelSideCard.tasks, shown: tasks),
    ),
    raftConversationHeaderToggle(
      key: const Key('channel-files-toggle'),
      glyph: RaftGlyph.paperclip,
      label: raftText(context, files ? 'Close files' : 'Open files'),
      pressed: files,
      onPressed: () =>
          ChannelSideCards.press(w, ChannelSideCard.files, shown: files),
    ),
  ];
}

/// Rebuilds [builder] when the flag or the cards change (a header holds no
/// state of its own).
Widget channelSideListener(WorkspaceController w, WidgetBuilder builder) =>
    ListenableBuilder(
      listenable: Listenable.merge([
        ChannelSideFlags.of(w),
        ChannelSideStore.of(w),
      ]),
      builder: (context, _) => builder(context),
    );

/// A header's Back that first closes what covers the conversation
/// ([ChannelSideCards.closeCovering]); null stays null (no Back on a desktop).
VoidCallback? channelBackClosingSide(
  WorkspaceController w,
  VoidCallback? back,
) {
  if (back == null) return null;
  return () {
    if (!ChannelSideCards.closeCovering(w)) back();
  };
}
