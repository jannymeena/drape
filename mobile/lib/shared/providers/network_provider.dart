import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/dio_service.dart';
import '../services/storage_service.dart';

/// Single secure-storage wrapper for the app.
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// Single shared [Dio] instance with the auth + logging interceptors attached.
final dioProvider = Provider<Dio>((ref) {
  return buildDio(ref.read(storageServiceProvider));
});
