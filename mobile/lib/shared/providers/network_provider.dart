import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/dashboard_cache.dart';
import '../services/dio_service.dart';
import '../services/storage_service.dart';

/// Single secure-storage wrapper for the app.
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// Stale-while-revalidate cache for the Today dashboard (shared_preferences).
final dashboardCacheProvider = Provider<DashboardCache>((ref) {
  return DashboardCache();
});

/// Single shared [Dio] instance with the auth + logging interceptors attached.
final dioProvider = Provider<Dio>((ref) {
  return buildDio(ref.read(storageServiceProvider));
});
