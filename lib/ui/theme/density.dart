import 'package:sozu_cliente_app/ui/theme/breakpoints.dart';

/// Densidad de la interfaz.
///
/// Esta es la respuesta correcta a "¿web debe verse distinto de móvil?".
/// La respuesta NO es "otra paleta de color" —así nació la bifurcación
/// `SozuTone` / `PortalColors`— sino "el mismo color con otro aire": paddings,
/// radios y tamaño de títulos.
///
/// Un solo eje, dos valores. Si aparece un tercero, casi siempre significa que
/// alguien quería un componente distinto, no una densidad distinta.
enum SozuDensity {
  /// Teléfono y ventanas angostas: paddings apretados, títulos un paso menores,
  /// radios de card más cerrados.
  compact,

  /// Tablet y escritorio: la escala completa.
  comfortable;

  bool get isCompact => this == SozuDensity.compact;

  /// Densidad implícita en un breakpoint. `tablet` ya usa la escala holgada:
  /// a 768 px hay espacio de sobra y así el salto visual ocurre una sola vez.
  static SozuDensity fromBreakpoint(SozuBreakpoint bp) =>
      bp.isMobile ? SozuDensity.compact : SozuDensity.comfortable;
}
