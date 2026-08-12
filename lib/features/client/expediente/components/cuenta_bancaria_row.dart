import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Fila de datos bancarios del expediente: la cuenta Y su carátula, en una
/// sola unidad.
///
/// No es un documento: no la sirve `cliente-expediente` sino el perfil, y se
/// captura con un formulario (banco, número, CLABE, titular) además del
/// archivo. La carátula NO tiene fila propia a propósito: sin cuenta no hay a
/// qué pertenecer, y separarlas pintaba dos renglones para lo mismo con
/// estatus distintos.
class CuentaBancariaRow extends StatelessWidget {
  final List<CuentaBancariaPerfil> cuentas;

  /// Abre el formulario de alta.
  final VoidCallback onAgregar;

  /// Abre la vista de cuentas; null mientras no haya evidencia que mostrar.
  final VoidCallback? onVer;

  const CuentaBancariaRow({
    super.key,
    required this.cuentas,
    required this.onAgregar,
    this.onVer,
  });

  /// Badge agregado: sin cuentas → Pendiente · alguna sin carátula →
  /// Incompleto · todas validadas → Validada · el resto → En revisión.
  (String, Color, Color) _badge(SozuColorRoles tone) {
    if (cuentas.isEmpty) return ('Pendiente', tone.surfaceAlt, tone.fgMuted);
    if (!cuentas.every((c) => c.evidencia != null)) {
      return ('Incompleto', tone.dangerSoft, tone.danger);
    }
    if (cuentas.every((c) => c.estatus == 2)) {
      return ('Validada', tone.primarySoft, tone.primaryHover);
    }
    return ('En revisión', tone.warningSoft, tone.warningFg);
  }

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final (label, bg, fg) = _badge(tone);
    final n = cuentas.length;
    final subtitulo = n > 0
        ? '$n cuenta${n > 1 ? 's' : ''} registrada${n > 1 ? 's' : ''}'
        : 'Banco, número de cuenta, CLABE, titular y la carátula del estado';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.s.space.md,
        vertical: context.s.space.sm,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: tone.border),
        borderRadius: context.s.radius.smBorder,
      ),
      child: Row(
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
              Icons.credit_card_outlined,
              size: 17,
              color: tone.fgMuted,
            ),
          ),
          SizedBox(width: context.s.space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Cuenta bancaria y carátula',
                        style: context.s.text.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tone.fg,
                        ),
                      ),
                    ),
                    SizedBox(width: context.s.space.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: context.s.radius.fullBorder,
                      ),
                      child: Text(
                        label,
                        style: context.s.text.overline.copyWith(
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.s.text.caption.copyWith(
                    fontWeight: FontWeight.w500,
                    color: tone.fgSubtle,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.s.space.xs),
          Tooltip(
            message: 'Agregar cuenta bancaria',
            child: InkWell(
              onTap: onAgregar,
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
                child: Icon(
                  Icons.upload_outlined,
                  size: 16,
                  color: tone.fgMuted,
                ),
              ),
            ),
          ),
          if (onVer != null) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Ver cuentas',
              child: InkWell(
                onTap: onVer,
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
                  child: Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: tone.fgMuted,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
