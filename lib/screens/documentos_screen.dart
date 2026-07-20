import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/file_download.dart';
import '../core/format.dart';
import '../core/open_doc.dart';
import '../core/open_media.dart';
import '../core/portal_theme.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';
import '../widgets/portal_top_bar.dart';
import '../widgets/portal_widgets.dart';

/// Documentos del cliente — espejo de la sección "Documentos" del Portal del
/// cliente (ClienteDocumentos.tsx): barra de stats por estatus, filtros por
/// propiedad/tipo, agrupación por propiedad o estado (secciones colapsables),
/// items con icono por tipo + chip de estatus, hoja de detalle con acciones
/// (ver in-app, descargar) y secciones de facturas CFDI (propiedad y
/// mantenimiento).

// ─── Catálogos de estatus y tipo (paridad con document-data.ts) ──────────────

const _kEstadosStats = [
  'pendiente',
  'rechazado',
  'recibido',
  'validado',
  'firmado',
];

const _kOrdenGruposEstado = [
  'rechazado',
  'pendiente',
  'recibido',
  'validado',
  'firmado',
];

/// Prioridad de acción dentro de un grupo por propiedad (portal:
/// sortByActionPriority).
const _kPrioridadEstado = {
  'rechazado': 0,
  'pendiente': 1,
  'recibido': 2,
  'validado': 3,
  'firmado': 4,
};

const _kCategorias = [
  'contrato',
  'escritura',
  'comprobante',
  'cfdi',
  'identificacion',
  'garantia',
  'otro',
];

String _estadoLabel(String estado) => switch (estado) {
  'pendiente' => 'Pendiente',
  'recibido' => 'Recibido',
  'validado' => 'Validado',
  'rechazado' => 'Rechazado',
  'firmado' => 'Firmado',
  _ => estado,
};

/// Color principal del estatus (mismos tonos que el portal: warning /
/// primary / success / destructive).
Color _estadoColor(String estado, SozuTone tone) => switch (estado) {
  'pendiente' => SozuColors.amber600,
  'rechazado' => tone.negative,
  'recibido' => SozuColors.emerald700,
  'validado' => SozuColors.emerald500,
  'firmado' => SozuColors.emerald600,
  _ => tone.textMuted,
};

String _categoriaLabel(String categoria) => switch (categoria) {
  'contrato' => 'Contrato',
  'escritura' => 'Escritura',
  'comprobante' => 'Comprobante',
  'cfdi' => 'CFDI',
  'identificacion' => 'Identificación',
  'garantia' => 'Garantía',
  'otro' => 'Otro',
  _ => categoria,
};

/// Icono por tipo de documento (portal getTypeInfo: FileSignature, Landmark,
/// Receipt, FileCode2, BadgeCheck, ShieldCheck, FileText).
IconData _categoriaIcono(String categoria) => switch (categoria) {
  'contrato' => Icons.history_edu_outlined,
  'escritura' => Icons.account_balance_outlined,
  'comprobante' => Icons.receipt_long_outlined,
  'cfdi' => Icons.request_quote_outlined,
  'identificacion' => Icons.badge_outlined,
  'garantia' => Icons.verified_user_outlined,
  'otro' => Icons.description_outlined,
  _ => Icons.description_outlined,
};

/// Nombre de archivo legible desde la URL firmada (sin query string).
String? _nombreArchivo(String? url) {
  if (url == null || url.isEmpty) return null;
  final sinQuery = url.split('?').first;
  final seg = Uri.tryParse(sinQuery)?.pathSegments;
  if (seg == null || seg.isEmpty) return null;
  final nombre = Uri.decodeComponent(seg.last);
  return nombre.isEmpty ? null : nombre;
}

/// Extensión del archivo (para el sub-texto "PDF · …", como el portal).
String? _extension(String? url) {
  final nombre = _nombreArchivo(url);
  if (nombre == null || !nombre.contains('.')) return null;
  final ext = nombre.split('.').last;
  if (ext.isEmpty || ext.length > 4) return null;
  return ext.toUpperCase();
}

// ─── Pantalla ─────────────────────────────────────────────────────────────────

class DocumentosScreen extends ConsumerStatefulWidget {
  const DocumentosScreen({super.key});

  @override
  ConsumerState<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends ConsumerState<DocumentosScreen> {
  String? _filtroEstado; // pendiente | rechazado | recibido | validado | firmado
  int? _filtroCuenta; // id cuenta de cobranza
  String? _filtroCategoria; // contrato | escritura | ... | otro
  bool _agruparPorEstado = false; // false = por propiedad (default del portal)
  final Set<String> _colapsados = {};

  bool get _hayFiltros =>
      _filtroEstado != null || _filtroCuenta != null || _filtroCategoria != null;

  void _limpiarFiltros() => setState(() {
    _filtroEstado = null;
    _filtroCuenta = null;
    _filtroCategoria = null;
  });

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final docs = ref.watch(clienteDocumentosProvider);

    // Modo portal (web ≥1024): el shell pinta sidebar + topbar y el fondo
    // #F9FAFB; PortalTopBar ya se colapsa solo (sin doble header).
    return Scaffold(
      backgroundColor: isPortalMode(context) ? Colors.transparent : null,
      appBar: const PortalTopBar(title: 'Documentos'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(clienteDocumentosProvider);
          try {
            await ref.read(clienteDocumentosProvider.future);
          } catch (_) {}
        },
        child: docs.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 18),
                    SizedBox(height: 10),
                    Skeleton(width: 200, height: 14),
                    SizedBox(height: 10),
                    Skeleton(width: 260, height: 14),
                  ],
                ),
              ),
            ],
          ),
          error: (_, __) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ErrorCard(
                title: 'No pudimos cargar tus documentos',
                onRetry: () => ref.invalidate(clienteDocumentosProvider),
              ),
            ],
          ),
          data: (data) => _contenido(context, tone, data),
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context, SozuTone tone, ClienteDocumentos data) {
    final portal = isPortalMode(context);
    // ── Stats sobre TODOS los documentos (como el portal) ──
    final stats = <String, int>{for (final e in _kEstadosStats) e: 0};
    for (final d in data.documentos) {
      stats[d.estatus] = (stats[d.estatus] ?? 0) + 1;
    }
    final verificados = (stats['validado'] ?? 0) + (stats['firmado'] ?? 0);

    // ── Opciones del filtro de propiedad (derivadas de los datos) ──
    final propiedades = <int, String>{};
    for (final d in data.documentos) {
      if (d.idCuenta != null) {
        propiedades[d.idCuenta!] = d.propiedad ?? 'Propiedad ${d.idCuenta}';
      }
    }
    for (final f in data.facturas) {
      propiedades.putIfAbsent(
          f.idCuenta, () => f.propiedad ?? 'Propiedad ${f.idCuenta}');
    }

    // ── Filtrado ──
    final filtrados = data.documentos.where((d) {
      if (_filtroEstado != null && d.estatus != _filtroEstado) return false;
      if (_filtroCuenta != null && d.idCuenta != _filtroCuenta) return false;
      if (_filtroCategoria != null && d.categoria != _filtroCategoria) {
        return false;
      }
      return true;
    }).toList();

    // ── Agrupación ──
    final grupos = <String, List<DocumentoItem>>{};
    if (_agruparPorEstado) {
      for (final d in filtrados) {
        grupos.putIfAbsent(d.estatus, () => []).add(d);
      }
    } else {
      for (final d in filtrados) {
        grupos.putIfAbsent(d.idCuenta?.toString() ?? 'persona', () => []).add(d);
      }
      for (final lista in grupos.values) {
        lista.sort(
          (a, b) => (_kPrioridadEstado[a.estatus] ?? 9)
              .compareTo(_kPrioridadEstado[b.estatus] ?? 9),
        );
      }
    }
    final clavesOrdenadas = _agruparPorEstado
        ? _kOrdenGruposEstado.where((k) => (grupos[k] ?? []).isNotEmpty).toList()
        : grupos.keys.toList();

    // ── Facturas: respetan filtros como el portal (sin estatus; tipo=cfdi) ──
    final facturasVisibles =
        (_filtroEstado != null ||
            (_filtroCategoria != null && _filtroCategoria != 'cfdi'))
        ? <FacturaDocumento>[]
        : data.facturas
              .where((f) => _filtroCuenta == null || f.idCuenta == _filtroCuenta)
              .toList();
    final mantVisibles =
        (_filtroEstado != null ||
            (_filtroCategoria != null && _filtroCategoria != 'cfdi') ||
            _filtroCuenta != null)
        ? <FacturaMantenimientoDoc>[]
        : data.facturasMantenimiento;

    final sinNada = data.documentos.isEmpty &&
        data.facturas.isEmpty &&
        data.facturasMantenimiento.isEmpty;
    final sinResultados =
        filtrados.isEmpty && facturasVisibles.isEmpty && mantVisibles.isEmpty;

    // Subtítulo (portal: "X de Y documentos verificados").
    final subtitulo = data.documentos.isNotEmpty
        ? '$verificados de ${data.total} documento${data.total == 1 ? '' : 's'} verificado${verificados == 1 ? '' : 's'}'
        : 'Todos tus documentos en un solo lugar.';

    if (sinNada) {
      return ListView(
        padding: portal
            ? const EdgeInsets.only(top: 24, bottom: 32)
            : const EdgeInsets.all(16),
        children: [
          if (portal) ...[
            Text(
              'Documentos',
              style: portalText(
                  size: 26, weight: FontWeight.w700, letterSpacing: -0.65),
            ),
            const SizedBox(height: 4),
            Text(
              subtitulo,
              style:
                  portalText(size: 13, color: PortalColors.mutedForeground),
            ),
            const SizedBox(height: 20),
          ],
          const EmptyCard(
            icon: Icons.folder_open_outlined,
            text:
                'Sin documentos aún.\nTus documentos aparecerán aquí conforme avance tu proceso.',
          ),
        ],
      );
    }

    // En modo portal el contenido ocupa el ancho del shell (max 1280 con
    // gutters, como ClienteDocumentos.tsx); en móvil se conserva el frame
    // de 900 con padding lateral.
    final lista = ListView(
        padding: portal
            ? const EdgeInsets.only(top: 24, bottom: 32)
            : const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          // Header de página del portal (h1 + subtítulo); en móvil el título
          // vive en el AppBar y solo se muestra el subtítulo.
          if (portal) ...[
            Text(
              'Documentos',
              style: portalText(
                  size: 26, weight: FontWeight.w700, letterSpacing: -0.65),
            ),
            const SizedBox(height: 4),
            Text(
              subtitulo,
              style:
                  portalText(size: 13, color: PortalColors.mutedForeground),
            ),
            const SizedBox(height: 20),
          ] else ...[
            Text(
              subtitulo,
              style: TextStyle(fontSize: 13, color: tone.textSecondary),
            ),
            const SizedBox(height: 12),
          ],

          // Barra de stats por estatus (chips clicables).
          _StatsBar(
            stats: stats,
            total: data.total,
            activo: _filtroEstado,
            onSeleccionar: (e) => setState(() => _filtroEstado = e),
          ),
          const SizedBox(height: 8),

          // Filtros: propiedad, tipo, agrupar, limpiar.
          _FiltrosRow(
            propiedades: propiedades,
            filtroCuenta: _filtroCuenta,
            filtroCategoria: _filtroCategoria,
            agruparPorEstado: _agruparPorEstado,
            hayFiltros: _hayFiltros,
            onCuenta: (v) => setState(() => _filtroCuenta = v),
            onCategoria: (v) => setState(() => _filtroCategoria = v),
            onAgrupar: (porEstado) =>
                setState(() => _agruparPorEstado = porEstado),
            onLimpiar: _limpiarFiltros,
          ),
          const SizedBox(height: 12),

          if (sinResultados)
            _SinResultados(onLimpiar: _limpiarFiltros)
          else ...[
            for (final clave in clavesOrdenadas) ...[
              _GrupoSection(
                titulo: _agruparPorEstado
                    ? _estadoLabel(clave)
                    : (clave == 'persona'
                          ? 'Documentos personales'
                          : (grupos[clave]!.first.propiedad ??
                              'Propiedad $clave')),
                docs: grupos[clave]!,
                colapsado: _colapsados.contains(clave),
                onToggle: () => setState(() {
                  _colapsados.contains(clave)
                      ? _colapsados.remove(clave)
                      : _colapsados.add(clave);
                }),
                onVerDoc: (d) => _mostrarDetalle(context, d),
              ),
              const SizedBox(height: 12),
            ],
            if (facturasVisibles.isNotEmpty) ...[
              _FacturasSection(
                titulo: 'Facturas · Propiedad',
                items: [
                  for (final f in facturasVisibles)
                    _FacturaEntry(
                      titulo: 'Factura CFDI',
                      subtitulo: f.propiedad ?? 'Propiedad ${f.idCuenta}',
                      fileBase: '${f.idCuenta}',
                      pdf: f.pdf,
                      xml: f.xml,
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (mantVisibles.isNotEmpty) ...[
              _FacturasSection(
                titulo: 'Facturas · Mantenimiento',
                items: [
                  for (final f in mantVisibles)
                    _FacturaEntry(
                      titulo: 'Factura mantenimiento',
                      subtitulo:
                          'Pago #${f.idPago}${f.fecha != null ? ' · ${formatDate(f.fecha)}' : ''}',
                      fileBase: 'pago-${f.idPago}',
                      pdf: f.pdf,
                      xml: f.xml,
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      );

    return portal ? lista : ContentFrame(maxWidth: 900, child: lista);
  }

  // ── Detalle de documento (sheet en angosto, diálogo en ancho) ──
  Future<void> _mostrarDetalle(BuildContext context, DocumentoItem d) {
    final ancho = MediaQuery.sizeOf(context).width >= 768;
    if (ancho) {
      return showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: _DetalleDocumento(d: d),
          ),
        ),
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetWrapper(child: _DetalleDocumento(d: d)),
    );
  }
}

// ─── Barra de stats (DocumentStatsBar) ────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final Map<String, int> stats;
  final int total;
  final String? activo;
  final ValueChanged<String?> onSeleccionar;

  const _StatsBar({
    required this.stats,
    required this.total,
    required this.activo,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(
            tone: tone,
            label: 'Todos',
            count: total,
            color: tone.textPrimary,
            seleccionado: activo == null,
            conPunto: false,
            onTap: () => onSeleccionar(null),
          ),
          for (final e in _kEstadosStats) ...[
            const SizedBox(width: 6),
            _chip(
              tone: tone,
              label: _estadoLabel(e),
              count: stats[e] ?? 0,
              color: _estadoColor(e, tone),
              seleccionado: activo == e,
              conPunto: true,
              onTap: () => onSeleccionar(activo == e ? null : e),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip({
    required SozuTone tone,
    required String label,
    required int count,
    required Color color,
    required bool seleccionado,
    required bool conPunto,
    required VoidCallback onTap,
  }) {
    final apagado = count == 0 && !seleccionado;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: seleccionado ? color.withValues(alpha: 0.10) : tone.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: seleccionado
                ? color.withValues(alpha: 0.45)
                : tone.border.withValues(alpha: apagado ? 0.5 : 1),
          ),
        ),
        child: Row(
          children: [
            if (conPunto) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: apagado ? tone.border : color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: seleccionado
                    ? color
                    : (apagado ? tone.textMuted : tone.textPrimary),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: seleccionado
                    ? color
                    : (apagado ? tone.textMuted : tone.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Fila de filtros (DocumentFilters) ────────────────────────────────────────

class _FiltrosRow extends StatelessWidget {
  final Map<int, String> propiedades;
  final int? filtroCuenta;
  final String? filtroCategoria;
  final bool agruparPorEstado;
  final bool hayFiltros;
  final ValueChanged<int?> onCuenta;
  final ValueChanged<String?> onCategoria;
  final ValueChanged<bool> onAgrupar;
  final VoidCallback onLimpiar;

  const _FiltrosRow({
    required this.propiedades,
    required this.filtroCuenta,
    required this.filtroCategoria,
    required this.agruparPorEstado,
    required this.hayFiltros,
    required this.onCuenta,
    required this.onCategoria,
    required this.onAgrupar,
    required this.onLimpiar,
  });

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Propiedad
          _dropdown<int?>(
            context: context,
            tone: tone,
            texto: filtroCuenta != null
                ? (propiedades[filtroCuenta] ?? 'Propiedad')
                : 'Todas las propiedades',
            activo: filtroCuenta != null,
            opciones: [
              const PopupMenuItem<int?>(
                value: -1,
                child: Text('Todas las propiedades'),
              ),
              for (final e in propiedades.entries)
                PopupMenuItem<int?>(value: e.key, child: Text(e.value)),
            ],
            onSeleccion: (v) => onCuenta(v == -1 ? null : v),
          ),
          const SizedBox(width: 8),
          // Tipo
          _dropdown<String?>(
            context: context,
            tone: tone,
            texto: filtroCategoria != null
                ? _categoriaLabel(filtroCategoria!)
                : 'Todos los tipos',
            activo: filtroCategoria != null,
            opciones: [
              const PopupMenuItem<String?>(
                value: 'todos',
                child: Text('Todos los tipos'),
              ),
              for (final c in _kCategorias)
                PopupMenuItem<String?>(
                  value: c,
                  child: Text(_categoriaLabel(c)),
                ),
            ],
            onSeleccion: (v) => onCategoria(v == 'todos' ? null : v),
          ),
          const SizedBox(width: 8),
          // Agrupar por
          Container(
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: tone.border),
              borderRadius: BorderRadius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                _segmento(tone, 'Propiedad', !agruparPorEstado,
                    () => onAgrupar(false)),
                Container(width: 1, color: tone.border),
                _segmento(tone, 'Estado', agruparPorEstado,
                    () => onAgrupar(true)),
              ],
            ),
          ),
          if (hayFiltros) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onLimpiar,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: tone.negative.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: tone.negative.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.close, size: 13, color: tone.negative),
                    const SizedBox(width: 4),
                    Text(
                      'Limpiar',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tone.negative,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required BuildContext context,
    required SozuTone tone,
    required String texto,
    required bool activo,
    required List<PopupMenuEntry<T>> opciones,
    required ValueChanged<T> onSeleccion,
  }) {
    return PopupMenuButton<T>(
      itemBuilder: (_) => opciones,
      onSelected: onSeleccion,
      tooltip: '',
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: activo ? tone.primarySoft : tone.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: activo ? SozuColors.emerald500.withValues(alpha: 0.4) : tone.border,
          ),
        ),
        child: Row(
          children: [
            Text(
              texto,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: activo ? tone.primaryDark : tone.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 15,
              color: activo ? tone.primaryDark : tone.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _segmento(
    SozuTone tone,
    String label,
    bool activo,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: activo
            ? tone.textPrimary.withValues(alpha: 0.08)
            : Colors.transparent,
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: activo ? tone.textPrimary : tone.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Sección de grupo colapsable (GroupSection) ───────────────────────────────

class _GrupoSection extends StatelessWidget {
  final String titulo;
  final List<DocumentoItem> docs;
  final bool colapsado;
  final VoidCallback onToggle;
  final ValueChanged<DocumentoItem> onVerDoc;

  const _GrupoSection({
    required this.titulo,
    required this.docs,
    required this.colapsado,
    required this.onToggle,
    required this.onVerDoc,
  });

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tone.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: tone.surfaceAlt.withValues(alpha: 0.6),
                border: colapsado
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: tone.border.withValues(alpha: 0.5),
                        ),
                      ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tone.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${docs.length} doc${docs.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 11, color: tone.textSecondary),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    colapsado
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 16,
                    color: tone.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (!colapsado)
            for (var i = 0; i < docs.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: tone.border.withValues(alpha: 0.4),
                ),
              _DocRow(d: docs[i], onTap: () => onVerDoc(docs[i])),
            ],
        ],
      ),
    );
  }
}

// ─── Item de documento (DocumentListItem) ─────────────────────────────────────

class _DocRow extends StatelessWidget {
  final DocumentoItem d;
  final VoidCallback onTap;

  const _DocRow({required this.d, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final color = _estadoColor(d.estatus, tone);
    final ext = _extension(d.urlFirmada);
    final subtitulo = [
      if (ext != null) ext else _categoriaLabel(d.categoria),
      formatDate(d.fecha),
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(_categoriaIcono(d.categoria), size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: tone.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: tone.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _estadoLabel(d.estatus),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: tone.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─── Sección de facturas (FacturasSection) ────────────────────────────────────

class _FacturaEntry {
  final String titulo;
  final String subtitulo;

  /// Base del nombre de archivo para la descarga (p. ej. "12" → factura-12.pdf).
  final String fileBase;
  final String? pdf;
  final String? xml;

  const _FacturaEntry({
    required this.titulo,
    required this.subtitulo,
    required this.fileBase,
    this.pdf,
    this.xml,
  });
}

class _FacturasSection extends StatelessWidget {
  final String titulo;
  final List<_FacturaEntry> items;

  const _FacturasSection({required this.titulo, required this.items});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            titulo.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: tone.textMuted,
            ),
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: tone.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tone.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: tone.border.withValues(alpha: 0.4),
                  ),
                _facturaRow(context, tone, items[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _facturaRow(BuildContext context, SozuTone tone, _FacturaEntry f) {
    return InkWell(
      onTap: () => _mostrarFactura(context, f),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tone.primarySoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.receipt_outlined,
                size: 18,
                color: SozuColors.emerald600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.titulo,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: tone.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    f.subtitulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: tone.textSecondary),
                  ),
                ],
              ),
            ),
            if (f.pdf != null) _archivoTag(tone, 'PDF', tone.negative),
            if (f.xml != null) ...[
              const SizedBox(width: 4),
              _archivoTag(tone, 'XML', const Color(0xFF2563EB)),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: tone.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _archivoTag(SozuTone tone, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Future<void> _mostrarFactura(BuildContext context, _FacturaEntry f) {
    final ancho = MediaQuery.sizeOf(context).width >= 768;
    final detalle = _DetalleFactura(f: f);
    if (ancho) {
      return showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: detalle,
          ),
        ),
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetWrapper(child: detalle),
    );
  }
}

// ─── Detalle de factura (FacturaDetailModal) ──────────────────────────────────

class _DetalleFactura extends StatelessWidget {
  final _FacturaEntry f;

  const _DetalleFactura({required this.f});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tone.primarySoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.receipt_outlined,
                  size: 20,
                  color: SozuColors.emerald600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.titulo,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: tone.textPrimary,
                      ),
                    ),
                    Text(
                      f.subtitulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: tone.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: tone.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ARCHIVOS DISPONIBLES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: tone.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              _archivos(context, tone),
              const SizedBox(height: 14),
              _acciones(context, tone),
            ],
          ),
        ),
      ],
    );
  }

  /// Lista de archivos disponibles: grid de 2 columnas (PDF | XML) en ancho,
  /// apilados en angosto — espejo de `grid grid-cols-2` de FacturaModalContent.
  Widget _archivos(BuildContext context, SozuTone tone) {
    final ancho = MediaQuery.sizeOf(context).width >= 768;
    final pdfBtn = f.pdf == null
        ? null
        : _archivoBtn(
            context,
            tone,
            icono: Icons.picture_as_pdf_outlined,
            color: tone.negative,
            titulo: 'PDF',
            subtitulo: 'Factura imprimible',
            onTap: () => _descargar(context, f.pdf!, '${f.fileBase}.pdf'),
          );
    final xmlBtn = f.xml == null
        ? null
        : _archivoBtn(
            context,
            tone,
            icono: Icons.code,
            color: const Color(0xFF2563EB),
            titulo: 'XML',
            subtitulo: 'Archivo fiscal SAT',
            onTap: () => _descargar(context, f.xml!, '${f.fileBase}.xml'),
          );

    if (ancho && pdfBtn != null && xmlBtn != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: pdfBtn),
          const SizedBox(width: 12),
          Expanded(child: xmlBtn),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pdfBtn != null) pdfBtn,
        if (pdfBtn != null && xmlBtn != null) const SizedBox(height: 8),
        if (xmlBtn != null) xmlBtn,
      ],
    );
  }

  /// Footer: "Descargar ZIP" (PDF+XML) + "Cerrar", como el portal. Sin una
  /// librería de compresión se descargan ambos archivos en secuencia.
  Widget _acciones(BuildContext context, SozuTone tone) {
    final ambos = f.pdf != null && f.xml != null;
    final cerrar = TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Cerrar'),
    );
    if (!ambos) return cerrar;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _descargarZip(context),
            style: FilledButton.styleFrom(
              backgroundColor: tone.primarySoft,
              foregroundColor: tone.primaryDark,
              elevation: 0,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Descargar ZIP'),
          ),
        ),
        const SizedBox(width: 8),
        cerrar,
      ],
    );
  }

  Future<void> _descargar(
      BuildContext context, String url, String filename) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await downloadFile(url, 'factura-$filename');
    if (!ok && context.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo descargar el archivo.')),
      );
    }
  }

  Future<void> _descargarZip(BuildContext context) async {
    await downloadFile(f.pdf!, 'factura-${f.fileBase}.pdf');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await downloadFile(f.xml!, 'factura-${f.fileBase}.xml');
  }

  Widget _archivoBtn(
    BuildContext context,
    SozuTone tone, {
    required IconData icono,
    required Color color,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: tone.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icono, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tone.textPrimary,
                    ),
                  ),
                  Text(
                    subtitulo,
                    style: TextStyle(fontSize: 11, color: tone.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.download_outlined, size: 18, color: tone.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─── Detalle de documento (DocumentDetailSheet) ───────────────────────────────

class _DetalleDocumento extends StatelessWidget {
  final DocumentoItem d;

  const _DetalleDocumento({required this.d});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final color = _estadoColor(d.estatus, tone);
    final archivo = _nombreArchivo(d.urlFirmada);
    final ext = _extension(d.urlFirmada);
    final tieneArchivo = (d.urlFirmada ?? '').isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header (icono por tipo + nombre + tipo · propiedad)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(_categoriaIcono(d.categoria), size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: tone.textPrimary,
                      ),
                    ),
                    Text(
                      '${_categoriaLabel(d.categoria)} · ${d.propiedad ?? 'Documento personal'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: tone.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _estadoLabel(d.estatus),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: tone.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Aviso para rechazados (portal muestra el motivo y CTA de ayuda).
              if (d.estatus == 'rechazado') ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tone.negative.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: tone.negative.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline,
                              size: 16, color: tone.negative),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Este documento fue rechazado. Contacta a tu '
                              'asesor para subir una nueva versión.',
                              style: TextStyle(
                                fontSize: 12,
                                color: tone.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Motivo del rechazo (solo si el backend lo expone).
                      if ((d.motivoRechazo ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Motivo: ${d.motivoRechazo!.trim()}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: tone.negative,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      // CTA de soporte.
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => openDoc(context, 'mailto:soporte@sozu.com'
                              '?subject=${Uri.encodeComponent('Documento rechazado: ${d.nombre}')}'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: tone.negative,
                            side: BorderSide(
                              color: tone.negative.withValues(alpha: 0.35),
                            ),
                            minimumSize: const Size(0, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          icon: const Icon(Icons.support_agent_outlined, size: 16),
                          label: const Text('Contactar a soporte'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Detalles del archivo (portal: renderMetadata).
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tone.surfaceAlt.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tone.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DETALLES DEL ARCHIVO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: tone.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (archivo != null) _fila(tone, 'Nombre', archivo),
                    if (ext != null) _fila(tone, 'Formato', ext),
                    _fila(tone, 'Subido', formatDate(d.fecha)),
                    _fila(tone, 'Tipo', d.tipo),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Acciones: ver (visor in-app), descargar, cerrar.
              if (tieneArchivo) ...[
                FilledButton.icon(
                  onPressed: () =>
                      openMedia(context, d.urlFirmada, titulo: d.nombre),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Ver documento'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => openDoc(context, d.urlFirmada),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Descargar'),
                ),
                const SizedBox(height: 8),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tone.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Este documento no tiene un archivo asociado.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: tone.textSecondary),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fila(SozuTone tone, String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: TextStyle(fontSize: 12, color: tone.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: tone.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Estado vacío con filtros activos (EmptyState del portal) ─────────────────

class _SinResultados extends StatelessWidget {
  final VoidCallback onLimpiar;

  const _SinResultados({required this.onLimpiar});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: tone.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.description_outlined,
              size: 24,
              color: tone.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Sin resultados',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tone.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ajusta o limpia los filtros para ver más documentos.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: tone.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onLimpiar,
            child: const Text('Limpiar filtros'),
          ),
        ],
      ),
    );
  }
}

// ─── Envoltorio de bottom sheet (esquinas redondeadas + scroll) ───────────────

class _SheetWrapper extends StatelessWidget {
  final Widget child;

  const _SheetWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return SafeArea(
      child: Container(
        margin: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        decoration: BoxDecoration(
          color: tone.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}
