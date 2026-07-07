import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/open_doc.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../widgets/common.dart';
import '../widgets/level_map.dart';

const _cronoLimit = 5;

/// Detalle de propiedad: datos técnicos, productos adicionales, etapa actual,
/// cronograma de pagos (5 + ver más), ficha técnica (LevelMap) y documentos.
class PropiedadDetalleScreen extends ConsumerStatefulWidget {
  final int cuentaId;

  const PropiedadDetalleScreen({super.key, required this.cuentaId});

  @override
  ConsumerState<PropiedadDetalleScreen> createState() =>
      _PropiedadDetalleScreenState();
}

class _PropiedadDetalleScreenState
    extends ConsumerState<PropiedadDetalleScreen> {
  bool _cronoExpanded = false;

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final detalle = ref.watch(propiedadDetalleProvider(widget.cuentaId));

    return Scaffold(
      appBar: AppBar(title: Text(detalle.valueOrNull?.nombre ?? 'Propiedad')),
      body: detalle.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            Skeleton(height: 180, radius: 16),
            SizedBox(height: 16),
            Skeleton(width: 200, height: 20),
            SizedBox(height: 16),
            Skeleton(height: 120, radius: 16),
          ],
        ),
        error: (_, __) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ErrorCard(
              title: 'No pudimos cargar esta propiedad',
              onRetry: () =>
                  ref.invalidate(propiedadDetalleProvider(widget.cuentaId)),
            ),
          ],
        ),
        data: (d) => ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // Hero
            SizedBox(
              height: 200,
              width: double.infinity,
              child: d.urlImagen != null
                  ? Image.network(
                      d.urlImagen!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _heroPlaceholder(tone),
                    )
                  : _heroPlaceholder(tone),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.proyecto.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                  color: tone.primaryDark,
                                )),
                            Text(d.nombre,
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: tone.textPrimary)),
                            Text('${d.modelo} · ${d.tipo}',
                                style: TextStyle(
                                    fontSize: 14, color: tone.textSecondary)),
                          ],
                        ),
                      ),
                      StatusBadge(
                        label: d.estatus,
                        tone: d.categoria == 'patrimonio'
                            ? BadgeTone.positive
                            : BadgeTone.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Avance
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Avance de pago · ${d.avancePago}%',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: tone.textPrimary)),
                            Text(
                                '${formatMXN(d.pagado)} de ${formatMXN(d.monto)}',
                                style: TextStyle(
                                    fontSize: 12, color: tone.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SozuProgressBar(percent: d.avancePago),
                        if (d.saldoPendiente > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                                'Saldo pendiente: ${formatMXN(d.saldoPendiente)}',
                                style: TextStyle(
                                    fontSize: 12, color: tone.pending)),
                          ),
                      ],
                    ),
                  ),

                  // Datos técnicos
                  const SectionTitle(
                      icon: Icons.construction_outlined,
                      text: 'Datos técnicos'),
                  AppCard(
                    child: Wrap(
                      runSpacing: 12,
                      children: [
                        _dato(tone, 'PROYECTO', d.proyecto),
                        _dato(tone, 'UNIDAD', 'U-${d.unidad}'),
                        _dato(tone, 'TIPO', d.tipo),
                        _dato(
                            tone,
                            'ÁREA',
                            d.m2Interiores != null
                                ? '${d.m2Interiores} m²'
                                : '—'),
                        _dato(tone, 'RECÁMARAS', '${d.recamaras}'),
                        _dato(tone, 'BAÑOS', '${d.banos}'),
                        _dato(tone, 'PISO',
                            d.numeroPiso != null ? '${d.numeroPiso}' : '—'),
                        _dato(tone, 'ENTREGA', d.entrega),
                      ],
                    ),
                  ),

                  // Productos adicionales
                  if (d.productos.isNotEmpty) ...[
                    SectionTitle(
                        icon: Icons.inventory_2_outlined,
                        text: 'Productos adicionales · ${d.productos.length}'),
                    for (final p in d.productos) ...[
                      _ProductoRow(p: p),
                      const SizedBox(height: 10),
                    ],
                  ],

                  // Etapa actual
                  const SectionTitle(
                      icon: Icons.flag_outlined, text: 'Etapa actual'),
                  AppCard(
                    child: _StageTracker(
                        stages: d.stages, activa: d.etapaActiva),
                  ),

                  // Cronograma de pagos
                  _cronogramaHeader(tone, d),
                  if (d.esquemaPago.isEmpty)
                    const EmptyCard(
                        icon: Icons.calendar_today_outlined,
                        text: 'Sin plan de pagos')
                  else ...[
                    for (final e in _cronoExpanded
                        ? d.esquemaPago
                        : d.esquemaPago.take(_cronoLimit)) ...[
                      _CronoRow(e: e),
                      const SizedBox(height: 10),
                    ],
                    if (d.esquemaPago.length > _cronoLimit)
                      Center(
                        child: TextButton(
                          onPressed: () => setState(
                              () => _cronoExpanded = !_cronoExpanded),
                          child: Text(
                            _cronoExpanded
                                ? 'Mostrar menos'
                                : 'Ver ${d.esquemaPago.length - _cronoLimit} más',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: tone.primaryDark),
                          ),
                        ),
                      ),
                  ],

                  // Ficha técnica
                  if (d.ficha.numeroPiso != null ||
                      d.ficha.planoNivelUrl != null ||
                      d.ficha.planoDistribucionUrl != null ||
                      d.ficha.regiones.isNotEmpty)
                    _FichaTecnica(ficha: d.ficha),

                  // Documentos
                  const SectionTitle(
                      icon: Icons.description_outlined, text: 'Documentos'),
                  if (d.documentos.isEmpty)
                    const EmptyCard(
                        icon: Icons.folder_open_outlined,
                        text: 'Sin documentos para esta propiedad')
                  else
                    for (final doc in d.documentos) ...[
                      _DocRow(d: doc),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroPlaceholder(SozuTone tone) => Container(
        color: tone.surfaceAlt,
        alignment: Alignment.center,
        child: Icon(Icons.business_outlined, size: 48, color: tone.textMuted),
      );

  Widget _dato(SozuTone tone, String label, String value) {
    return FractionallySizedBox(
      widthFactor: 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, letterSpacing: 0.8, color: tone.textMuted)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tone.textPrimary)),
        ],
      ),
    );
  }

  Widget _cronogramaHeader(SozuTone tone, PropiedadDetalle d) {
    final pagados = d.esquemaPago.where((e) => e.pagoCompletado).length;
    final visibles = _cronoExpanded
        ? d.esquemaPago.length
        : d.esquemaPago.length.clamp(0, _cronoLimit);
    return SectionTitle(
      icon: Icons.calendar_month_outlined,
      text: 'Cronograma de pagos',
      trailing: d.esquemaPago.isEmpty
          ? null
          : Text(
              '$visibles de ${d.esquemaPago.length} · $pagados pagados',
              style: TextStyle(fontSize: 12, color: tone.textMuted),
            ),
    );
  }
}

class _ProductoRow extends StatelessWidget {
  final ProductoDetalle p;

  const _ProductoRow({required this.p});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final badgeTone = switch (p.estatus) {
      'Pagado' => BadgeTone.positive,
      'En curso' => BadgeTone.neutral,
      _ => BadgeTone.pending,
    };
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration:
                BoxDecoration(color: tone.primarySoft, shape: BoxShape.circle),
            child: const Icon(Icons.inventory_2_outlined,
                size: 18, color: SozuColors.emerald600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tone.textPrimary)),
                const SizedBox(height: 4),
                StatusBadge(label: p.estatus, tone: badgeTone),
              ],
            ),
          ),
          Text(formatMXN(p.monto),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tone.textPrimary)),
        ],
      ),
    );
  }
}

class _StageTracker extends StatelessWidget {
  final List<EtapaStage> stages;
  final String activa;

  const _StageTracker({required this.stages, required this.activa});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final activeLabel = stages
            .where((s) => s.status == 'active')
            .map((s) => s.label)
            .firstOrNull ??
        (activa == 'post_entrega' ? 'Entregada' : stages.lastOrNull?.label ?? '');

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < stages.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: stages[i].status == 'pending'
                        ? tone.border
                        : SozuColors.emerald500,
                  ),
                ),
              _dot(tone, stages[i], i),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final s in stages)
              SizedBox(
                width: 70,
                child: Text(
                  s.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 9,
                    color: s.status == 'pending'
                        ? tone.textMuted
                        : tone.textSecondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: tone.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Ahora estás aquí · $activeLabel',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tone.primaryDark),
          ),
        ),
      ],
    );
  }

  Widget _dot(SozuTone tone, EtapaStage s, int index) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: switch (s.status) {
          'completed' => SozuColors.emerald500,
          'active' => tone.primarySoft,
          _ => tone.surfaceAlt,
        },
        border: s.status == 'active'
            ? Border.all(color: SozuColors.emerald500, width: 2)
            : null,
      ),
      alignment: Alignment.center,
      child: s.status == 'completed'
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: s.status == 'active' ? tone.primaryDark : tone.textMuted,
              ),
            ),
    );
  }
}

class _CronoRow extends StatelessWidget {
  final EsquemaPagoItem e;

  const _CronoRow({required this.e});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final parcial = !e.pagoCompletado && e.saldo < e.monto;
    final (label, badgeTone) = e.pagoCompletado
        ? ('Pagado', BadgeTone.positive)
        : parcial
            ? ('Parcial', BadgeTone.pending)
            : ('Pendiente', BadgeTone.neutral);
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.concepto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tone.textPrimary)),
                Text(formatDate(e.fechaPago),
                    style: TextStyle(fontSize: 12, color: tone.textSecondary)),
                const SizedBox(height: 6),
                StatusBadge(label: label, tone: badgeTone),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatMXN(e.monto),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tone.textPrimary)),
              if (!e.pagoCompletado && e.saldo > 0)
                Text('Falta ${formatMXN(e.saldo)}',
                    style: TextStyle(fontSize: 11, color: tone.pending)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FichaTecnica extends StatelessWidget {
  final FichaTecnica ficha;

  const _FichaTecnica({required this.ficha});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
            icon: Icons.map_outlined, text: 'Ficha técnica de tu propiedad'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ubicación, nivel y distribución de tu unidad'
                '${ficha.modelo != '—' ? ' · Modelo ${ficha.modelo}' : ''}',
                style: TextStyle(fontSize: 12, color: tone.textSecondary),
              ),
              if (ficha.numeroDepa != null || ficha.numeroPiso != null) ...[
                const SizedBox(height: 8),
                Text(
                  [
                    if (ficha.numeroDepa != null) 'Unidad ${ficha.numeroDepa}',
                    if (ficha.numeroPiso != null)
                      'Nivel ${ficha.numeroPiso}${ficha.totalPisos != null ? ' de ${ficha.totalPisos}' : ''}',
                    if (ficha.m2Total != null) '${ficha.m2Total} m²',
                  ].join(' · '),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tone.textPrimary),
                ),
              ],
              // Ubicación en el nivel: mapa interactivo o imagen.
              if (ficha.regiones.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('UBICACIÓN EN EL NIVEL',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w600,
                        color: tone.textMuted)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tone.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tone.border),
                  ),
                  child: LevelMap(
                      regiones: ficha.regiones, numeroDepa: ficha.numeroDepa),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            color: SozuColors.emerald500,
                            borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 6),
                    Text('Tu unidad',
                        style: TextStyle(
                            fontSize: 11, color: tone.textSecondary)),
                  ],
                ),
              ] else if (ficha.planoNivelUrl != null) ...[
                const SizedBox(height: 12),
                _planoImage(context, tone, 'UBICACIÓN EN EL NIVEL',
                    ficha.planoNivelUrl!),
              ],
              if (ficha.planoDistribucionUrl != null) ...[
                const SizedBox(height: 12),
                _planoImage(
                    context, tone, 'DISTRIBUCIÓN', ficha.planoDistribucionUrl!),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _planoImage(
      BuildContext context, SozuTone tone, String label, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
                color: tone.textMuted)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => openDoc(context, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: tone.surfaceAlt,
              height: 200,
              width: double.infinity,
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ],
    );
  }
}

class _DocRow extends StatelessWidget {
  final DocumentoItem d;

  const _DocRow({required this.d});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return GestureDetector(
      onTap: () => openDoc(context, d.urlFirmada),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: tone.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.description_outlined,
                  size: 18, color: SozuColors.emerald600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: tone.textPrimary)),
                  Text('${d.tipo} · ${formatDate(d.fecha)}',
                      style:
                          TextStyle(fontSize: 12, color: tone.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.open_in_new,
                size: 18, color: SozuColors.emerald600),
          ],
        ),
      ),
    );
  }
}
