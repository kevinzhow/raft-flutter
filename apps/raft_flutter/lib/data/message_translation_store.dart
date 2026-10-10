import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:raft_client/raft_client.dart';

import 'workspace_controller.dart';

/// raft-shared `SUPPORTED_TRANSLATION_LANGUAGES` (value → English label).
const messageTranslationLanguages = <String, String>{
  'en': 'English',
  'zh-cn': 'Simplified Chinese',
  'zh-tw': 'Traditional Chinese',
  'ja': 'Japanese',
  'ko': 'Korean',
  'es': 'Spanish',
  'fr': 'French',
  'de': 'German',
  'pt-br': 'Portuguese (Brazil)',
  'it': 'Italian',
};

/// raft-shared `normalizeTranslationLanguageCode`.
String? normalizeTranslationLanguage(String? language) {
  final normalized = language?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  const aliases = {'zh': 'zh-cn', 'zh-hans': 'zh-cn', 'zh-hant': 'zh-tw'};
  if (aliases[normalized] case final alias?) return alias;
  if (messageTranslationLanguages.containsKey(normalized)) return normalized;
  final base = normalized.split('-').first;
  return messageTranslationLanguages.containsKey(base) ? base : null;
}

enum MessageTranslationMode { auto, manual, off }

enum MessageTranslationDisplay { translated, original, bilingual }

enum MessageTranslationStatus { pending, translated, skipped, failed, notFound }

/// One cached translation (Web translationStore `TranslationEntry`). It is
/// current only for its [targetLanguage] and the [originalContent] it was
/// requested for, so an edit or a new target language reads as absent.
@immutable
class MessageTranslationEntry {
  const MessageTranslationEntry({
    required this.messageId,
    required this.status,
    this.reason,
    this.translatedContent,
    this.sourceLanguage,
    this.targetLanguage,
    this.originalContent,
    this.pendingBatch,
    this.showOriginal,
  });
  final String messageId;
  final MessageTranslationStatus status;
  final String? reason, translatedContent, sourceLanguage, targetLanguage;
  final String? originalContent;

  /// The request whose 30 s timeout fails this entry while still pending.
  final int? pendingBatch;
  final bool? showOriginal;

  bool get hasContent =>
      status == MessageTranslationStatus.translated &&
      (translatedContent?.trim().isNotEmpty ?? false);

  /// Web `shouldRenderTranslationIndicator`.
  bool get indicated =>
      hasContent ||
      status == MessageTranslationStatus.pending ||
      status == MessageTranslationStatus.failed;

  MessageTranslationEntry withShowOriginal(bool? value) =>
      MessageTranslationEntry(
        messageId: messageId,
        status: status,
        reason: reason,
        translatedContent: translatedContent,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        originalContent: originalContent,
        pendingBatch: pendingBatch,
        showOriginal: value,
      );

  MessageTranslationEntry timedOut() => MessageTranslationEntry(
    messageId: messageId,
    status: MessageTranslationStatus.failed,
    reason: 'provider_timeout',
    targetLanguage: targetLanguage,
    originalContent: originalContent,
    showOriginal: showOriginal,
  );
}

/// The viewer's translation preferences (`/auth/me`) joined with the
/// server's gate (`/servers/:id/translation-settings`).
@immutable
class MessageTranslationSettings {
  const MessageTranslationSettings({
    required this.preferredLanguage,
    required this.effectiveLanguage,
    required this.mode,
    required this.display,
    required this.serverEnabled,
    required this.providerAvailable,
    required this.canManage,
    required this.loaded,
  });
  final String? preferredLanguage;
  final String effectiveLanguage;
  final MessageTranslationMode mode;
  final MessageTranslationDisplay display;
  final bool serverEnabled, providerAvailable, canManage;

  /// Whether the server gate has been read for the current server.
  final bool loaded;
  bool get available => loaded && serverEnabled && providerAvailable;

  /// Web MessageItem `translationTargetLanguage`.
  String? get targetLanguage => available && mode != MessageTranslationMode.off
      ? effectiveLanguage
      : null;
}

/// Per-row projection of Web MessageItem's translation fields. Pure: built
/// from the cached entry and settings with a few map reads.
@immutable
class MessageTranslationPresentation {
  const MessageTranslationPresentation({
    this.entry,
    this.eligible = false,
    this.skeleton = false,
    this.needsRequest = false,
    this.manualAction = false,
    this.showingOriginal = false,
    this.translatedContent,
    this.bilingual = false,
  });
  static const none = MessageTranslationPresentation();

  /// The current entry for this row (`activeTranslationEntry`).
  final MessageTranslationEntry? entry;
  final bool eligible;

  /// Auto mode with no translation yet: the body is a one-line skeleton.
  final bool skeleton;

  /// Auto mode, nothing cached for this revision and target: request it.
  final bool needsRequest;

  /// Manual mode: the message menu offers Translate.
  final bool manualAction;
  final bool showingOriginal;
  final String? translatedContent;

  /// Bilingual view: the original renders below the translation.
  final bool bilingual;
  bool get manualPending => entry?.status == MessageTranslationStatus.pending;
  bool get indicated => entry?.indicated ?? false;
}

class _ServerGate {
  const _ServerGate({
    required this.enabled,
    required this.available,
    required this.canManage,
  });
  final bool enabled, available, canManage;
}

/// Web `useTranslationStore`, owned by [WorkspaceController.translations]: settings for the
/// selected server, the in-memory translation cache keyed by message id, and
/// the batched `/message-translations:batch` requests. Like Web the cache is
/// not persisted; it survives channel and server switches and is dropped
/// with the account.
class MessageTranslationStore extends ChangeNotifier {
  MessageTranslationStore(this.w) {
    _events = w.client.events.listen((event) {
      if (event.name == 'account:updated') {
        _adopt();
        notifyListeners();
      }
    });
  }

  /// Device languages, most preferred first (Web `navigator.languages`).
  @visibleForTesting
  static List<String> Function() deviceLanguages = () => [
    for (final locale in WidgetsBinding.instance.platformDispatcher.locales)
      locale.toLanguageTag(),
  ];

  /// Web `PENDING_TIMEOUT_MS` (+250 ms scheduling slack).
  static const pendingTimeout = Duration(milliseconds: 30250);

  /// Coalesces rows built in the same scroll burst into one batch.
  static const batchDelay = Duration(milliseconds: 120);
  static const maxBatch = 200;

  final WorkspaceController w;
  StreamSubscription<RaftEvent>? _events;
  Object? _identity;
  int _epoch = 0, _batch = 0;
  final _entries = <String, MessageTranslationEntry>{};
  final _servers = <String, _ServerGate>{};
  final _loading = <String>{}, _failedLoads = <String>{};
  final _inFlight = <String>{};
  final _timeouts = <int, Timer>{};
  final _queued = <String, RaftMessage>{};
  Timer? _flush;
  String? settingsError;

  /// Drops everything learned under another account.
  void _adopt() {
    final next = (w.client.origin, w.client.user?.id);
    if (_identity == next) return;
    _identity = next;
    _epoch++;
    _memo = null;
    _entries.clear();
    _servers.clear();
    _loading.clear();
    _failedLoads.clear();
    _inFlight.clear();
    _queued.clear();
    _flush?.cancel();
    for (final timer in _timeouts.values) {
      timer.cancel();
    }
    _timeouts.clear();
    settingsError = null;
  }

  String? get _serverId => w.server?.id;
  bool get settingsLoading => _loading.contains(_serverId);

  MessageTranslationSettings? _memo;
  Object? _memoUser, _memoGate;
  String? _device;
  bool _deviceRead = false;

  /// Settings are read for every row build: memoised on the identity of the
  /// accepted user record and server gate they derive from.
  MessageTranslationSettings get settings {
    _adopt();
    final user = w.client.user?.json ?? const {};
    final gate = _servers[_serverId];
    final memo = _memo;
    if (memo != null &&
        identical(user, _memoUser) &&
        identical(gate, _memoGate)) {
      return memo;
    }
    _memoUser = user;
    _memoGate = gate;
    return _memo = _settings(user, gate);
  }

  MessageTranslationSettings _settings(Map user, _ServerGate? gate) {
    final preferred = normalizeTranslationLanguage(
      (user['preferredLanguage'] ?? user['targetLanguage'])?.toString(),
    );
    String? device() {
      if (_deviceRead) return _device;
      _deviceRead = true;
      for (final tag in deviceLanguages()) {
        final normalized = normalizeTranslationLanguage(tag);
        if (normalized != null) return _device = normalized;
      }
      return null;
    }

    final mode = switch (user['preferredTranslationMode'] ??
        user['translationMode']) {
      'auto' => MessageTranslationMode.auto,
      'manual' => MessageTranslationMode.manual,
      'off' => MessageTranslationMode.off,
      _ => switch (user['autoTranslationEnabled']) {
        false => MessageTranslationMode.off,
        _ => MessageTranslationMode.auto,
      },
    };
    return MessageTranslationSettings(
      preferredLanguage: preferred,
      effectiveLanguage: preferred ?? device() ?? 'en',
      mode: mode,
      display: switch (user['preferredTranslationDisplay']) {
        'bilingual' => MessageTranslationDisplay.bilingual,
        'original' => MessageTranslationDisplay.original,
        _ => MessageTranslationDisplay.translated,
      },
      serverEnabled: gate?.enabled ?? false,
      providerAvailable: gate?.available ?? false,
      canManage: gate?.canManage ?? false,
      loaded: gate != null,
    );
  }

  /// Web `loadSettings(serverId)`: once per server. Failures other than
  /// 404/501 are retried only on [force].
  void ensureSettings({bool force = false}) {
    _adopt();
    final id = _serverId;
    if (_disposed || id == null || _loading.contains(id)) return;
    final gate = _servers[id];
    // Web loads once per server id; a role change keeps the accepted gate.
    if (gate != null && !force) return;
    if (gate == null && _failedLoads.contains(id) && !force) return;
    _loading.add(id);
    _failedLoads.remove(id);
    settingsError = null;
    final epoch = _epoch, generation = w.client.generation;
    if (force) notifyListeners();
    unawaited(() async {
      try {
        final data = await w.client.get('/servers/$id/translation-settings');
        if (epoch != _epoch) return;
        _servers[id] = _gate(data);
      } on RaftApiException catch (e) {
        if (epoch != _epoch) return;
        if (e.status == 404 || e.status == 501) {
          _servers[id] = _ServerGate(
            enabled: false,
            available: false,
            canManage: false,
          );
        } else if (generation == w.client.generation) {
          _failedLoads.add(id);
          settingsError = e.message;
        }
      } catch (e) {
        if (epoch != _epoch) return;
        if (generation == w.client.generation) {
          _failedLoads.add(id);
          settingsError = '$e';
        }
      } finally {
        if (epoch == _epoch) {
          _loading.remove(id);
          notifyListeners();
        }
      }
    }());
  }

  _ServerGate _gate(Object? data) {
    final map = data is Map ? data : const {};
    return _ServerGate(
      enabled: map['translationEnabled'] == true,
      available:
          (map['translationAvailable'] ?? map['available'] ?? true) == true,
      canManage: map['canManageTranslation'] == true,
    );
  }

  /// Web `updateServerTranslationEnabled`: the admin toggle's accepted
  /// response becomes the gate at once.
  void adoptServerSettings(Object? response) {
    _adopt();
    final id = _serverId;
    if (id == null || response is! Map) return;
    _servers[id] = _gate(response);
    notifyListeners();
  }

  /// Web MessageItem's derived translation fields for [message].
  MessageTranslationPresentation present(RaftMessage message) {
    final s = settings;
    final target = s.targetLanguage;
    if (target == null || !_translatable(message)) {
      return MessageTranslationPresentation.none;
    }
    final own =
        message.string('senderType') == 'user' &&
        message.senderId == w.client.user?.id;
    if (s.mode != MessageTranslationMode.manual && own) {
      return MessageTranslationPresentation.none;
    }
    final raw = _entries[message.id];
    final entry =
        raw != null &&
            raw.targetLanguage == target &&
            (raw.originalContent == null ||
                raw.originalContent == message.content)
        ? raw
        : null;
    final hasContent = entry?.hasContent ?? false;
    final display = switch (entry?.showOriginal) {
      true => MessageTranslationDisplay.original,
      false when s.display == MessageTranslationDisplay.original =>
        MessageTranslationDisplay.translated,
      _ => s.display,
    };
    final showingOriginal = display == MessageTranslationDisplay.original;
    final auto = s.mode == MessageTranslationMode.auto;
    final translated = hasContent && !showingOriginal
        ? entry!.translatedContent
        : null;
    return MessageTranslationPresentation(
      entry: entry,
      eligible: true,
      skeleton:
          auto &&
          !showingOriginal &&
          (entry == null || entry.status == MessageTranslationStatus.pending),
      needsRequest: auto && entry == null,
      manualAction:
          s.mode == MessageTranslationMode.manual &&
          message.content.trim().isNotEmpty &&
          !hasContent &&
          entry?.status != MessageTranslationStatus.failed,
      showingOriginal: showingOriginal,
      translatedContent: translated,
      bilingual:
          translated != null &&
          display == MessageTranslationDisplay.bilingual &&
          message.content.isNotEmpty,
    );
  }

  /// System rows, optimistic sends and rows whose body is a structured card
  /// (action card, forwarded bundle) have no translatable body.
  bool _translatable(RaftMessage message) {
    if (message.string('messageType') == 'system') return false;
    if (WorkspaceController.isPendingSend(message)) return false;
    final metadata = message.json['actionMetadata'];
    return metadata is! Map ||
        !const {'action-card', 'forwarded-bundle'}.contains(metadata['kind']);
  }

  /// Auto mode: queue a row that entered the timeline's built window. Rows
  /// built in the same burst share one batch (Web requests the visible
  /// window on scroll; already-cached and in-flight ids are skipped).
  void want(RaftMessage message) {
    if (_disposed || _queued.containsKey(message.id)) return;
    _queued[message.id] = message;
    _flush ??= Timer(batchDelay, _flushQueued);
  }

  void _flushQueued() {
    _flush = null;
    if (_queued.isEmpty) return;
    final batch = _queued.values.toList();
    _queued.clear();
    if (settings.mode != MessageTranslationMode.auto) return;
    unawaited(requestTranslations(batch));
  }

  /// Manual "Translate" (Web `handleManualTranslate`) and failed-row Retry
  /// (Web `retryMessage`): a forced single-message request.
  Future<void> translate(RaftMessage message) =>
      requestTranslations([message], force: true);

  /// Web `setShowOriginal`.
  void setShowOriginal(String messageId, bool showOriginal) {
    final entry = _entries[messageId];
    if (entry == null) return;
    _entries[messageId] = entry.withShowOriginal(showOriginal);
    notifyListeners();
  }

  /// Web translationStore `requestTranslations`.
  Future<void> requestTranslations(
    List<RaftMessage> messages, {
    bool force = false,
  }) async {
    final target = settings.targetLanguage;
    if (target == null) return;
    final viewer = w.client.user?.id;
    final candidates = <RaftMessage>[];
    final seen = <String>{};
    for (final message in messages) {
      if (!seen.add(message.id) || !_translatable(message)) continue;
      if (!force &&
          message.string('senderType') == 'user' &&
          viewer != null &&
          message.senderId == viewer) {
        continue;
      }
      final existing = _entries[message.id];
      final request =
          existing == null ||
          (existing.originalContent != null &&
              existing.originalContent != message.content) ||
          existing.targetLanguage != target ||
          (existing.status != MessageTranslationStatus.pending && force);
      if (request) candidates.add(message);
    }
    if (candidates.isEmpty) return;
    final batch = candidates.take(maxBatch).toList();
    final ids = [for (final m in batch) m.id];
    final key =
        '$target:${([...ids]..sort()).join(',')}:${force ? 'force' : 'normal'}';
    if (_disposed || !_inFlight.add(key)) return;
    final serial = ++_batch, epoch = _epoch;
    final generation = w.client.generation;
    final original = {for (final m in batch) m.id: m.content};
    for (final m in batch) {
      _entries[m.id] = MessageTranslationEntry(
        messageId: m.id,
        status: MessageTranslationStatus.pending,
        targetLanguage: target,
        originalContent: m.content,
        pendingBatch: serial,
        showOriginal: force ? false : null,
      );
    }
    _timeouts[serial] = Timer(pendingTimeout, () => _timeout(serial, ids));
    notifyListeners();
    if (candidates.length > batch.length) {
      // Web sends the first 200; the rest wait for the next window report.
      for (final m in candidates.skip(maxBatch)) {
        want(m);
      }
    }
    try {
      final data = await w.client.post(
        '/message-translations:batch',
        data: {
          'messageIds': ids,
          'targetLanguage': target,
          'mode': force ? 'manual' : 'auto',
        },
      );
      if (epoch != _epoch) return;
      final map = data is Map ? data : const {};
      final raw =
          (map['results'] ?? map['translations'] ?? map['items'] ?? [])
              as Object?;
      final results = raw is List ? raw.whereType<Map>() : const <Map>[];
      final answered = <String>{};
      for (final result in results) {
        if (result['messageId'] == null) continue;
        final id = '${result['messageId']}';
        answered.add(id);
        final previous = _entries[id];
        final entry = _entry(result, original[id], previous?.showOriginal);
        _entries[id] = entry.status == MessageTranslationStatus.pending
            ? MessageTranslationEntry(
                messageId: id,
                status: entry.status,
                reason: entry.reason,
                targetLanguage: entry.targetLanguage,
                originalContent: entry.originalContent,
                pendingBatch: previous?.pendingBatch ?? serial,
              )
            : entry;
      }
      for (final id in ids) {
        if (answered.contains(id)) continue;
        _entries[id] = MessageTranslationEntry(
          messageId: id,
          status: MessageTranslationStatus.notFound,
          reason: 'not_found',
          targetLanguage: target,
          originalContent: original[id],
        );
      }
    } on RaftApiException catch (e) {
      if (epoch != _epoch) return;
      _fail(ids, original, target, generation, unavailable: e.status);
    } catch (_) {
      if (epoch != _epoch) return;
      _fail(ids, original, target, generation);
    } finally {
      if (epoch == _epoch) {
        _inFlight.remove(key);
        if (!ids.any((id) => _entries[id]?.pendingBatch == serial)) {
          _timeouts.remove(serial)?.cancel();
        }
        notifyListeners();
      }
    }
  }

  void _fail(
    List<String> ids,
    Map<String, String> original,
    String target,
    int generation, {
    int? unavailable,
  }) {
    if (unavailable == 404 || unavailable == 501) {
      // Web: the API is not mounted here; forget the rows and hide the UI.
      ids.forEach(_entries.remove);
      final id = _serverId;
      if (id != null) {
        _servers[id] = _ServerGate(
          enabled: _servers[id]?.enabled ?? false,
          available: false,
          canManage: _servers[id]?.canManage ?? false,
        );
      }
      return;
    }
    if (generation != w.client.generation) {
      // The request was retired by a workspace switch, not answered: leave
      // the rows uncached so the next visit asks again.
      ids.forEach(_entries.remove);
      return;
    }
    for (final id in ids) {
      _entries[id] = MessageTranslationEntry(
        messageId: id,
        status: MessageTranslationStatus.failed,
        reason: 'provider',
        targetLanguage: target,
        originalContent: original[id],
      );
    }
  }

  void _timeout(int serial, List<String> ids) {
    _timeouts.remove(serial);
    var changed = false;
    for (final id in ids) {
      final entry = _entries[id];
      if (entry?.status != MessageTranslationStatus.pending ||
          entry?.pendingBatch != serial) {
        continue;
      }
      _entries[id] = entry!.timedOut();
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Web `normalizeEntry`.
  MessageTranslationEntry _entry(
    Map raw,
    String? originalContent,
    bool? showOriginal,
  ) {
    var reason =
        raw['quotaReason'] ??
        raw['skipReason'] ??
        raw['failureReason'] ??
        raw['reason'];
    if (reason == 'provider_failed') reason = 'provider';
    if (reason == 'placeholder_mismatch') reason = 'placeholder';
    final entry = MessageTranslationEntry(
      messageId: '${raw['messageId']}',
      status: switch (raw['status']) {
        'pending' => MessageTranslationStatus.pending,
        'translated' => MessageTranslationStatus.translated,
        'skipped' => MessageTranslationStatus.skipped,
        'failed' => MessageTranslationStatus.failed,
        _ => MessageTranslationStatus.notFound,
      },
      reason: reason?.toString(),
      translatedContent: (raw['translatedContent'] ?? raw['translation'])
          ?.toString(),
      sourceLanguage: (raw['sourceLanguage'] ?? raw['sourceLang'])?.toString(),
      targetLanguage: (raw['targetLanguage'] ?? raw['targetLang'])?.toString(),
      originalContent: originalContent,
    );
    return showOriginal != null && entry.hasContent
        ? entry.withShowOriginal(showOriginal)
        : entry;
  }

  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _events?.cancel();
    _flush?.cancel();
    for (final timer in _timeouts.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
