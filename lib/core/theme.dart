import 'package:flutter/material.dart';

// ============================================================================
// vidviz DESIGN SYSTEM
// ============================================================================

// --- Core Colors (Neutral Elegance Palette) ---
const Color primary = Color(0xFF2D3436);        // Koyu gri
const Color secondary = Color(0xFF636E72);      // Orta gri
const Color accent = Color(0xFF0984E3);         // Soft mavi
const Color surface = Color(0xFFF8F9FA);        // Açık gri
const Color background = Color(0xFFFFFFFF);     // Beyaz
const Color error = Color(0xFFD63031);          // Kırmızı
const Color success = Color(0xFF00B894);        // Yeşil
const Color warning = Color(0xFFFDCB6E);        // Sarı

// --- Text Colors ---
const Color textPrimary = Color(0xFF2D3436);    // Ana metin
const Color textSecondary = Color(0xFF636E72);  // İkincil metin
const Color textDisabled = Color(0xFFB2BEC3);   // Disabled
const Color textOnAccent = Color(0xFFFFFFFF);   // Accent üzerinde

// --- Dark Mode Colors ---
const Color darkPrimary = Color(0xFFFAFAFA);    // Neredeyse beyaz
const Color darkSecondary = Color(0xFFB2BEC3);  // Açık gri
const Color darkAccent = Color(0xFF74B9FF);     // Açık mavi
const Color darkSurface = Color(0xFF1E1E1E);    // Yumuşak siyah
const Color darkBackground = Color(0xFF121212); // Daha koyu
const Color darkTextPrimary = Color(0xFFFAFAFA);
const Color darkTextSecondary = Color(0xFFB2BEC3);

// --- Border & Divider ---
const Color border = Color(0xFFDFE6E9);         // Light border
const Color divider = Color(0xFFECF0F1);        // Light divider
const Color darkBorder = Color(0xFF2D3436);     // Dark border
const Color darkDivider = Color(0xFF363636);    // Dark divider

// --- Spacing System (4px base unit) ---
const double spaceXXS = 4.0;
const double spaceXS = 8.0;
const double spaceS = 12.0;
const double spaceM = 16.0;   // Default
const double spaceL = 24.0;
const double spaceXL = 32.0;
const double spaceXXL = 48.0;

// --- Border Radius ---
const double radiusS = 8.0;
const double radiusM = 12.0;  // Default
const double radiusL = 16.0;
const double radiusXL = 24.0;
const double radiusFull = 999.0; // Pill shape

// --- Elevation (Minimal shadows) ---
const double elevationNone = 0.0;
const double elevationS = 1.0;
const double elevationM = 2.0;
const double elevationL = 4.0;

// --- Typography Sizes ---
const double textDisplay = 28.0;   // Page titles
const double textTitle = 20.0;     // Card titles
const double textBody = 16.0;      // Content
const double textCaption = 14.0;   // Metadata
const double textSmall = 12.0;     // Labels

// --- Icon Sizes ---
const double iconS = 16.0;
const double iconM = 24.0;  // Default
const double iconL = 32.0;
const double iconXL = 48.0;

// --- Animation Durations ---
const Duration animFast = Duration(milliseconds: 150);
const Duration animNormal = Duration(milliseconds: 250);
const Duration animSlow = Duration(milliseconds: 300);
const Duration animCardBackground = Duration(seconds: 15);  // Card gradient animation
const Duration animHeaderBackground = Duration(seconds: 20); // Header gradient animation
const Duration animZoom = Duration(seconds: 10);            // Zoom animation

// --- Particle Settings ---
const int particleCountCard = 10;    // Card'larda az particle (performance)
const int particleCountHeader = 25;  // Header'da daha fazla

// --- Neon Gradient Palettes (ProjectList için) ---
const List<List<Color>> neonPalettes = [
  [Color(0xFF4A00E0), Color(0xFF8E2DE2)], // Mor → Mavi
  [Color(0xFFFF0099), Color(0xFF493240)], // Pembe → Koyu
  [Color(0xFF00F260), Color(0xFF0575E6)], // Yeşil → Mavi
  [Color(0xFFFF512F), Color(0xFFDD2476)], // Turuncu → Pembe
];

// --- ProjectList Specific Colors ---
const Color projectListBg = Color(0xFF101010);        // Ana arka plan
const Color projectListCardBg = Color(0xFF1E1E1E);    // Card arka plan
const Color projectListCardBorder = Color(0x1AFFFFFF); // Card border (10% white)

// --- Neon Button Gradient ---
const LinearGradient neonButtonGradient = LinearGradient(
  colors: [Color(0xFF00E5FF), Color(0xFF2979FF)],
);

// --- Button Colors ---
const Color neonCyan = Color(0xFF00E5FF);           // Neon cyan for shadows
const Color transparent = Colors.transparent;       // Transparent color
const Color buttonTextColor = Colors.white;         // Button text color

// --- Video Player Colors ---
const Color videoPlayerBg = Colors.black;           // Video player background
const Color videoPlayerControls = Colors.white;     // Video player controls

// --- Layer/Asset Type Colors (Timeline için) ---
const Color layerRaster = Color(0xFF002AFF);        // Raster/Photo - Pembe
const Color layerVector = Color(0xFF006FFF);        // Vector/Text - Cyan
const Color layerVisualizer = Color(0xFF9900FF);    // Visualizer - Mor
const Color layerShader = Color(0xFF00E3E3);        // Shader - Turuncu
const Color layerOverlay = Color(0xFF00CA08);       // Media Overlay - Yeşil
const Color layerAudioReactive = Color(0xFFFF5F3B); // Audio Reactive - Sarı
const Color layerAudio = Color(0xFFFF9800);         // Audio - Mavi
const Color layerDeleted = Color(0xFFFF2B2B);

const Color assetRed = Color(0xFFFF1F6D);         // Audio - Mavi
const Color assetGreen = Color(0xFF25FF95);         // Audio - Mavi

ThemeData buildDarkTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    scaffoldBackgroundColor: darkBackground,  // Modern: #121212
    canvasColor: darkSurface,                 // Modern: #1E1E1E
    primaryColor: darkAccent,                 // Modern: #74B9FF
    colorScheme: base.colorScheme.copyWith(
      primary: darkAccent,                    // #74B9FF
      secondary: Color(0xFF00E5FF),           // Neon cyan
      background: darkBackground,             // #121212
      surface: darkSurface,                   // #1E1E1E
      onPrimary: darkTextPrimary,             // #FAFAFA
      onSecondary: darkTextPrimary,
      onBackground: darkTextPrimary,
      onSurface: darkTextPrimary,
      error: error,                           // #D63031
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: darkSurface,           // #1E1E1E
      foregroundColor: darkTextPrimary,       // #FAFAFA
      elevation: elevationNone,               // 0
    ),
    iconTheme: IconThemeData(color: darkTextPrimary),
    textTheme: base.textTheme.apply(
      bodyColor: darkTextPrimary,
      displayColor: darkTextPrimary,
    ),
    dividerColor: darkDivider,                // #363636
    cardColor: darkSurface,                   // #1E1E1E
  );
}

ThemeData buildLightTheme() {
  final base = ThemeData.light();
  return base.copyWith(
    scaffoldBackgroundColor: background,      // Modern: #FFFFFF
    canvasColor: surface,                     // Modern: #F8F9FA
    primaryColor: accent,                     // Modern: #0984E3
    colorScheme: base.colorScheme.copyWith(
      primary: accent,                        // #0984E3
      secondary: Color(0xFF00B894),           // Success green
      background: background,                 // #FFFFFF
      surface: surface,                       // #F8F9FA
      onPrimary: textOnAccent,                // #FFFFFF
      onSecondary: textOnAccent,
      onBackground: textPrimary,              // #2D3436
      onSurface: textPrimary,
      error: error,                           // #D63031
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,               // #F8F9FA
      foregroundColor: textPrimary,           // #2D3436
      elevation: elevationNone,               // 0
    ),
    iconTheme: IconThemeData(color: textPrimary),
    textTheme: base.textTheme.apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    ),
    dividerColor: divider,                    // #ECF0F1
    cardColor: surface,                       // #F8F9FA
  );
}

/// ThemeData extension - Yardımcı getter'lar
extension AppThemeExtension on ThemeData {
  bool get isDark => brightness == Brightness.dark;
}
