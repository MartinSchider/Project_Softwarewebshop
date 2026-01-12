// lib/providers/recommendations_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/repositories/product_repository.dart';
import 'package:webshop/services/recommendation_service.dart';

/// A FutureProvider that yields the app-wide SharedPreferences instance.
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

/// Provides a singleton [RecommendationService] wired with [ProductRepository]
final recommendationServiceProvider = Provider<RecommendationService>((ref) {
  // Create a single service instance that starts without prefs (nullable)
  // so it can record in-memory until persistent prefs are ready.
  final service = RecommendationService(ProductRepository(), null);

  // When SharedPreferences becomes available, migrate any in-memory data.
  ref.listen<AsyncValue<SharedPreferences>>(sharedPreferencesProvider, (prev, next) {
    next.whenData((prefs) async {
      try {
        await service.migrateToPrefs(prefs);
      } catch (_) {
        // Ignore migration errors to keep recommendations non-blocking.
      }
    });
  });

  return service;
});

/// A notifier that uses an `int` state as a simple change trigger.
///
/// Consumers can watch the integer to rebuild when a new view was recorded,
/// while calling `recordView` on the notifier will update the state.
class RecommendationsNotifier extends StateNotifier<int> {
  final RecommendationService _service;
  RecommendationsNotifier(this._service) : super(0);

  /// Helper used by tests to inspect the internal state value.
  int get debugState => state;

  /// Records a product view against the current user (or anon). After
  /// recording we increment the internal integer state so consumers can
  /// react (e.g., re-fetch behavioral recommendations).
  Future<void> recordView({String? userId, required String productId}) async {
    try {
      await _service.recordProductView(userId: userId, productId: productId);
    } catch (_) {
      // Ignore tracking errors.
    }
    state = state + 1; // trigger a rebuild for listeners
  }

  Future<List<Product>> getRelated(String productId, {int limit = 6}) async {
    return _service.getRelatedProducts(productId, limit: limit);
  }

  Future<List<Product>> getBehavioral({String? userId, int limit = 8}) async {
    return _service.getBehavioralRecommendations(userId, limit: limit);
  }

  /// Wrapper for AI-powered recommendations that merges several signals.
  Future<List<Product>> getAiPowered({String? userId, String? seedProductId, String? query, int limit = 8}) async {
    return _service.getAiPoweredRecommendations(userId: userId, seedProductId: seedProductId, query: query, limit: limit);
  }
}

/// Provider that exposes the [RecommendationsNotifier]. Consumers should use
/// `ref.watch(recommendationsNotifierProvider)` to listen for changes and
/// `ref.read(recommendationsNotifierProvider.notifier)` to call methods.
final recommendationsNotifierProvider = StateNotifierProvider<RecommendationsNotifier, int>((ref) {
  final service = ref.watch(recommendationServiceProvider);
  return RecommendationsNotifier(service);
});
