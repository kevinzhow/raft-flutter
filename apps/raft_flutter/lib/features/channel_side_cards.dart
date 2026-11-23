// What is open beside a conversation, and how it opens and closes (Web v1.24
// ChatPanel `tasksCardOpen`, `closeCard`, `toggleTasksCard`, `headerMobileBack`).
// The cards are the person's (ChannelSideStore): they follow them from
// conversation to conversation. An old `?chatTab=tasks|files` link opens its
// card; closing the card clears the query.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_navigation_history.dart';
import '../data/workspace_controller.dart';
import 'channel_artifact_place.dart';
import 'channel_side_flags.dart';
import 'channel_side_store.dart';
import 'channel_side_web_preview.dart';

abstract final class ChannelSideCards {
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

  /// Task v2 on and a conversation that can have cards (not a thread).
  static bool enabled(WorkspaceController w) {
    final channel = w.channel;
    return channel != null &&
        channel.type != 'thread' &&
        ChannelSideFlags.of(w).taskV2;
  }

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
      if (desktop) {
        final conversation = w.channel!.id;
        final browser = preview.browserTabs.forConversation(conversation);
        final artifact = ChannelArtifactPlace.of(w)
            .forConversation(conversation);
        if (browser != null &&
            (artifact == null || browser.inFrontOf(artifact.openedAt))) {
          preview.browserTabs.close(conversation);
        } else {
          ChannelArtifactPlace.of(w).close(conversation);
        }
      } else {
        preview.close();
      }
      return true;
    }
    if (cards.isEmpty) return false;
    for (final card in cards) {
      close(w, card);
    }
    return true;
  }

  /// The side area's key for the web page in the store's focus order.
  static const appCardKey = 'app';
}

/// The Tasks and Files buttons between Search and Settings (Web
/// `useChannelHeadToggles`): pressed while their card is open. Empty without
/// Task v2 or for a thread.
List<Widget> channelSideToggles(BuildContext context, WorkspaceController w) {
  if (!ChannelSideCards.enabled(w)) return const [];
  final tasks = ChannelSideCards.isOpen(w, ChannelSideCard.tasks);
  final files = ChannelSideCards.isOpen(w, ChannelSideCard.files);
  return [
    raftConversationHeaderToggle(
      key: const Key('channel-tasks-toggle'),
      glyph: RaftGlyph.listTodo,
      label: raftText(context, tasks ? 'Close Tasks' : 'Open Tasks'),
      pressed: tasks,
      onPressed: () => ChannelSideCards.toggle(w, ChannelSideCard.tasks),
    ),
    raftConversationHeaderToggle(
      key: const Key('channel-files-toggle'),
      glyph: RaftGlyph.paperclip,
      label: raftText(context, files ? 'Close files' : 'Open files'),
      pressed: files,
      onPressed: () => ChannelSideCards.toggle(w, ChannelSideCard.files),
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
