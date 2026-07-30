/// Construye el `ThemeData` de Material a partir de los tokens de SOZU.
///
/// Cuelga `SozuTheme` como `ThemeExtension` (para que `context.s` funcione) y
/// mapea los roles a los temas de componente de Material, para que AppBar,
/// SnackBar, diálogos y TextField hereden la apariencia SOZU sin pedirlo.
library;

import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/tokens/typography.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Tema claro. **Memoizado**: siempre devuelve la MISMA instancia.
///
/// Devolver una instancia nueva hace que el `AnimatedTheme` del `MaterialApp`
/// re-interpole el tema completo 200 ms en cada rebuild (`SozuTheme` no
/// implementa `==`, así que el mapa de extensiones se compara por identidad).
/// La densidad y el movimiento reducido NO se resuelven aquí sino en
/// `SozuAdaptiveTokens`, más abajo en el árbol.
ThemeData sozuLightTheme() => _lightTheme;

/// Tema oscuro. Memoizado por las mismas razones que [sozuLightTheme].
ThemeData sozuDarkTheme() => _darkTheme;

final ThemeData _lightTheme = _build(SozuTheme.light, Brightness.light);
final ThemeData _darkTheme = _build(SozuTheme.dark, Brightness.dark);

ThemeData _build(SozuTheme t, Brightness brightness) {
  final c = t.color;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    primaryContainer: c.primarySoft,
    onPrimaryContainer: c.fg,
    secondary: c.primaryHover,
    onSecondary: c.onPrimary,
    surface: c.surface,
    onSurface: c.fg,
    surfaceContainerHighest: c.surfaceAlt,
    onSurfaceVariant: c.fgMuted,
    outline: c.border,
    outlineVariant: c.borderSoft,
    error: c.danger,
    onError: c.onPrimary,
    errorContainer: c.dangerSoft,
    onErrorContainer: c.danger,
    tertiary: c.warning,
    onTertiary: c.fg,
  );

  final textTheme = sozuTextThemeFrom(t);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: kSozuFontFamily,
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: c.background,
    canvasColor: c.surface,
    dividerColor: c.border,
    extensions: <ThemeExtension<dynamic>>[t],

    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),

    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      foregroundColor: c.fg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: t.text.h2.copyWith(fontSize: 20, color: c.fg),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: c.surface,
      selectedItemColor: c.primaryHover,
      unselectedItemColor: c.fgSubtle,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: t.text.overline.copyWith(fontSize: 11),
      unselectedLabelStyle: t.text.overline.copyWith(fontSize: 11),
    ),

    cardTheme: CardThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: t.radius.cardBorder,
        side: BorderSide(color: c.border),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceAlt,
      hintStyle: t.text.body.copyWith(color: c.fgSubtle),
      labelStyle: t.text.label.copyWith(color: c.fgMuted),
      errorStyle: t.text.caption.copyWith(color: c.danger),
      border: OutlineInputBorder(
        borderRadius: t.radius.mdBorder,
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: t.radius.mdBorder,
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: t.radius.mdBorder,
        borderSide: BorderSide(color: c.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: t.radius.mdBorder,
        borderSide: BorderSide(color: c.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: t.radius.mdBorder,
        borderSide: BorderSide(color: c.danger, width: 1.5),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        disabledBackgroundColor: c.muted,
        disabledForegroundColor: c.fgSubtle,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: t.radius.lgBorder),
        textStyle: t.text.button.copyWith(fontSize: 16),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.fg,
        side: BorderSide(color: c.border),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: t.radius.lgBorder),
        textStyle: t.text.button,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.primaryHover,
        textStyle: t.text.button,
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: c.muted,
      side: BorderSide(color: c.border),
      labelStyle: t.text.caption.copyWith(color: c.fgMuted),
      shape: RoundedRectangleBorder(borderRadius: t.radius.fullBorder),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: t.radius.cardBorder),
      titleTextStyle: t.text.h3.copyWith(color: c.fg),
      contentTextStyle: t.text.body.copyWith(color: c.fgMuted),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: c.overlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(t.radius.card),
        ),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.fg,
      contentTextStyle: t.text.body.copyWith(color: c.surface),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: t.radius.mdBorder),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.primary,
      linearTrackColor: c.muted,
      circularTrackColor: c.muted,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected) ? c.onPrimary : c.surface,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected) ? c.primary : c.muted,
      ),
    ),

    listTileTheme: ListTileThemeData(
      iconColor: c.fgMuted,
      textColor: c.fg,
      shape: RoundedRectangleBorder(borderRadius: t.radius.mdBorder),
    ),

    iconTheme: IconThemeData(color: c.fgMuted),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.fg,
        borderRadius: BorderRadius.circular(t.radius.sm),
      ),
      textStyle: t.text.caption.copyWith(color: c.surface),
    ),
  );
}
