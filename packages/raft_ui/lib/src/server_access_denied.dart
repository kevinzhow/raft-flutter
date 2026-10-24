// Web App.tsx ServerAccessDeniedPage: the page an unknown or forbidden
// `/s/<slug>` shows before it redirects to the user's own server. Presentation
// only: the app owns the fallback server, the 3 second timer and navigation.
import 'package:flutter/material.dart';

import 'components.dart';
import 'css_pixel_snap.dart';
import 'design_primitives.dart';
import 'localization.dart';
import 'page_tokens.dart';
import 'recipes/button_variants.g.dart';
import 'theme.dart';

/// `flex min-h-0 flex-1 items-center justify-center bg-layer-canvas px-4
/// font-display safe-top safe-bottom theme-brutal:bg-brutal-cream` around one
/// `max-w-md` Card (`p-6`): "Server not found" h1, the redirect sentence
/// (the fallback server name in bold, or "your server list") and one outline
/// button.
class RaftServerAccessDeniedPage extends StatelessWidget {
  const RaftServerAccessDeniedPage({
    super.key,
    required this.onContinue,
    this.serverName,
  });

  /// The fallback server's name; null when the user has none to go to.
  final String? serverName;

  /// "Go to my server" / "Choose a server".
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final safe = MediaQuery.paddingOf(context);
    final body = RaftTypography.heading(
      t,
      size: 14,
      line: t.size('type.notFoundBody.line', fallback: 20),
      weight: FontWeight.w400,
      color: t.muted,
    );
    final description = serverName == null
        ? TextSpan(
            text: raftText(
              context,
              'Redirecting to your server list in 3 seconds.',
            ),
          )
        : _withName(
            raftText(context, 'Redirecting to <name></name> in 3 seconds.'),
            serverName!,
            body.copyWith(fontWeight: FontWeight.w700),
          );
    final card = Container(
      key: const ValueKey('server-denied-card'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: t.panel,
        border: Border.all(color: t.semantic.lineMuted, width: t.border),
        borderRadius: BorderRadius.circular(8),
        boxShadow: t.themeShadows.md.paintOrder,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              raftText(context, 'Server not found'),
              style: RaftTypography.heading(
                t,
                size: t.size('type.notFoundTitle.size', fallback: 22),
                line: t.size('type.notFoundTitle.line', fallback: 28),
                weight: RaftTypography.black(t),
                color: t.strong,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text.rich(description, style: body),
          const SizedBox(height: 20),
          RaftButton(
            key: const ValueKey('server-denied-continue'),
            label: raftText(
              context,
              serverName == null ? 'Choose a Server' : 'Go to My Server',
            ),
            variant: RaftControlVariant.outline,
            size: t.option('standalone.buttonSize', or: 'lg') == 'lg'
                ? RaftButtonRecipeSize.lg
                : RaftButtonRecipeSize.md,
            onPressed: onContinue,
          ),
        ],
      ),
    );
    return Material(
      color: t.standaloneSurface,
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontFamily: t.headingFont,
          color: t.semantic.foreground,
        ),
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            primary: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: box.hasBoundedHeight ? box.maxHeight : 0,
              ),
              child: Padding(
                // `px-4 safe-top safe-bottom` (`.safe-bottom` = inset + 1rem).
                padding: EdgeInsets.fromLTRB(
                  16 + safe.left,
                  safe.top,
                  16 + safe.right,
                  safe.bottom + 16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 448),
                    child: RaftCssPixelSnap(
                      child: SizedBox(width: double.infinity, child: card),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Splits an ICU-style `before<name></name>after` catalog string around the
  /// bold server name.
  static InlineSpan _withName(String template, String name, TextStyle bold) {
    const marker = '<name></name>';
    final at = template.indexOf(marker);
    if (at < 0) return TextSpan(text: template);
    return TextSpan(
      children: [
        TextSpan(text: template.substring(0, at)),
        TextSpan(text: name, style: bold),
        TextSpan(text: template.substring(at + marker.length)),
      ],
    );
  }
}
