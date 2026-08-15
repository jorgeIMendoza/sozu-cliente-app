import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/ui.dart';

/// Tarjeta que lleva al expediente de alguien: la empresa, su representante o
/// un accionista.
///
/// Dice tres cosas y ya: de quién es, qué lleva dentro y cuánto le falta. El
/// detalle vive en su pantalla, no aquí.
class ExpedienteFichaCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;

  /// Requisitos de esa persona y cuántos van aprobados.
  final int total;
  final int aprobados;

  final VoidCallback onAbrir;

  /// Acción secundaria opcional (quitar a una persona ligada).
  final Widget? accion;

  const ExpedienteFichaCard({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.total,
    required this.aprobados,
    required this.onAbrir,
    this.accion,
  });

  bool get _completo => total > 0 && aprobados >= total;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final falta = total - aprobados;

    return SPressable(
      onTap: onAbrir,
      borderRadius: t.radius.lgBorder,
      semanticLabel: 'Abrir $titulo',
      child: Container(
        padding: EdgeInsets.all(t.space.md),
        decoration: BoxDecoration(
          border: Border.all(color: tone.border),
          borderRadius: t.radius.lgBorder,
          color: tone.surface,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _completo ? tone.primarySoft : tone.surfaceAlt,
                borderRadius: t.radius.mdBorder,
              ),
              alignment: Alignment.center,
              child: Icon(
                icono,
                size: 19,
                color: _completo ? tone.primaryHover : tone.fgMuted,
              ),
            ),
            SizedBox(width: t.space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tone.fg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.caption.copyWith(color: tone.fgSubtle),
                  ),
                  SizedBox(height: t.space.xs),
                  // El avance va como barra y como texto: el color solo no
                  // comunica, y aquí lo que importa es cuánto falta.
                  Row(
                    children: [
                      Expanded(
                        child: SProgressBar(
                          percent: total == 0 ? 0 : (aprobados / total) * 100,
                          semanticsLabel: '$aprobados de $total listos',
                        ),
                      ),
                      SizedBox(width: t.space.xs),
                      Text(
                        total == 0
                            ? 'Sin cargar'
                            : (_completo ? 'Completo' : 'Faltan $falta'),
                        style: t.text.overline.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _completo ? tone.primaryHover : tone.fgMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (accion != null) accion!,
            Icon(Icons.chevron_right, size: 20, color: tone.fgSubtle),
          ],
        ),
      ),
    );
  }
}
