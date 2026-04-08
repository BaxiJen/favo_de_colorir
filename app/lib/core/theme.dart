import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design System: "Artisanal Modernism" — The Digital Atelier
/// Baseado no DESIGN.md do Stitch
class FavoColors {
  FavoColors._();

  // Surface hierarchy (clay & paper layers)
  static const Color surface = Color(0xFFFFF8F4);
  static const Color surfaceContainerLow = Color(0xFFFCF2EA);
  static const Color surfaceContainer = Color(0xFFF6ECE5);
  static const Color surfaceContainerHigh = Color(0xFFF0E5DD);
  static const Color surfaceContainerHighest = Color(0xFFEAE1D9);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);

  // Primary (deep brown/amber)
  static const Color primary = Color(0xFF8D4B00);
  static const Color primaryContainer = Color(0xFFB15F00);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFFFDCC3);

  // Secondary (warm terracotta)
  static const Color secondary = Color(0xFFC75B39);
  static const Color secondaryContainer = Color(0xFFFFDBCF);
  static const Color onSecondaryContainer = Color(0xFF5D1900);

  // Text
  static const Color onSurface = Color(0xFF1F1B17);
  static const Color onSurfaceVariant = Color(0xFF554336);
  static const Color outline = Color(0xFF857568);
  static const Color outlineVariant = Color(0xFFDBC2B0);

  // Semantic
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFBA1A1A);
  static const Color warning = Color(0xFFFFA726);

  // Legacy aliases (para não quebrar código existente)
  static const Color honey = primary;
  static const Color honeyLight = surfaceContainerLow;
  static const Color honeyDark = Color(0xFF6D3A00);
  static const Color terracotta = secondary;
  static const Color cream = surface;
  static const Color warmWhite = surfaceContainerLowest;
  static const Color warmGray = onSurfaceVariant;
  static const Color darkBrown = onSurface;
}

class FavoTheme {
  FavoTheme._();

  static TextTheme get _textTheme {
    // Epilogue for display/headlines (artisanal voice)
    // Manrope for body/titles (functional voice)
    final epilogue = GoogleFonts.epilogueTextTheme();
    final manrope = GoogleFonts.manropeTextTheme();

    return TextTheme(
      // Display — Epilogue, editorial impact
      displayLarge: epilogue.displayLarge!.copyWith(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        color: FavoColors.onSurface,
        letterSpacing: -1.5,
      ),
      displayMedium: epilogue.displayMedium!.copyWith(
        fontSize: 44,
        fontWeight: FontWeight.w700,
        color: FavoColors.onSurface,
        letterSpacing: -0.5,
      ),
      displaySmall: epilogue.displaySmall!.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: FavoColors.onSurface,
      ),

      // Headlines — Epilogue
      headlineLarge: epilogue.headlineLarge!.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: FavoColors.onSurface,
      ),
      headlineMedium: epilogue.headlineMedium!.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: FavoColors.onSurface,
      ),
      headlineSmall: epilogue.headlineSmall!.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: FavoColors.onSurface,
      ),

      // Titles — Manrope
      titleLarge: manrope.titleLarge!.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: FavoColors.onSurface,
      ),
      titleMedium: manrope.titleMedium!.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: FavoColors.onSurface,
      ),
      titleSmall: manrope.titleSmall!.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: FavoColors.onSurface,
      ),

      // Body — Manrope
      bodyLarge: manrope.bodyLarge!.copyWith(
        fontSize: 16,
        color: FavoColors.onSurfaceVariant,
      ),
      bodyMedium: manrope.bodyMedium!.copyWith(
        fontSize: 14,
        color: FavoColors.onSurfaceVariant,
      ),
      bodySmall: manrope.bodySmall!.copyWith(
        fontSize: 12,
        color: FavoColors.onSurfaceVariant,
      ),

      // Labels — Manrope
      labelLarge: manrope.labelLarge!.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: FavoColors.onSurface,
      ),
      labelMedium: manrope.labelMedium!.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: FavoColors.onSurfaceVariant,
      ),
      labelSmall: manrope.labelSmall!.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: FavoColors.onSurfaceVariant,
      ),
    );
  }

  static ThemeData get light {
    final textTheme = _textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: FavoColors.primary,
        primaryContainer: FavoColors.primaryContainer,
        onPrimary: FavoColors.onPrimary,
        secondary: FavoColors.secondary,
        secondaryContainer: FavoColors.secondaryContainer,
        surface: FavoColors.surface,
        onSurface: FavoColors.onSurface,
        onSurfaceVariant: FavoColors.onSurfaceVariant,
        outline: FavoColors.outline,
        outlineVariant: FavoColors.outlineVariant,
        error: FavoColors.error,
      ),
      scaffoldBackgroundColor: FavoColors.surface,
      textTheme: textTheme,

      // AppBar — clean, no elevation, no line
      appBarTheme: AppBarTheme(
        backgroundColor: FavoColors.surface,
        foregroundColor: FavoColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),

      // Cards — no border, tonal shift for depth ("No-Line" philosophy)
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: FavoColors.surfaceContainerLowest,
        margin: EdgeInsets.zero,
      ),

      // Elevated buttons — rounded xl, gradient-like
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FavoColors.primary,
          foregroundColor: FavoColors.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(48),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Outlined buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FavoColors.primary,
          side: BorderSide(color: FavoColors.outlineVariant.withAlpha(40)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(48),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FavoColors.primary,
        ),
      ),

      // Input fields — filled, no border, tonal shift on focus
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FavoColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: FavoColors.primary.withAlpha(100),
            width: 1,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: FavoColors.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        labelStyle: textTheme.bodyMedium,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: FavoColors.onSurfaceVariant.withAlpha(128),
        ),
      ),

      // Navigation bar — warm, organic
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: FavoColors.surfaceContainerLow,
        indicatorColor: FavoColors.primaryContainer.withAlpha(40),
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      ),

      // FAB — ambient glow
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: FavoColors.primary,
        foregroundColor: FavoColors.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // Chips — rounded-full (smooth pebbles)
      chipTheme: ChipThemeData(
        backgroundColor: FavoColors.surfaceContainerLow,
        selectedColor: FavoColors.primaryContainer.withAlpha(40),
        labelStyle: textTheme.labelMedium!,
        shape: const StadiumBorder(),
        side: BorderSide.none,
      ),

      // Divider — ghost, not visible
      dividerTheme: DividerThemeData(
        color: FavoColors.outlineVariant.withAlpha(40),
        thickness: 0.5,
      ),

      // ListTile
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: FavoColors.surface,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return FavoColors.onPrimary;
          }
          return FavoColors.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return FavoColors.primary;
          }
          return FavoColors.surfaceContainerHigh;
        }),
      ),
    );
  }
}
