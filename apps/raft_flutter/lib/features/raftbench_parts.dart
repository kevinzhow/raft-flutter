// Shared pieces of the RaftBench page (Web packages/web/src/raftbench): the
// text steps its Tailwind classes name, locale formats, the Card and the
// native `<details>` disclosure the page uses.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:raft_ui/raft_ui.dart';

/// `text-display`, `text-title`, `text-headline`, `text-callout`,
/// `text-footnote`, `text-caption`, `text-mono-meta` (raft-ui 0.7.0 scale),
/// in the page's inherited font. Colors default to `text-foreground`.
class RaftbenchType {
  RaftbenchType(this.t);
  final RaftTokens t;

  Color get hint => t.colors['foreground-hint']!;
  Color get brand => t.colors['primary-400']!;
  Color get danger => t.colors['danger-strong']!;
  Color get warning => t.colors['warning-strong']!;

  TextStyle _base(
    double size,
    double line,
    FontWeight weight, {
    double tracking = 0,
    Color? color,
  }) => RaftTypography.inherited(
    t,
    size: size,
    line: line,
    weight: weight,
    color: color ?? t.ink,
  ).copyWith(letterSpacing: size * tracking);

  TextStyle body({FontWeight weight = FontWeight.w400, Color? color}) =>
      _base(16, 24, weight, color: color);
  TextStyle display({Color? color}) =>
      _base(34, 40, FontWeight.w700, tracking: -.02, color: color);
  TextStyle title({Color? color}) =>
      _base(22, 28, FontWeight.w700, tracking: -.01, color: color);
  TextStyle headline({Color? color}) =>
      _base(17, 22, FontWeight.w700, color: color);
  TextStyle callout({FontWeight weight = FontWeight.w400, Color? color}) =>
      _base(14, 20, weight, color: color);
  TextStyle footnote({FontWeight weight = FontWeight.w400, Color? color}) =>
      _base(13, 18, weight, color: color);
  TextStyle caption({FontWeight weight = FontWeight.w500, Color? color}) =>
      _base(12, 16, weight, color: color);
  TextStyle monoMeta({Color? color}) =>
      RaftTypography.mono(t, size: 12, line: 16, color: color ?? hint);
}

/// `react-intl` formats with the page's defaults: numeric date, `h:mm` time.
class RaftbenchFormat {
  RaftbenchFormat(BuildContext context)
    : locale = Localizations.localeOf(context)
          .toLanguageTag()
          .replaceAll('-', '_');
  final String locale;

  String number(num value, {int maximumFractionDigits = 3}) =>
      (NumberFormat.decimalPattern(
        locale,
      )..maximumFractionDigits = maximumFractionDigits).format(value);

  /// `formatDate`: 10/24/2026 (en), 2026/10/24 (zh).
  String date(DateTime value) => DateFormat.yMd(locale).format(value.toLocal());

  /// `formatTime(value, {hour: "numeric", minute: "2-digit"})`.
  String time(DateTime value) => DateFormat.jm(locale).format(value.toLocal());

  /// `formatTime(value, {hour, minute, second: "2-digit"})`.
  String timeSeconds(DateTime value) => locale.startsWith('zh')
      ? DateFormat('HH:mm:ss', locale).format(value.toLocal())
      : DateFormat('hh:mm:ss a', locale).format(value.toLocal());

  String stamp(String iso) {
    final value = DateTime.tryParse(iso);
    return value == null ? iso : '${date(value)} ${time(value)}';
  }

  /// `formatUsdAmount`: dollars with cents; a positive amount under a cent
  /// reads "under $0.01", never "$0.00".
  String usd(double amount, String below) {
    final format = NumberFormat.simpleCurrency(
      locale: locale,
      name: 'USD',
      decimalDigits: 2,
    );
    return amount > 0 && amount < .01
        ? below.replaceAll('{amount}', format.format(.01))
        : format.format(amount);
  }
}

/// A raft-ui `Card` with the page's padding (`p-4 md:p-5`).
class RaftbenchCard extends StatelessWidget {
  const RaftbenchCard({
    super.key,
    required this.child,
    this.padded = true,
    this.color,
    this.clip = false,
    this.transparentBorder = false,
  });
  final Widget child;
  final bool padded, clip, transparentBorder;
  final Color? color;

  /// `p-4 md:p-5`.
  static double inset(BuildContext context) =>
      raftBreakpointWidth(context) >= 768 ? 20 : 16;

  @override
  Widget build(BuildContext context) => RaftRecipeCard(
    padding: padded ? EdgeInsets.all(inset(context)) : EdgeInsets.zero,
    background: color,
    clip: clip,
    transparentBorder: transparentBorder,
    child: child,
  );
}

/// The page's Button: raft-ui `Button` (default variant), size sm unless
/// said otherwise.
class RaftbenchButton extends StatelessWidget {
  const RaftbenchButton(
    this.label, {
    super.key,
    this.onPressed,
    this.small = false,
    this.variant = RaftButtonRecipeVariant.default_,
    this.expand = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool small, expand;
  final RaftButtonRecipeVariant variant;

  @override
  Widget build(BuildContext context) => RaftButton(
    label: label,
    onPressed: onPressed,
    tone: variant,
    size: small ? RaftButtonRecipeSize.sm : RaftButtonRecipeSize.md,
    visualHeight: small ? RaftMetrics.buttonSm : RaftMetrics.buttonMd,
    expand: expand,
  );
}

/// A `<details>` / `<summary>` pair: the native disclosure triangle, then the
/// summary, content below when open.
class RaftbenchDetails extends StatefulWidget {
  const RaftbenchDetails({
    super.key,
    required this.summary,
    required this.child,
    this.initiallyOpen = false,
    this.open,
    this.onToggle,
    this.summaryStyle,
  });
  final Widget summary;
  final Widget child;
  final bool initiallyOpen;

  /// A controlled value (Web `open={...}`), overriding the toggle state until
  /// the user toggles it.
  final bool? open;
  final ValueChanged<bool>? onToggle;
  final TextStyle? summaryStyle;

  @override
  State<RaftbenchDetails> createState() => _RaftbenchDetailsState();
}

class _RaftbenchDetailsState extends State<RaftbenchDetails> {
  late bool open = widget.open ?? widget.initiallyOpen;

  @override
  void didUpdateWidget(covariant RaftbenchDetails old) {
    super.didUpdateWidget(old);
    // React sets the `open` attribute only when the prop changes.
    if (widget.open != null && widget.open != old.open) open = widget.open!;
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = widget.summaryStyle ?? DefaultTextStyle.of(context).style;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          expanded: open,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => open = !open);
              widget.onToggle?.call(open);
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    // The marker sits on the first line's baseline box.
                    padding: EdgeInsets.only(
                      top:
                          ((style.height ?? 1.4) * (style.fontSize ?? 14) - 8) /
                          2,
                      right: 6,
                    ),
                    child: CustomPaint(
                      size: const Size(8, 8),
                      painter: _TrianglePainter(
                        open: open,
                        color: style.color ?? t.ink,
                      ),
                    ),
                  ),
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: widget.summaryStyle,
                      child: widget.summary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (open) widget.child,
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter({required this.open, required this.color});
  final bool open;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (open) {
      path
        ..moveTo(0, 1.5)
        ..lineTo(size.width, 1.5)
        ..lineTo(size.width / 2, size.height - 1)
        ..close();
    } else {
      path
        ..moveTo(1.5, 0)
        ..lineTo(size.width - 1, size.height / 2)
        ..lineTo(1.5, size.height)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) =>
      old.open != open || old.color != color;
}

/// A bar `h-1.5` / `h-2` with a rounded track and a fill.
class RaftbenchBar extends StatelessWidget {
  const RaftbenchBar({
    super.key,
    required this.height,
    required this.track,
    required this.fill,
    required this.fraction,
    this.pulse = false,
  });
  final double height, fraction;
  final Color track, fill;

  /// An indeterminate third-width fill that pulses (`animate-pulse`).
  final bool pulse;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: ColoredBox(
      color: track,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: fraction.clamp(0, 1).toDouble(),
          child: pulse
              ? _Pulse(child: ColoredBox(color: fill))
              : ColoredBox(color: fill),
        ),
      ),
    ),
  );
}

/// Tailwind `animate-pulse` (2s, opacity 1 -> .5), stopped by reduced motion.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.stop();
    } else if (!controller.isAnimating) {
      // ignore: raft_lints/avoid_unreviewed_idle_work -- Tailwind animate-pulse on the indeterminate bar: a State-vsync controller (stops with TickerMode) that is stopped under reduced motion.
      controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 1, end: .5).animate(controller),
    child: widget.child,
  );
}
