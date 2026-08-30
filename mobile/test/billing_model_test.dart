import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/profile/models/billing.dart';

void main() {
  /// The paywall used to hardcode $14.99/month on the Buy/Don't Buy limit
  /// screen and in the trial footnote, while the plan columns showed $9.99 —
  /// two prices for one plan. Everything now falls back to these constants, so
  /// pin them to what the backend actually charges
  /// (`billing_service.PLANS`: 999 / 7999 cents).
  test('price fallbacks match the backend plan prices', () {
    expect(kProMonthlyPriceFallback, r'$9.99');
    expect(kProYearlyPriceFallback, r'$79.99');

    // And they agree with what the wire format renders, so a price change on
    // the backend can't leave the fallbacks quoting the old number.
    const monthly = PlanSummary(
      plan: 'pro_monthly',
      priceCents: 999,
      currency: 'CAD',
    );
    const yearly = PlanSummary(
      plan: 'pro_yearly',
      priceCents: 7999,
      currency: 'CAD',
    );
    expect(monthly.priceLabel, kProMonthlyPriceFallback);
    expect(yearly.priceLabel, kProYearlyPriceFallback);
  });

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
