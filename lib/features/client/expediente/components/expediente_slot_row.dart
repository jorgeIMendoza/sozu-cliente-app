import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/core/format.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/expediente/components/expediente_card.dart'
    show expedienteEstatusStyle;
import 'package:sozu_cliente_app/ui/ui.dart';

/// Fila de un documento del expediente: icono, nombre, estatus, y las acciones
/// de subir y ver.
///
/// Tonta: recibe el slot y qué hacer, no sabe de providers ni de red.
class ExpedienteSlotRow extends StatelessWidget {
  final ExpedienteSlot slot;

  /// Este slot está en proceso de subida.
  final bool subiendo;

  /// Hay otra subida en curso: se bloquean todas las demás.
  final bool bloqueado;
  final VoidCallback onSubir;

  /// Abre el documento ya guardado; null si todavía no hay ninguno.
  final VoidCallback? onVer;

  /// Texto libre que escribió el cliente (la descripción de un anexo). Es
  /// INFORMATIVO: va en su propia línea y recortado, nunca como nombre de la
  /// fila. El nombre lo manda el backend y es estable; esto puede ser cualquier
  /// cosa y de cualquier largo.
  final String? descripcion;

  const ExpedienteSlotRow({
    super.key,
    required this.slot,
    required this.subiendo,
    required this.bloqueado,
    required this.onSubir,
    this.onVer,
    this.descripcion,
  });

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    // 'opcional' se muestra como 'Pendiente': para el cliente es lo mismo que
    // le falta, y "Opcional" invita a no subirlo.
    final st = expedienteEstatusStyle(
      slot.estatus == 'opcional' ? 'pendiente' : slot.estatus,
      tone,
    );
    final tieneDoc = slot.fecha != null;
    final motivo = slot.bloqueadoMotivo;
    final puedeActuar = slot.puedeSubir && !subiendo && !bloqueado;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.s.space.md,
        vertical: context.s.space.sm,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: tone.border),
        borderRadius: context.s.radius.smBorder,
        color: motivo != null ? tone.surfaceAlt : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tone.surfaceAlt,
                  borderRadius: context.s.radius.mdBorder,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.description_outlined,
                  size: 17,
                  color: tone.fgMuted,
                ),
              ),
              SizedBox(width: context.s.space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          slot.nombre,
                          style: context.s.text.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tone.fg,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: st.bg,
                            borderRadius: context.s.radius.fullBorder,
                          ),
                          child: Text(
                            st.label,
                            style: context.s.text.overline.copyWith(
                              fontWeight: FontWeight.w700,
                              color: st.fg,
                            ),
                          ),
                        ),
                        if (!slot.requerido)
                          Text(
                            'Opcional',
                            style: context.s.text.overline.copyWith(
                              color: tone.fgSubtle,
                            ),
                          ),
                      ],
                    ),
                    if (descripcion != null && descripcion!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        descripcion!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.s.text.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: tone.fgMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      tieneDoc
                          ? 'Subido el ${formatDateEsMX(slot.fecha)}'
                          : 'Sin cargar',
                      style: context.s.text.caption.copyWith(
                        fontWeight: FontWeight.w500,
                        color: tone.fgSubtle,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.s.space.xs),
              _IconBtn(
                tooltip: tieneDoc ? 'Reemplazar documento' : 'Subir documento',
                onTap: puedeActuar ? onSubir : null,
                child: subiendo
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        tieneDoc ? Icons.edit_outlined : Icons.upload_outlined,
                        size: 16,
                        color: puedeActuar
                            ? tone.fgMuted
                            : tone.fgSubtle.withValues(alpha: 0.4),
                      ),
              ),
              if (onVer != null) ...[
                const SizedBox(width: 6),
                _IconBtn(
                  tooltip: 'Ver documento',
                  onTap: onVer,
                  child: Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: tone.fgMuted,
                  ),
                ),
              ],
            ],
          ),
          if (motivo != null) ...[
            SizedBox(height: context.s.space.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 14, color: tone.warningFg),
                SizedBox(width: context.s.space.xxs),
                Expanded(
                  child: Text(
                    motivo,
                    style: context.s.text.caption.copyWith(color: tone.fgMuted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onTap;
  final Widget child;

  const _IconBtn({
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: context.s.radius.smBorder,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: tone.surface,
            border: Border.all(color: tone.border),
            borderRadius: context.s.radius.smBorder,
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
