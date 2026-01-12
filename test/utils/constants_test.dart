// test/utils/constants_test.dart

/// CONSTANTS VALIDATION TESTS
///
/// These tests ensure that all application-wide constants are properly defined
/// and follow expected conventions and constraints.
///
/// TEST COVERAGE:
/// - App metadata (name, titles)
/// - Spacing constants (padding, margins)
/// - Color definitions (theme colors, status colors)
/// - Timing constants (animations, snackbar durations)
/// - UI dimensions (border radius, elevations, panel widths)
/// - String constants (titles, labels)
/// - URL constants (images, logos)
///
/// PURPOSE:
/// - Catch accidental constant modifications that break UI consistency
/// - Validate Material Design compliance (e.g., 8dp grid system)
/// - Ensure proper hierarchy (small < medium < large)
/// - Verify reasonable UX values (animation < 2s, etc.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webshop/utils/constants.dart';

void main() {
  group('App Metadata Constants', () {
    test('App name should be correctly defined', () {
      expect(appName, isNotEmpty, reason: 'App name should not be empty');
      expect(appName, 'Webshop', reason: 'App name should be "Webshop"');
      expect(appName, isA<String>(), reason: 'App name should be a String');
    });

    test('App titles should be defined and descriptive', () {
      expect(appTitleWithChatbot, isNotEmpty,
          reason: 'App title with chatbot should not be empty');
      expect(aiChatbotTitle, isNotEmpty,
          reason: 'AI chatbot title should not be empty');
      expect(appTitleWithChatbot, contains(appName),
          reason: 'App title should contain app name');
    });
  });

  group('Spacing Constants (Material Design 8dp Grid)', () {
    test('All padding values should be positive', () {
      expect(defaultPadding, greaterThan(0),
          reason: 'Default padding should be positive');
      expect(smallPadding, greaterThan(0),
          reason: 'Small padding should be positive');
      expect(mediumPadding, greaterThan(0),
          reason: 'Medium padding should be positive');
    });

    test('Padding hierarchy should follow size naming', () {
      expect(smallPadding, lessThan(mediumPadding),
          reason: 'Small padding should be less than medium padding');
      expect(mediumPadding, lessThan(defaultPadding),
          reason: 'Medium padding should be less than default padding');
    });

    test('Padding values should conform to Material Design standards', () {
      expect(defaultPadding, 16.0,
          reason: 'Default padding should be 16.0 (Material Design standard)');
      expect(smallPadding, 8.0,
          reason: 'Small padding should be 8.0 (8dp grid)');
      expect(mediumPadding, 12.0, reason: 'Medium padding should be 12.0');
    });

    test('Padding values should be multiples of 4 (8dp grid system)', () {
      expect(defaultPadding % 4, 0,
          reason: 'Default padding should be multiple of 4');
      expect(smallPadding % 4, 0,
          reason: 'Small padding should be multiple of 4');
      expect(mediumPadding % 4, 0,
          reason: 'Medium padding should be multiple of 4');
    });
  });

  group('Color Constants', () {
    test('All colors should be valid Color objects', () {
      expect(successColor, isA<Color>(),
          reason: 'Success color should be a Color');
      expect(errorColor, isA<Color>(), reason: 'Error color should be a Color');
      expect(infoColor, isA<MaterialColor>(),
          reason: 'Info color should be a MaterialColor');
      expect(whiteColor, isA<Color>(), reason: 'White color should be a Color');
      expect(blackColor, isA<Color>(), reason: 'Black color should be a Color');
      expect(lightGreyColor, isA<Color>(),
          reason: 'Light grey color should be a Color');
    });

    test('Status colors should match expected color families', () {
      expect(successColor, Colors.green,
          reason: 'Success color should be green for positive feedback');
      expect(errorColor, Colors.red,
          reason: 'Error color should be red for error feedback');
      expect(infoColor, Colors.blue,
          reason: 'Info color should be blue for informational feedback');
    });

    test('Neutral colors should be correctly defined', () {
      expect(whiteColor, Colors.white,
          reason: 'White color should be Colors.white');
      expect(blackColor, Colors.black,
          reason: 'Black color should be Colors.black');
      expect(lightGreyColor, isA<Color>(),
          reason: 'Light grey should be a valid Color');
    });
  });

  group('Timing Constants (UX Performance)', () {
    test('Animation duration should be in reasonable range', () {
      expect(animationDuration.inMilliseconds, greaterThan(0),
          reason: 'Animation duration should be positive');
      expect(animationDuration.inMilliseconds, lessThan(2000),
          reason:
              'Animation duration should be less than 2 seconds for good UX');
      expect(animationDuration.inMilliseconds, greaterThanOrEqualTo(200),
          reason: 'Animation should be at least 200ms to be noticeable');
    });

    test('Snackbar duration should be readable but not intrusive', () {
      expect(snackbarDuration.inSeconds, greaterThan(0),
          reason: 'Snackbar duration should be positive');
      expect(snackbarDuration.inSeconds, lessThanOrEqualTo(10),
          reason: 'Snackbar should not persist too long');
      expect(snackbarDuration.inSeconds, greaterThanOrEqualTo(2),
          reason: 'Snackbar should be visible long enough to read');
    });
  });

  group('UI Dimension Constants', () {
    test('Border radius should be positive', () {
      expect(borderRadius, greaterThan(0),
          reason: 'Border radius should be positive for rounded corners');
      expect(borderRadius, 12.0,
          reason: 'Border radius should be 12.0 for modern UI');
    });

    test('Card elevation should be positive', () {
      expect(cardElevation, greaterThan(0),
          reason: 'Card elevation should be positive for shadow effect');
      expect(cardElevation, lessThanOrEqualTo(24),
          reason: 'Card elevation should not exceed Material Design max (24)');
    });

    test('Chat panel width should be appropriate for desktop', () {
      expect(chatPanelWidth, greaterThan(200),
          reason: 'Chat panel should be wide enough for content');
      expect(chatPanelWidth, lessThan(600),
          reason: 'Chat panel should not take up too much screen space');
      expect(chatPanelWidth, 360.0, reason: 'Chat panel width should be 360.0');
    });
  });

  group('String Constants (Checkout Labels)', () {
    test('Order summary label should be defined', () {
      expect(orderSummaryTitle, isNotEmpty,
          reason: 'Order summary title should not be empty');
      expect(orderSummaryTitle, isA<String>(),
          reason: 'Order summary title should be a String');
    });

    test('Payment method label should be defined', () {
      expect(paymentMethodTitle, isNotEmpty,
          reason: 'Payment method title should not be empty');
      expect(paymentMethodTitle, isA<String>(),
          reason: 'Payment method title should be a String');
    });

    test('Gift card label should be defined', () {
      expect(giftCardTitle, isNotEmpty,
          reason: 'Gift card title should not be empty');
      expect(giftCardTitle, isA<String>(),
          reason: 'Gift card title should be a String');
    });
  });

  group('URL Constants (External Resources)', () {
    test('Default no-image URL should be valid', () {
      expect(defaultNoImageUrl, isNotEmpty,
          reason: 'Default no-image URL should not be empty');
      expect(defaultNoImageUrl, contains('http'),
          reason: 'Default no-image URL should be a valid HTTP/HTTPS URL');
      expect(Uri.tryParse(defaultNoImageUrl), isNotNull,
          reason: 'Default no-image URL should be parseable as URI');
    });

    test('Google logo URL should be valid', () {
      expect(googleLogoUrl, isNotEmpty,
          reason: 'Google logo URL should not be empty');
      expect(googleLogoUrl, contains('http'),
          reason: 'Google logo URL should be a valid HTTP/HTTPS URL');
      expect(Uri.tryParse(googleLogoUrl), isNotNull,
          reason: 'Google logo URL should be parseable as URI');
    });
  });

  group('Consistency and Relationships', () {
    test('Animation and snackbar durations should be compatible', () {
      expect(snackbarDuration, greaterThan(animationDuration),
          reason: 'Snackbar should be visible longer than its animation');
    });

    test('All numeric spacing values should be defined', () {
      expect(defaultPadding, isNotNull,
          reason: 'Default padding should be defined');
      expect(smallPadding, isNotNull,
          reason: 'Small padding should be defined');
      expect(mediumPadding, isNotNull,
          reason: 'Medium padding should be defined');
      expect(borderRadius, isNotNull,
          reason: 'Border radius should be defined');
    });

    test('All required color constants should exist', () {
      expect(successColor, isNotNull,
          reason: 'Success color should be defined');
      expect(errorColor, isNotNull, reason: 'Error color should be defined');
      expect(infoColor, isNotNull, reason: 'Info color should be defined');
      expect(whiteColor, isNotNull, reason: 'White color should be defined');
      expect(blackColor, isNotNull, reason: 'Black color should be defined');
    });
  });
}
