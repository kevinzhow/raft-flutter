import 'dart:async';

import 'package:flutter/foundation.dart';

/// One page of an account-level announcement (`AnnouncementPage`).
@immutable
class AnnouncementPageData {
  const AnnouncementPageData({this.title, required this.body});
  final String? title;
  final String body;
}

/// `Announcement.cta`: the primary action beside "Got it". [href] is an
/// internal path or query (`/...`, `?...`) or an https URL.
@immutable
class AnnouncementCta {
  const AnnouncementCta({required this.label, required this.href});
  final String label, href;

  /// Web `activate`: a leading `/` or `?` navigates inside the app, anything
  /// else opens in a new browsing context.
  bool get internal => href.startsWith('/') || href.startsWith('?');
}

/// `Announcement.image`: a picture served by `GET /announcements/images/:id`
/// (public, no credentials) with its localized alt text.
@immutable
class AnnouncementImage {
  const AnnouncementImage({required this.assetId, required this.alt});
  final String assetId, alt;
}

/// Web `Announcement` (packages/shared): an account-level popup, shown until
/// the user dismisses it (OK, CTA or close); a new announcement is a new id.
@immutable
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.pages,
    this.label,
    this.cta,
    this.image,
    this.publishedAt,
    this.startsAt,
    this.endsAt,
    this.locale,
    this.deliveryVersion,
    this.deliveryServerId,
  });

  final String id, title;

  /// Eyebrow of the dialog; null reads "Latest updates".
  final String? label;
  final AnnouncementCta? cta;
  final AnnouncementImage? image;

  /// Empty pages are the server's "clear" signal: nothing is presented. Only
  /// the first page is shown.
  final List<AnnouncementPageData> pages;
  final String? publishedAt, startsAt, endsAt, locale;

  /// Additive `deliveryVersion` (omitted by older servers: version 1).
  final int? deliveryVersion;

  /// `deliveryScope: { type: 'server', serverId }`: the one server this row
  /// is delivered for. Null is the account scope (also the omitted legacy
  /// value).
  final String? deliveryServerId;

  static Announcement? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    final pages = <AnnouncementPageData>[
      if (raw['pages'] is List)
        for (final page in raw['pages'] as List)
          if (page is Map && page['body'] is String)
            AnnouncementPageData(
              title: page['title'] is String ? page['title'] as String : null,
              body: page['body'] as String,
            ),
    ];
    String? text(String key) => raw[key] is String ? raw[key] as String : null;
    final label = text('label')?.trim();
    final cta = raw['cta'];
    final image = raw['image'];
    final scope = raw['deliveryScope'];
    return Announcement(
      id: id,
      title: text('title') ?? '',
      pages: pages,
      label: label == null || label.isEmpty ? null : label,
      cta:
          cta is Map &&
              cta['label'] is String &&
              (cta['label'] as String).trim().isNotEmpty &&
              cta['href'] is String &&
              (cta['href'] as String).trim().isNotEmpty
          ? AnnouncementCta(
              label: (cta['label'] as String).trim(),
              href: (cta['href'] as String).trim(),
            )
          : null,
      image:
          image is Map && image['assetId'] is String && image['alt'] is String
          ? AnnouncementImage(
              assetId: image['assetId'] as String,
              alt: image['alt'] as String,
            )
          : null,
      publishedAt: text('publishedAt'),
      startsAt: text('startsAt'),
      endsAt: text('endsAt'),
      locale: text('locale'),
      deliveryVersion: raw['deliveryVersion'] is int
          ? raw['deliveryVersion'] as int
          : null,
      deliveryServerId:
          scope is Map &&
              scope['type'] == 'server' &&
              scope['serverId'] is String
          ? scope['serverId'] as String
          : null,
    );
  }
}

typedef AnnouncementGet = Future<dynamic> Function(
  String path, {
  Map<String, dynamic>? query,
});
typedef AnnouncementPost = Future<dynamic> Function(
  String path, {
  Map<String, dynamic>? query,
});

/// Web `useAnnouncementStore` (packages/web/src/store/announcementStore.ts).
///
/// * [load] reads `GET /announcements/active` (the server's OLDEST row this
///   user has not finished reading) on workspace entry and on return to the
///   foreground. It never runs while a row is presented ([pending] non-empty)
///   and shares one in-flight request; a publish event does not trigger it.
/// * [close] only hides the row locally. Web v1.21.12 no longer uses it for
///   the dialog: ✕, Escape, the scrim, "Got it", the CTA and Enter all
///   [dismiss].
/// * [dismiss] hides the row and records `POST /announcements/:id/dismiss`
///   (closing counts as read since v1.21.12). A failed write
///   lands in [writeFailedIds] (memory only): later loads of the same context
///   skip past it with `?after=<last failed id of that context>` for the rest
///   of this session, and the presentation raises an error notice.
///
/// Since Web v1.21.23 both calls carry `server_id=<current server>` whenever
/// a server is selected: the server delivers a server-targeted announcement
/// only with it. A switch of server fences the previous server's response,
/// drops the previous server's rows from [pending] and re-reads.
///
/// Account scoped: [reset] (account change / sign-out) drops everything and
/// fences responses of the previous account.
class AnnouncementStore extends ChangeNotifier {
  AnnouncementStore({
    required this.get,
    required this.post,
    required this.principal,
    this.serverId,
  }) : _principal = principal();

  final AnnouncementGet get;
  final AnnouncementPost post;

  /// The signed-in account; a change resets the store like the Web
  /// authStore does when `user.id` changes.
  final String? Function() principal;
  String? _principal;

  /// The selected server (Web `useServerStore.current?.id`); null reads the
  /// account context and sends no `server_id`.
  final String? Function()? serverId;
  String? _contextKey;
  bool _contextSynced = false;

  /// Failure frontiers per context (`account` or a server id): the last id is
  /// the request-only `after` cursor of that context's queue.
  final Map<String, List<String>> _failedByContext = {};

  /// Bumped only by [reset] (Web `announcementAccountGeneration`): a write
  /// that fails after an account change records nothing.
  int _accountGeneration = 0;

  List<Announcement> pending = const [];
  bool loaded = false;

  /// Ids reported read-complete this session (idempotence of [markRead]).
  List<String> markedReadIds = const [];

  /// Ids whose read-complete write failed this session (never persisted).
  List<String> writeFailedIds = const [];

  Future<void>? _inFlight;
  int _generation = 0;
  bool _disposed = false;

  /// The row the modal presents, if any.
  Announcement? get current => pending.isEmpty ? null : pending.first;

  void _syncPrincipal() {
    final next = principal();
    if (next == _principal) return;
    _principal = next;
    reset();
  }

  String _context() => serverId?.call() ?? 'account';

  /// The queue was last read (or never read) for another context than the
  /// selected server.
  bool get needsReload => !_contextSynced || _contextKey != _context();

  /// Web `syncContext`: a changed context retires the in-flight read and
  /// drops rows delivered for another server.
  void _syncContext() {
    final next = _context();
    if (_contextSynced && _contextKey == next) return;
    final first = !_contextSynced;
    _contextSynced = true;
    _contextKey = next;
    if (first) return;
    _generation++;
    _inFlight = null;
    pending = [
      for (final a in pending)
        if (a.deliveryServerId == null || a.deliveryServerId == next) a,
    ];
    loaded = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> load() {
    if (_disposed) return Future.value();
    _syncPrincipal();
    _syncContext();
    // A presented row is owned by this presentation until the user closes
    // it; another device's dismissal must not pull it away.
    if (pending.isNotEmpty) return Future.value();
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final generation = _generation;
    final requestContext = _context();
    final completer = Completer<void>();
    _inFlight = completer.future;
    () async {
      try {
        final skipped = _failedByContext[requestContext] ?? const <String>[];
        final after = skipped.isEmpty ? null : skipped.last;
        final data = await get(
          '/announcements/active',
          query: after == null && requestContext == 'account'
              ? null
              : {
                  'after': ?after,
                  if (requestContext != 'account') 'server_id': requestContext,
                },
        );
        if (_disposed || generation != _generation) return;
        final rows = data is Map && data['announcements'] is List
            ? [
                for (final raw in data['announcements'] as List)
                  ?Announcement.fromJson(raw),
              ]
            : const <Announcement>[];
        loaded = true;
        // A row presented while this request was in flight wins over a late
        // (especially empty) response.
        if (pending.isEmpty) {
          final hidden = {
            ...(_failedByContext[requestContext] ?? const <String>[]),
            ...markedReadIds,
          };
          pending = [
            for (final row in rows)
              if (!hidden.contains(row.id)) row,
          ];
        }
        notifyListeners();
      } catch (error) {
        if (_disposed || generation != _generation) return;
        debugPrint('Failed to load announcements: $error');
        loaded = true;
        notifyListeners();
      } finally {
        if (identical(_inFlight, completer.future)) _inFlight = null;
        completer.complete();
      }
    }();
    return completer.future;
  }

  /// Records explicit confirmation, closing or CTA activation. Rendering
  /// alone never does.
  Future<void> markRead(String id) async {
    if (_disposed || markedReadIds.contains(id)) return;
    final writeContext = _context();
    final accountGeneration = _accountGeneration;
    markedReadIds = [...markedReadIds, id];
    try {
      await post(
        '/announcements/$id/dismiss',
        query: writeContext == 'account' ? null : {'server_id': writeContext},
      );
    } catch (error) {
      if (_disposed || accountGeneration != _accountGeneration) return;
      final failed = _failedByContext[writeContext] ?? const <String>[];
      if (!failed.contains(id)) {
        _failedByContext[writeContext] = [...failed, id];
      }
      debugPrint('Failed to record announcement as read: $error');
      markedReadIds = [
        for (final marked in markedReadIds)
          if (marked != id) marked,
      ];
      if (!writeFailedIds.contains(id)) {
        writeFailedIds = [...writeFailedIds, id];
      }
      notifyListeners();
    }
  }

  /// Local visibility only.
  void close(String id) {
    if (_disposed || !pending.any((a) => a.id == id)) return;
    pending = [
      for (final a in pending)
        if (a.id != id) a,
    ];
    notifyListeners();
  }

  /// Account dismissal + local hide, shared by every dismissal action.
  Future<void> dismiss(String id) {
    close(id);
    return markRead(id);
  }

  void reset() {
    _generation++;
    _accountGeneration++;
    _inFlight = null;
    _failedByContext.clear();
    _contextSynced = false;
    _contextKey = null;
    final changed =
        pending.isNotEmpty ||
        loaded ||
        markedReadIds.isNotEmpty ||
        writeFailedIds.isNotEmpty;
    pending = const [];
    loaded = false;
    markedReadIds = const [];
    writeFailedIds = const [];
    if (changed && !_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

/// Web `OnboardingAnnouncementGateState`.
enum AnnouncementGateState { pending, blocked, ready }

/// Web `useOnboardingAnnouncementGateStore`: whether the current server's
/// setup projection allows an announcement over it.
///
/// Suppressed while the gate reading is not `ready`, and for the rest of the
/// session on any server whose onboarding was seen in progress (`blocked`):
/// a user who just finished setup meets the announcement on the NEXT entry.
///
/// The reading comes from the setup projection (`ServerSetupGate` reports
/// every accepted read). Native mounts that gate around conversation
/// content only, so [attach] counts mounted gates per server and the host
/// reads the projection itself when none is mounted.
class AnnouncementOnboardingGate extends ChangeNotifier {
  final Map<String, AnnouncementGateState> byServerId = {};
  final Set<String> sawOnboardingServerIds = {};
  final Map<String, int> _attached = {};

  /// Setup gates unmount after the account session (and this gate) is
  /// torn down; their late detach / reports are dropped.
  bool _disposed = false;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// Web `ServerSetupProjectionGate` announcementGateState for a resolved
  /// read: no projection (first read failed) → blocked; `phase: null` →
  /// ready; anything short of complete with the survey and handoff done →
  /// blocked.
  static AnnouncementGateState fromProjection(Map<String, dynamic>? p) {
    if (p == null) return AnnouncementGateState.blocked;
    if (p['phase'] == null) return AnnouncementGateState.ready;
    final post = p['postSetup'] is Map ? p['postSetup'] as Map : const {};
    if (p['phase'] != 'complete' ||
        post['surveyPending'] == true ||
        post['handoffPending'] == true) {
      return AnnouncementGateState.blocked;
    }
    return AnnouncementGateState.ready;
  }

  AnnouncementGateState stateFor(String serverId) =>
      byServerId[serverId] ?? AnnouncementGateState.pending;

  /// Web `shouldSuppressAnnouncements` for [serverId] (no server: pending).
  bool suppressed(String? serverId) =>
      serverId == null ||
      stateFor(serverId) != AnnouncementGateState.ready ||
      sawOnboardingServerIds.contains(serverId);

  void setForServer(String serverId, AnnouncementGateState state) {
    // Only `blocked` is evidence of onboarding; every server passes through
    // `pending`.
    final saw =
        state == AnnouncementGateState.blocked &&
        sawOnboardingServerIds.add(serverId);
    if (_disposed || (byServerId[serverId] == state && !saw)) return;
    byServerId[serverId] = state;
    _changed();
  }

  void report(String serverId, Map<String, dynamic>? projection) =>
      setForServer(serverId, fromProjection(projection));

  /// The live reading goes; the session memory of onboarding stays.
  void clearForServer(String serverId) {
    if (byServerId.remove(serverId) != null) _changed();
  }

  void attach(String serverId) =>
      _attached[serverId] = (_attached[serverId] ?? 0) + 1;

  void detach(String serverId) {
    final count = (_attached[serverId] ?? 1) - 1;
    if (count <= 0) {
      _attached.remove(serverId);
    } else {
      _attached[serverId] = count;
    }
    _changed();
  }

  bool hasGate(String serverId) => (_attached[serverId] ?? 0) > 0;

  void reset() {
    byServerId.clear();
    sawOnboardingServerIds.clear();
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
