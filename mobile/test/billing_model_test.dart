import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/profile/models/billing.dart';

void main() {
  test('SubscriptionInfo parses the pro shape', () {
    final sub = SubscriptionInfo.fromJson({
      'tier': 'pro',
      'plan': 'pro_monthly',
      'status': 'active',
      'price_cents': 999,
      'currency': 'CAD',
      'current_period_end': '2026-08-04T00:00:00Z',
      'cancel_at_period_end': false,
      'retention_offer': 'none',
      'plans': [
        {'plan': 'pro_monthly', 'price_cents': 999, 'currency': 'CAD'},
        {'plan': 'pro_yearly', 'price_cents': 7999, 'currency': 'CAD'},
      ],
    });
    expect(sub.isPro, isTrue);
    expect(sub.plans, hasLength(2));
    expect(sub.plans.last.isYearly, isTrue);
    expect(sub.plans.first.priceLabel, r'$9.99');
  });

  test('SubscriptionInfo defaults to free with empty payload', () {
    final sub = SubscriptionInfo.fromJson({'tier': 'free', 'plans': []});
    expect(sub.isPro, isFalse);
    expect(sub.currentPeriodEnd, isNull);
  });

  test('BillingRecord parses credits as negative amounts', () {
    final record = BillingRecord.fromJson({
      'description': 'Retention offer — 50% off next period',
      'amount_cents': -500,
      'currency': 'CAD',
      'status': 'paid',
      'occurred_at': '2026-07-05T00:00:00Z',
      'invoice_number': null,
    });
    expect(record.amountCents, -500);
    expect(record.invoiceNumber, isNull);
  });

  test('PaymentMethodInfo parses', () {
    final m = PaymentMethodInfo.fromJson({
      'id': 'x',
      'kind': 'card',
      'brand': 'visa',
      'last4': '4242',
      'exp_month': 12,
      'exp_year': 2030,
      'is_default': true,
    });
    expect(m.isDefault, isTrue);
    expect(m.last4, '4242');
  });
}
