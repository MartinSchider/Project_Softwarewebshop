// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webshop/firebase_options.dart';
import 'package:webshop/products_screen.dart';
import 'package:webshop/utils/constants.dart';

/// The application entry point.
///
/// This function is responsible for:
/// 1. Initializing the Flutter framework bindings.
/// 2. Setting up the Firebase backend connection using platform-specific options.
/// 3. Wrapping the entire application in a [ProviderScope] to enable Riverpod state management.
void main() async {
  // Ensure Flutter engine is ready before making async calls.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize connection to Firebase (Firestore, Auth, Functions).
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // We removed the offline persistence block here to prevent conflicts on some platforms.
  // The app will function correctly using standard network fetching.

  // Launch the app wrapped in Riverpod's scope.
  runApp(const ProviderScope(child: MyApp()));
}

/// The root widget of the application.
///
/// This widget defines the global [MaterialApp] configuration, including:
/// - The application title.
/// - The global theme (colors, fonts, input styles) to ensure design consistency.
/// - The home route ([ProductsScreen]).
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

      // Hides the "DEBUG" banner in the top-right corner during development.
      debugShowCheckedModeBanner: false,

      // --- GLOBAL THEME CONFIGURATION ---
      theme: ThemeData(
        // Color Scheme: Automatically generates a palette based on the primary seed color.
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

        scaffoldBackgroundColor: scaffoldBackgroundColor,

        // AppBar Theme: Consistent header styling across all pages.
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: whiteColor,
          elevation: cardElevation,
        ),

        // Button Theme: Standardized shapes and colors for primary actions.
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

        // Text Button Theme: Standardized link/secondary action styling.
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryColor,
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),

        // Card Theme: Consistent shadows and rounded corners for content containers.
        cardTheme: CardTheme.of(context).copyWith(
          elevation: cardElevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          margin: const EdgeInsets.symmetric(
              horizontal: smallPadding, vertical: smallPadding / 2),
        ),

        // Input Theme: Consistent text field borders and focus states.
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

        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),

      // Starts the user on the Product Catalog screen.
      // Authentication is handled lazily when the user attempts an action (e.g., Add to Cart).
      home: const ProductsScreen(),
    );
  }
}
