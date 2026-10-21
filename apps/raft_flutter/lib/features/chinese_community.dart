// The Chinese community entry (Web LeftRail `openCommunity` and
// pages/ChineseCommunityPage.tsx): for a Chinese display language the Help
// menu's community item shows the WeChat QR page instead of joining the
// default community server.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/attachment_http.dart';
import '../platform/content_links.dart';

/// `CHINESE_COMMUNITY_QR_CONFIG_URL` (utils/chineseCommunityQr.ts).
const chineseCommunityQrConfigUrl =
    'https://static.raft.build/community/chinese-qr.json';

/// `CHINESE_COMMUNITY_QR_FALLBACK_CONFIG_PATH`: served by the Web app itself.
const chineseCommunityQrFallbackPath = '/community/chinese-qr.json';

/// `shouldShowChineseCommunityEntry(displayLocale)`: a Chinese display language.
bool showChineseCommunityEntry(BuildContext context) =>
    Localizations.maybeLocaleOf(context)?.languageCode == 'zh';

/// The Help menu's community item (LeftRail `openCommunity`): Chinese display
/// language opens the QR page, anything else runs [join]. [joining] is the
/// join flow in progress ("Joining community…", item disabled).
RaftMenuEntry communityHelpEntry(
  BuildContext context, {
  required String apiOrigin,
  required bool joining,
  required VoidCallback join,
}) {
  final chinese = showChineseCommunityEntry(context);
  return RaftMenuEntry(
    label: raftText(
      context,
      joining
          ? 'Joining community…'
          : chinese
          ? 'Join Chinese Community'
          : 'Join Community',
    ),
    glyph: RaftGlyph.usersRound,
    onPressed: joining
        ? null
        : chinese
        ? () => unawaited(showChineseCommunityPage(context, apiOrigin))
        : join,
  );
}

/// `ChineseCommunityQrConfig`.
@immutable
class ChineseCommunityQrConfig {
  const ChineseCommunityQrConfig({
    required this.imageUrl,
    this.updatedAt,
    this.expiresAt,
    this.fallbackContact,
  });
  final String imageUrl;
  final String? updatedAt, expiresAt, fallbackContact;
}

/// `normalizeChineseCommunityQrConfig`: an object with a non-blank `imageUrl`.
ChineseCommunityQrConfig? normalizeChineseCommunityQrConfig(Object? value) {
  if (value is! Map) return null;
  String? text(String key) {
    final v = value[key];
    return v is String && v.trim().isNotEmpty ? v.trim() : null;
  }

  final image = text('imageUrl');
  if (image == null) return null;
  return ChineseCommunityQrConfig(
    imageUrl: image,
    updatedAt: text('updatedAt'),
    expiresAt: text('expiresAt'),
    fallbackContact: text('fallbackContact'),
  );
}

/// `resolveChineseCommunityQrConfig`: the QR image must live on the config's
/// own origin under `/community/`, with no credentials, query or fragment
/// (and a remote config must be https), or the config is refused.
/// [remote] is false for the Web app's own fallback file, which Web reads by a
/// relative path (so it carries no https rule of its own).
ChineseCommunityQrConfig? resolveChineseCommunityQrConfig(
  Object? value,
  Uri configUrl, {
  bool remote = true,
}) {
  final config = normalizeChineseCommunityQrConfig(value);
  if (config == null) return null;
  final Uri image;
  try {
    image = configUrl.resolve(config.imageUrl);
  } on FormatException {
    return null;
  }
  if ((remote && configUrl.scheme != 'https') ||
      image.origin != configUrl.origin ||
      !image.path.startsWith('/community/') ||
      image.userInfo.isNotEmpty ||
      image.hasQuery ||
      image.hasFragment) {
    return null;
  }
  return ChineseCommunityQrConfig(
    imageUrl: image.toString(),
    updatedAt: config.updatedAt,
    expiresAt: config.expiresAt,
    fallbackContact: config.fallbackContact,
  );
}

/// `isChineseCommunityQrExpired`: an unparsable date never expires.
bool isChineseCommunityQrExpired(String? expiresAt, {DateTime? now}) {
  if (expiresAt == null) return false;
  final expires = DateTime.tryParse(expiresAt);
  if (expires == null) return false;
  return expires.isBefore(now ?? DateTime.now());
}

/// Reads [url] as JSON without caching; null on any failure (`fetchConfig`).
typedef ChineseCommunityFetch = Future<Object?> Function(String url);

Future<Object?> _fetchJson(String url) async {
  final response = await AttachmentHttp.shared.get<Object?>(
    url,
    options: Options(
      responseType: ResponseType.json,
      headers: const {'Cache-Control': 'no-store'},
    ),
  );
  return response.data;
}

/// Opens the QR page over the app (Web navigates to `/community/chinese`).
Future<void> showChineseCommunityPage(BuildContext context, String apiOrigin) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/community/chinese'),
        // Web reads the fallback by a path relative to the app's own origin.
        builder: (_) => ChineseCommunityPage(
          fallbackConfigUrl: ContentLinks.originFor(apiOrigin)
              .resolve(chineseCommunityQrFallbackPath)
              .toString(),
        ),
      ),
    );

class ChineseCommunityPage extends StatefulWidget {
  const ChineseCommunityPage({
    super.key,
    this.configUrl = chineseCommunityQrConfigUrl,
    required this.fallbackConfigUrl,
    this.fetch = _fetchJson,
    this.now,
    this.imageBuilder,
  });

  /// The primary configuration (`getChineseCommunityQrConfigUrl`).
  final String configUrl;

  /// The Web app's own copy (`/community/chinese-qr.json` on its origin).
  final String fallbackConfigUrl;
  final ChineseCommunityFetch fetch;
  final DateTime Function()? now;

  /// Builds the QR picture; [onError] reports a picture that failed to load.
  final Widget Function(String url, VoidCallback onError)? imageBuilder;

  @override
  State<ChineseCommunityPage> createState() => _ChineseCommunityPageState();
}

enum _Source { primary, fallback }

class _ChineseCommunityPageState extends State<ChineseCommunityPage> {
  // Loading until a config is read; then ready (primary or fallback) or missing.
  bool loading = true;
  ChineseCommunityQrConfig? config;
  _Source source = _Source.primary;
  // 'config' or 'image': why there is no config (`QrState.missing.reason`).
  String missingReason = 'config';
  String? failedImageUrl;
  int request = 0;

  @override
  void initState() {
    super.initState();
    unawaited(loadConfig());
  }

  Future<ChineseCommunityQrConfig?> read(
    String url, {
    bool remote = true,
  }) async {
    try {
      return resolveChineseCommunityQrConfig(
        await widget.fetch(url),
        Uri.parse(url),
        remote: remote,
      );
    } catch (_) {
      return null;
    }
  }

  /// `loadFallbackConfig`: the app's own copy, else missing for [reason].
  Future<void> loadFallback([String reason = 'config']) async {
    final ticket = ++request;
    final fallback = await read(widget.fallbackConfigUrl, remote: false);
    if (!mounted || ticket != request) return;
    setState(() {
      loading = false;
      config = fallback;
      source = _Source.fallback;
      missingReason = reason;
      failedImageUrl = null;
    });
  }

  /// `loadConfig` (also the first load).
  Future<void> loadConfig() async {
    final ticket = ++request;
    setState(() {
      loading = true;
      failedImageUrl = null;
    });
    final primary = await read(widget.configUrl);
    if (!mounted || ticket != request) return;
    if (primary != null) {
      setState(() {
        loading = false;
        config = primary;
        source = _Source.primary;
      });
      return;
    }
    await loadFallback();
  }

  void imageFailed() {
    final current = config;
    if (current == null || failedImageUrl == current.imageUrl) return;
    if (source == _Source.primary) {
      unawaited(loadFallback('image'));
    } else {
      setState(() => failedImageUrl = current.imageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = config;
    final expired =
        current != null &&
        isChineseCommunityQrExpired(current.expiresAt, now: widget.now?.call());
    final imageFailedNow =
        current != null && failedImageUrl == current.imageUrl;
    final showImage = current != null && !expired && !imageFailedNow;
    // `qrUnavailableMessageId`: no config says why it is missing; a config
    // that cannot be shown is expired or its picture failed.
    final unavailable = current == null
        ? missingReason == 'image'
              ? 'The QR code cannot be loaded. Please refresh later or contact the Raft team.'
              : 'The QR code is not configured yet. Refresh later or contact the Raft team.'
        : expired
        ? 'This QR code has expired. Please refresh later or contact the Raft team.'
        : imageFailedNow
        ? 'The QR code cannot be loaded. Please refresh later or contact the Raft team.'
        : 'The QR code is not configured yet. Refresh later or contact the Raft team.';
    final image = showImage
        ? (widget.imageBuilder ?? _networkImage)(current.imageUrl, () {
            // Reported while painting: settle after the frame.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) imageFailed();
            });
          })
        : null;
    void close() => Navigator.of(context).maybePop();
    return Title(
      // useBrowserDocumentTitle(pages.chineseCommunity.title)
      title: raftText(context, 'Scan the QR code to join'),
      color: RaftTokens.of(context).panel,
      child: RaftDismissScope(
        onDismiss: close,
        child: RaftChineseCommunityPage(
          state: loading
              ? RaftChineseCommunityQr.loading
              : showImage
              ? RaftChineseCommunityQr.image
              : RaftChineseCommunityQr.unavailable,
          image: image,
          unavailable: unavailable,
          // A native page has no browser Back.
          leading: RaftIconButton(
            key: const ValueKey('chinese-community-back'),
            glyph: RaftGlyph.arrowLeft,
            tooltip: raftText(context, 'Back'),
            visualSize: 32,
            minimumTargetSize: 48,
            variant: RaftControlVariant.ghost,
            onPressed: close,
          ),
        ),
      ),
    );
  }

  static Widget _networkImage(String url, VoidCallback onError) => Builder(
    builder: (context) =>
        // ignore: raft_lints/avoid_raw_image_decode -- A QR code from the community host: a bounded 288px picture decoded at its own size (cacheWidth).
        Image.network(
          url,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: (288 * MediaQuery.devicePixelRatioOf(context)).ceil(),
          fit: BoxFit.contain,
          // `[image-rendering:pixelated]`: a QR code is never smoothed.
          filterQuality: FilterQuality.none,
          errorBuilder: (_, _, _) {
            onError();
            return const SizedBox.shrink();
          },
        ),
  );
}
