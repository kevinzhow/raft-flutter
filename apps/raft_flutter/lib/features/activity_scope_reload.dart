import 'dart:convert';

import '../data/activity_filter_choice.dart';

/// Web ThreadsInbox reload triggers of the scopes: Pinned reloads when the
/// sidebar's pinned list changes, Saved when a save or unsave was accepted
/// (`savedRevision`). Both are tracked on every call so a change that happened
/// under another choice does not reload later.
class ActivityScopeReload {
  String? _pins;
  int? _saved;

  /// Whether the list of [choice] must reload now.
  bool changed({
    required ActivityFilterChoice choice,
    required Object? pinned,
    required int savedRevision,
  }) {
    final pins = jsonEncode(pinned ?? const []);
    final pinsChanged = _pins != null && _pins != pins;
    final savedChanged = _saved != null && _saved != savedRevision;
    _pins = pins;
    _saved = savedRevision;
    return switch (choice) {
      ActivityFilterChoice.pinned => pinsChanged,
      ActivityFilterChoice.saved => savedChanged,
      _ => false,
    };
  }
}
