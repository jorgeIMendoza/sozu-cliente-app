import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Tarjeta "ETAPA ACTUAL": stepper de 4 pasos (EN PREVENTA → EN PAGO → EN
/// ESCRITURACIÓN → POR ENTREGAR) más la caja "AHORA ESTÁS AQUÍ".
///
/// La etapa la resuelve el backend y llega ya calculada en [stages] / [activa].
class EtapaActualStepper extends StatelessWidget {
  final List<EtapaStage> stages;
  final String activa;
  final double saldoPendiente;

  /// true en modo portal web (≥1024): la card va sin el margen superior de la
  /// vista móvil y el título usa el label de sección del design system.
  final bool portal;

  const EtapaActualStepper({
    super.key,
    required this.stages,
    required this.activa,
    required this.saldoPendiente,
    this.portal = false,
  });

  /// Etiqueta legible por etapa.
  static const _labels = <String, String>{
    'preventa': 'EN PREVENTA',
    'pago_final': 'EN PAGO',
    'escrituracion': 'EN ESCRITURACIÓN',
    'entrega': 'POR ENTREGAR',
  };

  /// Oración descriptiva por etapa; se pinta bajo "AHORA ESTÁS AQUÍ" solo en
  /// modo portal.
  static const _descripciones = <String, String>{
    'preventa':
        'Tu unidad está reservada. Falta confirmar el plan de pagos y '
        'firmar contrato preliminar.',
    'pago_final':
        'Estás liquidando las parcialidades acordadas en tu esquema de '
        'financiamiento.',
    'escrituracion':
        'Pagos completados. Coordinando firma de escritura pública ante '
        'notaría.',
    'entrega':
        'Escritura firmada. Esperando fecha de entrega física de tu unidad.',
  };

  static String _labelDe(EtapaStage s) =>
      _labels[s.id] ?? s.label.toUpperCase();

  static String _fmtSaldo(double n) =>
      '\$${NumberFormat('#,##0', 'es_MX').format(n)} MXN';

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;

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

    // Línea de saldo solo en etapas de cobro con saldo real.
    final muestraSaldo =
        !entregada &&
        saldoPendiente > 0 &&
        (activa == 'preventa' || activa == 'pago_final');

    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título dentro de la tarjeta, con icono de edificio.
        Row(
          children: [
            Icon(
              Icons.apartment_outlined,
              size: 16,
              color: portal ? PortalColors.mutedForeground : SozuBrand.green600,
            ),
            const SizedBox(width: 8),
            portal
                ? const Expanded(child: SSectionLabel(text: 'Etapa actual'))
                : Text(
                    'ETAPA ACTUAL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: tone.fgMuted,
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
                        // Anillo en el nodo actual,
                        // solo en modo portal para no tocar la vista móvil.
                        ring: portal && statusDe(pasos[i]) == 'active',
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
              color: SozuBrand.green500.withValues(alpha: 0.25),
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
                  color: tone.primaryHover,
                ),
              ),
              // Oración descriptiva de la etapa (solo portal).
              if (portal && _descripciones[activa] != null) ...[
                const SizedBox(height: 6),
                Text(
                  _descripciones[activa]!,
                  style: TextStyle(fontSize: 13, height: 1.45, color: tone.fg),
                ),
              ],
              if (muestraSaldo) ...[
                const SizedBox(height: 4),
                Text(
                  'Saldo pendiente: ${_fmtSaldo(saldoPendiente)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tone.fg,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (portal) {
      return SCard(padding: const EdgeInsets.all(20), child: contenido);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: SCard(child: contenido),
    );
  }
}

/// Un paso del stepper: conectores laterales + círculo + etiqueta en máximo
/// dos líneas (responsive: la etiqueta reduce tamaño en pantallas angostas).
class _Paso extends StatelessWidget {
  final SozuColorRoles tone;
  final int numero;
  final String label;
  final String status; // completed | active | pending
  final bool? lineaIzq; // null = sin conector (primer paso)
  final bool? lineaDer; // null = sin conector (último paso)
  final double fontSize;

  /// Anillo suave alrededor del nodo actual. Solo lo activa el modo portal.
  final bool ring;

  const _Paso({
    required this.tone,
    required this.numero,
    required this.label,
    required this.status,
    required this.lineaIzq,
    required this.lineaDer,
    required this.fontSize,
    this.ring = false,
  });

  Widget _linea(bool? verde) => Expanded(
    child: Container(
      height: 2,
      color: verde == null
          ? Colors.transparent
          : verde
          ? SozuBrand.green500
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
                // Actual: círculo verde relleno con número.
                color: esCompletado || esActivo
                    ? SozuBrand.green500
                    : tone.surfaceAlt,
                border: esCompletado || esActivo
                    ? null
                    : Border.all(color: tone.border),
                // Anillo suave del nodo actual.
                boxShadow: ring
                    ? [
                        BoxShadow(
                          color: SozuBrand.green500.withValues(alpha: 0.15),
                          spreadRadius: 4,
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: esCompletado
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '$numero',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: esActivo ? Colors.white : tone.fgSubtle,
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
                  ? tone.primaryHover
                  : esCompletado
                  ? tone.fgMuted
                  : tone.fgSubtle,
            ),
          ),
        ),
      ],
    );
  }
}
