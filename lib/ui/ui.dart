/// Design system de SOZU - **fuente de verdad única** de la apariencia de la
/// plataforma (web, Android, iOS).
///
/// Import único: `import 'package:sozu_cliente_app/ui/ui.dart';`
///
/// ## Cómo se usa
///
/// ```dart
/// Container(
///   padding: EdgeInsets.all(context.s.space.md),
///   decoration: BoxDecoration(
///     color: context.s.color.surface,
///     borderRadius: context.s.radius.cardBorder,
///     border: Border.all(color: context.s.color.border),
///     boxShadow: context.s.shadow.md,
///   ),
///   child: Text('Hola', style: context.s.text.body),
/// )
///
/// final cols = context.responsive(mobile: 1, tablet: 2, desktop: 3);
/// ```
///
/// ## Reglas
///
/// 1. **Nada de `Color(0x…)`, `circular(16)` ni `fontSize: 14` en pantallas.**
///    Si el valor que necesitas no existe, se agrega a `tokens/`, no a la
///    pantalla. Así es como se mantuvo una sola paleta.
/// 2. **`ui/` no conoce el backend.** Nada aquí puede importar `supabase_flutter`,
///    `flutter_riverpod` ni `data/`. Un componente que necesita datos los recibe
///    por parámetro. Esta es la separación UI ↔ lógica de negocio, y es
///    verificable: si aparece uno de esos imports, es un bug de arquitectura.
/// 3. **Un concepto, un componente.** Antes existían `AppCard` y `PortalCard`
///    haciendo lo mismo con paletas distintas. Si hace falta que algo se vea
///    diferente en web, es una *variante* o una *densidad*, no un componente
///    nuevo.
///
/// ## Estado de la migración
///
/// `SozuColors`, `SozuTone`, `core/theme.dart`, `core/brand.dart` y
/// `core/typography.dart` fueron ELIMINADOS: no hay capa de alias ni mapeo
/// intermedio. Todo el código lee los nombres definitivos desde aquí.
///
/// Queda un solo pendiente: `core/portal_theme.dart` (`PortalColors`). Sus 749
/// referencias incluyen ~137 dentro de expresiones `const`, y migrarlas a
/// `context.s.color` rompe la const-ness - hay que quitar el `const` caso por
/// caso, y solo el compilador los localiza con precisión.
///
/// Ver `docs/adr/0001-arquitectura-modular.md`.
library;

// Tokens
export 'package:sozu_cliente_app/ui/tokens/color_roles.dart';
export 'package:sozu_cliente_app/ui/tokens/elevation.dart';
export 'package:sozu_cliente_app/ui/tokens/motion.dart';
export 'package:sozu_cliente_app/ui/tokens/palette.dart';
export 'package:sozu_cliente_app/ui/tokens/radii.dart';
export 'package:sozu_cliente_app/ui/tokens/spacing.dart';
export 'package:sozu_cliente_app/ui/tokens/typography.dart';

// Primitivas
export 'package:sozu_cliente_app/ui/primitives/s_autocomplete_field.dart';
export 'package:sozu_cliente_app/ui/primitives/s_button.dart';
export 'package:sozu_cliente_app/ui/primitives/s_empty_state.dart';
export 'package:sozu_cliente_app/ui/primitives/s_pressable.dart';
export 'package:sozu_cliente_app/ui/primitives/s_search_field.dart';
export 'package:sozu_cliente_app/ui/primitives/s_section_label.dart';
export 'package:sozu_cliente_app/ui/primitives/s_skeleton.dart';
export 'package:sozu_cliente_app/ui/primitives/s_stagger.dart';
export 'package:sozu_cliente_app/ui/primitives/s_text_field.dart';
export 'package:sozu_cliente_app/ui/primitives/sozu_logo.dart';
export 'package:sozu_cliente_app/ui/primitives/web_selectable.dart';

// Tema
export 'package:sozu_cliente_app/ui/theme/breakpoints.dart';
export 'package:sozu_cliente_app/ui/theme/density.dart';
export 'package:sozu_cliente_app/ui/theme/page_transitions.dart';
export 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
export 'package:sozu_cliente_app/ui/theme/theme_data.dart';
