import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/primitives/s_button.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Peso del diálogo: [info] para confirmar un paso normal, [warning] cuando la
/// consecuencia recae en quien acepta.
enum SConfirmTone { info, warning }

/// Confirmación con condiciones: título, mensaje y la lista de lo que el
/// usuario está aceptando.
///
/// Se usa antes de una acción cuya consecuencia es del usuario (subir un
/// documento que puede ser rechazado y tendrá que volver a cargar). Los
/// [puntos] van en el diálogo y no en la pantalla anterior a propósito: ahí se
/// leen de pasada, aquí hay que aceptarlos.
///
/// Devuelve `true` si aceptó, `false` o `null` si canceló.
Future<bool?> showSConfirm(
  BuildContext context, {
  required String titulo,
  String? mensaje,
  List<String> puntos = const [],
  String etiquetaAceptar = 'Aceptar',
  String etiquetaCancelar = 'Cancelar',
  SConfirmTone tono = SConfirmTone.info,
}) {
  final tone = context.s.color;
  final esAdvertencia = tono == SConfirmTone.warning;

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: tone.surface,
      shape: RoundedRectangleBorder(borderRadius: context.s.radius.sheetBorder),
      titlePadding: EdgeInsets.fromLTRB(
        context.s.space.lg,
        context.s.space.lg,
        context.s.space.lg,
        context.s.space.sm,
      ),
      contentPadding: EdgeInsets.fromLTRB(
        context.s.space.lg,
        0,
        context.s.space.lg,
        context.s.space.md,
      ),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            esAdvertencia ? Icons.warning_amber_rounded : Icons.info_outline,
            size: 20,
            color: esAdvertencia ? tone.warningFg : tone.info,
          ),
          SizedBox(width: context.s.space.xs),
          Expanded(
            child: Text(
              titulo,
              style: context.s.text.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: tone.fg,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mensaje != null)
              Text(
                mensaje,
                style: context.s.text.bodySmall.copyWith(color: tone.fgMuted),
              ),
            if (puntos.isNotEmpty) ...[
              if (mensaje != null) SizedBox(height: context.s.space.sm),
              Container(
                padding: EdgeInsets.all(context.s.space.sm),
                decoration: BoxDecoration(
                  color: esAdvertencia ? tone.warningSoft : tone.infoSoft,
                  borderRadius: context.s.radius.mdBorder,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final p in puntos)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: p == puntos.last ? 0 : context.s.space.xs,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 15,
                              color: esAdvertencia
                                  ? tone.warningFg
                                  : tone.infoFg,
                            ),
                            SizedBox(width: context.s.space.xs),
                            Expanded(
                              child: Text(
                                p,
                                style: context.s.text.caption.copyWith(
                                  color: tone.fg,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      // Una fila propia y no `actions`: el `OverflowBar` de AlertDialog apila
      // los botones en cuanto el texto crece y quedan dos anchos distintos.
      actionsPadding: EdgeInsets.fromLTRB(
        context.s.space.lg,
        0,
        context.s.space.lg,
        context.s.space.lg,
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: SButton.secondary(
                label: etiquetaCancelar,
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
            ),
            SizedBox(width: context.s.space.sm),
            Expanded(
              child: SButton(
                label: etiquetaAceptar,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
