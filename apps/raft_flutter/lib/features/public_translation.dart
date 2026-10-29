// Message translation on the Public server page (Web PublicServerPage.tsx
// `useTranslationBatch(..., {skipSettingsLoad: true})` and translationStore
// `publicServerProjection`): the server's gate comes with the public readback,
// requests go to `POST /public/servers/:slug/message-translations:batch`, and
// a signed-out visitor keeps the preferences in the browser
// (`raft:public-translation-preferences:v1`) instead of the account.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/message_translation_store.dart';
import '../data/workspace_cache.dart';

/// Web `PUBLIC_TRANSLATION_PREFERENCES_KEY`.
const publicTranslationPreferencesKey =
    'raft:public-translation-preferences:v1';

/// The preference fields a signed-out visitor keeps locally (Web
/// `writePublicTranslationPreferences`).
const publicTranslationPreferenceFields = [
  'preferredLanguage',
  'preferredTimezone',
  'preferredTranslationMode',
  'preferredTranslationDisplay',
  'preferredTimeFormat',
];

/// A signed-out visitor's translation preferences, kept on this device.
class PublicLocalPreferences extends ChangeNotifier {
  /// The record the translation store reads; replaced (never mutated) on a
  /// change so its memo can follow identity.
  Map<String, dynamic> json = const {};
  bool _disposed = false;

  Future<void> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        publicTranslationPreferencesKey,
      );
      final parsed = raw == null ? null : jsonDecode(raw);
      if (_disposed) return;
      if (parsed is Map) {
        json = {
          for (final key in publicTranslationPreferenceFields)
            if (parsed.containsKey(key)) key: parsed[key],
        };
        notifyListeners();
      }
    } catch (_) {
      // Unreadable: the defaults.
    }
  }

  /// Merges [fields] and saves; a null value clears the preference.
  Future<void> update(Map<String, Object?> fields) async {
    json = {...json, ...fields};
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(
        publicTranslationPreferencesKey,
        jsonEncode({
          for (final key in publicTranslationPreferenceFields) key: json[key],
        }),
      );
    } catch (_) {
      // Not saved: the choice still holds for this visit.
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The session facts the translation store needs when there is no workspace:
/// a visitor reading a public server owns nothing on the device.
class PublicTranslationAuthority implements MessageTranslationAuthority {
  PublicTranslationAuthority(this.client);
  @override
  final RaftClient client;
  @override
  RaftRecord? get server => null;
  @override
  WorkspaceCache? get cache => null;
  @override
  Future<List<Map<String, dynamic>>> readDeviceTranslations(
    String serverId,
  ) async => const [];
  @override
  void writeDeviceTranslations(
    String serverId,
    List<Map<String, dynamic>> entries,
  ) {}
  @override
  Future<dynamic> readTranslationGate(String serverId) async => null;
  @override
  void saveTranslationGate(String serverId, Map<String, dynamic>? gate) {}
}

/// Web `getPublicPersonalSettingsTabIds`: which personal Settings tabs a
/// public-page visitor gets. Language & Region only where the server offers
/// translation.
List<String> publicPersonalSettingsTabs({
  required bool authenticated,
  required bool translationEnabled,
}) => [
  if (authenticated) 'account',
  if (translationEnabled) 'language-region',
  'appearance',
];

/// Web MessageItem `TranslationIndicator` for [message]: the status line
/// under a translated message, or null.
Widget? publicTranslationStatus(
  BuildContext context,
  MessageTranslationStore store,
  RaftMessage message,
  MessageTranslationPresentation translation,
) {
  final entry = translation.entry;
  if (entry == null || !entry.indicated) return null;
  final RaftMessageTranslationStatus status;
  if (entry.hasContent) {
    final original = translation.showingOriginal;
    status = RaftMessageTranslationStatus(
      tone: RaftMessageTranslationTone.normal,
      actionLabel: raftText(
        context,
        original ? 'Show Translation' : 'Show Original',
      ),
      tooltip: raftText(
        context,
        original
            ? 'Original shown. Show translation'
            : 'Translated. Show original',
      ),
      onAction: () => store.setShowOriginal(message.id, !original),
    );
  } else if (entry.status == MessageTranslationStatus.pending) {
    status = RaftMessageTranslationStatus(
      tone: RaftMessageTranslationTone.pending,
      message: raftText(context, 'Translating…'),
      tooltip: raftText(context, 'Translating'),
    );
  } else {
    final unavailable = raftText(context, 'Translation unavailable');
    status = RaftMessageTranslationStatus(
      tone: RaftMessageTranslationTone.failed,
      message: unavailable,
      actionLabel: raftText(context, 'Retry'),
      tooltip: unavailable,
      onAction: () => unawaited(store.translate(message)),
    );
  }
  return KeyedSubtree(
    key: ValueKey('message-translation-indicator-${message.id}'),
    child: status,
  );
}
