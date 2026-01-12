// lib/widgets/recommended_products.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/providers/recommendations_provider.dart';
import 'package:webshop/widgets/product_card.dart';

/// A horizontal list widget that displays recommended products (either related
/// to a current product, or behavioural suggestions based on the user).
class RecommendedProducts extends ConsumerWidget {
  final String? basisProductId; // if provided, show "related" products
  final String? userId; // optional user id for behaviour-based suggestions
  final bool behaviour; // if true, show behavioural recommendations

  const RecommendedProducts({
    super.key,
    this.basisProductId,
    this.userId,
    this.behaviour = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the notifier's integer state to re-run the future when a new
    // view is recorded. We also need the notifier (the .notifier) to call
    // the async methods.
    ref.watch(recommendationsNotifierProvider);
    final notifier = ref.read(recommendationsNotifierProvider.notifier);

    return FutureBuilder<List<Product>>(
      future: behaviour
          ? notifier.getBehavioral(userId: userId, limit: 8)
          : (basisProductId != null
              ? notifier.getRelated(basisProductId!, limit: 8)
              : Future.value([])),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(behaviour ? 'Recommendations for you' : 'Related products',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) => SizedBox(
                  width: 220,
                  child: ProductCard(product: items[index]),
                ),
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemCount: items.length,
              ),
            ),
          ],
        );
      },
    );
  }
}
