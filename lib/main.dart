// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webshop/firebase_options.dart';
import 'package:webshop/products_screen.dart';
import 'package:webshop/utils/constants.dart';

/// The application entry point.
///
/// This asynchronous function is responsible for the critical setup phase before the UI renders:
/// 1. **Binding Initialization**: Ensures the Flutter engine is fully loaded to handle platform channels.
/// 2. **Firebase Setup**: Initializes the connection to backend services (Firestore, Auth, etc.) using platform-specific configuration.
/// 3. **State Management**: Wraps the entire application tree in a [ProviderScope], which stores the state of all Riverpod providers.
void main() async {
  // 1. Ensure Flutter engine is ready before making async calls to native plugins.
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize connection to Firebase.
  // 'DefaultFirebaseOptions.currentPlatform' ensures the correct keys are used for Android/iOS/Web.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Note: Offline persistence is disabled here to prevent platform-specific conflicts
  // during development. The app relies on standard network fetching.

  // 3. Launch the app wrapped in Riverpod's scope.
  runApp(const ProviderScope(child: MyApp()));
}

/// The root widget of the application.
///
/// This widget defines the global [MaterialApp] configuration, acting as the foundation for:
/// * **Navigation**: Sets the home route to [ProductsScreen].
/// * **Branding**: Applies a centralized [ThemeData] to ensure consistent colors, shapes, and inputs across all screens.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Define brand colors locally for the theme configuration.
    const MaterialColor primaryColor = Colors.teal;
    const Color secondaryColor = Colors.orangeAccent;
    const Color scaffoldBackgroundColor = lightGreyColor;

    return MaterialApp(
      title: appName,

      // Hides the "DEBUG" banner in the top-right corner for a cleaner look during development.
      debugShowCheckedModeBanner: false,

      // ==================================================================
      // GLOBAL THEME CONFIGURATION
      // ==================================================================
      theme: ThemeData(
        // 1. Color Scheme:
        // Automatically generates a accessible palette based on the primary seed color.
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
        ).copyWith(
          secondary: secondaryColor,
          primary: primaryColor,
          onPrimary: whiteColor,
          surface: whiteColor,
          onSurface: blackColor,
          error: errorColor,
          onError: whiteColor,
        ),

        // Background color for Screens (Scaffolds)
        scaffoldBackgroundColor: scaffoldBackgroundColor,

        // 2. AppBar Theme:
        // Ensures all headers look consistent (primary color background, white text).
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: whiteColor,
          elevation: cardElevation,
        ),

        // 3. Button Theme:
        // Standardizes shapes (rounded corners) and colors for primary actions.
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: whiteColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(smallPadding),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: defaultPadding, vertical: mediumPadding),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),

        // 4. Text Button Theme:
        // Standardizes link/secondary action styling.
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryColor,
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),

        // 5. Card Theme:
        // Consistent shadows and rounded corners for content containers (Product Cards, etc.).
        cardTheme: CardTheme.of(context).copyWith(
          elevation: cardElevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          margin: const EdgeInsets.symmetric(
              horizontal: smallPadding, vertical: smallPadding / 2),
        ),

        // 6. Input Theme:
        // Consistent text field borders (rounded) and focus states for forms (Login, Checkout).
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(smallPadding),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(smallPadding),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          labelStyle: const TextStyle(color: primaryColor),
        ),

        // Adapts visual density for desktop/mobile platforms.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),

      // ==================================================================
      // ROUTING
      // ==================================================================
      // Starts the user on the Product Catalog screen.
      // Authentication is handled lazily when the user attempts a protected action (e.g., Add to Cart).
      home: const ProductsScreen(),
    );
  }
}