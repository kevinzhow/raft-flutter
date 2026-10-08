import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/system_notification_projection.dart';

/// Fixed source templates are localized before private values are inserted.
/// The source's ICU branches are selected explicitly; names never enter a
/// translation lookup, and no projected copy is persisted.
class SystemNotificationCopy {
  const SystemNotificationCopy(this.title, this.body, {this.bodyContent});
  final String title, body;
  final Widget? bodyContent;
}

bool _dateSymbolsReady = false;
SystemNotificationCopy systemNotificationCopy(
  BuildContext context,
  SystemNotice notice,
) {
  final p = notice.parameters;
  final zh = Localizations.localeOf(context).languageCode == 'zh';
  final locale = zh ? 'zh_CN' : 'en';
  String text(String key) => raftText(context, key);
  String format(String key, Map<String, Object?> values) =>
      raftFormat(context, key, values);
  Object count(Object? value) =>
      zh ? value ?? 0 : NumberFormat.decimalPattern(locale).format(value ?? 0);
  switch (notice.id) {
    case 'plan-downgrade':
      if (p['expired'] == true) {
        return SystemNotificationCopy(text(notice.title), text(notice.body));
      }
      final days = p['count'] as int? ?? 0;
      final bold = zh
          ? '$days 天'
          : '${count(days)} ${days == 1 ? 'day' : 'days'}';
      final prefix = zh ? '还剩 ' : '';
      final suffix = zh
          ? '，请减少资源或升级。'
          : ' left to reduce resources or upgrade.';
      return SystemNotificationCopy(
        text(notice.title),
        '$prefix$bold$suffix',
        bodyContent: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: prefix),
              TextSpan(
                text: bold,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: suffix),
            ],
          ),
        ),
      );
    case 'computer-attention':
      final upgrade = p['upgrade'] as int? ?? 0;
      final offline = p['offline'] as int? ?? 0;
      return SystemNotificationCopy(
        text(notice.title),
        [
          if (upgrade > 0)
            format(
              upgrade == 1 ? '{count} needs upgrade' : '{count} need upgrade',
              {'count': count(upgrade)},
            ),
          if (offline > 0) format('{count} offline', {'count': count(offline)}),
        ].join(' · '),
      );
    case 'machine-offline':
      final number = p['count'] as int? ?? 0;
      final active = p['active'] as int? ?? 0;
      return SystemNotificationCopy(
        format(number == 1 ? '{names} is offline' : '{names} are offline', {
          'count': number,
          'names': p['names'],
        }),
        active == 0
            ? text(notice.body)
            : format(
                active == 1
                    ? "{count} agent is active on this computer and can't run until it reconnects."
                    : "{count} agents are active on this computer and can't run until it reconnects.",
                {'count': count(active)},
              ),
      );
    case 'machine-disk-low':
      final number = p['count'] as int? ?? 0;
      return SystemNotificationCopy(
        format(
          number == 1
              ? 'A computer you added is low on disk space'
              : '{count} computers you added are low on disk space',
          {'count': count(number)},
        ),
        format(
          '{free} free ({percent}%). Agents may fail to save work or start until space is freed.',
          {'free': p['free'], 'percent': p['percent']},
        ),
      );
    case 'feedback-replies':
      final number = p['count'] as int? ?? 0;
      return SystemNotificationCopy(
        text(notice.title),
        format(
          number == 1
              ? '{count} feedback conversation has unread replies.'
              : '{count} feedback conversations have unread replies.',
          {'count': count(number)},
        ),
      );
  }
  if (notice.id.startsWith('joint-over-limit:')) {
    if (!_dateSymbolsReady) {
      unawaited(initializeDateFormatting());
      _dateSymbolsReady = true;
    }
    final raw = '${p['deadline'] ?? ''}';
    final date = DateTime.tryParse(raw)?.toLocal();
    final deadline = date == null
        ? raw
        : '${DateFormat.yMMMd(locale).format(date)} ${DateFormat.jm(locale).format(date)}';
    final locked = p['locked'] == true;
    return SystemNotificationCopy(
      format(
        locked ? '#{channel} is read-only' : '#{channel} will become read-only',
        {'channel': p['channel']},
      ),
      format(
        locked
            ? "This Joint Channel is read-only because it has more than 2 free servers. It becomes writable again when one server's admin upgrades or a free server leaves."
            : "This Joint Channel has more than 2 free servers and becomes read-only on {deadline}. To keep it writable, one server's admin needs to upgrade, or a free server needs to leave.",
        {'deadline': deadline},
      ),
    );
  }
  // Unknown projections retain original copy, never lookup interpolated data.
  return SystemNotificationCopy(notice.title, notice.body);
}
