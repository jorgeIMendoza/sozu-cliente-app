import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../data/models.dart';
import 'common.dart';

/// Tarjeta "ETAPA ACTUAL" del detalle de propiedad, espejo del portal del
/// cliente (InvestmentStepper + caja contextual de StatusTimeline):
/// - Stepper horizontal de 4 pasos: EN PREVENTA → EN PAGO → EN ESCRITURACIÓN
///   → POR ENTREGAR. Completados con check verde, paso actual en círculo
///   verde relleno con número, futuros en gris; línea conectora verde hasta
///   el paso actual.
/// - Debajo, caja verde claro "AHORA ESTÁS AQUÍ · etapa" con el saldo
///   pendiente real cuando la etapa activa es de pago.
///
/// La etapa se calcula en el backend (mismo criterio que buildStages del
/// portal: estatus_disponibilidad + avance de pago) y llega ya resuelta en
/// [stages] / [activa].
class EtapaActualStepper extends StatelessWidget {
  final List<EtapaStage> stages;
  final String activa;
  final double saldoPendiente;

  const EtapaActualStepper({
    super.key,
    required this.stages,
    required this.activa,
    required this.saldoPendiente,
  });

  /// Etiquetas del portal (statusLabel de FinancialHero/PortalHeader).
  static const _labels = <String, String>{
    'preventa': 'EN PREVENTA',
    'pago_final': 'EN PAGO',
    'escrituracion': 'EN ESCRITURACIÓN',
    'entrega': 'POR ENTREGAR',
  };

  static String _labelDe(EtapaStage s) =>
      _labels[s.id] ?? s.label.toUpperCase();

  static String _fmtSaldo(double n) =>
      '\$${NumberFormat('#,##0', 'es_MX').format(n)} MXN';

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);

    // El portal muestra 4 pasos; post_entrega no aparece como paso propio:
    // si la propiedad ya fue entregada, los 4 se ven completados.
    final entregada = activa == 'post_entrega';
    final pasos = stages.where((s) => s.id != 'post_entrega').toList();

    String statusDe(EtapaStage s) => entregada ? 'completed' : s.status;

    final etiquetaActiva = entregada
        ? 'ENTREGADA'
        : pasos
                .where((s) => statusDe(s) == 'active')
                .map(_labelDe)
                .firstOrNull ??
            (_labels[activa] ?? activa.toUpperCase());

    // Línea de saldo solo en etapas de cobro con saldo real (igual que el
    // contextMessage "Saldo pendiente: $X" del portal).
    final muestraSaldo = !entregada &&
        saldoPendiente > 0 &&
        (activa == 'preventa' || activa == 'pago_final');

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título dentro de la tarjeta, con icono de edificio.
            Row(
              children: [
                const Icon(Icons.apartment_outlined,
                    size: 16, color: SozuColors.emerald600),
                const SizedBox(width: 8),
                Text(
                  'ETAPA ACTUAL',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: tone.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (pasos.isNotEmpty) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final angosto = constraints.maxWidth < 380;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < pasos.length; i++)
                        Expanded(
                          child: _Paso(
                            tone: tone,
                            numero: i + 1,
                            label: _labelDe(pasos[i]),
                            status: statusDe(pasos[i]),
                            // Conector izquierdo: verde hasta el paso actual.
                            lineaIzq: i == 0
                                ? null
                                : statusDe(pasos[i]) != 'pending',
                            // Conector derecho: verde si el siguiente paso ya
                            // fue alcanzado (este paso está completado).
                            lineaDer: i == pasos.length - 1
                                ? null
                                : statusDe(pasos[i]) == 'completed',
                            fontSize: angosto ? 8.5 : 10,
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // Caja verde claro: "AHORA ESTÁS AQUÍ · <ETAPA>" + saldo.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: tone.primarySoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: SozuColors.emerald500.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AHORA ESTÁS AQUÍ · $etiquetaActiva',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: tone.primaryDark,
                    ),
                  ),
                  if (muestraSaldo) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Saldo pendiente: ${_fmtSaldo(saldoPendiente)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: tone.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un paso del stepper: conectores laterales + círculo + etiqueta en máximo
/// dos líneas (responsive: la etiqueta reduce tamaño en pantallas angostas).
class _Paso extends StatelessWidget {
  final SozuTone tone;
  final int numero;
  final String label;
  final String status; // completed | active | pending
  final bool? lineaIzq; // null = sin conector (primer paso)
  final bool? lineaDer; // null = sin conector (último paso)
  final double fontSize;

  const _Paso({
    required this.tone,
    required this.numero,
    required this.label,
    required this.status,
    required this.lineaIzq,
    required this.lineaDer,
    required this.fontSize,
  });

  Widget _linea(bool? verde) => Expanded(
        child: Container(
          height: 2,
          color: verde == null
              ? Colors.transparent
              : verde
                  ? SozuColors.emerald500
                  : tone.border,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final esActivo = status == 'active';
    final esCompletado = status == 'completed';

    return Column(
      children: [
        Row(
          children: [
            _linea(lineaIzq),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Actual: círculo verde relleno con número (como el portal).
                color: esCompletado || esActivo
                    ? SozuColors.emerald500
                    : tone.surfaceAlt,
                border: esCompletado || esActivo
                    ? null
                    : Border.all(color: tone.border),
              ),
              alignment: Alignment.center,
              child: esCompletado
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '$numero',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: esActivo ? Colors.white : tone.textMuted,
                      ),
                    ),
            ),
            _linea(lineaDer),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: esActivo ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: 0.3,
              height: 1.25,
              color: esActivo
                  ? tone.primaryDark
                  : esCompletado
                      ? tone.textSecondary
                      : tone.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
