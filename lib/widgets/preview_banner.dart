import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/core/version.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Cintillo superior visible solo en builds que no son de producción (ver
/// [isPreviewBuild] en core/version.dart). Los deploys productivos compilan con
/// `--dart-define=APP_ENV=prod` y no lo muestran.
///
/// Usa el rol `info` (azul), no `warning` (ámbar): esto no es una advertencia de
/// que algo esté mal, es un dato de contexto. Reservar el ámbar y el rojo para
/// lo que de verdad requiere acción es lo que hace que el usuario les crea
/// cuando aparecen.
///
/// Leyenda: `PREVIEW • v1.0.0-YYMMDD.HHMM`. Sin icono y de una sola línea -
/// el timestamp del build es el dato que se pide al reportar un bug, así que va
/// completo y no se recorta en móvil.
///
/// Primer consumidor de `context.s` en la app: sirve de ejemplo de cómo se ve
/// un widget escrito contra los tokens (cero `Color(0x…)`, cero `fontSize:`).
class PreviewBanner extends StatelessWidget {
  final Widget child;

  const PreviewBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!isPreviewBuild) return child;

    final t = context.s;
    final c = t.color;

    return Column(
      // stretch: sin esto la Column se encoge al ancho del texto y la franja
      // queda como una pastilla centrada en vez de cruzar la pantalla. Antes
      // funcionaba de rebote porque había un Row (mainAxisSize.max) adentro.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: c.infoSoft,
          child: SafeArea(
            bottom: false,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.infoSoftStrong)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: t.space.md,
                  vertical: t.space.xs,
                ),
                child: Text(
                  'PREVIEW  •  $appVersionLabel',
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: t.text.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.9,
                    color: c.infoFg,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
