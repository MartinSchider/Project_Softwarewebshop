// lib/services/recommendation_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/repositories/product_repository.dart';

/// A lightweight client-side recommendation service that tracks simple
/// user behavior (recently viewed products) and returns related
/// and behaviour-based product suggestions.
///
/// Note: SharedPreferences may not be immediately available during app
/// startup (especially on web). To avoid throwing on first access, this
/// service supports a nullable [SharedPreferences] and falls back to an
/// in-memory store until the persistent preferences become available.
class RecommendationService {
  final ProductRepository _productRepository;
  SharedPreferences? _prefs; // nullable, assignable when prefs become available

  // In-memory fallback when SharedPreferences isn't ready yet.
  final Map<String, List<String>> _inMemoryRecent = {};

  static const _recentKeyPrefix = 'recently_viewed_';
  static const int _maxRecent = 20;

  RecommendationService(this._productRepository, this._prefs);

  String _keyFor(String? userId) => _recentKeyPrefix + (userId ?? 'anon');

  /// Migrate any in-memory recorded events to persistent preferences.
  ///
  /// Merges lists and avoids duplicates, preferring the more recent in-memory
  /// items (which are assumed to be newer than any existing stored items).
  Future<void> migrateToPrefs(SharedPreferences prefs) async {
    // If we already have prefs assigned, nothing to do.
    if (_prefs != null) return;

    for (final entry in _inMemoryRecent.entries) {
      final key = entry.key;
      final inMemoryList = entry.value;

      final existing = prefs.getStringList(key) ?? <String>[];

      // Merge: inMemory first, then existing items that are not present.
      final merged = <String>[];
      merged.addAll(inMemoryList);
      for (final id in existing) {
        if (!merged.contains(id)) merged.add(id);
      }

      if (merged.length > _maxRecent) merged.removeRange(_maxRecent, merged.length);

      await prefs.setStringList(key, merged);
    }

    // Clear in-memory backup and switch to persistent prefs.
    _inMemoryRecent.clear();
    _prefs = prefs;
  }

  /// Records a product view for the given [userId]. If [userId] is null,
  /// the event is stored under an anonymous key.
  Future<void> recordProductView({String? userId, required String productId}) async {
    final key = _keyFor(userId);

    if (_prefs != null) {
      final list = _prefs!.getStringList(key) ?? <String>[];
      list.remove(productId);
      list.insert(0, productId);
      if (list.length > _maxRecent) list.removeRange(_maxRecent, list.length);
      await _prefs!.setStringList(key, list);
    } else {
      final list = _inMemoryRecent[key] ?? <String>[];
      list.remove(productId);
      list.insert(0, productId);
      if (list.length > _maxRecent) list.removeRange(_maxRecent, list.length);
      _inMemoryRecent[key] = list;
    }
  }

  /// Returns the recent product IDs for [userId] or anonymous if null.
  List<String> getRecent(String? userId) {
    final key = _keyFor(userId);
    if (_prefs != null) {
      return _prefs!.getStringList(key) ?? <String>[];
    }
    return _inMemoryRecent[key] ?? <String>[];
  }

  /// Returns products related to the given [productId] using category
  /// similarity. Results exclude the original product and are limited by [limit].
  Future<List<Product>> getRelatedProducts(String productId, {int limit = 6}) async {
    final product = await _productRepository.getProductById(productId);
    if (product == null) return [];

    final candidates = await _productRepository.getProductsByCategory(product.category, limit: limit + 1);

    // Exclude the product itself and return up to [limit] items.
    return candidates.where((p) => p.id != productId).take(limit).toList();
  }

  /// Generates behavioural recommendations based on recently viewed items.
  /// Strategy:
  /// 1. Gather last N viewed product IDs.
  /// 2. Determine the most-seen categories among them.
  /// 3. Return top products from those categories excluding already seen products.
  Future<List<Product>> getBehavioralRecommendations(String? userId, {int limit = 8}) async {
    final recent = getRecent(userId);
    if (recent.isEmpty) return [];

    // Map category -> count
    final Map<String, int> counts = {};
    for (final id in recent) {
      final p = await _productRepository.getProductById(id);
      if (p == null) continue;
      counts[p.category] = (counts[p.category] ?? 0) + 1;
    }

    if (counts.isEmpty) return [];

    // Sort categories by frequency
    final sortedCategories = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    final seen = recent.toSet();
    final List<Product> results = [];

    for (final cat in sortedCategories) {
      if (results.length >= limit) break;
      final candidates = await _productRepository.getProductsByCategory(cat, limit: limit * 2);
      for (final c in candidates) {
        if (results.length >= limit) break;
        if (seen.contains(c.id)) continue;
        results.add(c);
      }
    }

    return results;
  }

  /// AI-powered recommendation approximation.
  ///
  /// This method combines behavioral signals (recent views), related
  /// products (category-based), and an optional free-text query or seed
  /// product to produce a ranked list of suggestions. The implementation
  /// is intentionally lightweight and runs entirely on-device.
  Future<List<Product>> getAiPoweredRecommendations({String? userId, String? seedProductId, String? query, int limit = 8}) async {
    final candidates = <Product>[];

    // 1) Seed product related items (if provided)
    if (seedProductId != null) {
      final related = await getRelatedProducts(seedProductId, limit: limit * 2);
      candidates.addAll(related);
    }

    // 2) Behavioral items
    final behavioral = await getBehavioralRecommendations(userId, limit: limit * 3);
    candidates.addAll(behavioral);

    // 3) If a query is given, perform a lightweight text search and add matches
    if (query != null && query.trim().isNotEmpty) {
      final searched = await _productRepository.searchProductsByText(query, limit: limit * 3);
      candidates.addAll(searched);
    }

    // Scoring: simple heuristic combining (a) appearance in recent views' categories,
    // (b) textual relevance to query or seed product, and (c) freshness (recently viewed exclusion)
    final recent = getRecent(userId).toSet();

    // Build category frequency map from recent items
    final Map<String, int> catFreq = {};
    for (final id in getRecent(userId)) {
      final p = await _productRepository.getProductById(id);
      if (p == null) continue;
      catFreq[p.category] = (catFreq[p.category] ?? 0) + 1;
    }

    Map<Product, double> scores = {};

    for (final p in candidates) {
      if (recent.contains(p.id)) continue; // don't recommend already-seen items
      final base = 1.0;
      double score = base;

      // Category relevance
      score += (catFreq[p.category] ?? 0) * 0.5;

      // Query relevance (if provided)
      if (query != null && query.trim().isNotEmpty) {
        final q = query.toLowerCase();
        final hay = (p.name + ' ' + p.description).toLowerCase();
        if (hay.contains(q)) score += 2.0;
        final words = q.split(RegExp(r"\s+"));
        for (final w in words) {
          if (hay.contains(w)) score += 0.5;
        }
      }

      // Seed-product name relevance
      if (seedProductId != null) {
        final seed = await _productRepository.getProductById(seedProductId);
        if (seed != null) {
          final seedWords = (seed.name + ' ' + seed.description).toLowerCase().split(RegExp(r"\s+"));
          for (final w in seedWords) {
            if ((p.name + ' ' + p.description).toLowerCase().contains(w)) score += 0.2;
          }
        }
      }

      // Small boost for in-stock items
      if (p.stock > 0) score += 0.3;

      scores[p] = (scores[p] ?? 0) + score;
    }

    // Sort candidates by score and return top [limit]
    final ranked = scores.keys.toList()
      ..sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));

    return ranked.take(limit).toList();
  }
}
