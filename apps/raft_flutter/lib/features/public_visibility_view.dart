import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/feature_flag_client_facts.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'management_support.dart'
    show
        cachedServerFlag,
        managementMap,
        managementRows,
        pageIdentity,
        readPageSnapshot,
        rememberServerFlag,
        writePageSnapshot;

/// Settings > Server Profile: SettingsPanel.tsx PublicVisibilitySection.
/// Owner only, behind `public_server_v0`; the Guest-join switch also needs
/// `server_guest_v0`. GET/PATCH /servers/:id/public-visibility and PATCH
/// /servers/:id/public-guest-join and /servers/:id/public-search (Allow search
/// engines); turning public on asks for confirmation with the exposed channel
/// list. The server list carries `publicPageLive` (the globe after the server
/// name and on public channels), so it is reloaded after the visibility
/// changes: the owner who just flipped it should not wait.
class PublicVisibilitySection extends StatefulWidget {
  const PublicVisibilitySection({
    super.key,
    required this.controller,
    required this.webOrigin,
  });
  final WorkspaceController controller;

  /// `shareableWebOrigin()` for the public page URL.
  final String webOrigin;
  @override
  State<PublicVisibilitySection> createState() =>
      _PublicVisibilitySectionState();
}

class _PublicVisibilitySectionState extends State<PublicVisibilitySection> {
  static const publicFlag = 'public_server_v0', guestFlag = 'server_guest_v0';
  static const snapshotKey = 'server:public-visibility';
  WorkspaceController get w => widget.controller;
  late bool publicEnabled = cachedServerFlag(w, publicFlag) ?? false;
  late bool guestEnabled = cachedServerFlag(w, guestFlag) ?? false;
  Map<String, dynamic>? readback;
  bool loading = false, saving = false, copied = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Clears when the read starts or a change starts (Web setError('') at submit); the page is remounted on server/account change.
  String? error;
  Timer? copiedTimer;

  bool get owner => w.server?.string('role') == 'owner';
  String get base => '/servers/${w.server!.id}';

  @override
  void initState() {
    super.initState();
    readback =
        readPageSnapshot(w, snapshotKey)?['readback'] as Map<String, dynamic>?;
    // The remembered flag shows the card at once; without a readback it
    // renders its loading state instead of a wrong "off" first frame.
    loading = owner && publicEnabled && readback == null;
    if (owner) unawaited(start());
  }

  @override
  void dispose() {
    copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> start() async {
    final identity = pageIdentity(w);
    try {
      final result = managementMap(
        await w.client.post(
          '/feature-flags/evaluate',
          data: featureFlagEvaluateBody(
            keys: [publicFlag, guestFlag],
            serverId: w.server?.id,
          ),
        ),
      );
      bool on(String key) =>
          managementRows(result['evaluations'])
              .any((f) => f['key'] == key && f['enabled'] == true);
      final public = on(publicFlag), guest = on(guestFlag);
      rememberServerFlag(w, publicFlag, public, identity);
      rememberServerFlag(w, guestFlag, guest, identity);
      if (!mounted || identity != pageIdentity(w)) return;
      setState(() {
        publicEnabled = public;
        guestEnabled = guest;
      });
    } catch (_) {
      // An unresolved flag keeps the section hidden.
      if (mounted && loading) setState(() => loading = false);
      return;
    }
    if (!publicEnabled) {
      if (mounted && loading) setState(() => loading = false);
      return;
    }
    setState(() {
      loading = readback == null;
      error = null;
    });
    try {
      final data = managementMap(await w.query('$base/public-visibility'));
      if (!mounted || identity != pageIdentity(w)) return;
      setState(() {
        readback = data;
        loading = false;
      });
      writePageSnapshot(w, snapshotKey, identity, {'readback': data});
    } catch (e) {
      if (mounted && identity == pageIdentity(w)) {
        setState(() {
          loading = false;
          error = _error(e, 'Failed to load public access settings');
        });
      }
    }
  }

  static String _error(Object e, String fallback) =>
      userErrorText(e, fallback: fallback, where: 'public visibility');

  Future<void> patch(
    String path,
    Map<String, dynamic> body,
    String failure,
  ) async {
    final identity = pageIdentity(w);
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final data = managementMap(await w.command('PATCH', path, data: body));
      if (!mounted || identity != pageIdentity(w)) return;
      setState(() => readback = {...?readback, ...data});
      writePageSnapshot(w, snapshotKey, identity, {'readback': readback});
    } catch (e) {
      if (mounted && identity == pageIdentity(w)) {
        setState(() => error = _error(e, failure));
      }
      rethrow;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  /// PATCH public-visibility, then the globe's source of truth.
  Future<void> setVisibility(bool visible) async {
    await patch('$base/public-visibility', {
      'publiclyVisible': visible,
    }, 'Failed to update public access');
    unawaited(w.loadServerDirectory().catchError((_) => false));
  }

  List<RaftPublicChannel> get channels => [
    for (final c in managementRows(readback?['exposedChannels']))
      RaftPublicChannel(
        name: '${c['name'] ?? ''}',
        description: c['description'] as String?,
      ),
  ];

  Future<void> makePublic() async {
    await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('public-visibility-confirm'),
        confirmKey: const ValueKey('public-visibility-confirm-button'),
        title: 'Make this server public?',
        confirmLabel: 'Make public',
        loadingLabel: 'Making public…',
        confirmVariant: RaftButtonRecipeVariant.accent,
        maxWidth: 512,
        content: RaftPublicVisibilityConfirmBody(channels: channels),
        onConfirm: () => setVisibility(true),
      ),
    );
  }

  Future<void> copy(String url) async {
    try {
      await Clipboard.setData(ClipboardData(text: url));
    } catch (_) {
      if (mounted) setState(() => error = 'Failed to copy the public page URL');
      return;
    }
    if (!mounted) return;
    setState(() => copied = true);
    copiedTimer?.cancel();
    copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!owner || !publicEnabled) return const SizedBox.shrink();
    final r = readback;
    final visible = r?['publiclyVisible'] == true;
    final url = visible
        ? '${widget.webOrigin}/s/${r?['slug'] ?? w.server!.string('slug')}'
        : null;
    final idle = !loading && !saving && r != null;
    return RaftAdminSection(
      regionKey: const ValueKey('public-visibility-section'),
      label: 'Public access',
      glyph: RaftGlyph.globe2,
      child: RaftPublicVisibilityCard(
        publiclyVisible: visible,
        onPublic: idle
            ? (on) {
                if (on) {
                  makePublic();
                } else {
                  setVisibility(false).catchError((_) {});
                }
              }
            : null,
        publicUrl: url,
        copied: copied,
        onCopy: url == null ? null : () => copy(url),
        guestJoin: guestEnabled ? (r?['publicGuestJoinEnabled'] == true) : null,
        onGuestJoin: idle && visible
            ? (on) => patch('$base/public-guest-join', {
                'publicGuestJoinEnabled': on,
              }, 'Failed to update Guest joining').catchError((_) {})
            : null,
        searchEngines: r?['publicSearchEnabled'] == true,
        onSearchEngines: idle && visible
            ? (on) => patch('$base/public-search', {
                'publicSearchEnabled': on,
              }, 'Failed to update search engine access').catchError((_) {})
            : null,
        loading: loading,
        channels: channels,
        error: error,
      ),
    );
  }
}
