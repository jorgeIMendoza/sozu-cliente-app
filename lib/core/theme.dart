import 'package:flutter/material.dart';

/// Tokens de diseño SOZU (espejo de src/theme/theme.ts del app RN).
/// Verde esmeralda primario, ámbar para pendientes, fondo claro, tarjetas
/// con esquinas redondeadas y sombra suave. Soporta claro/oscuro.
class SozuColors {
  // Paleta base
  static const emerald50 = Color(0xFFECFDF5);
  static const emerald100 = Color(0xFFD1FAE5);
  static const emerald400 = Color(0xFF34D399);
  static const emerald500 = Color(0xFF10B981); // primario
  static const emerald600 = Color(0xFF059669);
  static const emerald700 = Color(0xFF047857);

  static const amber50 = Color(0xFFFFFBEB);
  static const amber500 = Color(0xFFF59E0B);
  static const amber600 = Color(0xFFD97706);

  static const rose500 = Color(0xFFF43F5E);
  static const rose600 = Color(0xFFE11D48);

  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);

  // Oscuro
  static const primarySoftDark = Color(0xFF0B3B30);
  static const pendingSoftDark = Color(0xFF3B2F0B);
}

/// Colores semánticos dependientes del tema.
class SozuTone {
  final Color primary;
  final Color primaryDark;
  final Color primarySoft;
  final Color positive;
  final Color pending;
  final Color pendingSoft;
  final Color negative;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  const SozuTone({
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.positive,
    required this.pending,
    required this.pendingSoft,
    required this.negative,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  static const light = SozuTone(
    primary: SozuColors.emerald500,
    primaryDark: SozuColors.emerald600,
    primarySoft: SozuColors.emerald50,
    positive: SozuColors.emerald600,
    pending: SozuColors.amber500,
    pendingSoft: SozuColors.amber50,
    negative: SozuColors.rose600,
    background: SozuColors.slate50,
    surface: Colors.white,
    surfaceAlt: SozuColors.slate50,
    border: SozuColors.slate200,
    textPrimary: SozuColors.slate900,
    textSecondary: SozuColors.slate600,
    textMuted: SozuColors.slate400,
  );

  static const dark = SozuTone(
    primary: SozuColors.emerald500,
    primaryDark: SozuColors.emerald400,
    primarySoft: SozuColors.primarySoftDark,
    positive: SozuColors.emerald400,
    pending: SozuColors.amber500,
    pendingSoft: SozuColors.pendingSoftDark,
    negative: SozuColors.rose500,
    background: SozuColors.slate900,
    surface: SozuColors.slate800,
    surfaceAlt: SozuColors.slate700,
    border: SozuColors.slate700,
    textPrimary: SozuColors.slate50,
    textSecondary: SozuColors.slate300,
    textMuted: SozuColors.slate400,
  );

  static SozuTone of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

ThemeData sozuLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: SozuColors.emerald500,
    brightness: Brightness.light,
  ).copyWith(
    primary: SozuColors.emerald500,
    secondary: SozuColors.emerald600,
    surface: Colors.white,
  );
  return _base(scheme, SozuTone.light);
}

ThemeData sozuDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: SozuColors.emerald500,
    brightness: Brightness.dark,
  ).copyWith(
    primary: SozuColors.emerald500,
    secondary: SozuColors.emerald400,
    surface: SozuColors.slate800,
  );
  return _base(scheme, SozuTone.dark);
}

ThemeData _base(ColorScheme scheme, SozuTone tone) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: tone.background,
    appBarTheme: AppBarTheme(
      backgroundColor: tone.background,
      foregroundColor: tone.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: tone.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: tone.surface,
      selectedItemColor: tone.primaryDark,
      unselectedItemColor: tone.textMuted,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tone.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: tone.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: tone.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: SozuColors.emerald500, width: 1.5),
      ),
      hintStyle: TextStyle(color: tone.textMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SozuColors.emerald500,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
