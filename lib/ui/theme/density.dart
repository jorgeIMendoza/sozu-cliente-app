import 'package:sozu_cliente_app/ui/theme/breakpoints.dart';

/// Densidad de la interfaz: mismo color con otro aire (paddings, radios y
/// tamaño de títulos). No cambia la paleta.
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

  /// Densidad implícita en un breakpoint. `tablet` ya usa la escala holgada.
  static SozuDensity fromBreakpoint(SozuBreakpoint bp) =>
      bp.isMobile ? SozuDensity.compact : SozuDensity.comfortable;
}
