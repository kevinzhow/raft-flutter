// The panes open beside the conversation, as one stack: which of them is on
// top, which of them fit beside the chat, and the one way to close one.
//
// Open-ness itself lives in five unrelated owners (the cards, the channel
// details, the Artifact and the browser, the profile and the docked thread),
// so nothing here is told that a pane opened: the area already works out which
// sections are open once per build and hands that set over
// ([ChannelSideStack.of]). A section that was not open on the last call takes
// the next tick, one that stays keeps its own and one that closed loses it, so
// the newest tick is the pane opened last. A section added to
// [ChannelSideSection] later joins the stack by being open, with no call to
// wire up.
import 'package:flutter/foundation.dart';

import '../data/workspace_controller.dart';
import 'channel_details_host.dart';
import 'channel_side_cards.dart';
import 'channel_side_layout.dart';
import 'channel_side_store.dart';

/// Closes exactly the one side section [section], leaving every other open
/// pane where it is.
///
/// Written as an exhaustive switch on purpose: a new [ChannelSideSection]
/// stops compiling here until it says how it closes, instead of silently
/// ignoring Back.
void closeChannelSideSection(
  WorkspaceController w,
  ChannelSideSection section,
) {
  switch (section) {
    case ChannelSideSection.tasks:
      ChannelSideCards.close(w, ChannelSideCard.tasks);
    case ChannelSideSection.files:
      ChannelSideCards.close(w, ChannelSideCard.files);
    case ChannelSideSection.details:
      ChannelDetailsStore.of(w).close();
    case ChannelSideSection.context:
      // Nothing opens the context view on its own yet: it is in the saved
      // layout (v1.24) as a section that follows the profile, is carried with
      // it and is never left alone in a column, and `_openChannelSide` never
      // puts it in the open set. Until it has an opener, the profile it
      // follows is what takes its column away; whoever gives it one gives it
      // its own line here.
      w.closeProfile();
    case ChannelSideSection.profile:
      w.closeProfile();
    case ChannelSideSection.artifact:
      // Only this conversation's Artifact or browser, not the cards beside it.
      ChannelSideCards.closeArtifact(w);
    case ChannelSideSection.thread:
      // What the thread panel's own Close does (`closeThreadPanel`); the rest
      // of that method is the workspace view's own state.
      w.closeThread();
  }
}

/// The open side sections in the order they opened, newest on top.
@immutable
class ChannelSideStack {
  const ChannelSideStack(this.openedAt);

  /// The stack of the sections [open] of [store]: the ticks after this call's
  /// opens and closes.
  factory ChannelSideStack.of(
    ChannelSideStore store,
    Set<ChannelSideSection> open,
  ) => ChannelSideStack(store.openOrder(open));

  /// No order known: the first column in layout order is the top. The
  /// placements that do not depend on the order use this.
  static const unordered = ChannelSideStack(<ChannelSideSection, int>{});

  /// When each open section opened, on [ChannelSideStore]'s clock.
  final Map<ChannelSideSection, int> openedAt;

  /// How recently [column] was opened: its newest open section's tick.
  int tickOf(VisibleChannelSideColumn column) {
    var newest = 0;
    for (final section in column.sections) {
      final at = openedAt[section] ?? 0;
      if (at > newest) newest = at;
    }
    return newest;
  }

  /// Which of [visible] is on top: the column whose newest open section opened
  /// last. Ties go to the first in layout order.
  int topOf(List<VisibleChannelSideColumn> visible) {
    var top = 0;
    for (var i = 1; i < visible.length; i++) {
      if (tickOf(visible[i]) > tickOf(visible[top])) top = i;
    }
    return top;
  }

  /// The section of [column] that opened last: the one Back closes.
  ChannelSideSection topSectionOf(VisibleChannelSideColumn column) {
    var top = column.sections.first;
    for (final section in column.sections) {
      if ((openedAt[section] ?? 0) > (openedAt[top] ?? 0)) top = section;
    }
    return top;
  }

  /// Which of [visible] stand beside the chat in [width], each at its own
  /// minimum width and never narrower, with [chatFloor] left for the chat.
  ///
  /// Each column in layout order takes its place if it still fits beside the
  /// ones already there; one that does not fit is passed over, so a wide
  /// column does not keep a narrow one behind it out of a place it fits in.
  /// The top pane always shows:
  /// where it does not fit beside the ones already taken, they give their
  /// place back, least recently opened first. Empty when not even the top pane
  /// fits beside the chat, which is where the whole area covers instead.
  /// The result is in layout order, so a pane does not move when another one
  /// opens.
  List<VisibleChannelSideColumn> fitting(
    List<VisibleChannelSideColumn> visible, {
    required double width,
    required double chatFloor,
  }) {
    final top = topOf(visible);
    final taken = <int>[];
    var used = chatFloor;
    for (var i = 0; i < visible.length; i++) {
      if (used + visible[i].minWidth > width) continue;
      taken.add(i);
      used += visible[i].minWidth;
    }
    if (!taken.contains(top)) {
      while (taken.isNotEmpty && used + visible[top].minWidth > width) {
        var oldest = taken.first;
        for (final i in taken) {
          if (tickOf(visible[i]) < tickOf(visible[oldest])) oldest = i;
        }
        taken.remove(oldest);
        used -= visible[oldest].minWidth;
      }
      if (used + visible[top].minWidth > width) return const [];
      taken.add(top);
    }
    taken.sort();
    return [for (final i in taken) visible[i]];
  }
}
