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

class ChannelSideStore extends ChangeNotifier {
  ChannelSideStore._(this.w) {
    _open = _readCards(_openKey);
    _collapsed = _readCards(_collapsedKey);
    _splits = _readSplits();
    _layout = _readDeviceLayout();
    _confirmed = _layout;
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

  /// The layout last known to be saved (or, with none saved there, this
  /// device's): what a refused save goes back to.
  late ChannelSideLayout _confirmed;

  /// The layout shown; always complete (every section is in exactly one
  /// column, so a section opening always has a place).
  ChannelSideLayout get layout => _layout;

  bool _hasSeen = false, _hasFollowed = false;
  Object? _seenRaw;

  /// The last layout the sidebar order brought: what the server holds, as far
  /// as this device knows.
  ChannelSideLayout? _followed;
  int _inFlight = 0, _latest = 0;
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
  void resizeColumn(int column, num width, bool commit) =>
      _resizeColumns({column: width}, commit);

  /// An expanded seam settles the visible columns together in one save.
  void resizeColumns(Map<int, num> widths) => _resizeColumns(widths, true);

  void _resizeColumns(Map<int, num> widths, bool commit) {
    var next = _layout;
    for (final entry in widths.entries) {
      next = next.resize(entry.key, entry.value);
    }
    if (!identical(next, _layout)) {
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

  /// Show [layout] (the server's, or a fallback) and keep it as this device's.
  void _show(ChannelSideLayout layout) {
    final next = layout.complete();
    _confirmed = next;
    _remember(_layoutKey, next.toJson());
    if (!next.same(_layout)) {
      _layout = next;
      notifyListeners();
    }
  }

  /// Saving it on the server member. Saves can overlap (a drop, then a released
  /// resize within one round trip), and each answer, or a rollback, rewrites
  /// the sidebar order: while any is in flight the layout shown is the newest
  /// one asked for; once all have settled it is checked against what the newest
  /// one left in the sidebar order, and only a refused newest save puts back
  /// what the server held, else what was last confirmed.
  void _save(ChannelSideLayout layout) {
    _remember(_layoutKey, layout.toJson());
    // No server open (yet): this device's copy is all there is.
    if (w.client.serverId == null) {
      _confirmed = layout;
      return;
    }
    final seq = ++_latest;
    _inFlight++;
    unawaited(_settle(seq, layout));
  }

  Future<void> _settle(int seq, ChannelSideLayout layout) async {
    try {
      await w.updateSidebarOrder({'channelSideLayout': layout.toJson()});
    } catch (_) {
      // updateSidebarOrder reports a refusal through the order it restores.
    }
    _inFlight--;
    if (_ended) return;
    final raw = w.sidebarOrder['channelSideLayout'];
    final held = ChannelSideLayout.parse(raw);
    if (seq == _latest) _latestSaved = held != null && held.same(layout);
    if (_inFlight > 0) return;
    if (_latestSaved) {
      _confirmed = layout;
      return;
    }
    // Refused: back to what the server holds, else what was last confirmed.
    _hasSeen = true;
    _seenRaw = raw;
    _hasFollowed = true;
    _followed = held;
    _show(held ?? _confirmed);
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

  static void _remember(String key, Object value) {
    try {
      final preferences = DevicePreferences.current;
      if (preferences != null) {
        unawaited(preferences.setString(key, jsonEncode(value)));
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
