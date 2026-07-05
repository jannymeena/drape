import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/api_error.dart';
import '../../shared/providers/network_provider.dart';
import 'models/billing.dart';

/// Backend billing endpoints (item 8b). The backend flips
/// `users.subscription_tier` on upgrade/cancel-expiry — after any mutation,
/// invalidate [subscriptionProvider] so gates and banners refresh.
class BillingService {
  BillingService(this._dio);

  final Dio _dio;

  /// `GET /subscription`.
  Future<SubscriptionInfo> getSubscription() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/subscription');
      return SubscriptionInfo.fromJson(r.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /subscription/upgrade` — 409 `already_subscribed` when active.
  Future<SubscriptionInfo> upgrade(String plan) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/subscription/upgrade',
        data: {'plan': plan},
      );
      return SubscriptionInfo.fromJson(r.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /subscription/cancel` — soft: Pro runs to the period end and the
  /// retention offer becomes available.
  Future<SubscriptionInfo> cancel({String? reason}) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/subscription/cancel',
        data: {'reason': ?reason},
      );
      return SubscriptionInfo.fromJson(r.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /subscription/retention-offer/accept` — un-cancels + credit.
  Future<SubscriptionInfo> acceptRetentionOffer() async {
    try {
      final r = await _dio
          .post<Map<String, dynamic>>('/subscription/retention-offer/accept');
      return SubscriptionInfo.fromJson(r.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /billing/history`.
  Future<List<BillingRecord>> getHistory() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/billing/history');
      return (r.data!['records'] as List<dynamic>)
          .map((e) => BillingRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /payment-methods`.
  Future<List<PaymentMethodInfo>> getPaymentMethods() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/payment-methods');
      return (r.data!['methods'] as List<dynamic>)
          .map((e) => PaymentMethodInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /payment-methods` — [token] is the payment SDK's card token
  /// (the dev mock accepts anything and mints a visa).
  Future<PaymentMethodInfo> addPaymentMethod(String token) async {
    try {
      final r = await _dio
          .post<Map<String, dynamic>>('/payment-methods', data: {'token': token});
      return PaymentMethodInfo.fromJson(r.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final billingServiceProvider = Provider<BillingService>((ref) {
  return BillingService(ref.read(dioProvider));
});

final subscriptionProvider =
    FutureProvider.autoDispose<SubscriptionInfo>((ref) {
  return ref.read(billingServiceProvider).getSubscription();
});

final billingHistoryProvider =
    FutureProvider.autoDispose<List<BillingRecord>>((ref) {
  return ref.read(billingServiceProvider).getHistory();
});

final paymentMethodsProvider =
    FutureProvider.autoDispose<List<PaymentMethodInfo>>((ref) {
  return ref.read(billingServiceProvider).getPaymentMethods();
});
