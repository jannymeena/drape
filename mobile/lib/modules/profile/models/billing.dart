/// Wire models for the billing endpoints (`/subscription`, `/billing/history`,
/// `/payment-methods`). Mirrors backend `schemas/billing.py`.
library;

class PlanSummary {
  const PlanSummary({
    required this.plan,
    required this.priceCents,
    required this.currency,
  });

  final String plan; // pro_monthly | pro_yearly
  final int priceCents;
  final String currency;

  bool get isYearly => plan == 'pro_yearly';

  /// "$9.99" — prices are cents in the wire format.
  String get priceLabel =>
      '\$${(priceCents / 100).toStringAsFixed(2)}';

  factory PlanSummary.fromJson(Map<String, dynamic> json) => PlanSummary(
        plan: json['plan'] as String,
        priceCents: json['price_cents'] as int,
        currency: json['currency'] as String? ?? 'CAD',
      );
}

class SubscriptionInfo {
  const SubscriptionInfo({
    required this.tier,
    this.plan,
    this.status,
    this.priceCents,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
    this.retentionOffer = 'none',
    this.plans = const [],
  });

  final String tier; // free | pro
  final String? plan;
  final String? status;
  final int? priceCents;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final String retentionOffer; // none | offered | accepted
  final List<PlanSummary> plans;

  bool get isPro => tier == 'pro';

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) =>
      SubscriptionInfo(
        tier: json['tier'] as String? ?? 'free',
        plan: json['plan'] as String?,
        status: json['status'] as String?,
        priceCents: json['price_cents'] as int?,
        currentPeriodEnd: json['current_period_end'] == null
            ? null
            : DateTime.parse(json['current_period_end'] as String),
        cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
        retentionOffer: json['retention_offer'] as String? ?? 'none',
        plans: (json['plans'] as List<dynamic>? ?? const [])
            .map((e) => PlanSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class BillingRecord {
  const BillingRecord({
    required this.description,
    required this.amountCents,
    required this.currency,
    required this.status,
    required this.occurredAt,
    this.invoiceNumber,
  });

  final String description;
  final int amountCents; // negative = credit
  final String currency;
  final String status;
  final DateTime occurredAt;
  final String? invoiceNumber;

  factory BillingRecord.fromJson(Map<String, dynamic> json) => BillingRecord(
        description: json['description'] as String,
        amountCents: json['amount_cents'] as int,
        currency: json['currency'] as String? ?? 'CAD',
        status: json['status'] as String? ?? 'paid',
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        invoiceNumber: json['invoice_number'] as String?,
      );
}

class PaymentMethodInfo {
  const PaymentMethodInfo({
    required this.id,
    required this.kind,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    required this.isDefault,
  });

  final String id;
  final String kind;
  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;
  final bool isDefault;

  factory PaymentMethodInfo.fromJson(Map<String, dynamic> json) =>
      PaymentMethodInfo(
        id: json['id'] as String,
        kind: json['kind'] as String,
        brand: json['brand'] as String,
        last4: json['last4'] as String,
        expMonth: json['exp_month'] as int,
        expYear: json['exp_year'] as int,
        isDefault: json['is_default'] as bool? ?? false,
      );
}
