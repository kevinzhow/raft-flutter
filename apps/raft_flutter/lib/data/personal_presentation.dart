import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'search_memory.dart';

class PersonalPresentation {
  const PersonalPresentation({
    this.font = 'md',
    this.liveActivity = true,
    this.modelName = true,
    this.hideEmptySections = false,
  });
  final String font;
  final bool liveActivity, modelName, hideEmptySections;
  double get fontSize => font == 'sm'
      ? 12
      : font == 'lg'
      ? 16
      : 14;
  PersonalPresentation copyWith({
    String? font,
    bool? liveActivity,
    bool? modelName,
    bool? hideEmptySections,
  }) => PersonalPresentation(
    font: font ?? this.font,
    liveActivity: liveActivity ?? this.liveActivity,
    modelName: modelName ?? this.modelName,
    hideEmptySections: hideEmptySections ?? this.hideEmptySections,
  );
}

/// Local device choices, scoped to API origin and human account. No server,
/// directory rows, message payloads or credentials are stored in this record.
/// Source appearanceStore.ts: local choice wins best-effort profile font seed.
class PersonalPresentationStore extends ChangeNotifier {
  PersonalPresentationStore({
    SearchMemoryStorage? storage,
    this.desktop = false,
  }) : storage = storage ?? PreferencesSearchMemoryStorage() {
    value = const PersonalPresentation();
  }
  final SearchMemoryStorage storage;
  final bool desktop;
  late PersonalPresentation value;
  String? key;
  int revision = 0;
  bool ended = false, fontChosen = false;
  Future<void> writes = Future.value();
  String? scopeKey(String origin, String? principal) => principal == null
      ? null
      : 'raft:presentation:${jsonEncode([origin, principal])}';
  Future<void> bind(
    String origin,
    String? principal, {
    String? profileFont,
  }) async {
    final nextKey = scopeKey(origin, principal);
    if (nextKey == key) {
      if (!fontChosen && ['sm', 'md', 'lg'].contains(profileFont)) {
        fontChosen = true;
        value = value.copyWith(font: profileFont);
        notifyListeners();
        if (nextKey != null) persist(nextKey, value);
      }
      return;
    }
    key = nextKey;
    final ticket = ++revision;
    fontChosen = ['sm', 'md', 'lg'].contains(profileFont);
    value = PersonalPresentation(
      font: ['sm', 'md', 'lg'].contains(profileFont) ? profileFont! : 'md',
    );
    if (nextKey == null) {
      notifyListeners();
      return;
    }
    // Preloaded device preferences answer at once: the stored choice (font,
    // hidden empty sections, live activity) is in place before the first
    // frame instead of replacing the defaults one frame later.
    if (storage case final SynchronousSearchMemoryStorage sync
        when sync.ready) {
      _adopt(nextKey, sync.readSync(nextKey));
      persist(nextKey, value);
      return;
    }
    notifyListeners();
    String? encoded;
    try {
      encoded = await storage.read(nextKey);
    } catch (_) {
      /* optional local storage */
    }
    if (ended || revision != ticket || key != nextKey) return;
    _adopt(nextKey, encoded);
    persist(nextKey, value);
  }

  void _adopt(String nextKey, String? encoded) {
    try {
      final raw = encoded == null ? null : jsonDecode(encoded);
      if (raw is Map) {
        fontChosen = fontChosen || ['sm', 'md', 'lg'].contains(raw['font']);
        value = PersonalPresentation(
          font: ['sm', 'md', 'lg'].contains(raw['font'])
              ? raw['font'] as String
              : value.font,
          liveActivity: raw['liveActivity'] is bool
              ? raw['liveActivity']
              : true,
          modelName: raw['modelName'] is bool ? raw['modelName'] : true,
          hideEmptySections: raw['hideEmptySections'] is bool
              ? raw['hideEmptySections']
              : false,
        );
      }
    } catch (_) {
      /* corrupt device preferences use current safe defaults */
    }
    notifyListeners();
  }

  bool update(
    String? captured, {
    String? font,
    bool? liveActivity,
    bool? modelName,
    bool? hideEmptySections,
  }) {
    if (ended || captured == null || captured != key) return false;
    revision++;
    if (font != null) fontChosen = true;
    value = value.copyWith(
      font: font == null
          ? null
          : ['sm', 'md', 'lg'].contains(font)
          ? font
          : 'md',
      liveActivity: liveActivity,
      modelName: modelName,
      hideEmptySections: hideEmptySections,
    );
    notifyListeners();
    persist(captured, value);
    return true;
  }

  void persist(String captured, PersonalPresentation accepted) {
    final encoded = jsonEncode({
      'font': fontChosen ? accepted.font : null,
      'liveActivity': accepted.liveActivity,
      'modelName': accepted.modelName,
      'hideEmptySections': accepted.hideEmptySections,
    });
    writes = writes.then((_) async {
      try {
        await storage.write(captured, encoded);
      } catch (_) {
        /* keep responsive memory state */
      }
    });
  }

  @override
  void dispose() {
    ended = true;
    revision++;
    super.dispose();
  }
}

class PersonalPresentationScope
    extends InheritedNotifier<PersonalPresentationStore> {
  const PersonalPresentationScope({
    super.key,
    required PersonalPresentationStore store,
    required super.child,
  }) : super(notifier: store);
  static PersonalPresentationStore? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PersonalPresentationScope>()
      ?.notifier;
  static double bodyFontSize(BuildContext context, String? profileFont) =>
      maybeOf(context)?.value.fontSize ??
      (profileFont == 'sm'
          ? 12
          : profileFont == 'lg'
          ? 16
          : 14);
}
