// Web pages/ChineseCommunityPage.tsx: "Scan the QR code to join", one WeChat
// QR code in a card. Presentation only: the app fetches the QR configuration
// and chooses the state.
import 'package:flutter/material.dart';

import 'css_pixel_snap.dart';
import 'design_primitives.dart';
import 'localization.dart';
import 'theme.dart';
import 'tokens/shadows.g.dart' show RaftProductShadows;

/// What the QR box shows.
enum RaftChineseCommunityQr {
  /// The configuration is being read (a pulsing square).
  loading,

  /// The QR [RaftChineseCommunityPage.image] is shown.
  image,

  /// [RaftChineseCommunityPage.unavailable] says why there is no QR code.
  unavailable,
}

/// `main.h-dvh bg-layer-sidebar px-4 font-display safe-top safe-bottom` around
/// a `max-w-sm` column: the `text-title sm:text-display` h1 and a `Card`
/// (`w-full max-w-[20rem] p-3 sm:p-4`) holding the square QR box.
class RaftChineseCommunityPage extends StatelessWidget {
  const RaftChineseCommunityPage({
    super.key,
    required this.state,
    this.image,
    this.unavailable = '',
    this.leading,
  });
  final RaftChineseCommunityQr state;

  /// The QR picture (`object-contain`, pixelated), for [RaftChineseCommunityQr.image].
  final Widget? image;

  /// Catalog source text of the reason ("The QR code is not configured yet..."),
  /// for [RaftChineseCommunityQr.unavailable].
  final String unavailable;

  /// A native page has no browser Back: the app's Back affordance, top left.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final safe = MediaQuery.paddingOf(context);
    final wide = MediaQuery.sizeOf(context).width >= 640;
    final black = const Color(0xFF000000);
    final box = AspectRatio(
      aspectRatio: 1,
      child: Container(
        key: const ValueKey('chinese-community-qr-box'),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.brutal ? t.product.brutalCream : t.canvas,
          border: Border.all(
            color: t.brutal ? black : t.semantic.lineMuted,
            width: t.border,
          ),
          borderRadius: BorderRadius.circular(t.brutal ? 0 : 6),
        ),
        child: switch (state) {
          RaftChineseCommunityQr.loading => Container(
            key: const ValueKey('chinese-community-qr-loading'),
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: t.colors['fill-muted'] ?? t.semantic.lineMuted,
              borderRadius: BorderRadius.circular(t.brutal ? 0 : 6),
            ),
          ),
          RaftChineseCommunityQr.image => SizedBox.expand(
            key: const ValueKey('chinese-community-qr-image'),
            child: image,
          ),
          RaftChineseCommunityQr.unavailable => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Semantics(
              liveRegion: true,
              child: Text(
                raftText(context, unavailable),
                key: const ValueKey('chinese-community-qr-missing'),
                textAlign: TextAlign.center,
                style: RaftTypography.heading(
                  t,
                  size: 14,
                  line: 20,
                  weight: FontWeight.w600,
                  color: t.muted,
                ),
              ),
            ),
          ),
        },
      ),
    );
    final card = Semantics(
      container: true,
      label: raftText(context, 'WeChat QR code'),
      child: Container(
        key: const ValueKey('chinese-community-card'),
        constraints: const BoxConstraints(maxWidth: 320),
        padding: EdgeInsets.all(wide ? 16 : 12),
        decoration: BoxDecoration(
          color: t.brutal ? const Color(0xFFFFFFFF) : t.panel,
          border: Border.all(
            color: t.brutal ? black : t.semantic.lineMuted,
            width: t.border,
          ),
          borderRadius: BorderRadius.circular(t.brutal ? 0 : 8),
          boxShadow: t.brutal
              ? RaftProductShadows.shadowBrutal.paintOrder
              : t.themeShadows.md.paintOrder,
        ),
        child: box,
      ),
    );
    return Material(
      color: t.brutal ? t.product.brutalCream : t.canvas,
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontFamily: t.headingFont,
          color: t.semantic.foreground,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16 + safe.left,
                  safe.top,
                  16 + safe.right,
                  safe.bottom + 16,
                ),
                child: Center(
                  child: SingleChildScrollView(
                    primary: false,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 384),
                      child: RaftCssPixelSnap(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                raftText(context, 'Scan the QR code to join'),
                                textAlign: TextAlign.center,
                                style: RaftTypography.heading(
                                  t,
                                  size: wide ? 30 : 24,
                                  line: wide ? 36 : 32,
                                  weight: RaftTypography.black(t),
                                  color: t.brutal ? black : t.strong,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            card,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (leading != null)
              Positioned(
                left: 8 + safe.left,
                top: 8 + safe.top,
                child: leading!,
              ),
          ],
        ),
      ),
    );
  }
}
