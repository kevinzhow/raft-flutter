// The state of the cards beside a conversation (Web v1.24
// `channelSideLayoutStore.ts`, `channelSideCardStore.ts`, the splits of
// `ChannelSideArea.tsx` and `activeSideCard`): which of Tasks and Files are
// open or folded, which one shows where only one fits, the Tasks filter, the
// person's column layout and each stack's heights.
//
// One setting for the person, not one per channel: the cards follow them from
// channel to channel. The column layout is saved on the server (the sidebar
// order's `channelSideLayout`); this device keeps the last one for the first
// frame and for a server where none is saved yet.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/device_preferences.dart';
import '../data/workspace_controller.dart';
import 'channel_side_layout.dart';

/// The two cards Task v2 opens beside the chat.
enum ChannelSideCard { tasks, files }

enum ChannelTasksFilter { all, mine }

const _openKey = 'raft.channelSide.open';
const _collapsedKey = 'raft.channelSide.collapsed';
const _layoutKey = 'raft.channelSide.layout';
const _conversationWidthKey = 'raft.channelSide.conversationWidth';
const _splitsKey = 'raft.channelSide.splits';

/// The card opened or picked last (ties go to the first in [open]); a card
/// never picked counts as 0. Null when none is open.
String? activeSideCard(Iterable<String> open, Map<String, int> focusAt) {
  String? best;
  for (final card in open) {
    if (best == null || (focusAt[card] ?? 0) > (focusAt[best] ?? 0)) {
      best = card;
    }
  }
  return best;
}

typedef _DockWidths = ({ChannelSideLayout layout, int? conversationWidth});

class ChannelSideStore extends ChangeNotifier {
  ChannelSideStore._(this.w) {
    _open = _readCards(_openKey);
    _collapsed = _readCards(_collapsedKey);
    _splits = _readSplits();
    _layout = _readDeviceLayout();
    _conversationWidth = _readConversationWidth();
    _confirmed = (layout: _layout, conversationWidth: _conversationWidth);
    w.addListener(_orderChanged);
    w.services.disposeWithSession(dispose);
    _orderChanged();
  }

  static final _owners = Expando<ChannelSideStore>();

  /// The store of [w]'s presentation (created on first use, disposed with the
  /// session).
  static ChannelSideStore of(WorkspaceController w) =>
      _owners[w] ??= ChannelSideStore._(w);

  final WorkspaceController w;
  bool _ended = false;

  // ---- the cards -----------------------------------------------------------

  late Map<ChannelSideCard, bool> _open, _collapsed;
  final _focusAt = <String, int>{};

  /// When each open side section opened (see [openOrder]).
  final _openedAt = <ChannelSideSection, int>{};
  int _tick = 0;
  ChannelTasksFilter _taskFilter = ChannelTasksFilter.all;

  bool cardOpen(ChannelSideCard card) => _open[card]!;
  bool collapsed(ChannelSideCard card) => _collapsed[card]!;
  ChannelTasksFilter get taskFilter => _taskFilter;

  /// When each card was last opened or picked, as an order (not a time):
  /// `tasks`, `files`, and the keys the area adds for the Artifact (`app`), the
  /// context view and the channel details.
  Map<String, int> get focusAt => Map.unmodifiable(_focusAt);

  /// The card that shows where only one of [open] fits.
  String? activeCard(Iterable<String> open) => activeSideCard(open, _focusAt);

  /// Opening a card also makes it the one that shows where only one fits; one
  /// already open is only picked.
  void setCardOpen(ChannelSideCard card, bool open) {
    if (_open[card] == open) {
      if (open) focus(card.name);
      return;
    }
    _open = {..._open, card: open};
    _writeCards(_openKey, _open);
    if (open) _focusAt[card.name] = ++_tick;
    notifyListeners();
  }

  void setCollapsed(ChannelSideCard card, bool collapsed) {
    if (_collapsed[card] == collapsed) return;
    _collapsed = {..._collapsed, card: collapsed};
    _writeCards(_collapsedKey, _collapsed);
    notifyListeners();
  }

  void focus(String card) {
    _focusAt[card] = ++_tick;
    notifyListeners();
  }

  /// When each of the sections [open] beside the conversation opened, as an
  /// order on the same clock as [focusAt]: one that was not open on the last
  /// call takes the next tick, one that stays keeps its own and one that
  /// closed loses it. The newest is the top of the side stack
  /// (`ChannelSideStack`).
  ///
  /// Called while the area lays out, so it never notifies: the same set twice
  /// changes nothing.
  Map<ChannelSideSection, int> openOrder(Set<ChannelSideSection> open) {
    _openedAt.removeWhere((section, _) => !open.contains(section));
    for (final section in open) {
      _openedAt.putIfAbsent(section, () => ++_tick);
    }
    return Map.unmodifiable(_openedAt);
  }

  void setTaskFilter(ChannelTasksFilter filter) {
    if (_taskFilter == filter) return;
    _taskFilter = filter;
    notifyListeners();
  }

  static Map<ChannelSideCard, bool> _readCards(String key) {
    Object? value;
    try {
      final raw = DevicePreferences.current?.getString(key);
      value = raw == null ? null : jsonDecode(raw);
    } catch (_) {}
    return {
      for (final card in ChannelSideCard.values)
        card: value is Map && value[card.name] == true,
    };
  }

  static void _writeCards(String key, Map<ChannelSideCard, bool> flags) =>
      _remember(key, {for (final e in flags.entries) e.key.name: e.value});

  // ---- the column layout ---------------------------------------------------

  late ChannelSideLayout _layout;
  int? _conversationWidth;

  /// Device-local conversation width, set when an expanded seam settles.
  int? get conversationWidth => _conversationWidth;

  /// The last accepted dock layout and its device-local conversation width.
  late _DockWidths _confirmed;

  /// The layout shown; always complete (every section is in exactly one
  /// column, so a section opening always has a place).
  ChannelSideLayout get layout => _layout;

  bool _hasSeen = false, _hasFollowed = false;
  Object? _seenRaw;

  /// The last layout the sidebar order brought: what the server holds, as far
  /// as this device knows.
  ChannelSideLayout? _followed;
  int _inFlight = 0, _latest = 0, _confirmedSeq = 0;
  bool _latestSaved = true;

  /// Move a section (a drop); saved once, when it lands.
  void moveSection(ChannelSideSection section, ChannelSideDrop drop) {
    final next = _layout.move(section, drop);
    if (identical(next, _layout)) return;
    _save(next);
    _layout = next;
    notifyListeners();
  }

  /// A column's width as dragged; [commit] saves it (on release), otherwise it
  /// only shows.
  void resizeColumn(
    int column,
    num width,
    bool commit, {
    double? conversationWidth,
  }) => _resizeColumns({column: width}, commit, conversationWidth);

  void resizeDock(Map<int, num> widths, double conversationWidth) =>
      _resizeColumns(widths, true, conversationWidth);

  void _resizeColumns(
    Map<int, num> widths,
    bool commit,
    double? conversationWidth,
  ) {
    var next = _layout;
    for (final entry in widths.entries) {
      next = next.resize(entry.key, entry.value);
    }
    final previousConversation = _conversationWidth;
    if (conversationWidth != null) {
      final width = math.max(
        channelSideMinSavedWidth,
        conversationWidth.round(),
      );
      _conversationWidth = width;
    }
    if (!identical(next, _layout) ||
        previousConversation != _conversationWidth) {
      _layout = next;
      notifyListeners();
    }
    if (commit) _save(_layout);
  }

  /// The server member's layout as the sidebar order loads (a reload, a server
  /// switch, another client's save): it is the layout. None saved there: this
  /// device's. An order that carries the same layout (any sidebar-order write
  /// answers with the whole order) changes nothing, so a width being dragged or
  /// a section being moved isn't reset; nor does one while this device's own
  /// saves are in flight.
  void _orderChanged() {
    if (_ended) return;
    final raw = w.sidebarOrder['channelSideLayout'];
    if (_hasSeen && identical(raw, _seenRaw)) return;
    _hasSeen = true;
    _seenRaw = raw;
    final saved = ChannelSideLayout.parse(raw);
    if (_hasFollowed && saved == _followed) return;
    _hasFollowed = true;
    _followed = saved;
    if (_inFlight > 0) return;
    _show(saved ?? _readDeviceLayout());
  }

  void _show(ChannelSideLayout layout) {
    final next = layout.complete();
    final width = _confirmed.conversationWidth;
    _confirmed = (layout: next, conversationWidth: width);
    _remember(_layoutKey, next.toJson());
    if (!next.same(_layout) || width != _conversationWidth) {
      _layout = next;
      _conversationWidth = width;
      notifyListeners();
    }
  }

  void _confirm(_DockWidths widths) {
    _confirmed = widths;
    _remember(_layoutKey, widths.layout.toJson());
    _remember(_conversationWidthKey, widths.conversationWidth);
  }

  /// Keep the newest requested widths visible while saves overlap. Persist
  /// acknowledged pairs in request order so an older reply can't replace a
  /// newer accepted pair.
  void _save(ChannelSideLayout layout) {
    final widths = (layout: layout, conversationWidth: _conversationWidth);
    final seq = ++_latest;
    if (w.client.serverId == null) {
      _confirmedSeq = seq;
      _latestSaved = true;
      _confirm(widths);
      return;
    }
    _inFlight++;
    unawaited(_settle(seq, widths));
  }

  Future<void> _settle(int seq, _DockWidths widths) async {
    ChannelSideLayout? acknowledged;
    try {
      final order = await w.sidebarRepository.update({
        'channelSideLayout': widths.layout.toJson(),
      });
      acknowledged = ChannelSideLayout.parse(order?['channelSideLayout']);
    } catch (_) {
      // Keep the confirmed pair if the workspace could not save this one.
    }
    _inFlight--;
    if (_ended) return;
    final saved = acknowledged?.same(widths.layout) ?? false;
    if (seq == _latest) _latestSaved = saved;
    if (acknowledged != null && seq > _confirmedSeq) {
      _confirmedSeq = seq;
      _confirm((
        layout: acknowledged.complete(),
        conversationWidth: saved
            ? widths.conversationWidth
            : _confirmed.conversationWidth,
      ));
    }
    if (_inFlight > 0 || _latestSaved) return;
    // The sidebar projection can contain the optimistic layout of an older
    // request. Roll back to the pair backed by a receipt.
    final raw = w.sidebarOrder['channelSideLayout'];
    _hasSeen = true;
    _seenRaw = raw;
    _hasFollowed = true;
    _followed = ChannelSideLayout.parse(raw);
    _show(_confirmed.layout);
  }

  static int? _readConversationWidth() {
    try {
      final raw = DevicePreferences.current?.getString(_conversationWidthKey);
      final width = int.tryParse(raw ?? '');
      if (width != null && width >= channelSideMinSavedWidth) return width;
    } catch (_) {}
    return null;
  }

  static ChannelSideLayout _readDeviceLayout() {
    ChannelSideLayout? parsed;
    try {
      final raw = DevicePreferences.current?.getString(_layoutKey);
      parsed = raw == null ? null : ChannelSideLayout.parse(jsonDecode(raw));
    } catch (_) {}
    return (parsed ?? ChannelSideLayout.defaults).complete();
  }

  // ---- the heights of a stack ----------------------------------------------

  late Map<String, List<double>> _splits;

  static String _splitKey(List<ChannelSideSection> stack) =>
      stack.map((s) => s.name).join('|');

  /// The heights of [stack] (a column's open sections, top to bottom) as shares
  /// of its column: the saved ones, else Tasks over Files 60/40; with the
  /// thread, the Artifact or the profile, 3 parts to it and 2 to each other
  /// section; else even.
  List<double> splitShares(List<ChannelSideSection> stack) {
    final saved = _splits[_splitKey(stack)];
    if (saved != null &&
        saved.length == stack.length &&
        saved.every((n) => n > 0)) {
      return saved;
    }
    if (stack.length == 2 &&
        stack[0] == ChannelSideSection.tasks &&
        stack[1] == ChannelSideSection.files) {
      return const [0.6, 0.4];
    }
    final parts = [
      for (final section in stack)
        switch (section) {
          ChannelSideSection.thread ||
          ChannelSideSection.artifact ||
          ChannelSideSection.profile ||
          ChannelSideSection.context ||
          ChannelSideSection.details => 3,
          _ => 2,
        },
    ];
    final total = parts.fold(0, (a, b) => a + b);
    return [for (final part in parts) part / total];
  }

  /// Keeps [shares] for [stack] when a drag or a key ends.
  void saveSplit(List<ChannelSideSection> stack, List<double> shares) {
    if (shares.any((n) => !n.isFinite)) return;
    _splits = {..._splits, _splitKey(stack): List.of(shares)};
    _remember(_splitsKey, _splits);
    notifyListeners();
  }

  static Map<String, List<double>> _readSplits() {
    try {
      final raw = DevicePreferences.current?.getString(_splitsKey);
      final value = raw == null ? null : jsonDecode(raw);
      if (value is Map) {
        return {
          for (final e in value.entries)
            if (e.key is String &&
                e.value is List &&
                (e.value as List).every((n) => n is num))
              e.key as String: [
                for (final n in e.value as List) (n as num).toDouble(),
              ],
        };
      }
    } catch (_) {}
    return {};
  }

  // ---- the device ------------------------------------------------------------

  static void _remember(String key, Object? value) {
    try {
      final preferences = DevicePreferences.current;
      if (preferences != null) {
        unawaited(
          value == null
              ? preferences.remove(key)
              : preferences.setString(key, jsonEncode(value)),
        );
      }
    } catch (_) {
      // Storage can be unavailable; the state still holds for the session.
    }
  }

  @override
  void dispose() {
    if (_ended) return;
    _ended = true;
    w.removeListener(_orderChanged);
    super.dispose();
  }
}
