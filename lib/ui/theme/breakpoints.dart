import 'package:flutter/material.dart';

/// Breakpoints y medidas de layout, alineados a Tailwind (`md` = 768,
/// `lg` = 1024).
///
/// Miran SOLO el ancho disponible, nunca `kIsWeb`: un layout se decide por el
/// espacio que tiene, no por la plataforma.
enum SozuBreakpoint {
  /// < 768 - teléfono. Una columna, bottom-nav.
  mobile,

  /// 768-1023 - tablet / ventana media. Dos columnas, aún sin sidebar.
  tablet,

  /// ≥ 1024 - escritorio. Sidebar 256 + topbar 64.
  desktop;

  bool get isMobile => this == SozuBreakpoint.mobile;
  bool get isTablet => this == SozuBreakpoint.tablet;
  bool get isDesktop => this == SozuBreakpoint.desktop;

  /// true si hay espacio para el shell ancho (sidebar + topbar).
  bool get hasSidebar => this == SozuBreakpoint.desktop;

  /// true si caben dos columnas (`1fr + 300px` del estado de cuenta).
  bool get hasTwoColumns => this != SozuBreakpoint.mobile;

  static SozuBreakpoint fromWidth(double width) {
    if (width >= kSozuDesktopMin) return SozuBreakpoint.desktop;
    if (width >= kSozuTabletMin) return SozuBreakpoint.tablet;
    return SozuBreakpoint.mobile;
  }
}

/// Ancho mínimo para dos columnas (Tailwind `md`).
const double kSozuTabletMin = 768;

/// Ancho mínimo para el shell con sidebar (Tailwind `lg`).
const double kSozuDesktopMin = 1024;

// ---------------------------------------------------------------------------
// Medidas del shell ancho
// ---------------------------------------------------------------------------

/// Ancho de la barra lateral fija (`w-60`). Entre los 256 originales, que le
/// robaban aire a la columna de contenido, y los 224 que dejaban las etiquetas
/// apretadas contra el borde.
const double kSozuSidebarWidth = 240;

/// Alto de la topbar (`h-16`).
const double kSozuTopBarHeight = 64;

/// Max-width del área de contenido (`xl:max-w-7xl`), centrado en pantallas
/// anchas.
const double kSozuContentMaxWidth = 1280;

extension SozuBreakpointX on BuildContext {
  /// Breakpoint actual. Usa `MediaQuery.sizeOf`: solo reconstruye cuando cambia
  /// el tamaño, no con cada cambio de padding, teclado o brillo.
  SozuBreakpoint get bp =>
      SozuBreakpoint.fromWidth(MediaQuery.sizeOf(this).width);

  /// Elige un valor por breakpoint, cayendo hacia abajo cuando falta.
  ///
  /// ```dart
  /// final cols = context.responsive(mobile: 1, tablet: 2, desktop: 3);
  /// final pad  = context.responsive(mobile: 16, desktop: 32); // tablet → 16
  /// ```
  T responsive<T>({required T mobile, T? tablet, T? desktop}) {
    switch (bp) {
      case SozuBreakpoint.desktop:
        return desktop ?? tablet ?? mobile;
      case SozuBreakpoint.tablet:
        return tablet ?? mobile;
      case SozuBreakpoint.mobile:
        return mobile;
    }
  }
}
