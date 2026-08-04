import 'package:flutter/material.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Tipo de alerta del acceso.
enum AuthAlertKind { error, warning, info, success }

/// Caja de alerta con icono. Cada variante toma su par fondo/texto de los roles
/// semánticos del tema.
class AuthAlert extends StatelessWidget {
  const AuthAlert({
    super.key,
    required this.kind,
    required this.icon,
    required this.message,
  });

  final AuthAlertKind kind;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;

    final (Color background, Color foreground) = switch (kind) {
      AuthAlertKind.error => (c.dangerSoft, c.danger),
      AuthAlertKind.warning => (c.warningSoft, c.warningFg),
      AuthAlertKind.info => (c.infoSoft, c.infoFg),
      AuthAlertKind.success => (c.primarySoftStrong, c.primaryHover),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.md,
        vertical: t.space.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: t.radius.mdBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          SizedBox(width: t.space.sm),
          Expanded(
            child: Text(
              message,
              style: t.text.body.copyWith(color: foreground, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
