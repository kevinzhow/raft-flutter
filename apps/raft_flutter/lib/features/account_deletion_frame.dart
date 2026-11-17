// The frame of the pages that stand in for the app while an account deletion
// is requested or pending (Web pages/AccountDeletionFrame.tsx: the sign-in
// page's frame, and `AccountDeletionHeading`, their top: a yellow sticker with
// the page's icon, the title, and a line under it), and how the deletion pages
// write the deletion date and the days left (features/settings/account/
// deleteAccountFlow.ts).
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web metrics (Tailwind steps) that [RaftSpace] has no step for.
abstract final class AccountDeletionMetrics {
  /// `gap-2.5`.
  static const double gap10 = 10;

  /// `py-3.5`, a checklist row.
  static const double rowPadding = 14;

  /// `size-14`, the heading sticker.
  static const double sticker = 56;

  /// `size-[9px]`, the attention dot.
  static const double dot = 9;

  /// `border-[1.5px]`.
  static const double edge = 1.5;

  /// The Make owner select, `min-w-40` and `sm:max-w-60`.
  static const double selectMin = 160, selectMax = 240;
}

class AccountDeletionFrame extends StatelessWidget {
  const AccountDeletionFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => RaftAuthShell(child: child);
}

/// Web `AccountDeletionHeading`: `size-14` sticker (rounded, ink edge, the
/// `you` yellow) holding a 28px icon, then the balanced title and a line.
class AccountDeletionHeading extends StatelessWidget {
  const AccountDeletionHeading({
    super.key,
    required this.glyph,
    required this.title,
    this.subtitle,
    this.subtitleSpan,
  });
  final RaftGlyph glyph;
  final String title;
  final String? subtitle;

  /// The line under the title with a styled run (the date in bold).
  final InlineSpan? subtitleSpan;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ink = t.colors['sticker-ink']!;
    final radius = t.size('radius.sticker', fallback: 4);
    final subtitleStyle = RaftTypography.heading(
      t,
      size: t.size('type.authDescription.size', fallback: 15),
      line: t.size('type.authDescription.line', fallback: 20),
      weight: FontWeight.w400,
    ).copyWith(color: t.muted);
    return Padding(
      padding: const EdgeInsets.only(bottom: RaftSpace.x5),
      child: Column(
        children: [
          Container(
            key: const ValueKey('account-deletion-sticker'),
            width: AccountDeletionMetrics.sticker,
            height: AccountDeletionMetrics.sticker,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.colors['you'],
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: ink,
                width: AccountDeletionMetrics.edge,
              ),
              boxShadow: [
                BoxShadow(color: t.colors['sticker-edge']!, spreadRadius: 1.5),
              ],
            ),
            child: ExcludeSemantics(
              child: RaftIcon(glyph, size: 28, color: ink, strokeWidth: 2),
            ),
          ),
          const SizedBox(height: RaftSpace.x5),
          Text(
            title,
            textAlign: TextAlign.center,
            style: RaftTypography.heading(
              t,
              size: t.size('type.authTitle.size', fallback: 22),
              line: t.size('type.authTitle.line', fallback: 28),
            ).copyWith(color: t.semantic.foreground),
          ),
          if (subtitleSpan != null) ...[
            const SizedBox(height: RaftSpace.x2),
            Text.rich(
              subtitleSpan!,
              textAlign: TextAlign.center,
              style: subtitleStyle,
            ),
          ] else if (subtitle != null) ...[
            const SizedBox(height: RaftSpace.x2),
            Text(subtitle!, textAlign: TextAlign.center, style: subtitleStyle),
          ],
        ],
      ),
    );
  }
}

/// The deletion date as v7 writes it, the day alone ("November 9"), in the
/// person's time zone; "" for none. The date always comes from the server's
/// `scheduledFor`, never from a grace period counted here (Web
/// `useDeletionDate`).
String accountDeletionDate(BuildContext context, String? scheduledFor) {
  final at = scheduledFor == null ? null : DateTime.tryParse(scheduledFor);
  if (at == null) return '';
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.MMMMd(locale).format(at.toLocal());
}

const _day = Duration(days: 1);

/// Whole days until [scheduledFor], rounded up (a deletion later today is 1
/// day away); null for none (Web `daysUntilDeletion`).
int? daysUntilDeletion(String? scheduledFor, DateTime now) {
  final at = scheduledFor == null ? null : DateTime.tryParse(scheduledFor);
  if (at == null) return null;
  final left = at.difference(now).inMicroseconds / _day.inMicroseconds;
  final days = left.ceil();
  return days < 0 ? 0 : days;
}

/// One plural-aware catalog line: the English source of each variant is its
/// own key (the catalog does not interpret ICU), the Chinese is the same.
String accountDeletionCount(
  BuildContext context,
  int count,
  String one,
  String other, [
  Map<String, Object?> values = const {},
]) =>
    raftFormat(context, count == 1 ? one : other, {'count': count, ...values});

/// [template] with `{date}` set in [style] (bold on the confirmation).
TextSpan accountDeletionDateSpan(
  String template,
  String date,
  TextStyle style,
) {
  final at = template.indexOf('{date}');
  if (at < 0) return TextSpan(text: template);
  return TextSpan(
    children: [
      TextSpan(text: template.substring(0, at)),
      TextSpan(text: date, style: style),
      TextSpan(text: template.substring(at + '{date}'.length)),
    ],
  );
}

/// `Intl.ListFormat` conjunction for the server names.
String accountDeletionList(BuildContext context, List<String> names) {
  if (Localizations.localeOf(context).languageCode == 'zh') {
    return names.join('、');
  }
  return switch (names.length) {
    0 => '',
    1 => names.single,
    2 => '${names[0]} and ${names[1]}',
    _ => '${names.take(names.length - 1).join(', ')}, and ${names.last}',
  };
}
