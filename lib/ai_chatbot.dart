// AI chatbot service that operates on dynamic product objects.
// We intentionally avoid importing the Product model here so the chatbot can be used with in-file product definitions as well.
class AIChatBot {
  /// Returns a reply for [question] using available [products].
  /// [products] is a list of dynamic objects that should expose `.name`, `.price` and `.stock`.
  static Future<String> respond(String question, List<dynamic> products) async {
    final q = question.toLowerCase().trim();

    if (q.isEmpty) return 'Please type a question.';

    // check handlers in order
    final handlers = [
      _handleGreeting,
      _handleHelp,
      (String s, List<dynamic> ps) => _handlePrice(s, ps),
      (String s, List<dynamic> ps) => _handleAvailability(s, ps),
      (String s, List<dynamic> ps) => _handleCheap(s, ps),
      (String s, List<dynamic> ps) => _handleExpensive(s, ps),
      (String s, List<dynamic> ps) => _handleProductList(s, ps),
    ];

    for (final h in handlers) {
      try {
        final res = await h(q, products); // call handler and wait for result
        if (res != null) return res;
      } catch (_) {
        // ignore handler errors and try next
      }
    }
    // if text was present but no handler matched, return fallback
    return _fallback(q);
  }

  // Handler signatures return Future<String?> to allow async operations later.
  static Future<String?> _handleGreeting(String q, List<dynamic> _) async {
    if (q.contains('hello') ||
        q.startsWith('hi') ||
        q.startsWith('hey') ||
        q.contains('good day')) {
      return 'Hello! I\'m your shop assistant — I can help with prices, availability and recommendations.';
    }
    return null;
  }

  static Future<String?> _handleHelp(String q, List<dynamic> _) async {
    if (q.contains('help') || q.contains('support')) {
      return 'I can answer questions about product prices, availability (in stock), and show you the cheapest or most expensive items.';
    }
    return null;
  }

  static Future<String?> _handlePrice(String q, List<dynamic> products) async {
    if (!q.contains('price')) return null;
    for (final p in products) {
      try {
        final name = (p.name as String).toLowerCase();
        if (q.contains(name)) {
          return 'The ${p.name} costs \$${(p.price as num).toStringAsFixed(2)}.';
        }
      } catch (_) {}
    }
    return 'Which product would you like the price for? (e.g. "price of sunglasses")';
  }

  static Future<String?> _handleAvailability(
      String q, List<dynamic> products) async {
    if (!(q.contains('available') ||
        q.contains('in stock') ||
        q.contains('stock'))) return null;
    for (final p in products) {
      try {
        final name = (p.name as String).toLowerCase();
        if (q.contains(name)) {
          // this section has been commented out, because the stock-variable doesn't work yet
          // instead it automatically assumes products are available
          /*   final stock = p.stock as int;
          if (stock > 0) {
            return '${p.name} is available. We currently have $stock units in stock.';
          } else {
            return 'Sorry, ${p.name} is currently out of stock.';
          } */

          // If stock field doesn't exist or is null, assume product is available
          return '${p.name} is available in our shop.';
        }
      } catch (_) {}
    }
    return 'Which product are you asking about?';
  }

  static Future<String?> _handleCheap(String q, List<dynamic> products) async {
    if (!(q.contains('cheap') ||
        q.contains('cheapest') ||
        q.contains('affordable'))) return null;

    if (products.isEmpty) return 'Sorry, no products found.';

    final sorted = List<dynamic>.from(products)
      ..sort((a, b) {
        final pa = (a.price as num).toDouble();
        final pb = (b.price as num).toDouble();
        return pa.compareTo(pb);
      });

    // take the first 3 cheapest items and format response
    final list = sorted
        .take(3)
        .map((p) => '${p.name} (\$${(p.price as num).toStringAsFixed(2)})')
        .join(', ');
    return 'Our cheapest items are: $list';
  }

  static Future<String?> _handleExpensive(
      String q, List<dynamic> products) async {
    if (!(q.contains('expensive') || q.contains('most expensive'))) return null;

    if (products.isEmpty) return 'Sorry, no products found.';

    final sorted = List<dynamic>.from(products)
      ..sort((a, b) {
        final pa = (a.price as num).toDouble();
        final pb = (b.price as num).toDouble();
        return pb.compareTo(pa);
      });

    // take the first 3 most expensive items and format response
    final list = sorted
        .take(3)
        .map((p) => '${p.name} (\$${(p.price as num).toStringAsFixed(2)})')
        .join(', ');
    return 'Our most expensive items are: $list';
  }

  // handle requests for listing available products
  static Future<String?> _handleProductList(
      String q, List<dynamic> products) async {
    // Check if the query is asking for products or items
    if (!(q.contains(' show ') ||
        q.contains(' list ') ||
        q.contains(' what ') ||
        q.contains(' items ') ||
        q.contains('products') ||
        q.contains(' all '))) {
      return null;
    }

    if (products.isEmpty) {
      return 'Sorry, there are no products at the moment.';
    }

    // Take only the first 5 items
    final limitedProducts = products.take(5).toList();
    final totalCount = products.length;

    // Format the response with line breaks, showing stock info if available
    final itemList = limitedProducts.map((p) {
      // when stock-variable is working, uncomment below
      /*   final stock = p.stock as int;
      return '\n- ${p.name} ($stock units in stock, \$${(p.price as num).toStringAsFixed(2)})'; */

      // when stock-variable is working delete following line
      return '\n- ${p.name} (available, \$${(p.price as num).toStringAsFixed(2)})';
    }).join('');

    // Add total count if there are more items
    final suffix = totalCount > 5
        ? '\n(and ${totalCount - 5} more products available)'
        : '';
    return 'Available products:$itemList$suffix';
  }

  // =========================================================================
  // METHODE FÜR KATEGORIE-BASIERTE PRODUKTSUCHE (AKTUELL AUSKOMMENTIERT)
  // =========================================================================
  // Diese Methode kann verwendet werden, sobald die 'category'-Variable
  // in den Produkten implementiert ist.
  //
  // Um diese Methode zu aktivieren:
  // 1. Entfernen Sie die Kommentare um den Code
  // 2. Fügen Sie '_handleCategoryList' zur handlers-Liste in der respond()-Methode hinzu
  // 3. Stellen Sie sicher, dass _ProductData in product_list_page.dart das Feld 'category' hat
  // 4. Passen Sie die Hilfe-Texte an, um Kategorien zu erwähnen
  // =========================================================================

  /* 
  // Handler für Kategorie-basierte Produktlisten
  // Beispiel-Anfragen: "show electronics", "list clothing items", "what's in accessories"
  static Future<String?> _handleCategoryList(String q, List<dynamic> products) async {
    // Prüfen, ob die Anfrage nach Produkten in einer Kategorie fragt
    if (!(q.contains('show') || q.contains('list') || q.contains('what') || 
          q.contains('items') || q.contains('products') || q.contains('in'))) {
      return null;
    }

    // Suche die Kategorie in der Anfrage
    final cat = await _findCategoryInQuery(q, products);
    if (cat == null) return null; // Keine Kategorie gefunden

    // Filtere alle Produkte nach der gefundenen Kategorie
    final categoryProducts = products.where((p) {
      try {
        // Vergleiche die Kategorie des Produkts (case-insensitive)
        return (p.category as String).toLowerCase() == cat.toLowerCase();
      } catch (_) {
        // Falls das Produkt keine Kategorie hat, überspringe es
        return false;
      }
    }).toList();

    // Wenn keine Produkte in dieser Kategorie gefunden wurden
    if (categoryProducts.isEmpty) {
      return 'Sorry, there are no products in the $cat category.';
    }

    // Nimm nur die ersten 5 Produkte
    final limitedProducts = categoryProducts.take(5).toList();
    final totalCount = categoryProducts.length;
    
    // Formatiere die Antwort mit Zeilenumbrüchen
    final itemList = limitedProducts.map((p) {
      try {
        // Versuche, Stock-Information anzuzeigen (falls verfügbar)
        final stock = p.stock as int;
        if (stock > 0) {
          return '\n- ${p.name} ($stock units in stock, \$${(p.price as num).toStringAsFixed(2)})';
        } else {
          return '\n- ${p.name} (out of stock, \$${(p.price as num).toStringAsFixed(2)})';
        }
      } catch (_) {
        // Falls Stock-Feld nicht existiert, zeige nur "available"
        return '\n- ${p.name} (available, \$${(p.price as num).toStringAsFixed(2)})';
      }
    }).join('');
    
    // Füge Hinweis hinzu, wenn es mehr als 5 Produkte gibt
    final suffix = totalCount > 5 ? '\n(and ${totalCount - 5} more products in this category)' : '';
    return 'Products in $cat:$itemList$suffix';
  }

  // Hilfsmethode: Findet eine Kategorie in der Benutzeranfrage
  // Durchsucht alle vorhandenen Produktkategorien und prüft, 
  // ob eine davon in der Anfrage erwähnt wird
  static Future<String?> _findCategoryInQuery(String q, List<dynamic> products) async {
    try {
      final lower = q.toLowerCase();
      final categories = <String>{}; // Set zur Speicherung eindeutiger Kategorien
      
      // Sammle alle vorhandenen Kategorien aus den Produkten
      for (final p in products) {
        try {
          final c = (p.category as String).toLowerCase();
          categories.add(c); // Füge Kategorie zum Set hinzu
        } catch (_) {
          // Produkt hat keine Kategorie, überspringe es
        }
      }
      
      // Prüfe, ob eine der Kategorien in der Benutzeranfrage vorkommt
      for (final c in categories) {
        if (lower.contains(c)) {
          return c; // Kategorie gefunden!
        }
      }
    } catch (_) {
      // Fehler beim Verarbeiten - gebe null zurück
    }
    return null; // Keine Kategorie gefunden
  }
  */

  // if no keyword was found, return fallback message
  static String _fallback(String q) {
    return 'Sorry, I did not understand that. Try asking about a product\'s price, availability, or ask to show available products.';
  }
}
