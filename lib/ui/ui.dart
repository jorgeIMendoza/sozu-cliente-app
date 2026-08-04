/// Design system de SOZU - **fuente de verdad única** de la apariencia de la
/// plataforma (web, Android, iOS).
///
/// Import único: `import 'package:sozu_cliente_app/ui/ui.dart';`
///
/// ```dart
/// Container(
///   padding: EdgeInsets.all(context.s.space.md),
///   decoration: BoxDecoration(
///     color: context.s.color.surface,
///     borderRadius: context.s.radius.sheetBorder,
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
/// 1. Nada de `Color(0x…)`, `circular(16)` ni `fontSize: 14` en pantallas: si el
///    valor no existe, se agrega a `tokens/`.
/// 2. `ui/` no conoce el backend: nada aquí importa `supabase_flutter`,
///    `flutter_riverpod` ni `data/`. Los datos llegan por parámetro.
/// 3. Un concepto, un componente. Si algo debe verse distinto en web es una
///    *variante* o una *densidad*, no un componente nuevo.
///
/// Pendiente de migrar: `core/portal_theme.dart` (`PortalColors`). Ojo al
/// hacerlo: `context.s` NO puede ir dentro de una expresión `const`, así que hay
/// que quitar el `const` caso por caso y solo el compilador los localiza.
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
export 'package:sozu_cliente_app/ui/primitives/s_avatar.dart';
export 'package:sozu_cliente_app/ui/primitives/s_badge.dart';
export 'package:sozu_cliente_app/ui/primitives/s_button.dart';
export 'package:sozu_cliente_app/ui/primitives/s_card.dart';
export 'package:sozu_cliente_app/ui/primitives/s_choice_chip.dart';
export 'package:sozu_cliente_app/ui/primitives/s_empty_state.dart';
export 'package:sozu_cliente_app/ui/primitives/s_error_state.dart';
export 'package:sozu_cliente_app/ui/primitives/s_pressable.dart';
export 'package:sozu_cliente_app/ui/primitives/s_progress_bar.dart';
export 'package:sozu_cliente_app/ui/primitives/s_search_field.dart';
export 'package:sozu_cliente_app/ui/primitives/s_section_label.dart';
export 'package:sozu_cliente_app/ui/primitives/s_skeleton.dart';
export 'package:sozu_cliente_app/ui/primitives/s_stagger.dart';
export 'package:sozu_cliente_app/ui/primitives/s_text_field.dart';
export 'package:sozu_cliente_app/ui/primitives/s_logo.dart';
export 'package:sozu_cliente_app/ui/primitives/s_web_selectable.dart';

// Tema
export 'package:sozu_cliente_app/ui/theme/breakpoints.dart';
export 'package:sozu_cliente_app/ui/theme/density.dart';
export 'package:sozu_cliente_app/ui/theme/page_transitions.dart';
export 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
export 'package:sozu_cliente_app/ui/theme/theme_data.dart';
