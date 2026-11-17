import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/web_billing.dart';

void main() {
  const coordinator = 'https://api.raft.build';

  test('opens the server Plan & Billing page on the paired Web', () {
    final uri = webBillingUri(coordinator: coordinator, slug: 'acme');
    expect(uri.toString(), 'https://app.raft.build/s/acme/settings/billing');
  });

  test('a paywall gate reopens the Web upgrade dialog at its first step', () {
    final uri = webBillingUri(
      coordinator: coordinator,
      slug: 'acme',
      gate: WebBillingGate.history,
    );
    expect(uri.path, '/s/acme/settings/billing');
    expect(uri.queryParameters, {
      'upgrade': 'history_30d',
      'upgradeCanceled': '1',
    });
  });

  test('an unknown gate is dropped, as Web isUpgradeGate drops it', () {
    final uri = webBillingUri(
      coordinator: coordinator,
      slug: 'acme',
      gate: 'seat_limit_invite',
    );
    expect(uri.hasQuery, isFalse);
  });

  test('without a server slug the Web root opens', () {
    expect(webBillingUri(coordinator: coordinator, slug: null).path, '/');
  });

  test(
    'openWebBilling launches the page and reports a failed launch',
    () async {
      final opened = <Uri>[];
      webBillingLauncher = (uri) async {
        opened.add(uri);
        return true;
      };
      addTearDown(() => webBillingLauncher = (_) async => false);
      expect(
        await openWebBilling(
          coordinator: coordinator,
          slug: 'acme',
          gate: WebBillingGate.uploadFileSize,
        ),
        isTrue,
      );
      expect(opened.single.queryParameters['upgrade'], 'upload_file_size');
      webBillingLauncher = (_) => throw StateError('no browser');
      expect(
        await openWebBilling(coordinator: coordinator, slug: 'acme'),
        isFalse,
      );
    },
  );
}
