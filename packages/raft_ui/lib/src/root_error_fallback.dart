// Web components/errors/RootErrorFallback.tsx: the page the app root shows
// when a render error escapes every other boundary. Presentation only: the
// app passes the error text and the reload action.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'raft_selection_area.dart';

import 'components.dart';
import 'css_pixel_snap.dart';
import 'design_primitives.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'theme.dart';
import 'raft/ui_tokens.dart';

/// RootErrorFallback: a `RootFallbackScroller` (full size, vertical scroll)
/// holding a `min-h-full` centred column (`bg-layer-canvas p-6 safe-top
/// safe-bottom`, brutal `bg-brutal-cream`) with one `max-w-2xl` Card
/// (`role="alert"`): header (title), message box, "Stack trace" disclosure
/// (closed), "Component stack" disclosure (open) and a right-aligned accent
/// "Reload app" button.
class RaftRootErrorFallback extends StatelessWidget {
  const RaftRootErrorFallback({
    super.key,
    required this.message,
    required this.onReload,
    this.stack,
    this.componentStack,
    this.componentStackOpen = true,
  });

  /// `error.message`. Empty hides the message box: a native app whose error
  /// text is a raw exception keeps it behind the "Stack trace" disclosure
  /// instead of printing it on the page.
  final String message;

  /// Web renders the component stack `<details open>`.
  final bool componentStackOpen;

  /// `error.stack`; null or empty hides the "Stack trace" disclosure.
  final String? stack;

  /// React `componentStack`; null or empty hides its disclosure.
  final String? componentStack;

  /// "Reload app" (`window.location.reload()` on Web).
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final safe = MediaQuery.paddingOf(context);
    final hasStack = stack != null && stack!.isNotEmpty;
    final hasComponents = componentStack != null && componentStack!.isNotEmpty;
    // v1.21.23 RootErrorFallback: a DS dialog card (16px radius, `p-5`, seam
    // ring + float shadow) with code boxes and a 44px pink button; the
    // pre-theme looks keep the a57b9dab card (rootError.look).
    if (t.option('rootError.look', or: 'web23') == 'web23') {
      return _web(context, t, safe, hasStack, hasComponents);
    }
    final card = Container(
      key: const ValueKey('root-error-card'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.panel,
        border: Border.all(color: t.semantic.lineMuted, width: t.border),
        borderRadius: BorderRadius.circular(8),
        boxShadow: t.themeShadows.lg.paintOrder,
      ),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // CardHeader `border-b px-6 py-4` (brutal: `border-b-2
            // border-black bg-soft-signal`; elegant keeps the recipe's
            // `has-[+content]:pb-0`).
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: t.semantic.lineMuted,
                    width: t.border,
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Semantics(
                  header: true,
                  child: Text(
                    raftText(context, 'Something went wrong'),
                    style: RaftTypography.heading(
                      t,
                      size: 20,
                      line: 28,
                      color: t.strong,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (message.isNotEmpty)
                    _ErrorBox(
                      key: const ValueKey('root-error-message'),
                      // `leading-relaxed` is 22.75px; Blink snaps the box edges to device
                      // pixels (the brutal 50.75px box paints 50, the elegant 48.75px
                      // box 49), so the line is rounded the same way.
                      child: Text(
                        message,
                        style: _mono(t, 14, _snapLine(context, t, 22.75)),
                      ),
                    ),
                  if (hasStack)
                    _ErrorDisclosure(
                      key: const ValueKey('root-error-stack'),
                      title: raftText(context, 'Stack trace'),
                      body: stack!,
                    ),
                  if (hasComponents)
                    _ErrorDisclosure(
                      key: const ValueKey('root-error-component-stack'),
                      title: raftText(context, 'Component stack'),
                      body: componentStack!,
                      initiallyOpen: componentStackOpen,
                    ),
                  const SizedBox(height: 8),
                  // `mt-6 flex justify-end` after the `mb-4` boxes.
                  Align(
                    alignment: Alignment.centerRight,
                    child: RaftButton(
                      key: const ValueKey('root-error-reload'),
                      label: raftText(context, 'Reload app'),
                      variant: RaftControlVariant.accent,
                      size: RaftButtonRecipeSize.md,
                      onPressed: onReload,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Material(
      color: t.canvas,
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
                // `p-6 safe-top safe-bottom`: `.safe-bottom` replaces the bottom 1.5rem
                // with inset + 1rem; `.safe-top` keeps the top 1.5rem.
                padding: EdgeInsets.fromLTRB(
                  24 + safe.left,
                  24 + safe.top,
                  24 + safe.right,
                  16 + safe.bottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 672),
                    child: RaftCssPixelSnap(
                      child: RaftSelectionArea(child: card),
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
}

extension on RaftRootErrorFallback {
  Widget _web(
    BuildContext context,
    RaftTokens t,
    EdgeInsets safe,
    bool hasStack,
    bool hasComponents,
  ) {
    final c = t.colors;
    Widget code(Widget child) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c['layer-code'],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.ui.lineHairline),
      ),
      child: child,
    );
    TextStyle mono({Color? color}) => RaftTypography.mono(
      t,
      size: 13,
      line: 20,
      color: color ?? c['foreground'],
    );
    Widget disclosure(String key, String title, String body, bool open) =>
        KeyedSubtree(
          key: ValueKey(key),
          child: code(
            _WebDisclosure(
              title: title,
              body: body,
              open: open,
              mono: mono(color: c['foreground-muted']),
              summary: RaftTypography.body(
                t,
                size: 13,
                line: 18,
                weight: FontWeight.w600,
                color: c['foreground'],
              ),
              marker: t.ui.foreground,
            ),
          ),
        );
    final card = Container(
      key: const ValueKey('root-error-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c['layer-popover'],
        borderRadius: BorderRadius.circular(
          t.size('radius.dialog', fallback: 16),
        ),
        border: Border.all(color: t.ui.lineSeam),
        boxShadow: t.themeShadows.lg.paintOrder,
      ),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                raftText(context, 'Something went wrong'),
                style: RaftTypography.body(
                  t,
                  size: 17,
                  line: 22,
                  weight: FontWeight.w700,
                  color: c['foreground'],
                ),
              ),
            ),
            if (message.isNotEmpty)
              KeyedSubtree(
                key: const ValueKey('root-error-message'),
                child: code(Text(message, style: mono())),
              ),
            if (hasStack)
              disclosure(
                'root-error-stack',
                raftText(context, 'Stack trace'),
                stack!,
                false,
              ),
            if (hasComponents)
              disclosure(
                'root-error-component-stack',
                raftText(context, 'Component stack'),
                componentStack!,
                componentStackOpen,
              ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: RaftButton(
                key: const ValueKey('root-error-reload'),
                label: raftText(context, 'Reload app'),
                variant: RaftControlVariant.accent,
                size: RaftButtonRecipeSize.lg,
                onPressed: onReload,
              ),
            ),
          ],
        ),
      ),
    );
    return Material(
      color: c['layer-canvas'],
      child: DefaultTextStyle.merge(
        style: TextStyle(fontFamily: t.bodyFont, color: c['foreground']),
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            primary: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: box.hasBoundedHeight ? box.maxHeight : 0,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24 + safe.left,
                  24 + safe.top,
                  24 + safe.right,
                  24 + safe.bottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 672),
                    child: RaftCssPixelSnap(
                      child: RaftSelectionArea(child: card),
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
}

/// `<details>` of the v1.21.23 fallback: a 13/18 600 summary with the native
/// marker and a `max-h-48` scrollable `<pre>` 8px below.
class _WebDisclosure extends StatefulWidget {
  const _WebDisclosure({
    required this.title,
    required this.body,
    required this.open,
    required this.mono,
    required this.summary,
    required this.marker,
  });
  final String title, body;
  final bool open;
  final TextStyle mono, summary;
  final Color marker;
  @override
  State<_WebDisclosure> createState() => _WebDisclosureState();
}

class _WebDisclosureState extends State<_WebDisclosure> {
  late bool open = widget.open;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RaftInteractive(
        semanticLabel: widget.title,
        onPressed: () => setState(() => open = !open),
        builder: (context, state) => Opacity(
          opacity: state.pressed ? .6 : 1,
          child: Row(
            children: [
              SizedBox(
                width: 13,
                height: 18,
                child: CustomPaint(
                  painter: _DisclosureMarker(open: open, color: widget.marker),
                ),
              ),
              Expanded(child: Text(widget.title, style: widget.summary)),
            ],
          ),
        ),
      ),
      if (open) ...[
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 192),
          child: SingleChildScrollView(
            primary: false,
            child: Text(widget.body, style: widget.mono),
          ),
        ),
      ],
    ],
  );
}

double _snapLine(BuildContext context, RaftTokens t, double line) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  if (dpr > 1) return line;
  return (line * dpr).ceil() / dpr;
}

TextStyle _mono(RaftTokens t, double size, double line) =>
    RaftTypography.mono(t, size: size, line: line, color: t.strong);

/// `mb-4 rounded-md border border-line-muted bg-layer-inset p-3` (brutal:
/// `border-2 border-black bg-white`).
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: t.semantic.layerInset,
          border: Border.all(color: t.semantic.lineMuted, width: t.border),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}

/// `<details>`: bold `<summary>` toggling a `max-h-48` scrollable `<pre>`.
class _ErrorDisclosure extends StatefulWidget {
  const _ErrorDisclosure({
    super.key,
    required this.title,
    required this.body,
    this.initiallyOpen = false,
  });
  final String title, body;
  final bool initiallyOpen;

  @override
  State<_ErrorDisclosure> createState() => _ErrorDisclosureState();
}

class _ErrorDisclosureState extends State<_ErrorDisclosure> {
  late bool open = widget.initiallyOpen;
  final tap = TapGestureRecognizer();

  @override
  void dispose() {
    tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return _ErrorBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftInteractive(
            semanticLabel: widget.title,
            onPressed: () => setState(() => open = !open),
            builder: (context, state) => Opacity(
              opacity: state.pressed ? .6 : 1,
              child: Row(
                children: [
                  // The native disclosure marker: a 7px triangle, 6px before
                  // the title.
                  SizedBox(
                    width: 13,
                    height: 16,
                    child: CustomPaint(
                      painter: _DisclosureMarker(open: open, color: t.strong),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: RaftTypography.heading(
                        t,
                        size: 12,
                        line: 16,
                        color: t.strong,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (open) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 192),
              child: SingleChildScrollView(
                primary: false,
                child: Text(
                  widget.body,
                  style: _mono(t, 12, 16).copyWith(color: t.muted),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DisclosureMarker extends CustomPainter {
  const _DisclosureMarker({required this.open, required this.color});
  final bool open;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final top = (size.height - 7) / 2;
    final path = Path();
    if (open) {
      path
        ..moveTo(0, top + .5)
        ..lineTo(7, top + .5)
        ..lineTo(3.5, top + 7);
    } else {
      path
        ..moveTo(0, top)
        ..lineTo(7, top + 3.5)
        ..lineTo(0, top + 7);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_DisclosureMarker old) =>
      old.open != open || old.color != color;
}
