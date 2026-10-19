import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart' show SchedulerPhase;
import 'package:raft_client/raft_client.dart';
import 'package:raft_client/system_proxy.dart' show SystemProxy;
import 'package:raft_updater/raft_updater.dart' show AppUpdater;
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'platform/cache_hygiene.dart' show purgeAccountCaches;
import 'data/device_preferences.dart';
import 'data/workspace_controller.dart';
import 'data/user_error.dart';
import 'data/workspace_cache.dart';
import 'data/raft_location.dart';
import 'data/shared_draft_attachment.dart';
import 'data/incoming_share_targets.dart';
import 'features/incoming_share_picker.dart';
import 'features/incoming_share_review.dart';
import 'data/raft_navigation_history.dart';
import 'features/app_root_router.dart';
import 'features/community_join.dart';
import 'features/invite_accept_view.dart';
import 'features/global_server_selector.dart';
import 'features/public_server_view.dart';
import 'features/workspace_view.dart';
import 'features/auth_view.dart';
import 'features/session_recovery_view.dart';
import 'features/account_onboarding.dart';
import 'features/private_route_guard.dart';
import 'features/root_error_boundary.dart';
import 'platform/auth_audit_log.dart';
import 'platform/memory_release.dart';
import 'platform/session_store.dart';
import 'platform/keyboard_inset_guard.dart';
import 'platform/launch_theme.dart';
import 'platform/linux_uri_scheme.dart';
import 'platform/session_persistence.dart';
import 'platform/attachment_http.dart';
import 'platform/native_sharing.dart';
import 'platform/ios_share_session.dart';
import 'platform/incoming_share_staging.dart';
import 'platform/content_coordinator.dart';
import 'platform/workspace_cache.dart';
import 'platform/desktop_title_bar.dart';
import 'platform/system_bars.dart';
import 'platform/system_fonts.dart';
import 'platform/app_update.dart';
import 'platform/app_services.dart';
import 'platform/app_window.dart';
import 'platform/app_update_smoke.dart';
import 'platform/background_notifications.dart';
import 'platform/cache_exit.dart';

final raftScreenshotKey = GlobalKey();

/// Creates the owned application services after native bootstrap is ready.
void runRaftAppRoot(List<String> args) {
  // Release builds show the root fallback instead of a grey/red screen.
  RootErrors.instance.install();
  // The branded splash stays until startup is ready; a fatal startup error
  // releases the first frame too, so the root fallback can paint.
  WidgetsBinding.instance.deferFirstFrame();
  var firstFrameAllowed = false;
  void allowFirstFrame() {
    if (firstFrameAllowed) return;
    firstFrameAllowed = true;
    WidgetsBinding.instance.allowFirstFrame();
  }

  void releaseOnError() {
    if (RootErrors.instance.current != null) allowFirstFrame();
  }

  RootErrors.instance.addListener(releaseOnError);
  // Release builds only: dev/local builds and platforms without a GitHub
  // release asset get a disabled service. Starts after the first frame.
  final updateOrigin = updateOriginOverride();
  final appUpdate = AppUpdateService.forThisBuild(origin: updateOrigin);
  // Linux AppImage in-place updates use the app's proxy-aware HTTP client.
  AppUpdater.instance.configureAppImage(
    httpClientFactory: (url) async {
      await SystemProxy.instance.ready(url);
      return SystemProxy.instance.createHttpClient();
    },
    origin: updateOrigin,
  );
  runApp(
    RootErrorBoundary(
      child: RaftApp(
        initialArguments: args,
        onStartupReady: allowFirstFrame,
        services: AppServices.withUpdates(appUpdate),
        ownsAppUpdate: true,
      ),
    ),
  );
  unawaited(
    WidgetsBinding.instance.waitUntilFirstFrameRasterized.then((_) async {
      await appUpdate.start();
      await runAppImageUpdateSmoke(
        appUpdate,
        AppUpdater.instance,
        origin: updateOrigin,
      );
    }),
  );
}

/// The server stores only locales shipped by the UI. Translation language is separate.
Locale displayLocale(String? preference, {Locale? device}) {
  final language = preference?.toLowerCase().replaceAll('_', '-');
  if (language == 'zh-cn' || language == 'zh-hans') {
    return const Locale('zh', 'CN');
  }
  if (language == 'en' || language?.startsWith('en-') == true) {
    return const Locale('en');
  }
  final resolved = device ?? WidgetsBinding.instance.platformDispatcher.locale;
  return resolved.languageCode == 'zh' &&
          (resolved.countryCode == 'CN' ||
              resolved.scriptCode == 'Hans' ||
              resolved.countryCode == null)
      ? const Locale('zh', 'CN')
      : const Locale('en');
}

class RaftApp extends StatefulWidget {
  const RaftApp({
    super.key,
    this.sessionStore,
    this.initialArguments = const [],
    this.initialLocation,
    this.createClient,
    this.openWorkspaceCache,
    this.nativeContent,
    this.nativeSharing,
    this.nativeSessionOwner,
    this.onStartupReady,
    required this.services,
    this.ownsAppUpdate = false,
  });

  /// Explicit service capability; tests/previews must declare disabled updates.
  final AppServices services;
  final bool ownsAppUpdate;
  final List<String> initialArguments;
  final SessionStore? sessionStore;
  final Uri? initialLocation;
  final RaftClient Function(String origin, SessionStore store, String kind)?
  createClient;
  final Future<WorkspaceCache?> Function()? openWorkspaceCache;
  final NativeContentCoordinator? nativeContent;
  final NativeSharing? nativeSharing;
  final NativeSessionOwner? nativeSessionOwner;
  final VoidCallback? onStartupReady;
  @override
  State<RaftApp> createState() => _RaftAppState();
}

class _RaftAppState extends State<RaftApp> with WidgetsBindingObserver {
  late final content = widget.nativeContent ?? NativeContentCoordinator();
  late final sharing = widget.nativeSharing ?? NativeSharing();
  late final shareSession = IOSShareSession(channel: sharing.channel);
  VoidCallback? removeShareReceiver;
  final pendingShares = <IncomingShareStaging>[];
  bool sharePickerOpen = false, shareDrainScheduled = false;
  int shareEpoch = 0;
  late final RaftAppRouter appRouter;
  late final PlatformRouteInformationProvider routeInformation;
  Uri requestedLocation = Uri(path: '/');
  Uri? chooserReturn;
  Uri? serverSwitchLocation, serverSwitchReturn;
  bool showServerSelector = true,
      directoryLoading = true,
      selectingServer = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when a directory load, server choice or create starts, when the selector is reopened; set only for the current rootRequest.
  String? selectorError;

  /// Public server page (Web PublicServerPage): `/s/<slug>[/channel/<id>]`
  /// shown to a signed-out visitor, or to a signed-in account that has no
  /// such server. Dismissed by Sign in / Create account or when the server is
  /// not public (or unknown / forbidden); a signed-in account then sees the
  /// server-not-found page, a signed-out visitor the auth page in [authMode].
  bool publicDismissed = false;
  ({String slug, String? channelId})? publicNonmember;
  RaftClient? anonymousClient;

  /// `/s/<slug>` of a server this account does not have: App.tsx
  /// ServerResolver shows ServerAccessDeniedPage, then redirects.
  String? deniedSlug;
  RaftRecord? deniedFallback;
  Timer? deniedTimer;

  /// `/s/community` for an account that has not joined it: the app joins on
  /// arrival ("Joining community…"); an agreement to accept opens the dialog
  /// over the not-found page (App.tsx ServerResolver + useJoinCommunityFlow).
  String? joiningCommunitySlug, communityAttempt;
  bool communityDialogOpen = false;

  /// The invite link being answered (App.tsx `inviteToken`), the Raft server a
  /// full link names, and the anonymous client that reads it while signed out.
  InviteLink? invite;
  String? inviteOrigin, authMode;
  RaftClient? inviteClient;
  int rootRequest = 0;
  final Map<String, Uri> serverSurfaces = {};
  Object? workspaceRootInputs;
  String? publishedServerId;
  int? publishedWorkspaceIndex;
  late final SessionPersistence sessionPersistence;
  late final sessionOwner =
      widget.nativeSessionOwner ??
      NativeSessionOwner(poll: content.pollBackground);
  bool startupReady = false;
  void finishStartup() {
    if (startupReady) return;
    startupReady = true;
    widget.onStartupReady?.call();
  }

  int authAttempt = 0;
  final privateRoutes = PrivateRouteGuard();
  RaftClient? client;
  WorkspaceController? workspace;
  WorkspaceCache? cache;

  /// Set when stored credentials may exist but the session could not be
  /// confirmed. The app shows a recovery state (never the login form) and
  /// retries; [signInInstead] is the user's explicit choice to give up.
  SessionRestoreException? restoreFailure;
  bool restoreRetrying = false, signInInstead = false;
  Timer? restoreRetry;
  int restoreAttempt = 0;
  static const restoreBackoff = <Duration>[
    Duration(seconds: 3),
    Duration(seconds: 6),
    Duration(seconds: 12),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];
  StreamSubscription<RaftEvent>? sessionEvents;
  // Known before the first build: the deferred first frame is not the only
  // guard against painting the default family before the stored one.
  RaftAppearance appearance = storedAppearance();
  bool restoring = true;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when a new sign-in succeeds (new client installed).
  String? bootError;
  String origin = const String.fromEnvironment(
    'RAFT_ORIGIN',
    defaultValue: 'https://api.raft.build',
  );
  @override
  void initState() {
    super.initState();
    requestedLocation =
        widget.initialLocation ??
        Uri.tryParse(
          WidgetsBinding.instance.platformDispatcher.defaultRouteName,
        ) ??
        Uri(path: '/');
    if (NativeSharing.isIncomingShareLink(requestedLocation)) {
      requestedLocation = Uri(path: '/');
    }
    invite = InviteLink.fromLocation(requestedLocation);
    inviteOrigin = invite?.origin;
    InviteRequests.instance.addListener(inviteRequested);
    if (invite == null) inviteRequested();
    appRouter = RaftAppRouter(
      home: (_) => restoring
          ? const RaftServerResolutionBody(label: 'Restoring session…')
          : sessionHome(),
      onLocation: receiveAppLocation,
      onRootBack: returnFromSelector,
      observers: [privateRoutes],
    );
    routeInformation = RaftAppRouteInformationProvider(
      initialRouteInformation: RouteInformation(uri: requestedLocation),
      consumeReplacement: appRouter.consumeReplacement,
    );
    sessionPersistence = SessionPersistence(
      widget.sessionStore ?? SecureSessionStore(),
    );
    WidgetsBinding.instance.addObserver(this);
    bindCacheExit(() => closeCacheForExit(cache?.close));
    RaftMemoryRelease.instance.install();
    NativeSystemFonts.instance.addListener(rebuildRoot);
    removeShareReceiver = sharing.registerReceiver(receiveSharedContent);
    content.onIncomingShare = () => unawaited(sharing.resume());
    content.onForegroundChanged = syncWorkspaceForeground;
    // The few fixed words of a system notification (the unread count) follow
    // the member's display language, like the rest of the app.
    content.notifications.localize = (source) =>
        displayLocale(client?.user?.string('displayLanguage')).languageCode ==
            'zh'
        ? raftChinese[source] ?? source
        : source;
    unawaited(sharing.init());
    unawaited(content.init(initialArguments: widget.initialArguments));
    // An AppImage installs nothing, so xdg-open cannot find it: after the
    // first frame, claim raft:// for it (never over another handler).
    if (LinuxUriSchemeRegistration.instance.supported) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(LinuxUriSchemeRegistration.instance.ensure()),
      );
    }
    restore();
  }

  /// The picker appears at once; the attachments are copied into the private
  /// inbox in the background ([IncomingShareStaging]) and the hand-off waits
  /// for that copy only when the user continues.
  void receiveSharedContent(IncomingShare raw) {
    final epoch = shareEpoch, owner = client, principal = client?.user?.id;
    if (raw.text != null && unsafeSharedText(raw.text!)) {
      showShareError();
      return;
    }
    if (raw.token != null &&
        pendingShares.any((s) => s.raw.token == raw.token)) {
      return;
    }
    final staging = IncomingShareStaging(raw);
    staging.start((progress, bytes) async {
      final share = await sharing.inbox.stage(
        raw,
        current: () => mounted && epoch == shareEpoch && !staging.cancelled,
        onProgress: progress,
        onBytes: bytes,
      );
      if (!mounted || epoch != shareEpoch || staging.cancelled) {
        throw const FormatException('Cancelled');
      }
      if (owner != null &&
          principal != null &&
          !await sharing.inbox.claim(share.token!, owner.origin, principal)) {
        throw const FormatException('Share owner changed');
      }
      return share;
    });
    pendingShares.add(staging);
    scheduleShares();
  }

  Future<void> clearSharesForAccount(
    String accountOrigin,
    String principal,
  ) async {
    try {
      await sharing.inbox.clearAccount(accountOrigin, principal);
    } catch (_) {
      // Retiring credentials and the workspace cache must still finish when a
      // platform directory is unavailable. Old file references remain owned by
      // their original account and cannot be restored into another account.
    }
  }

  /// A new account scope invalidates queued and copying shares.
  void retireShares() {
    shareEpoch++;
    for (final pending in pendingShares) {
      pending.cancel();
    }
    pendingShares.clear();
  }

  void showShareError() {
    if (!mounted) return;
    const message = 'The shared content could not be added.';
    // ignore: raft_lints/avoid_imperative_notice_state -- One-shot toast for a failed share hand-off, consumed by WorkspaceView.
    workspace?.setError(message);
    setState(() => selectorError = message);
  }

  void scheduleShares() {
    if (!mounted ||
        shareDrainScheduled ||
        sharePickerOpen ||
        pendingShares.isEmpty ||
        restoring ||
        client?.user == null ||
        workspace == null ||
        // Only a device with no saved directory has nothing to show yet.
        directoryLoading && workspace!.servers.isEmpty) {
      return;
    }
    shareDrainScheduled = true;
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      // Outside a frame the route can be pushed now, so the picker is built by
      // the very next frame instead of one frame later.
      // ignore: raft_lints/avoid_unreviewed_idle_work -- One-shot deferral out of a build or notification; the callback does not schedule another microtask itself.
      scheduleMicrotask(() {
        shareDrainScheduled = false;
        unawaited(openNextShare());
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      shareDrainScheduled = false;
      unawaited(openNextShare());
    });
    // ignore: raft_lints/avoid_unreviewed_idle_work -- Single request after a state change; nothing re-requests from the callback.
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> openNextShare() async {
    final c = client,
        w = workspace,
        navigator = appRouter.navigatorKey.currentState;
    if (!mounted ||
        sharePickerOpen ||
        pendingShares.isEmpty ||
        c?.user == null ||
        w == null ||
        navigator == null) {
      return;
    }
    final staging = pendingShares.removeAt(0),
        principal = c!.user!.id,
        epoch = shareEpoch;
    bool valid() =>
        mounted &&
        epoch == shareEpoch &&
        identical(client, c) &&
        identical(workspace, w) &&
        c.user?.id == principal;
    sharePickerOpen = true;
    var handedOff = false;
    try {
      // Bind the copied files to this account as soon as they are staged, in
      // the background, so Continue finds the claim already done.
      final owned = staging.result.then((share) async {
        if (!await sharing.inbox.claim(share.token!, c.origin, principal)) {
          throw const RaftApiException('The conversation changed.');
        }
        return share;
      });
      unawaited(owned.then<void>((_) {}, onError: (Object _) {}));
      // Present immediately from the accepted on-device directory; the picker
      // revalidates servers and destinations in place and the hand-off below
      // re-reads authority before anything is added.
      await navigator.push<bool>(
        AccountScopedRoute<bool>(
          valid: valid,
          builder: (_) => IncomingSharePicker(
            client: c,
            servers: w.servers,
            initialServer: c.serverId,
            valid: valid,
            staging: staging,
            cachedTargets: (server) => cachedShareTargets(w, server),
            onContinue: (server, target) async {
              // Cancel (or leaving the page) ends the hand-off: nothing below
              // changes the workspace once the user has backed out.
              bool live() => valid() && !staging.cancelled;
              // Continue never waits for the network. Only the copy is
              // awaited (on this device, and long finished unless the provider
              // is slow); the server, the conversation and its saved draft come
              // from the device. Membership, the destination row, a join or a
              // new DM are checked afterwards: [verifySharedDestination].
              final share = await owned;
              if (!live()) {
                throw const RaftApiException('The conversation changed.');
              }
              // The queued files are opened while the workspace switches.
              final restoring = Future.wait([
                for (final source in share.files)
                  sharing.inbox.restore(
                    {'token': share.token, 'file': source.uri},
                    c.origin,
                    principal,
                  ),
              ]);
              final known = w.servers
                  .where((s) => s.id == server.id)
                  .firstOrNull;
              if (known == null) w.servers = [...w.servers, server];
              await chooseServer(known ?? server, cacheOnly: true);
              if (!live() || c.serverId != server.id) {
                throw const RaftApiException('The conversation changed.');
              }
              final generation = c.generation, role = w.server?.string('role');
              int? channelWindow;
              String? targetChannelId;
              bool destinationCurrent() =>
                  live() &&
                  c.serverId == server.id &&
                  c.generation == generation &&
                  w.server?.string('role') == role &&
                  (channelWindow == null ||
                      channelWindow == w.messageDomain.channelGeneration &&
                          w.channel?.id == targetChannelId &&
                          w.channel?.joined == true);
              final cachedRow = target.channel;
              // A public channel the account has not joined: the joined row is
              // shown at once and the join runs in the background.
              final opened = cachedRow == null
                  ? WorkspaceController.pendingDm(
                      key: target.key,
                      serverId: server.id,
                      name: target.label.replaceFirst('@', ''),
                    )
                  : target.requiresJoin
                  ? RaftChannel({...cachedRow.json, 'joined': true})
                  : cachedRow;
              if (!acceptsSharedDraft(opened)) {
                throw const RaftApiException(
                  'This conversation cannot receive shared content.',
                );
              }
              final id = opened.id;
              // Send is off until the destination is checked; set before the
              // selection so no list refresh can drop the opened row.
              w.holdShared(id);
              try {
                if (target.requiresJoin) w.putSharedChannelRow(opened);
                final draftRestored = Completer<void>();
                final selectingChannel = w.selectChannel(
                  opened,
                  onDraftRestored: () {
                    if (!draftRestored.isCompleted) draftRestored.complete();
                  },
                );
                unawaited(
                  selectingChannel.whenComplete(() {
                    if (!draftRestored.isCompleted) draftRestored.complete();
                  }),
                );
                channelWindow = w.messageDomain.channelGeneration;
                targetChannelId = id;
                await draftRestored.future;
                if (!destinationCurrent() || w.channel?.id != id) {
                  throw const RaftApiException('The conversation changed.');
                }
                w.closeThread();
                w.setSection('chat');
                final files = <SharedDraftAttachment>[];
                for (final file in await restoring) {
                  if (file == null || !destinationCurrent()) {
                    throw const RaftApiException('Shared file unavailable.');
                  }
                  files.add(file);
                }
                await sharing.inbox.bindDestination(
                  share.token!,
                  server.id,
                  id,
                );
                if (!destinationCurrent()) {
                  throw const RaftApiException('The conversation changed.');
                }
                await w.stageSharedDraft(
                  share.text ?? '',
                  files,
                  sourceToken: share.token,
                );
              } catch (_) {
                w.releaseShared(id);
                rethrow;
              }
              handedOff = true;
              unawaited(
                verifySharedDestination(
                  c: c,
                  w: w,
                  server: server,
                  target: target,
                  opened: opened,
                  token: share.token!,
                  valid: valid,
                ),
              );
              await sharing.inbox.complete(share.token!);
            },
          ),
        ),
      );
    } catch (_) {
      if (valid()) showShareError();
    } finally {
      if (!handedOff) {
        // Dismissed or failed: stop a copy still running and drop its files.
        staging.cancel();
        final staged = await staging.settled;
        if (staged?.token != null && valid()) {
          await sharing.inbox.discard(staged!.token!);
        }
      }
      sharePickerOpen = false;
      scheduleShares();
    }
  }

  /// The checks the share hand-off no longer waits for. The composer is open
  /// on device data with Send held; this confirms membership and the
  /// destination row, joins a public channel, or creates a new DM, then
  /// releases Send. A refusal (the server says no) keeps the draft and the
  /// staged files and puts a notice on the composer; a transient failure
  /// releases, because the server still decides on every send.
  Future<void> verifySharedDestination({
    required RaftClient c,
    required WorkspaceController w,
    required RaftRecord server,
    required IncomingShareTarget target,
    required RaftChannel opened,
    required String token,
    required bool Function() valid,
  }) async {
    var scope = opened.id;
    final pending = WorkspaceController.isPendingDm(opened);
    bool stillHere() => valid() && c.user != null;
    void refuse(String notice) {
      if (stillHere()) w.blockShared(scope, notice);
    }

    const kept = ' Your draft and files are kept.';
    try {
      final membership = c.servers();
      unawaited(membership.then<void>((_) {}, onError: (Object _) {}));
      if (pending) {
        final created =
            await c.post(
                  '/channels/dm',
                  data: {
                    if (target.agentId != null) 'agentId': target.agentId,
                    if (target.userId != null) 'userId': target.userId,
                  },
                )
                as Map;
        if (!stillHere()) return;
        final row = await c.get('/channels/${created['id']}');
        if (!stillHere()) return;
        if (row is! Map || row['id'] is! String) {
          throw const RaftApiException('The conversation changed.');
        }
        final real = RaftChannel(Map<String, dynamic>.from(row));
        final from = scope;
        scope = real.id;
        await w.adoptResolvedDm(from, real);
        await sharing.inbox.bindDestination(token, server.id, real.id);
      } else if (target.requiresJoin) {
        try {
          await c.post('/channels/$scope/join');
        } on RaftApiException {
          // Not joined after all: the original row (and its Join button)
          // returns; the draft and files stay with the conversation.
          if (stillHere()) {
            w.putSharedChannelRow(target.channel!);
            w.releaseShared(scope);
            // ignore: raft_lints/avoid_imperative_notice_state -- One-shot toast, raised only while the share destination is still current (stillHere).
            w.setError('Could not join this channel.');
          }
          return;
        }
      }
      final row = await c.get('/channels/$scope');
      final servers = await membership;
      if (!stillHere()) return;
      if (!servers.any((s) => s.id == server.id)) {
        refuse('You are no longer a member of this server.$kept');
        return;
      }
      if (row is! Map ||
          row['id'] != scope ||
          row['serverId'] != server.id ||
          !acceptsSharedDraft(RaftChannel(Map<String, dynamic>.from(row)))) {
        refuse('This conversation cannot receive shared content.$kept');
        return;
      }
      if (target.requiresJoin) {
        w.putSharedChannelRow(RaftChannel(Map<String, dynamic>.from(row)));
      }
      w.releaseShared(scope);
    } on RaftApiException catch (e) {
      if (!stillHere()) return;
      if (pending) {
        refuse('Could not open this conversation.$kept');
      } else if (e.status == 403 || e.status == 404) {
        refuse('This conversation is no longer available.$kept');
      } else {
        w.releaseShared(scope);
      }
    } catch (_) {
      if (stillHere()) w.releaseShared(scope);
    }
  }

  Future<void> restore() async {
    // The foreground owns the session from its first instruction: this is
    // synchronous and never waits for or fails because of a background guest.
    final guestSettled = sessionOwner.claim();
    restoreRetry?.cancel();
    restoreRetry = null;
    var restored = false;
    try {
      final p = await SharedPreferences.getInstance();
      DevicePreferences.adopt(p);
      origin = p.getString('raft.origin') ?? origin;
      appearance = storedAppearance(p);
      // Heals the native splash theme (app update, restored preferences).
      unawaited(NativeLaunchTheme.instance.set(appearance));
      try {
        cache ??=
            await (widget.openWorkspaceCache?.call() ??
                DriftWorkspaceCache.open());
      } catch (e) {
        // The on-device cache is an accelerator; losing it must never look
        // like losing the session.
        AuthAuditLog.shared.note(
          'restore_failed',
          'cache_unavailable',
          detail: e.runtimeType.toString(),
        );
      }
      if (!mounted) {
        await cache?.close();
        return;
      }
      late final RaftClient created;
      created = makeClient(
        origin,
        sessionPersistence.guarded(() => mounted && identical(client, created)),
      );
      final previous = client;
      client = created;
      if (previous != null && !identical(previous, created)) {
        unawaited(previous.dispose());
      }
      // Cache-first: a stored account record paints the on-device workspace
      // at once; the session is revalidated in the background and a
      // rejected or replaced account ends through the session events below.
      restored = await created.restore(
        cachedFirst: true,
        credentialsReady: guestSettled,
        onLocalSession: (cached) {
          if (!cached) finishStartup();
        },
      );
      if (!mounted) {
        await created.dispose();
        return;
      }
      restoreFailure = null;
      restoreAttempt = 0;
      if (!restored) {
        // Either nothing is stored, or the server said the credentials are
        // dead (already recorded by the client). Only these show the form.
        final ended = created.lastEndReason;
        if (ended != null) {
          bootError = 'Your session has expired. Sign in again.';
        }
        client = null;
        unawaited(created.dispose());
      }
    } catch (e) {
      if (!mounted) return;
      enterRestoreRecovery(
        e is SessionRestoreException
            ? e
            : SessionRestoreException(
                SessionRestoreFailureKind.unexpected,
                cause: e,
              ),
      );
      return;
    } finally {
      if (mounted && restoreFailure == null) {
        setState(() {
          restoring = false;
          restoreRetrying = false;
        });
      }
      finishStartup();
    }
    final c = client;
    if (restored && c != null) {
      watchSession(c);
      setState(() => restoring = false);
      try {
        await finishOnboarding(c);
      } catch (e) {
        AuthAuditLog.shared.note(
          'startup_error',
          'onboarding',
          detail: e.runtimeType.toString(),
        );
      }
    }
  }

  /// Credentials may exist but the session is unconfirmed: keep them, show the
  /// recovery state, retry with backoff and on resume.
  void enterRestoreRecovery(SessionRestoreException failure) {
    final failed = client;
    client = null;
    if (failed != null) unawaited(failed.dispose());
    AuthAuditLog.shared.note(
      'restore_failed',
      failure.kind.name,
      detail: failure.status == null
          ? failure.cause?.runtimeType.toString()
          : 'status=${failure.status}',
    );
    restoreFailure = failure;
    restoreRetrying = false;
    restoring = false;
    final delay =
        restoreBackoff[restoreAttempt.clamp(0, restoreBackoff.length - 1)];
    restoreAttempt++;
    restoreRetry?.cancel();
    restoreRetry = Timer(delay, retryRestore);
    setState(() {});
    finishStartup();
  }

  void retryRestore() {
    if (!mounted || restoreFailure == null || restoreRetrying) return;
    restoreRetry?.cancel();
    restoreRetry = null;
    setState(() {
      restoreRetrying = true;
      signInInstead = false;
    });
    unawaited(restore());
  }

  RaftClient authClient(String base, int attempt) {
    final problem = authOriginError(base);
    if (problem != null) throw RaftUserError(problem);
    late final RaftClient candidate;
    candidate = makeClient(
      base.trim(),
      sessionPersistence.guarded(
        () =>
            mounted && (attempt == authAttempt || identical(client, candidate)),
      ),
    );
    return candidate;
  }

  RaftClient makeClient(String base, SessionStore store) {
    final kind =
        defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS
        ? 'mobile'
        : 'desktop';
    return widget.createClient?.call(base, store, kind) ??
        RaftClient(
          origin: base,
          sessionStore: store,
          clientKind: kind,
          auditSink: AuthAuditLog.shared,
          // One limiter view for the API and the attachment transfers: the
          // server counts both against the same per-user bucket.
          governor: AttachmentHttp.governor,
        );
  }

  Future<void> authenticate(
    String base,
    Future<void> Function(RaftClient) action,
  ) async {
    sessionOwner.claim();
    if (!mounted) return;
    final attempt = ++authAttempt;
    final c = authClient(base, attempt);
    bool current() => mounted && attempt == authAttempt;
    try {
      await widget.services.localNetwork.ensure(base, request: true);
      if (!current()) {
        await c.dispose();
        return;
      }
      await action(c);
      if (!current()) {
        await c.dispose();
        return;
      }
      final oldWorkspace = workspace, oldClient = client;
      final oldPrincipal = oldClient?.user?.id;
      if (oldClient != null &&
          oldPrincipal != null &&
          (oldClient.origin != c.origin || oldPrincipal != c.user?.id)) {
        retireShares();
        unawaited(clearSharesForAccount(oldClient.origin, oldPrincipal));
      }
      await oldWorkspace?.flushCache();
      if (!current()) {
        await c.dispose();
        return;
      }
      sessionEvents?.cancel();
      shareSession.bind(null);
      content.bindWorkspace(null);
      oldWorkspace
        ?..removeListener(workspaceChanged)
        ..dispose();
      if (oldWorkspace == null) await oldClient?.dispose();
      if (!current()) {
        await c.dispose();
        return;
      }
      workspace = null;
      rootRequest++;
      clearAccessDenied();
      serverSurfaces.clear();
      chooserReturn = null;
      serverSwitchLocation = serverSwitchReturn = null;
      showServerSelector = true;
      client = c;
      origin = base.trim();
      bootError = null;
      restoreRetry?.cancel();
      restoreFailure = null;
      signInInstead = false;
      watchSession(c);
      rebuildRoot();
      final prefs = await SharedPreferences.getInstance();
      if (!current() || !identical(client, c)) return;
      await prefs.setString('raft.origin', origin);
      if (!current() || !identical(client, c)) return;
      await finishOnboarding(c);
    } catch (_) {
      if (!identical(c, client)) await c.dispose();
      rethrow;
    }
  }

  Future<void> login(String base, String email, String password) =>
      authenticate(base, (c) => c.login(email.trim(), password));

  Future<void> register(
    String base,
    String email,
    String password,
    bool accepted,
  ) => authenticate(
    base,
    (c) => c.register(email.trim(), password, acceptTerms: accepted),
  );

  Future<void> completeOAuth(
    String base,
    String code,
    String verifier,
    bool accepted,
  ) => authenticate(
    base,
    (c) => c.completeMobileOAuth(code, verifier, acceptTerms: accepted),
  );

  Future<void> finishOnboarding(RaftClient c) async {
    if (!mounted || !identical(c, client) || accountNeedsOnboarding(c.user)) {
      return;
    }
    unawaited(resumePendingInvite());
    if (workspace != null) {
      if (!showServerSelector && serverSwitchLocation == null) {
        content.bindWorkspace(workspace);
      }
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            identical(c, client) &&
            !showServerSelector &&
            serverSwitchLocation == null) {
          syncWorkspaceForeground();
        }
      });
      return;
    }
    final view = View.of(context);
    final logicalWidth = view.physicalSize.width / view.devicePixelRatio;
    (workspace ??= WorkspaceController(
        c,
        cache: cache,
        restoreSharedAttachment: sharing.inbox.restore,
        discardSharedScope: (origin, principal, server, channel) async {
          try {
            await sharing.inbox.clearScope(origin, principal, server, channel);
          } catch (_) {
            // Provider/storage failures cannot interrupt authority revocation.
          }
        },
        mobileNavigation: logicalWidth < RaftLayoutMetrics.desktopBreakpoint,
      ))
      ..setForeground(false)
      ..addListener(workspaceChanged);
    setState(() {});
    await discoverServers();
  }

  String get serverMemoryKey =>
      'raft.server-surface.${Uri.encodeComponent(origin)}.${client?.user?.id}';

  Future<void> discoverServers() async {
    final w = workspace, c = client;
    if (w == null || c?.user == null) return;
    final request = ++rootRequest,
        principal = c!.user!.id,
        generation = c.generation;
    bool current() =>
        mounted &&
        request == rootRequest &&
        identical(client, c) &&
        identical(workspace, w) &&
        c.user?.id == principal &&
        c.generation == generation;
    setState(() {
      directoryLoading = true;
      selectorError = null;
    });
    try {
      if (!await w.loadServerDirectory(
            cachedFirst: true,
            onCacheMiss: finishStartup,
          ) ||
          !current()) {
        return;
      }
      final servers = w.servers;
      w.loading = false;
      directoryLoading = false;
      w.notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      if (!current()) return;
      final explicit =
          requestedLocation.pathSegments.length >= 2 &&
          requestedLocation.pathSegments.first == 's';
      final slug = explicit
          ? requestedLocation.pathSegments[1]
          : requestedLocation.path == '/servers'
          ? null
          : prefs.getString('$serverMemoryKey.last');
      final target = servers.where((s) => s.string('slug') == slug).firstOrNull;
      if (target != null) {
        publicNonmember = null;
        final remembered = prefs.getString('$serverMemoryKey.${target.id}');
        await chooseServer(
          target,
          location: explicit
              ? requestedLocation
              : remembered == null
              ? null
              : Uri.tryParse(remembered),
        );
      } else if (explicit && isAutoJoinCommunitySlug(slug)) {
        showServerSelector = true;
        await joinCommunityFromRoute(slug!, current);
      } else {
        showServerSelector = true;
        // A slug this account has no server for opens its public page first;
        // when that is unavailable (unknown or private) the public page is
        // dismissed and the server-not-found page takes over.
        final nonmember = explicit && slug != null && !publicDismissed
            ? publicRoute(requestedLocation)
            : null;
        publicNonmember = nonmember;
        if (nonmember != null) {
          setState(() {});
        } else if (explicit && servers.isNotEmpty && slug != null) {
          await showAccessDenied(slug, current);
        } else {
          appRouter.publish(
            Uri(path: requestedLocation.path == '/servers' ? '/servers' : '/'),
          );
          setState(() {});
        }
      }
    } catch (e) {
      if (current()) {
        setState(() {
          directoryLoading = false;
          selectorError = userErrorText(
            e,
            fallback: 'Something went wrong',
            where: 'server directory',
          );
        });
      }
    }
  }

  /// The surface last used in [server]: this run's, else the stored one.
  Future<Uri?> serverSurfaceMemory(RaftRecord server) async {
    final live = serverSurfaces[server.id];
    if (live != null) return live;
    final prefs = await SharedPreferences.getInstance();
    final stored = Uri.tryParse(
      prefs.getString('$serverMemoryKey.${server.id}') ?? '',
    );
    return stored != null &&
            !stored.hasScheme &&
            stored.pathSegments.length >= 2 &&
            stored.pathSegments[0] == 's' &&
            stored.pathSegments[1] == server.string('slug')
        ? stored
        : null;
  }

  /// ServerAccessDeniedPage: names the server the redirect goes to (the
  /// current one, else the last used, else the first) and goes there after
  /// 3 seconds, or when the button is pressed.
  Future<void> showAccessDenied(String slug, [bool Function()? current]) async {
    final w = workspace;
    if (w == null || w.servers.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || (current != null && !current())) return;
    final last = prefs.getString('$serverMemoryKey.last');
    final fallback =
        w.servers.where((s) => s.id == w.server?.id).firstOrNull ??
        w.servers.where((s) => s.string('slug') == last).firstOrNull ??
        w.servers.first;
    deniedTimer?.cancel();
    deniedSlug = slug;
    deniedFallback = fallback;
    showServerSelector = true;
    appRouter.publish(requestedLocation);
    setState(() {});
    deniedTimer = Timer(const Duration(seconds: 3), leaveAccessDenied);
  }

  void clearAccessDenied() {
    // The agreement dialog belongs to the not-found page: leaving it closes it.
    if (communityDialogOpen) {
      communityDialogOpen = false;
      appRouter.navigatorKey.currentState?.pop();
    }
    deniedTimer?.cancel();
    deniedTimer = null;
    deniedSlug = null;
    deniedFallback = null;
  }

  /// Joins the community the URL names, then opens it.
  Future<void> joinCommunityFromRoute(
    String slug, [
    bool Function()? current,
  ]) async {
    final w = workspace, c = client;
    if (w == null || c?.user == null || communityAttempt == slug) return;
    communityAttempt = slug;
    final principal = c!.user!.id;
    bool live() =>
        mounted &&
        identical(client, c) &&
        identical(workspace, w) &&
        c.user?.id == principal &&
        (current?.call() ?? true);
    setState(() => joiningCommunitySlug = slug);
    try {
      final joined = await joinCommunity(
        () => appRouter.navigatorKey.currentState!.overlay!.context,
        c,
        slug,
        beforeDialog: () {
          if (!live()) return;
          communityDialogOpen = true;
          setState(() => joiningCommunitySlug = null);
          unawaited(showAccessDenied(slug, live));
        },
      );
      communityDialogOpen = false;
      if (!live()) return;
      if (!joined) {
        setState(() => joiningCommunitySlug = null);
        return;
      }
      if (!await w.loadServerDirectory() || !live()) return;
      final server = w.servers
          .where((s) => s.string('slug') == slug)
          .firstOrNull;
      if (server == null) {
        if (!mounted) return;
        throw const RaftUserError(
          "Joined community server but it's missing from the list",
        );
      }
      joiningCommunitySlug = null;
      await chooseServer(server, location: Uri(path: '/s/$slug'));
    } catch (e) {
      communityDialogOpen = false;
      logUserError(e, where: 'community join from the route');
      if (!live()) return;
      // Web re-arms the attempt on an error; the not-found page or the
      // server list shows meanwhile.
      communityAttempt = null;
      selectorError = userErrorText(
        e,
        fallback: 'Failed to join community server',
        where: 'community join from the route',
      );
      setState(() => joiningCommunitySlug = null);
      if (w.servers.isNotEmpty) await showAccessDenied(slug, live);
    }
  }

  void inviteRequested() {
    final link = InviteRequests.instance.take();
    if (link == null || !mounted) return;
    showInvite(link);
  }

  void showInvite(InviteLink link) {
    setState(() {
      invite = link;
      inviteOrigin = link.origin;
    });
  }

  void clearInvite() {
    final client = inviteClient;
    inviteClient = null;
    unawaited(client?.dispose());
    if (invite == null && inviteOrigin == null) return;
    invite = null;
    inviteOrigin = null;
    rebuildRoot();
  }

  /// `takePendingInviteRedirectPath`: an invite left for sign-in resumes once
  /// the account is ready (verified, identity set up).
  Future<void> resumePendingInvite() async {
    final token = await PendingInvite.take();
    if (token != null && mounted && invite == null) {
      showInvite(InviteLink(token));
    }
  }

  /// The invite is read and accepted with this client: the signed-in account,
  /// else an anonymous client of the server the link names.
  RaftClient inviteApi() {
    final c = client;
    if (c?.user != null) return c!;
    return inviteClient ??= makeClient(
      inviteOrigin ?? origin,
      MemorySessionStore(),
    );
  }

  Future<bool> enterInvitedServer(String serverId) async {
    final w = workspace, c = client;
    if (c?.user == null) return false;
    if (w == null) {
      // Account setup is still pending: the server list loads after it.
      clearInvite();
      return true;
    }
    if (!await w.loadServerDirectory() || !mounted) return false;
    final joined = w.servers.where((s) => s.id == serverId).firstOrNull;
    if (joined == null) return false;
    clearInvite();
    await chooseServer(
      joined,
      location: Uri(path: '/s/${joined.string('slug')}'),
    );
    return true;
  }

  Widget inviteHome(bool signedIn) {
    final link = invite!;
    return InviteAcceptView(
      key: ValueKey('invite-${link.token}-$signedIn'),
      token: link.token,
      signedIn: signedIn,
      loadInfo: () async {
        final api = inviteApi();
        await widget.services.localNetwork.ensure(api.origin, request: true);
        return Map<String, dynamic>.from(
          await api.request(
            'GET',
            '/auth/invite-info',
            query: {'token': link.token},
            authorized: false,
          ),
        );
      },
      accept: (agreementId) async {
        final result = await inviteApi().post(
          '/auth/accept-invite',
          data: {'token': link.token, 'agreementId': ?agreementId},
        );
        return InviteJoined(
          '${result['serverId']}',
          '${result['serverName'] ?? ''}',
        );
      },
      onEnter: enterInvitedServer,
      onSignIn: () => leaveInviteFor('login'),
      onCreateAccount: () => leaveInviteFor('register'),
      onGoToRaft: clearInvite,
    );
  }

  /// storePendingInvite + clearInviteUrl + switch to the auth form.
  void leaveInviteFor(String mode) {
    final token = invite?.token;
    if (token != null) unawaited(PendingInvite.store(token));
    final link = invite;
    setState(() {
      authMode = mode;
      // The sign-in form targets the server the link named.
      if (link?.origin != null) origin = link!.origin!;
    });
    clearInvite();
  }

  Future<void> leaveAccessDenied() async {
    final fallback = deniedFallback;
    if (!mounted || deniedSlug == null) return;
    clearAccessDenied();
    if (fallback == null) {
      openServerSelector();
      return;
    }
    final location = await serverSurfaceMemory(fallback);
    if (!mounted) return;
    await chooseServer(fallback, location: location);
  }

  void workspaceChanged() {
    scheduleShares();
    final w = workspace;
    if (!mounted || w == null) return;
    final rootInputs = (
      identityHashCode(w),
      client?.generation,
      client?.user?.id,
      accountNeedsOnboarding(client?.user),
      showServerSelector,
      serverSwitchLocation,
      w.server?.id,
      directoryLoading,
      showServerSelector
          ? (identityHashCode(w.servers), w.servers.length)
          : null,
    );
    final rootChanged = rootInputs != workspaceRootInputs;
    if (rootChanged) unawaited(shareSession.publish());
    workspaceRootInputs = rootInputs;
    if (serverSwitchLocation != null && w.server != null) {
      // The app-root URI already owns the accepted switch. Controller
      // hydration notifications cannot publish its temporary default channel.
      if (rootChanged) {
        setState(() {});
        appRouter.refresh();
      }
      return;
    }
    if (w.server == null && !directoryLoading) {
      serverSwitchLocation = serverSwitchReturn = null;
      showServerSelector = true;
      if (chooserReturn != null &&
          !w.servers.any(
            (s) =>
                s.string('slug') ==
                chooserReturn!.pathSegments.elementAtOrNull(1),
          )) {
        chooserReturn = null;
      }
      content.bindWorkspace(null);
      if (deniedSlug == null) appRouter.publish(Uri(path: '/'));
    } else if (!showServerSelector && w.server != null) {
      final remember = serverSurfaces[w.server!.id] != w.location.uri;
      serverSurfaces[w.server!.id] = w.location.uri;
      final path = appRouter.currentConfiguration.path;
      final replace =
          path == '/' ||
          path != '/servers' &&
              publishedServerId == w.server!.id &&
              publishedWorkspaceIndex != null &&
              w.navigation.index <= publishedWorkspaceIndex!;
      appRouter.publish(w.location.uri, replace: replace);
      publishedServerId = w.server!.id;
      publishedWorkspaceIndex = w.navigation.index;
      final c = client,
          principal = client?.user?.id,
          serverId = w.server!.id,
          uri = w.location.uri,
          memoryKey = serverMemoryKey;
      if (remember) {
        unawaited(
          SharedPreferences.getInstance().then((prefs) async {
            if (!mounted ||
                !identical(client, c) ||
                client?.user?.id != principal ||
                serverSurfaces[serverId] != uri) {
              return;
            }
            await prefs.setString('$memoryKey.$serverId', uri.toString());
          }),
        );
      }
    }
    // WorkspaceView and the retained pages already subscribe to data. A
    // message/read-state update is not an app-root route configuration change.
    if (rootChanged) {
      setState(() {});
      appRouter.refresh();
    }
  }

  void openServerSelector() {
    final w = workspace;
    if (w == null || client?.user == null) return;
    final request = ++rootRequest;
    clearAccessDenied();
    serverSwitchLocation = serverSwitchReturn = null;
    publicNonmember = null;
    chooserReturn = w.server == null ? null : w.location.uri;
    requestedLocation = Uri(path: '/');
    showServerSelector = true;
    selectingServer = false;
    selectorError = null;
    w.setForeground(false);
    content.bindWorkspace(null);
    final c = client, principal = client?.user?.id, memoryKey = serverMemoryKey;
    unawaited(
      SharedPreferences.getInstance().then((prefs) async {
        if (mounted &&
            request == rootRequest &&
            identical(c, client) &&
            client?.user?.id == principal) {
          await prefs.remove('$memoryKey.last');
        }
      }),
    );
    appRouter.publish(requestedLocation);
    setState(() {});
  }

  Future<void> receiveAppLocation(Uri location) async {
    if (NativeSharing.isIncomingShareLink(location)) {
      unawaited(sharing.resume());
      return;
    }
    final link = InviteLink.fromLocation(location);
    if (link != null) {
      // An invite link opens the invite page; the URL itself is consumed.
      requestedLocation = Uri(path: '/');
      appRouter.publish(requestedLocation, replace: true);
      showInvite(link);
      return;
    }
    requestedLocation = location;
    publicDismissed = false;
    serverSwitchLocation = serverSwitchReturn = null;
    final w = workspace;
    if (w == null || directoryLoading) return;
    if (location.path == '/' || location.path == '/servers') {
      openServerSelector();
      appRouter.publish(location);
      return;
    }
    final segments = location.pathSegments;
    final target = segments.length >= 2 && segments.first == 's'
        ? w.servers.where((s) => s.string('slug') == segments[1]).firstOrNull
        : null;
    if (target == null) {
      if (segments.length >= 2 &&
          segments.first == 's' &&
          isAutoJoinCommunitySlug(segments[1])) {
        openServerSelector();
        requestedLocation = location;
        await joinCommunityFromRoute(segments[1]);
        return;
      }
      openServerSelector();
      // A signed-in account without this server sees its public page first;
      // an unavailable one falls through to the server-not-found page
      // (dismissPublic -> discoverServers -> showAccessDenied).
      final route = publicRoute(location);
      if (route != null) {
        requestedLocation = location;
        publicNonmember = route;
        setState(() {});
        appRouter.refresh();
      }
      return;
    }
    publicNonmember = null;
    await chooseServer(target, location: location);
  }

  Future<bool> returnFromSelector() async {
    if (invite != null) {
      // Back leaves the invite page (the Web "Go to Raft" action).
      clearInvite();
      return true;
    }
    final w = workspace, uri = serverSwitchReturn ?? chooserReturn;
    if ((!showServerSelector && serverSwitchLocation == null) ||
        w == null ||
        uri == null) {
      return false;
    }
    final target = w.servers
        .where((s) => s.string('slug') == uri.pathSegments.elementAtOrNull(1))
        .firstOrNull;
    if (target == null) return false;
    if (serverSwitchLocation != null) {
      serverSwitchLocation = uri;
      serverSwitchReturn = null;
      appRouter.publish(uri, replace: true);
      setState(() {});
    }
    await chooseServer(target, location: uri);
    return true;
  }

  /// ServerSwitcherMenu.tsx310–324 publishes one accepted route before the
  /// server resolver changes context; mobile explicitly discards old memory.
  Future<void> switchServerFromMenu(
    RaftRecord selected,
    bool replaceWithHome,
  ) async {
    final w = workspace, c = client;
    if (w == null ||
        c?.user == null ||
        w.server?.id == selected.id ||
        !w.servers.any((s) => s.id == selected.id)) {
      return;
    }
    final request = ++rootRequest, principal = c!.user!.id;
    bool current() =>
        mounted &&
        request == rootRequest &&
        identical(client, c) &&
        identical(workspace, w) &&
        c.user?.id == principal &&
        w.servers.any((s) => s.id == selected.id);
    final before = w.location.uri;
    final prefs = await SharedPreferences.getInstance();
    if (!current()) return;
    final remembered =
        serverSurfaces[selected.id]?.toString() ??
        prefs.getString('$serverMemoryKey.${selected.id}');
    var uri = Uri(path: '/s/${selected.string('slug')}');
    if (!replaceWithHome && remembered != null) {
      final candidate = Uri.tryParse(remembered);
      if (candidate != null &&
          !candidate.hasScheme &&
          !candidate.hasAuthority &&
          candidate.pathSegments.length >= 2 &&
          candidate.pathSegments[0] == 's' &&
          candidate.pathSegments[1] == selected.string('slug')) {
        try {
          uri = RaftLocation.fromUri(candidate).uri;
        } on ArgumentError {
          /* Invalid persisted surfaces fall back to the server root. */
        }
      }
    }
    serverSwitchReturn = replaceWithHome ? null : before;
    serverSwitchLocation = uri;
    requestedLocation = uri;
    w.setForeground(false);
    content.bindWorkspace(null);
    appRouter.publish(uri, replace: replaceWithHome);
    setState(() {});
    // Browser history changes synchronously before resolver effects. Flutter
    // reports through the engine after a frame; retain this first PUSH even
    // when cached hydration immediately redirects the server root with REPLACE.
    await WidgetsBinding.instance.endOfFrame;
    if (!current()) return;
    await chooseServer(
      selected,
      location: uri,
      resolveDesktopRoot:
          !replaceWithHome &&
          (uri.path == '/s/${selected.string('slug')}' ||
              uri.path == '/s/${selected.string('slug')}/'),
    );
  }

  /// [cacheOnly]: return once the on-device workspace of [selected] is painted
  /// (or known to be absent), never after a network read: the fresh channels
  /// and page arrive behind the screen like any server opening. Used by the
  /// share hand-off, which must not wait for the network.
  Future<void> chooseServer(
    RaftRecord selected, {
    Uri? location,
    bool resolveDesktopRoot = false,
    bool cacheOnly = false,
  }) async {
    final w = workspace, c = client;
    if (w == null ||
        c?.user == null ||
        !w.servers.any((s) => s.id == selected.id)) {
      return;
    }
    final request = ++rootRequest, principal = c!.user!.id;
    clearAccessDenied();
    bool current() =>
        mounted &&
        rootRequest == request &&
        identical(client, c) &&
        identical(workspace, w) &&
        c.user?.id == principal &&
        w.servers.any((s) => s.id == selected.id);
    setState(() {
      selectingServer = true;
      selectorError = null;
    });
    try {
      await w.flushCache();
      if (!current()) return;
      if (w.server?.id != selected.id) {
        // A server with an on-device workspace opens as soon as that cache
        // is painted; its fresh channels and page revalidate in place.
        final hydrated = Completer<void>();
        final selecting = w.selectServer(
          selected,
          onCacheMiss: () {
            finishStartup();
            if (cacheOnly && !hydrated.isCompleted) hydrated.complete();
          },
          onHydrated: () {
            if (!hydrated.isCompleted) hydrated.complete();
          },
        );
        if (!await Future.any([
          hydrated.future.then((_) => false),
          selecting.then((_) => true),
        ])) {
          unawaited(
            selecting.then<void>(
              (_) {},
              onError: (Object e) {
                if (current()) {
                  // ignore: raft_lints/avoid_imperative_notice_state -- One-shot toast, raised only while the server selection request is current.
                  w.setError(
                    userErrorText(
                      e,
                      fallback: 'Could not switch servers. Please try again.',
                      where: 'server selection',
                    ),
                  );
                }
              },
            ),
          );
        }
      }
      if (!current() || w.server?.id != selected.id) return;
      var uri = location ?? serverSurfaces[selected.id];
      // MainLayout DefaultRoute914–947 redirects a desktop server root to the
      // first actual channel with REPLACE. Mobile deliberately stays Home.
      if (resolveDesktopRoot && w.channels.isNotEmpty) {
        uri = RaftLocation.at(
          serverSlug: selected.string('slug'),
          route: RaftRoute.channel,
          entityId: w.channels.first.id,
        ).uri;
        appRouter.publish(uri, replace: true);
      }
      if (uri != null &&
          uri.pathSegments.elementAtOrNull(1) == selected.string('slug')) {
        // MainLayout useRailLegacyRedirect: legacy shapes REPLACE in place.
        final target = RaftLocation.fromUri(RaftLocation.canonicalLegacy(uri));
        final routeChanged = w.location.uri != target.uri;
        if (routeChanged) {
          w.navigation.navigate(target, kind: RaftNavigationKind.replace);
        }
        // The accepted route wins over a different cached selection. Resolve
        // without blocking the cached first frame or rewriting that route.
        if ({RaftRoute.channel, RaftRoute.dm}.contains(target.route) &&
            (routeChanged || w.channel?.id != target.entityId)) {
          unawaited(
            w.resolveConversationChannel(
              target.entityId!,
              preserveThread: target.thread != null,
            ),
          );
        }
      }
      showServerSelector = false;
      chooserReturn = serverSwitchLocation = serverSwitchReturn = null;
      directoryLoading = false;
      content.bindWorkspace(w);
      workspaceChanged();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (current() && !showServerSelector && w.server?.id == selected.id) {
          syncWorkspaceForeground();
        }
      });
      final prefs = await SharedPreferences.getInstance();
      if (current()) {
        await prefs.setString('$serverMemoryKey.last', selected.string('slug'));
      }
    } catch (e) {
      if (current()) {
        setState(
          () => selectorError = userErrorText(
            e,
            fallback: 'Could not switch servers. Please try again.',
            where: 'choose server',
          ),
        );
      }
    } finally {
      if (current()) setState(() => selectingServer = false);
    }
  }

  Future<void> createServer(String name, String slug) async {
    final w = workspace, c = client;
    if (w == null || c?.user == null || selectingServer) return;
    final request = ++rootRequest, principal = c!.user!.id;
    bool current() =>
        mounted &&
        request == rootRequest &&
        identical(client, c) &&
        identical(workspace, w) &&
        c.user?.id == principal &&
        showServerSelector;
    setState(() {
      selectingServer = true;
      selectorError = null;
    });
    try {
      final data = await c.post('/servers', data: {'name': name, 'slug': slug});
      if (!current()) return;
      final returned = RaftRecord(Map<String, dynamic>.from(data));
      if (returned.id.isEmpty) {
        throw const RaftApiException('The server response is incomplete.');
      }
      if (!await w.loadServerDirectory() || !current()) return;
      final created = w.servers.where((s) => s.id == returned.id).firstOrNull;
      if (created == null) {
        throw const RaftApiException(
          'The created server is no longer available.',
        );
      }
      await chooseServer(created);
    } catch (e) {
      if (current()) {
        setState(
          () => selectorError = userErrorText(
            e,
            fallback: 'Failed to create server',
            where: 'create server',
          ),
        );
      }
    } finally {
      if (current()) setState(() => selectingServer = false);
    }
  }

  /// App.tsx: `/^\/s\/([^/]+)(?:\/channel\/([^/]+))?(?:\/.*)?$/`.
  static ({String slug, String? channelId})? publicRoute(Uri location) {
    final segments = location.pathSegments;
    if (segments.length < 2 || segments.first != 's' || segments[1].isEmpty) {
      return null;
    }
    final channel = segments.length >= 4 && segments[2] == 'channel'
        ? segments[3]
        : null;
    return (slug: segments[1], channelId: channel);
  }

  void dismissPublic({String? mode, bool rediscover = false}) {
    setState(() {
      publicDismissed = true;
      publicNonmember = null;
      if (mode != null) authMode = mode;
    });
    appRouter.refresh();
    if (rediscover) unawaited(discoverServers());
  }

  Widget sessionHome() {
    scheduleShares();
    final active = client;
    if (restoreFailure != null && !signInInstead && active?.user == null) {
      workspaceRootInputs = null;
      return SessionRecoveryView(
        failure: restoreFailure!,
        busy: restoreRetrying,
        onRetry: retryRestore,
        onSignInAgain: () {
          // The stored credentials stay until a new sign-in replaces them.
          restoreRetry?.cancel();
          setState(() => signInInstead = true);
        },
      );
    }
    if (active?.user == null) {
      workspaceRootInputs = null;
      if (invite != null) return inviteHome(false);
      final route = publicRoute(requestedLocation);
      if (route != null && !publicDismissed) {
        return PublicServerView(
          key: ValueKey('public-${route.slug}'),
          client: anonymousClient ??=
              widget.createClient?.call(origin, MemorySessionStore(), 'web') ??
              RaftClient(origin: origin, sessionStore: MemorySessionStore()),
          slug: route.slug,
          initialChannelId: route.channelId,
          onSignIn: () => dismissPublic(mode: 'login'),
          onRegister: () => dismissPublic(mode: 'register'),
          onUnavailable: dismissPublic,
        );
      }
      return AuthView(
        key: ValueKey('auth-$authMode'),
        initialMode: authMode ?? 'login',
        origin: origin,
        bootError: bootError,
        onLogin: login,
        onRegister: register,
        onOAuth: completeOAuth,
      );
    }
    if (invite != null) return inviteHome(true);
    if (accountNeedsOnboarding(active!.user)) {
      return AccountOnboardingView(
        client: active,
        onComplete: () => finishOnboarding(active),
        onSignOut: logout,
      );
    }
    if (workspace == null) {
      return const RaftServerResolutionBody(label: 'Loading…');
    }
    if (joiningCommunitySlug != null) {
      return const RaftServerResolutionBody(
        key: ValueKey('joining-community'),
        label: 'Joining community…',
      );
    }
    final nonmember = publicNonmember;
    if (showServerSelector && nonmember != null && !publicDismissed) {
      final w = workspace!;
      return PublicServerView(
        key: ValueKey('public-${nonmember.slug}'),
        client: active,
        slug: nonmember.slug,
        initialChannelId: nonmember.channelId,
        account: PublicServerAccount(
          servers: w.servers,
          onSelect: chooseServer,
        ),
        appVersion: const String.fromEnvironment('RAFT_APP_VERSION'),
        onSignIn: () {},
        onRegister: () {},
        onUnavailable: () => dismissPublic(rediscover: true),
        onJoined: () async {
          if (!await w.loadServerDirectory()) {
            throw const RaftApiException('The server list is unavailable.');
          }
          final joined = w.servers
              .where((s) => s.string('slug') == nonmember.slug)
              .firstOrNull;
          if (joined == null) {
            throw const RaftApiException(
              'Joined server was not returned by the server list',
            );
          }
          publicNonmember = null;
          await chooseServer(
            joined,
            location: nonmember.channelId == null
                ? Uri(path: '/s/${joined.string('slug')}')
                : Uri(
                    path:
                        '/s/${joined.string('slug')}/channel/${Uri.encodeComponent(nonmember.channelId!)}',
                  ),
          );
        },
      );
    }
    if (showServerSelector &&
        deniedSlug != null &&
        workspace!.servers.isNotEmpty) {
      return RaftServerAccessDeniedPage(
        key: const ValueKey('server-access-denied'),
        serverName: deniedFallback?.name,
        onContinue: leaveAccessDenied,
      );
    }
    if (showServerSelector) {
      return GlobalServerSelector(
        key: ValueKey('selector-${active.user!.id}'),
        servers: workspace!.servers,
        user: active.user!,
        loading: directoryLoading || selectingServer,
        error: selectorError,
        onSelect: chooseServer,
        onCreate: createServer,
        onLogout: logout,
        onRetry: discoverServers,
      );
    }
    if (serverSwitchLocation != null) {
      return RaftServerResolutionBody(
        key: const Key('server-resolution-loading'),
        label: selectorError ?? 'Loading…',
      );
    }
    return WorkspaceView(
      controller: workspace!,
      appearance: appearance,
      onAppearance: setAppearance,
      onLogout: logout,
      onChooseServer: openServerSelector,
      onSwitchServer: switchServerFromMenu,
      notifications: content.notifications,
      sharing: sharing,
    );
  }

  void watchSession(RaftClient c) {
    shareSession.bind(c);
    final principal = c.user!.id;
    sessionEvents?.cancel();
    sessionEvents = c.events.listen((e) {
      if (e.name == 'account:updated' && mounted && identical(c, client)) {
        if (c.user?.id != principal) {
          // An account record cannot transfer the old workspace's private
          // projections to another principal, even on the same client object.
          unawaited(
            logout(
              previousPrincipal: principal,
              reason: SessionEndReason.principalChanged,
            ),
          );
          return;
        }
        if (accountNeedsOnboarding(c.user)) {
          rootRequest++;
          workspace?.setForeground(false);
          content.bindWorkspace(null);
        }
        setState(() {});
      }
      if (mounted &&
          identical(c, client) &&
          (e.name == 'server:membership-removed' ||
              e.name == 'server:member-updated' &&
                  e.payload is Map &&
                  e.payload['userId'] == principal)) {
        // The workspace reducer owns the actual authority projection. The app
        // root only retires its pending directory/create/selection completion.
        rootRequest++;
        if (selectingServer) {
          selectingServer = false;
          selectorError =
              'Server membership changed. Choose an available server again.';
        }
        if (directoryLoading) unawaited(discoverServers());
        setState(() {});
      }
      if (e.name == 'session:ended' && mounted && identical(c, client)) {
        // Say why the form appeared when the server (not the user) ended it.
        final reason = c.lastEndReason;
        if (reason != null && reason != SessionEndReason.userRequested) {
          bootError = 'Your session has expired. Sign in again.';
        }
        shareSession.bind(null);
        authAttempt++;
        rootRequest++;
        retireShares();
        unawaited(clearSharesForAccount(c.origin, principal));
        // Nothing more is written for this account once its data is cleared.
        final flushed = workspace?.retireCache() ?? Future<void>.value();
        flushed.then((_) => cache?.clearAccount(c.origin, principal));
        unawaited(purgeAccountCaches(c.origin, principal));
        content.bindWorkspace(null);
        workspace
          ?..removeListener(workspaceChanged)
          ..dispose();
        workspace = null;
        publicNonmember = null;
        clearAccessDenied();
        serverSurfaces.clear();
        chooserReturn = null;
        serverSwitchLocation = serverSwitchReturn = null;
        showServerSelector = true;
        appRouter.publish(Uri(path: '/'));
        client = null;
        setState(() {});
      }
    });
  }

  Future<void> logout({
    String? previousPrincipal,
    SessionEndReason reason = SessionEndReason.userRequested,
  }) async {
    shareSession.bind(null);
    authAttempt++;
    rootRequest++;
    content.bindWorkspace(null);
    final c = client, oldWorkspace = workspace;
    final principal = previousPrincipal ?? c?.user?.id;
    retireShares();

    final clearSession = c == null
        ? Future<Session?>.value()
        : sessionPersistence.clearAfter(
            c.origin,
            sessionOwner.claim(),
            principal: c.user?.id,
          );
    workspace = null;
    publicNonmember = null;
    authMode = null;
    clearAccessDenied();
    oldWorkspace?.removeListener(workspaceChanged);
    serverSurfaces.clear();
    chooserReturn = null;
    serverSwitchLocation = serverSwitchReturn = null;
    showServerSelector = true;
    appRouter.publish(Uri(path: '/'));
    client = null;
    sessionEvents?.cancel();
    // Retire requests and socket authentication synchronously, even while a
    // background owner is still finishing the credential record to revoke.
    final loggingOut = c?.logout(
      revocationSession: clearSession,
      reason: reason,
    );
    rebuildRoot();
    // Late writes (debounced directory saves, socket-driven windows) must not
    // land after the account's device data is cleared.
    await oldWorkspace?.retireCache();
    if (c != null && principal != null) {
      final shareCleanup = clearSharesForAccount(c.origin, principal);
      await cache?.clearAccount(c.origin, principal);
      await shareCleanup;
      // Cached attachments and videos of this account go with its other
      // cached data.
      await purgeAccountCaches(c.origin, principal);
    }
    await loggingOut;
    oldWorkspace?.dispose();
    if (oldWorkspace == null) await c?.dispose();
  }

  Future<void> setAppearance(RaftAppearance value) async {
    setState(() => appearance = value);
    final p = await SharedPreferences.getInstance();
    await p.setString('raft.mode', value.mode.name);
    await p.setString('raft.light', value.light.name);
    // The next cold start's native splash needs the new canvas.
    await NativeLaunchTheme.instance.set(value);
  }

  void syncWorkspaceForeground() {
    if (!mounted) return;
    workspace?.setForeground(
      content.appForeground &&
          !showServerSelector &&
          serverSwitchLocation == null,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    workspace?.setForeground(
      state == AppLifecycleState.resumed &&
          !showServerSelector &&
          serverSwitchLocation == null,
    );
    if (state == AppLifecycleState.resumed) {
      // A session the server could not confirm is asked again at once; the
      // network is often back exactly when the app returns to the foreground.
      if (restoreFailure != null) retryRestore();
      final held = client;
      if (held != null && (held.sessionDegraded || held.restoredOffline)) {
        unawaited(held.retrySession());
      }
      unawaited(sharing.resume());
      unawaited(NativeSystemFonts.instance.refresh());
      // The network (and its proxy) often changed while the app was away.
      unawaited(SystemProxy.instance.refresh());
      // At most once per 6 h; a no-op for dev builds and in tests.
      unawaited(widget.services.appUpdate?.checkIfDue());
      unawaited(content.notifications.refreshPermission());
      final w = workspace;
      if (w == null) return;
      w.resumeLiveSession();
    }
  }

  void rebuildRoot() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeLocales(List<Locale>? locales) => rebuildRoot();

  /// The engine waits for this before it tears the background isolate down.
  /// Completion, timeout, and failure all allow the exit.
  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await closeCacheForExit(cache?.close);
    return AppExitResponse.exit;
  }

  @override
  void dispose() {
    restoreRetry?.cancel();
    finishStartup();
    InviteRequests.instance.removeListener(inviteRequested);
    unawaited(inviteClient?.dispose());
    clearAccessDenied();
    authAttempt++;
    rootRequest++;
    shareEpoch++;
    removeShareReceiver?.call();
    unawaited(sharing.dispose());
    unawaited(shareSession.dispose());
    RaftMemoryRelease.instance.uninstall();
    WidgetsBinding.instance.removeObserver(this);
    bindCacheExit(null);
    NativeSystemFonts.instance.removeListener(rebuildRoot);
    unawaited(content.dispose());
    AttachmentHttp.close();
    sessionEvents?.cancel();
    final flushed = workspace?.flushCache() ?? Future<void>.value();
    final retiredClient = client;
    workspace
      ?..removeListener(workspaceChanged)
      ..dispose();
    final disposed = retiredClient?.dispose();
    flushed.whenComplete(() async {
      try {
        await disposed;
        await cache?.close();
      } finally {
        sessionOwner.release();
      }
    });
    routeInformation.dispose();
    appRouter.dispose();
    anonymousClient?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    privateRoutes.scopeChanged(
      '${client?.generation}|${client?.user?.id}',
      domain: 'account',
    );
    final locale = displayLocale(client?.user?.string('displayLanguage'));
    final textLocale = WidgetsBinding.instance.platformDispatcher.locale;
    ThemeData themed(RaftFamily family, {bool dark = false}) => raftTheme(
      family,
      dark: dark,
      systemFonts: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
      systemFontFamilies: NativeSystemFonts.instance.value,
      locale: locale,
      textLocale: textLocale,
    );
    return MaterialApp.router(
      title: 'Raft',
      routerDelegate: appRouter,
      routeInformationParser: const RaftAppRouteParser(),
      routeInformationProvider: routeInformation,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => RaftHoverScope.forPlatform(
        child: AppWindowCommands(
          navigatorKey: appRouter.navigatorKey,
          openSection: workspace?.setSection,
          child: AppServicesHost(
            services: widget.services,
            ownsAppUpdate: widget.ownsAppUpdate,
            child: RaftTextScaling(
              child: RepaintBoundary(
                key: raftScreenshotKey,
                child: DesktopTitleBar(
                  child: RaftTooltipProvider(
                    delay: const Duration(milliseconds: 600),
                    child: RaftViewportBreakpointScope(
                      // Resolves the theme's font combinations once the app is idle.
                      child: RaftFontWarmUpScope(
                        child: RaftSystemBars(
                          child: RaftErrorScope(
                            format: raftAppErrorFormatter,
                            child: RaftToastHost(
                              child: KeyboardInsetGuard(
                                imeVisible: platformImeVisibility,
                                child: child!,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      theme: themed(appearance.light),
      darkTheme: themed(RaftFamily.elegant, dark: true),
      themeMode: appearance.mode,
    );
  }
}
