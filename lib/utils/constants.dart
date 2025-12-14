// lib/utils/constants.dart
import 'package:flutter/material.dart';

/// Centralizes application-wide constants.
///
/// Using a single file for constants ensures design consistency (padding, colors, timing)
/// and makes it easier to update the look and feel of the app from one place.
///
/// Note: In a larger, multi-language app, user-facing strings should be moved
/// to localization files (ARB/Intl), but for this scope, constants are sufficient.

// --- App Name & Titles ---

/// The main display name of the application shown in the AppBar.
const String appName = 'Webshop';

/// Title used in contexts where the AI feature is highlighted.
const String appTitleWithChatbot = 'Webshop with AI Chatbot';

/// Header title for the AI Chat panel.
const String aiChatbotTitle = 'AI Shop Assistant';

/// Section title for the checkout order review.
const String orderSummaryTitle = 'Order Summary';

/// Section title for the gift card input area.
const String giftCardTitle = 'Gift Card';

/// Section title for selecting payment methods.
const String paymentMethodTitle = 'Payment Method';

// --- Durations ---

/// Standard duration for UI animations (e.g., opening the chat panel, transitions).
/// Kept short (300ms) to feel snappy but noticeable.
const Duration animationDuration = Duration(milliseconds: 300);

/// Duration for temporary feedback messages (SnackBars) before they auto-dismiss.
const Duration snackbarDuration = Duration(seconds: 4);

// --- Dimensions & Spacing ---

/// The standard padding used around the edges of screens and main containers.
/// Follows Material Design guidelines (typically 16.0).
const double defaultPadding = 16.0;

/// Smaller padding for internal spacing within widgets or tight lists.
const double smallPadding = 8.0;

/// Intermediate padding, useful for button internal padding or separating sections.
const double mediumPadding = 12.0;

/// Standard elevation for Cards to give depth.
const double cardElevation = 4.0;

/// Standard border radius for cards, buttons, and input fields.
const double borderRadius = 12.0;

/// Fixed width for the side chat panel on larger screens (Web/Desktop).
const double chatPanelWidth = 360.0;

// --- Default Image URLs ---

/// A placeholder image URL used when product data is missing an image
/// or when the network request fails.
const String defaultNoImageUrl =
    'https://via.placeholder.com/150/CCCCCC/000000?text=NoImage';

/// URL for the Google logo used in the Sign-In button.
const String googleLogoUrl =
    'https://upload.wikimedia.org/wikipedia/commons/4/4a/Logo_2013_Google.png';

// --- Colors ---

/// Color used for positive feedback (e.g., "Added to cart", "Order successful").
const Color successColor = Colors.green;

/// Color used for critical errors (e.g., "Network failed", "Payment declined").
const Color errorColor = Colors.red;

/// Color used for informational messages or links.
const MaterialColor infoColor = Colors.blue;

/// Standard white, used for text on dark backgrounds or card backgrounds.
const Color whiteColor = Colors.white;

/// Standard black, used for primary text.
const Color blackColor = Colors.black;

/// A subtle grey used for the app background to make white cards pop.
const Color lightGreyColor = Color(0xFFF5F5F5);

// --- Categories ---

/// List of available product categories for filtering.
const List<String> productCategories = [
  'All',
  'Electronics',
  'Clothing',
  'Home',
  'Beauty',
  'Sports',
  'Gadget', // Nuovo
  'Music',  // Nuovo
  'Food',   // Nuovo
  'General',
];