import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import 'common.dart';

/// Chip compacto que confirma la forma de pago final elegida (espejo de
/// PaymentMethodBadge.tsx del portal admin): recursos propios (STP) o crédito
/// hipotecario con el estatus real de la solicitud. No renderiza nada mientras
/// el cliente no haya elegido (tipoFinanciamiento == null).
class PaymentMethodBadge extends StatelessWidget {
  /// RECURSOS_PROPIOS | CREDITO_HIPOTECARIO | null (sin elegir).
  final String? tipoFinanciamiento;

  /// Solicitud de crédito vigente (solo aplica para CREDITO_HIPOTECARIO).
  final SolicitudCredito? solicitud;

  const PaymentMethodBadge({
    super.key,
    required this.tipoFinanciamiento,
    this.solicitud,
  });

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    switch (tipoFinanciamiento) {
      case 'RECURSOS_PROPIOS':
        return _card(
          tone,
          icon: Icons.account_balance_wallet_outlined,
          titulo: 'Recursos propios',
          cuerpo: Text(
            'Liquidarás el saldo restante con transferencia. '
            'Tu selección quedó registrada. Todo listo.',
            style: TextStyle(fontSize: 12, color: tone.textSecondary),
          ),
        );
      case 'CREDITO_HIPOTECARIO':
        return _credito(tone);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _credito(SozuTone tone) {
    final banco = solicitud?.bancoNombre;
    final titulo = (banco != null && banco != '—')
        ? 'Crédito hipotecario · $banco'
        : 'Crédito hipotecario';
    // Línea de seguimiento por estatus (ESTATUS_LINEA del portal); sin
    // solicitud aún → mensaje genérico de seguimiento del banco.
    final linea = solicitud != null
        ? _estatusLinea(solicitud!.estatus)
        : 'El banco dará seguimiento y te contactará para continuar con el '
              'proceso.';
    final (estatusLabel, estatusTone) = _estatusBadge(
      solicitud?.estatus ?? 'en_revision',
    );
    return _card(
      tone,
      icon: Icons.account_balance_outlined,
      titulo: titulo,
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.schedule, size: 12, color: tone.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  linea,
                  style: TextStyle(fontSize: 12, color: tone.textSecondary),
                ),
              ),
            ],
          ),
          if (solicitud != null) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusBadge(label: estatusLabel, tone: estatusTone),
                if (solicitud?.fechaExpiracion != null)
                  Text(
                    'Vence ${formatDate(solicitud!.fechaExpiracion)}',
                    style: TextStyle(fontSize: 11, color: tone.textMuted),
                  ),
              ],
            ),
          ],
          if (solicitud != null && !solicitud!.puedeCambiar) ...[
            const SizedBox(height: 4),
            Text(
              'La selección es definitiva mientras el banco responde.',
              style: TextStyle(fontSize: 11, color: tone.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  /// Línea de seguimiento por estatus — espejo de ESTATUS_LINEA del portal.
  String _estatusLinea(String estatus) => switch (estatus.toLowerCase()) {
    'nuevo' =>
      'Solicitud enviada. El broker se pondrá en contacto contigo lo antes '
          'posible.',
    'asignado' => 'Un ejecutivo del banco fue asignado a tu solicitud.',
    'contactado' => 'El banco ya hizo el primer contacto contigo.',
    'en_evaluacion' ||
    'en_revision' => 'El banco está evaluando tu solicitud.',
    'pre_aprobado' =>
      '¡Pre-aprobado! El banco continuará con los siguientes pasos.',
    'oferta_vinculante' => 'El banco emitió tu oferta vinculante.',
    'en_coordinacion' =>
      'Coordinando notario y fecha de firma con el banco.',
    'formalizado' => 'Crédito formalizado. Listo para escriturar.',
    'rechazado' => 'El banco declinó la solicitud. Puedes elegir otro banco.',
    'desistido' => 'Solicitud cancelada. Puedes elegir otro banco.',
    'expirada' || 'expirado' =>
      'Venció el plazo de respuesta del banco. Puedes elegir otro banco.',
    _ =>
      'El banco dará seguimiento y te contactará para continuar con el '
          'proceso.',
  };

  Widget _card(
    SozuTone tone, {
    required IconData icon,
    required String titulo,
    Widget? cuerpo,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      borderColor: tone.primary.withValues(alpha: 0.25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tone.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: SozuColors.emerald600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FORMA DE PAGO FINAL ELEGIDA',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                    color: tone.primaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tone.textPrimary,
                  ),
                ),
                if (cuerpo != null) ...[
                  const SizedBox(height: 4),
                  cuerpo,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// (etiqueta, tono) por estatus de la solicitud — mapa de ESTATUS_LINEA del
  /// portal: aprobados en verde, rechazo/expiración en rojo, resto ámbar.
  (String, BadgeTone) _estatusBadge(String estatus) {
    final e = estatus.toLowerCase();
    const labels = {
      'nuevo': 'Solicitud enviada',
      'asignado': 'Ejecutivo asignado',
      'contactado': 'Contactado',
      'en_evaluacion': 'En evaluación',
      'en_revision': 'En revisión',
      'pendiente': 'Pendiente',
      'pre_aprobado': 'Pre-aprobado',
      'aprobado': 'Aprobado',
      'oferta_vinculante': 'Oferta vinculante',
      'en_coordinacion': 'En coordinación',
      'formalizado': 'Formalizado',
      'rechazado': 'Rechazado',
      'desistido': 'Desistido',
      'expirada': 'Expirada',
      'expirado': 'Expirado',
    };
    final label = labels[e] ??
        (e.isEmpty
            ? '—'
            : e[0].toUpperCase() + e.substring(1).replaceAll('_', ' '));
    final badgeTone = switch (e) {
      'pre_aprobado' ||
      'aprobado' ||
      'oferta_vinculante' ||
      'formalizado' =>
        BadgeTone.positive,
      'rechazado' || 'desistido' || 'expirada' || 'expirado' =>
        BadgeTone.negative,
      _ => BadgeTone.pending,
    };
    return (label, badgeTone);
  }
}
