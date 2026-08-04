import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Diámetro por defecto. Constante nombrada y NO un token de espaciado: 44 es un
/// diámetro (el mínimo táctil de Apple/Material), no una separación.
const double _defaultDiameter = 44;

/// Alto de la letra como fracción del diámetro. No es token: depende de [size],
/// así que un valor fijo dejaría de escalar.
const double _initialsRatio = 0.38;

/// Avatar circular de marca con las iniciales del usuario.
///
/// Recibe las iniciales ya calculadas: no parte nombres ni carga imágenes.
///
/// ```dart
/// SAvatar(initials: 'EA')
/// SAvatar(initials: 'EA', size: 52)
/// ```
class SAvatar extends StatelessWidget {
  /// Iniciales a mostrar (1-3 caracteres).
  final String initials;

  /// Diámetro en px.
  final double size;

  const SAvatar({
    super.key,
    required this.initials,
    this.size = _defaultDiameter,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: t.color.primary, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initials,
        maxLines: 1,
        style: t.text.label.copyWith(
          color: t.color.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: size * _initialsRatio,
        ),
      ),
    );
  }
}
