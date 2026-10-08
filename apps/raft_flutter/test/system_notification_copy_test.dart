import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/system_notification_projection.dart';
import 'package:raft_flutter/features/system_notification_copy.dart';

void main() {
  Future<SystemNotificationCopy> copy(
    WidgetTester t,
    SystemNotice n,
    String locale,
  ) async {
    late SystemNotificationCopy result;
    await t.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) {
            result = systemNotificationCopy(context, n);
            return Text(result.body);
          },
        ),
      ),
    );
    await t.pump();
    return result;
  }

  SystemNotice notice(String id, Map<String, Object?> values) => SystemNotice(
    id: id,
    kind: SystemNoticeKind.warning,
    title: 'Computers need attention',
    body: 'Original fixture body',
    destination: SystemNoticeDestination.computer,
    parameters: values,
  );
  testWidgets('source plural branches preserve raw private names in Chinese', (
    t,
  ) async {
    final n = notice('machine-offline', {
      'count': 2,
      'names': 'Search, {count}',
      'active': 2,
    });
    final zh = await copy(t, n, 'zh');
    expect(zh.title, '共 2 台 Computer 离线：Search, {count}');
    expect(zh.body, '2 个 Agent 正在这台计算机上运行，重连前无法继续。');
    final en = await copy(t, n, 'en');
    expect(en.title, 'Search, {count} are offline');
    expect(
      en.body,
      "2 agents are active on this computer and can't run until it reconnects.",
    );
  });
  testWidgets(
    'attention omits zero counts and preserves upgrade before offline',
    (t) async {
      final zh = await copy(
        t,
        notice('computer-attention', {'upgrade': 1, 'offline': 2}),
        'zh',
      );
      expect(zh.body, '1 台需要升级 · 2 台离线');
      final en = await copy(
        t,
        notice('computer-attention', {'upgrade': 0, 'offline': 1}),
        'en',
      );
      expect(en.body, '1 offline');
    },
  );
  testWidgets(
    'source single disk Chinese count and truncated percent stay explicit',
    (t) async {
      final zh = await copy(
        t,
        notice('machine-disk-low', {
          'count': 1,
          'free': '1.0 GB',
          'percent': 1.2,
        }),
        'zh',
      );
      expect(zh.title, '你添加的 1 台计算机磁盘空间不足');
      expect(zh.body, '剩余 1.0 GB（1.2%）。腾出空间之前，Agent 可能无法保存工作或启动。');
    },
  );
  testWidgets(
    'plan grace uses source bold count without translating interpolated copy',
    (t) async {
      final n = SystemNotice(
        id: 'plan-downgrade',
        kind: SystemNoticeKind.warning,
        title: 'Plan downgraded to Free',
        body: '5 days left to reduce resources or upgrade.',
        destination: SystemNoticeDestination.billing,
        parameters: const {'expired': false, 'count': 5},
      );
      final zh = await copy(t, n, 'zh');
      expect(zh.title, '套餐已降级为 Free');
      expect(zh.body, '还剩 5 天，请减少资源或升级。');
      final span = (zh.bodyContent! as Text).textSpan! as TextSpan;
      expect(
        (span.children![1] as TextSpan).style!.fontWeight,
        FontWeight.w700,
      );
    },
  );
}
