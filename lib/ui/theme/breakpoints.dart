import 'package:flutter/material.dart';

/// Breakpoints y medidas de layout.
///
/// Alineados a Tailwind, que es de donde vienen los del portal: `md` = 768,
/// `lg` = 1024.
///
/// **Diferencia importante con el `isPortalMode` legacy:** estos breakpoints
/// miran SOLO el ancho disponible, nunca `kIsWeb`. El predicado viejo
/// (`kIsWeb && width >= 1024`) tiene dos defectos: una tablet Android en
/// horizontal nunca recibe el layout ancho aunque le quede mejor, y Flutter web
/// embebido en un contenedor angosto entra al branch equivocado. Un layout debe
/// decidirse por el espacio que tiene, no por la plataforma.
///
/// El legacy se conserva intacto durante la transición para no cambiar el
/// comportamiento de las 25 pantallas que lo usan hoy.
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

/// Ancho de la sidebar fija (`w-64`).
const double kSozuSidebarWidth = 256;

/// Alto de la topbar (`h-16`).
const double kSozuTopBarHeight = 64;

/// Max-width del área de contenido (`xl:max-w-7xl`), centrado en pantallas
/// anchas. Sin esto, en un monitor de 2560 px las líneas de texto se vuelven
/// ilegibles de largas.
const double kSozuContentMaxWidth = 1280;

extension SozuBreakpointX on BuildContext {
  /// Breakpoint actual según el ancho disponible.
  ///
  /// Usa `MediaQuery.sizeOf`, así que solo reconstruye cuando cambia el tamaño
  /// -no en cada cambio de padding, teclado o brillo.
  SozuBreakpoint get bp =>
      SozuBreakpoint.fromWidth(MediaQuery.sizeOf(this).width);

  /// Elige un valor por breakpoint, cayendo hacia abajo cuando falta.
  ///
  /// ```dart
  /// final cols = context.responsive(mobile: 1, tablet: 2, desktop: 3);
  /// final pad  = context.responsive(mobile: 16, desktop: 32); // tablet → 16
  /// ```
  ///
  /// Esto reemplaza a `if (isPortalMode(context)) … else …`: en vez de bifurcar
  /// el árbol de widgets (dos ramas que hay que mantener sincronizadas), se
  /// bifurca solo el valor.
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
