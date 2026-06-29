import 'package:flutter/material.dart';

import 'metallic_surface.dart';

class AppTheme {
  static const _gunmetal = Color(0xFF56616D);
  static const _steel = Color(0xFF7D8792);
  static const _silver = Color(0xFFC9CED3);
  static const _graphite = Color(0xFF20252B);

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: _gunmetal,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDCE1E6),
      onPrimaryContainer: Color(0xFF11161B),
      secondary: _steel,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE7EAEE),
      onSecondaryContainer: Color(0xFF171C21),
      tertiary: Color(0xFF8D7F6F),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFF3E5D4),
      onTertiaryContainer: Color(0xFF2D2217),
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: Color(0xFFF8F9FA),
      onSurface: Color(0xFF181C20),
      surfaceContainerHighest: Color(0xFFE1E5EA),
      onSurfaceVariant: Color(0xFF424950),
      outline: Color(0xFF727A83),
      outlineVariant: Color(0xFFC2C8CF),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFF2D3136),
      onInverseSurface: Color(0xFFEFF1F3),
      inversePrimary: _silver,
    );
    return _buildTheme(
      scheme,
      const MetallicPalette(
        base: Color(0xFFF1F3F5),
        sheen: Colors.white,
        wave: Color(0xFFD4D9DF),
        ridge: Color(0xFFAEB7C0),
        panel: Color(0xDDF7F8FA),
        panelBorder: Color(0xBFFFFFFF),
      ),
    );
  }

  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _silver,
      onPrimary: Color(0xFF20252B),
      primaryContainer: Color(0xFF3A424A),
      onPrimaryContainer: Color(0xFFE8ECEF),
      secondary: Color(0xFFB7C0C9),
      onSecondary: Color(0xFF22272D),
      secondaryContainer: Color(0xFF3B434B),
      onSecondaryContainer: Color(0xFFE5E9ED),
      tertiary: Color(0xFFD7C4AE),
      onTertiary: Color(0xFF302519),
      tertiaryContainer: Color(0xFF493A2A),
      onTertiaryContainer: Color(0xFFF3E5D4),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: _graphite,
      onSurface: Color(0xFFE7EAEE),
      surfaceContainerHighest: Color(0xFF444B53),
      onSurfaceVariant: Color(0xFFC4CAD1),
      outline: Color(0xFF8D96A0),
      outlineVariant: Color(0xFF444B53),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFE7EAEE),
      onInverseSurface: Color(0xFF20252B),
      inversePrimary: _gunmetal,
    );
    return _buildTheme(
      scheme,
      const MetallicPalette(
        base: Color(0xFF111417),
        sheen: Color(0xFF4D5660),
        wave: Color(0xFF2B3138),
        ridge: Color(0xFF6D7782),
        panel: Color(0xDD20252B),
        panelBorder: Color(0x667D8792),
      ),
    );
  }

  static ThemeData _buildTheme(ColorScheme scheme, MetallicPalette metallic) {
    final isDark = scheme.brightness == Brightness.dark;
    final textTheme = Typography.material2021(
      platform: TargetPlatform.android,
    ).black.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      extensions: [metallic],
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: metallic.panel,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: metallic.panel,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: metallic.panelBorder),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: metallic.panel,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer.withValues(
          alpha: isDark ? 0.65 : 0.8,
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface.withValues(alpha: isDark ? 0.35 : 0.72),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(width: 1.6, color: scheme.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.secondaryContainer.withValues(alpha: 0.72),
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: isDark ? 0.5 : 0.8),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
