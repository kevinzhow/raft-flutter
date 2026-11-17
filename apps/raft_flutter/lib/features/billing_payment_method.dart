// Web PlanSectionContent `PaymentMethodItem`: the Billing card's Payment
// method row (owners): what Stripe charges, read when the card shows
// (GET /billing/payment-method, an outside system). Left out when Stripe
// can't say. The last answer is kept for a revisit and read again in the
// background.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'management_support.dart';

/// Builds the Billing card's list with the payment-method row between
/// [before] (billed, renews) and [after] (seats) entries.
typedef BillingPaymentMethodBuilder = Widget Function(
  List<RaftDescriptionEntry> before,
  List<RaftDescriptionEntry> after,
);

const billingPaymentMethodPath = '/billing/payment-method';
const _snapshotKey = 'billing-payment-method';

class BillingPaymentMethodList extends StatefulWidget {
  const BillingPaymentMethodList({
    super.key,
    required this.controller,
    required this.before,
    required this.after,
  });
  final WorkspaceController controller;
  final List<RaftDescriptionEntry> before, after;

  @override
  State<BillingPaymentMethodList> createState() => _PaymentMethodState();
}

enum _Read { loading, ready, failed }

class _PaymentMethodState extends State<BillingPaymentMethodList> {
  WorkspaceController get w => widget.controller;
  _Read read = _Read.loading;
  Map<String, dynamic>? method;
  bool disposed = false;

  @override
  void initState() {
    super.initState();
    final kept = readPageSnapshot(w, _snapshotKey);
    if (kept != null) {
      read = _Read.ready;
      method = kept['method'] as Map<String, dynamic>?;
    }
    unawaited(load());
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    final identity = pageIdentity(w);
    try {
      final data = await w.client.get(billingPaymentMethodPath);
      if (disposed || identity != pageIdentity(w)) return;
      final raw = data is Map ? data['paymentMethod'] : null;
      final next = raw is Map ? Map<String, dynamic>.from(raw) : null;
      writePageSnapshot(w, _snapshotKey, identity, {'method': next});
      setState(() {
        read = _Read.ready;
        method = next;
      });
    } catch (_) {
      if (disposed || identity != pageIdentity(w)) return;
      // Stripe can't say: no row (a kept answer would be stale).
      setState(() => read = _Read.failed);
    }
  }

  String describe(BuildContext context) {
    final m = method;
    String tr(String s) => raftText(context, s);
    if (m == null) return tr('None on file');
    final last4 = m['last4'];
    if (m['type'] == 'card' && last4 != null && m['brand'] != null) {
      final locale = Localizations.localeOf(context).toLanguageTag();
      final year = m['expYear'], month = m['expMonth'];
      final expiry = year is num && month is num
          ? DateFormat(
              locale.toLowerCase().startsWith('zh') ? 'yy/MM' : 'MM/yy',
            ).format(DateTime.utc(year.toInt(), month.toInt()))
          : '';
      return raftFormat(
        context,
        '{brand} ending in {last4} · expires {expiry}',
        {
          'brand': _brand(context, '${m['brand']}'),
          'last4': last4,
          'expiry': expiry,
        },
      );
    }
    if (m['type'] == 'bank_account' && last4 is String && last4.isNotEmpty) {
      return raftFormat(context, 'Bank account ending in {last4}', {
        'last4': last4,
      });
    }
    return tr('Saved in Stripe');
  }

  /// The brand names of `planBilling.paymentMethod.card`'s select.
  String _brand(BuildContext context, String brand) => switch (brand) {
    'visa' => 'Visa',
    'mastercard' => 'Mastercard',
    'amex' => 'American Express',
    'discover' => 'Discover',
    'jcb' => 'JCB',
    'unionpay' => raftText(context, 'UnionPay'),
    'diners' => 'Diners Club',
    _ => raftText(context, 'Card'),
  };

  @override
  Widget build(BuildContext context) {
    final entries = [
      ...widget.before,
      if (read != _Read.failed)
        RaftDescriptionEntry(
          raftText(context, 'Payment method'),
          read == _Read.ready ? describe(context) : '',
          key: const ValueKey('billing-payment-method'),
          detailsChild: read == _Read.loading
              ? Semantics(
                  label: raftText(context, 'Loading the payment method'),
                  child: const RaftSpinner(
                    recipeSize: RaftSpinnerRecipeSize.xs,
                  ),
                )
              : null,
        ),
      ...widget.after,
    ];
    return RaftDescriptionList(entries: entries);
  }
}
