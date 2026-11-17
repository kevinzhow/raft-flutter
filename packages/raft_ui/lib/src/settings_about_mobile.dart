// Settings > About: the Source code line of the Version card (AboutSection.tsx)
// and the Mobile app section (MobileAppDownloads.tsx, MobileDownloadQr.tsx).
import 'package:flutter/material.dart';

import 'design_primitives.dart'
    show RaftTextLink, RaftTextLinkVariant, RaftTypography;
import 'icons.dart';
import 'link_scope.dart';
import 'localization.dart';
import 'qr_code.dart';
import 'raft/button.dart' show RaftButton, RaftButtonSize, RaftButtonVariant;
import 'raft/ui_tokens.dart';
import 'theme.dart';
import 'token_geometry.dart';
import 'tokens/raft_tokens.g.dart' show RaftTypeScale;

/// AboutSection's Mobile app section: the download targets.
///
/// The Google Play listing and the source repository open through the host's
/// [RaftLinkScope]; the App Store and APK links go through the callbacks
/// because their URLs come from the connected server.
@immutable
class RaftAboutMobileApp {
  const RaftAboutMobileApp({
    required this.onAndroid,
    required this.onIos,
    this.qrUrl,
  });
  final VoidCallback onAndroid, onIos;

  /// The web-origin `/download` chooser the QR encodes; null hides the QR
  /// (a failed encoder chunk renders nothing on Web).
  final String? qrUrl;
}

/// `GOOGLE_PLAY_URL` (utils/mobileDownloadUrl.ts).
const raftGooglePlayUrl =
    'https://play.google.com/store/apps/details?id=build.raft.app';

/// `RAFT_SOURCE_URL` (AboutSection.tsx): the server and web's public source.
const raftSourceUrl = 'https://github.com/botiverse/raft-source';

/// `RAFT_SOURCE_LICENSE`: a name, not prose, the same in every locale.
const raftSourceLicense = 'Raft License';

/// The Version card's Source code line: a strong external link, then the
/// license name in mono.
class RaftAboutSourceCode extends StatelessWidget {
  const RaftAboutSourceCode({super.key});

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final open = RaftLinkScope.handlerOf(context);
    final mono = t.typeSlot('mono-meta');
    return Wrap(
      key: const ValueKey('settings-about-source-code'),
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        RaftTextLink(
          key: const ValueKey('settings-about-source-code-link'),
          label: raftText(context, 'Source code'),
          variant: RaftTextLinkVariant.strong,
          scale: RaftTypeScale.footnote,
          external: true,
          externalLabel: raftText(context, '(opens in a new tab)'),
          onPressed: open == null ? null : () => open(raftSourceUrl),
        ),
        Text(
          raftSourceLicense,
          style: RaftTypography.mono(
            t,
            size: mono.fontSize,
            line: mono.lineHeight,
          ),
        ),
      ],
    );
  }
}

/// The phone's store, or null on a computer (Web `detectPhoneDevice`): by
/// platform, not width, so a folded tablet window is still a computer-sized
/// layout with a finger on it.
enum _Phone { android, ios }

_Phone? _phoneOf(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => _Phone.android,
  TargetPlatform.iOS => _Phone.ios,
  _ => null,
};

/// MobileAppDownloads: on a computer the QR code first with its sentence, then
/// the App Store, Google Play and APK as one line of links. On a phone that
/// phone's store as a button, the others as links, no QR.
class RaftAboutMobileDownloads extends StatelessWidget {
  const RaftAboutMobileDownloads({super.key, required this.app});
  final RaftAboutMobileApp app;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final open = RaftLinkScope.handlerOf(context);
    final phone = _phoneOf(Theme.of(context).platform);
    final ios = _Target(
      key: 'mobile-download-ios',
      label: raftText(context, 'Download on the App Store'),
      store: true,
      onPressed: app.onIos,
    );
    final googlePlay = _Target(
      key: 'mobile-download-google-play',
      label: raftText(context, 'Get it on Google Play'),
      store: true,
      onPressed: open == null ? null : () => open(raftGooglePlayUrl),
    );
    final apk = _Target(
      key: 'mobile-download-android',
      label: raftText(context, 'Download Android APK'),
      store: false,
      onPressed: app.onAndroid,
    );
    final links = Wrap(
      key: const ValueKey('mobile-download-links'),
      spacing: 16,
      runSpacing: 4,
      children: [
        for (final target in switch (phone) {
          _Phone.android => [ios, apk],
          _Phone.ios => [googlePlay, apk],
          null => [ios, googlePlay, apk],
        })
          target.link(context),
      ],
    );
    if (phone != null) {
      final store = phone == _Phone.android ? googlePlay : ios;
      return Column(
        key: ValueKey('mobile-download-${phone.name}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RaftButton(
            key: ValueKey(store.key),
            label: store.label,
            trailingGlyph: RaftGlyph.arrowUpRight,
            uiVariant: RaftButtonVariant.standard,
            uiSize: RaftButtonSize.md,
            onPressed: store.onPressed,
          ),
          const SizedBox(height: 12),
          links,
        ],
      );
    }
    final callout = t.typeSlot('callout');
    return Column(
      key: const ValueKey('mobile-download-computer'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          key: const ValueKey('mobile-download-qr-block'),
          children: [
            if (app.qrUrl != null) ...[
              RaftMobileDownloadQr(url: app.qrUrl!),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Text(
                raftText(context, "Scan with your phone's camera."),
                style: RaftTypography.inherited(
                  t,
                  size: callout.fontSize,
                  line: callout.lineHeight,
                  color: t.ui.foreground,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        links,
      ],
    );
  }
}

class _Target {
  const _Target({
    required this.key,
    required this.label,
    required this.store,
    required this.onPressed,
  });
  final String key, label;

  /// A store leaves Raft (new tab, the arrow); the APK is a download.
  final bool store;
  final VoidCallback? onPressed;

  Widget link(BuildContext context) => RaftTextLink(
    key: ValueKey(key),
    label: label,
    scale: RaftTypeScale.footnote,
    external: store,
    download: !store,
    externalLabel: store ? raftText(context, '(opens in a new tab)') : null,
    onPressed: onPressed,
  );
}

/// MobileDownloadQr.tsx: the code alone (`size-28 shrink-0 rounded-sticker
/// border border-line-hairline bg-sticker-paper p-1 text-sticker-ink`,
/// crisp-edged modules); the sentence beside it is the caller's. It encodes the
/// route with no `platform`: the phone that scans it is not this device.
class RaftMobileDownloadQr extends StatelessWidget {
  const RaftMobileDownloadQr({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final matrix = RaftQrMatrix.encode(url);
    return ExcludeSemantics(
      child: Container(
        key: const ValueKey('mobile-download-qr'),
        width: 112,
        height: 112,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: t.colors['sticker-paper'],
          border: Border.all(color: t.colors['line-hairline']!),
          borderRadius: t.corner('radius.sticker', fallback: 4),
        ),
        child: CustomPaint(
          painter: RaftQrCodePainter(matrix, t.colors['sticker-ink']!),
        ),
      ),
    );
  }
}
