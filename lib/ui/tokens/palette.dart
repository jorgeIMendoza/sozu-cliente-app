/// Rampas de color CRUDAS de SOZU. Nivel más bajo del design system.
///
/// **No usar estas constantes en pantallas.** Son la materia prima con la que
/// `color_roles.dart` compone los roles semánticos (`surface`, `fgMuted`,
/// `danger`, …). Una pantalla que pide `SozuNeutral.n500` está diciendo "quiero
/// este gris", cuando debería decir "quiero texto secundario" —y así es como se
/// bifurcó la paleta antes.
///
/// Uso correcto: `context.s.color.fgMuted`.
///
/// Estos valores son la fuente de verdad única: si alguna vez se genera CSS
/// para otra superficie, se genera desde aquí.
library;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Marca
// ---------------------------------------------------------------------------

/// Marca SOZU: fuente de verdad del verde institucional.
///
/// Base: `#239F71` = `hsl(158 64% 38%)`. La rampa 50→700 son los mismos tono y
/// saturación variando la luminosidad; los `soft*` son el verde aplicado con
/// opacidad sobre blanco, ya aplanados (evita usar alpha en superficies
/// grandes, que en web se ve sucio al superponerse sombras).
///
/// Cambiar [green] recolorea web, Android e iOS.
class SozuBrand {
  SozuBrand._();

  /// Verde de marca. Cambiar aquí = cambiar toda la app.
  static const Color green = Color(0xFF239F71); // hsl(158 64% 38%)

  // Rampa (misma H/S, distinta L).
  static const Color green50 = Color(0xFFEEFBF7); // L 96%
  static const Color green100 = Color(0xFFD9F7EC); // L 91%
  static const Color green400 = Color(0xFF2ED195); // L 50% — realce en dark
  static const Color green500 = green; // L 38% — primario
  static const Color green600 = Color(0xFF1D825D); // L 31% — hover / links
  static const Color green700 = Color(0xFF166448); // L 24% — pressed

  /// Verde claro para el degradado del botón primario (hsl 158 60% 46%).
  static const Color greenLight = Color(0xFF2FBC88);

  // Tintes aplanados sobre #FFFFFF.
  static const Color soft05 = Color(0xFFF4FAF8); // 5%
  static const Color soft06 = Color(0xFFF2F9F7); // 6%
  static const Color soft10 = Color(0xFFE9F5F1); // 10%
  static const Color soft15 = Color(0xFFDEF1EA); // 15%
  static const Color border30 = Color(0xFFBDE2D4); // 30%

  // Tintes para superficie oscura (el verde no se aclara: se oscurece hacia
  // el fondo, que es como se comporta un tinte translúcido sobre negro).
  static const Color softDark = Color(0xFF0B3B30);
  static const Color softDarkStrong = Color(0xFF12513E);
  static const Color borderDark = Color(0xFF2A5A48);
}

// ---------------------------------------------------------------------------
// Neutros
// ---------------------------------------------------------------------------

/// Rampa neutra para superficie clara.
///
/// **No es Tailwind `gray` puro.** Los valores provienen del Portal del Cliente
/// en producción (antes `PortalColors`), que es la referencia visual vigente.
/// Se eligió esta rampa sobre la `slate` (azulada) que usaba el tema móvil:
/// ver `docs/adr/0001-arquitectura-modular.md` §6.1.
///
/// `n150` existe porque el portal usa un borde suave levemente azulado
/// (#E9EEF4) que no cae en la rampa; se conserva porque diferencia la topbar
/// de las cards y eso es intencional en el diseño.
class SozuNeutral {
  SozuNeutral._();

  static const Color n0 = Color(0xFFFFFFFF); // superficie de cards
  static const Color n25 = Color(0xFFFBFCFD); // superficie sutil
  static const Color n50 = Color(0xFFF9FAFB); // fondo de página
  static const Color n75 = Color(0xFFF8F9FA); // superficie alterna / hover
  static const Color n100 = Color(0xFFF3F4F6); // muted: pista de progress
  static const Color n150 = Color(0xFFE9EEF4); // borde suave (topbar)
  static const Color n200 = Color(0xFFE5E7EB); // borde estándar
  static const Color n300 = Color(0xFFD1D5DB); // borde marcado / disabled
  static const Color n400 = Color(0xFF9BA1AB); // texto terciario
  static const Color n500 = Color(0xFF6B7280); // texto secundario
  static const Color n600 = Color(0xFF4B5563);
  static const Color n700 = Color(0xFF374151);
  static const Color n900 = Color(0xFF14161A); // texto principal
}

/// Rampa neutra para superficie oscura.
///
/// PROPUESTA, no medida: el Portal del Cliente es light-only, así que estos
/// valores no existían en el código. Lo que el ADR fija es que el rol exista en
/// dark; el hex exacto se afina con diseño (ADR §10.3). No se derivan invirtiendo
/// [SozuNeutral]: una inversión mecánica da grises que "flotan" —los oscuros
/// necesitan menos contraste entre niveles adyacentes que los claros.
class SozuNeutralDark {
  SozuNeutralDark._();

  // Los niveles de SUPERFICIE se aclararon respecto a la primera versión: el
  // fondo estaba en #101215 y el resultado se leía como negro puro, que abarata
  // la interfaz (las apps oscuras que se ven caras arrancan en ~#15-1A, no en
  // #0B). Los niveles de TEXTO (n400/n500/n900) no se tocaron: ahí el contraste
  // ya estaba calibrado y subirlos lo habría degradado.
  static const Color n0 = Color(0xFF1F2429); // superficie de cards
  static const Color n25 = Color(0xFF232830);
  static const Color n50 = Color(0xFF15181D); // fondo de página
  static const Color n75 = Color(0xFF272D34); // superficie alterna / hover
  static const Color n100 = Color(0xFF2F353D); // muted
  static const Color n150 = Color(0xFF2C323A); // borde suave
  static const Color n200 = Color(0xFF363D46); // borde estándar
  static const Color n300 = Color(0xFF464E58);
  static const Color n400 = Color(0xFF6B7280); // texto terciario
  static const Color n500 = Color(0xFF9BA1AB); // texto secundario
  static const Color n900 = Color(0xFFF3F4F6); // texto principal
}

// ---------------------------------------------------------------------------
// Semáforo
// ---------------------------------------------------------------------------

/// Ámbar: estados pendientes / advertencias.
class SozuAmber {
  SozuAmber._();

  static const Color base = Color(0xFFF59E0B);

  /// Ámbar oscurecido, para TEXTO e iconos sobre [soft]. El [base] sobre fondo
  /// claro no alcanza contraste AA (2.1:1); este sí (4.6:1).
  static const Color strong = Color(0xFFD97706);

  static const Color soft = Color(0xFFFEF5E7); // 10% sobre blanco
  static const Color softStrong = Color(0xFFFEF1DA); // 15% sobre blanco
  static const Color softDark = Color(0xFF3B2F0B);
  static const Color softDarkStrong = Color(0xFF4A3A0D);
  static const Color onDark = Color(0xFFFBBF24); // realce en superficie oscura
}

/// Rojo: errores / acciones destructivas.
///
/// Se adoptó red (#EF4444) sobre el rose (#E11D48) que usaba el tema móvil:
/// rose tiene un sesgo magenta que choca con el verde de marca (ADR §6.2).
class SozuRed {
  SozuRed._();

  static const Color base = Color(0xFFEF4444);
  static const Color soft = Color(0xFFFDECEC); // 10% sobre blanco
  static const Color softStrong = Color(0xFFFDE3E3); // 15% sobre blanco
  static const Color softDark = Color(0xFF3A1F1F);
  static const Color softDarkStrong = Color(0xFF4A2626);
  static const Color onDark = Color(0xFFF87171); // realce en superficie oscura
}

/// Azul: información neutral, avisos que no son error ni advertencia.
///
/// No compite con el verde de marca porque nunca se usa para acciones: solo
/// para cintillos, notas y estados informativos.
class SozuBlue {
  SozuBlue._();

  static const Color base = Color(0xFF2563EB); // blue-600
  static const Color strong = Color(0xFF1E40AF); // blue-800 — texto sobre soft
  static const Color soft = Color(0xFFDBEAFE); // blue-100 — fondo de cintillo
  static const Color softStrong = Color(0xFFBFDBFE); // blue-200 — borde
  static const Color softDark = Color(0xFF16243D);
  static const Color softDarkStrong = Color(0xFF1E3358);
  static const Color onDark = Color(0xFF93C5FD); // blue-300 — realce en oscuro
}

// ---------------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------------

/// Negros translúcidos para scrims y sombras. Se declaran como constantes
/// aplanadas en ARGB para poder usarse en contextos `const`.
class SozuAlpha {
  SozuAlpha._();

  static const Color black05 = Color(0x0D000000);
  static const Color black08 = Color(0x14000000);
  static const Color black10 = Color(0x1A000000);
  static const Color black12 = Color(0x1F000000);
  static const Color black45 = Color(0x73000000); // scrim de modales
  static const Color black60 = Color(0x99000000); // scrim de modales (dark)
}
