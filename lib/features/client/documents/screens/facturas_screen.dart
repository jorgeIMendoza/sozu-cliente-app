import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/core/format.dart';
import 'package:sozu_cliente_app/core/open_document.dart';
import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/documents/components/datos_facturacion_card.dart';
import 'package:sozu_cliente_app/features/client/documents/providers/documents_providers.dart';
import 'package:sozu_cliente_app/features/client/layouts/portal_top_bar.dart';
import 'package:sozu_cliente_app/features/client/profile/providers/profile_providers.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:sozu_cliente_app/widgets/fx.dart';
import 'package:sozu_cliente_app/widgets/portal_widgets.dart';

/// Etiqueta de las facturas que no traen unidad. Desaparece cuando el backend
/// manda `id_cuenta` en las de mantenimiento.
const _sinUnidad = 'Sin unidad asignada';

/// Facturas de una unidad: la de compra y las de mantenimiento.
@immutable
class _Unidad {
  final int? idCuenta;
  final String nombre;
  final FacturaDocumento? compra;
  final List<FacturaMantenimientoDoc> mantenimiento;

  const _Unidad({
    required this.idCuenta,
    required this.nombre,
    required this.compra,
    required this.mantenimiento,
  });

  int get total => (compra == null ? 0 : 1) + mantenimiento.length;
}

/// Agrupa las dos listas del backend por unidad.
///
/// La clave es `id_cuenta` (la PADRE en las dos): el nombre de la propiedad se
/// escribe distinto según de dónde venga y agrupar por texto parte la unidad en
/// dos.
List<_Unidad> _agrupar(ClienteDocumentos data) {
  final nombres = <int, String>{};
  final compras = <int, FacturaDocumento>{};
  for (final f in data.facturas) {
    compras[f.idCuenta] = f;
    if (f.propiedad != null) nombres[f.idCuenta] = f.propiedad!;
  }

  final mantenimiento = <int, List<FacturaMantenimientoDoc>>{};
  final huerfanas = <FacturaMantenimientoDoc>[];
  for (final f in data.facturasMantenimiento) {
    final id = f.idCuenta;
    if (id == null) {
      huerfanas.add(f);
      continue;
    }
    mantenimiento.putIfAbsent(id, () => []).add(f);
    if (f.propiedad != null) nombres.putIfAbsent(id, () => f.propiedad!);
  }

  final unidades = <_Unidad>[
    for (final id in {...compras.keys, ...mantenimiento.keys})
      _Unidad(
        idCuenta: id,
        nombre: nombres[id] ?? 'Unidad $id',
        compra: compras[id],
        mantenimiento: (mantenimiento[id] ?? [])
          ..sort((a, b) => (b.fecha ?? '').compareTo(a.fecha ?? '')),
      ),
  ]..sort((a, b) => a.nombre.compareTo(b.nombre));

  if (huerfanas.isNotEmpty) {
    unidades.add(
      _Unidad(
        idCuenta: null,
        nombre: _sinUnidad,
        compra: null,
        mantenimiento: huerfanas
          ..sort((a, b) => (b.fecha ?? '').compareTo(a.fecha ?? '')),
      ),
    );
  }
  return unidades;
}

/// Facturas del cliente: datos fiscales arriba y una lista de unidades que al
/// abrirse muestra sus facturas.
///
/// Solo facturas. Los contratos, escrituras y comprobantes viven en el detalle
/// de cada propiedad, que es donde se buscan.
class FacturasScreen extends ConsumerStatefulWidget {
  const FacturasScreen({super.key});

  @override
  ConsumerState<FacturasScreen> createState() => _FacturasScreenState();
}

class _FacturasScreenState extends ConsumerState<FacturasScreen> {
  /// Unidad abierta, o null en la lista. Con una sola unidad se abre sola: un
  /// listado de un elemento es un toque de más.
  int? _abierta;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final docs = ref.watch(documentsProvider);
    final portal = isPortalMode(context);

    Widget contenido(ClienteDocumentos data) {
      final unidades = _agrupar(data);
      final abierta = unidades.length == 1 ? 0 : _abierta;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DatosFacturacionCard(
            perfil: ref.watch(profileProvider).valueOrNull,
            onModificar: () => context.push('/datos-fiscales'),
          ),
          SizedBox(height: t.space.lg),
          if (unidades.isEmpty)
            const SEmptyState.card(
              icon: Icons.receipt_long_outlined,
              title: 'Aún no tienes facturas.',
              message:
                  'Aparecen conforme se emiten: la de tu unidad al comprarla y '
                  'las de mantenimiento cuando se entrega.',
            )
          else if (abierta != null && abierta < unidades.length)
            _DetalleUnidad(
              unidad: unidades[abierta],
              // Con una sola unidad no hay a dónde volver.
              onVolver: unidades.length == 1
                  ? null
                  : () => setState(() => _abierta = null),
            )
          else ...[
            SSectionLabel.heading(
              icon: Icons.apartment_outlined,
              text: 'Tus unidades (${unidades.length})',
            ),
            for (var i = 0; i < unidades.length; i++) ...[
              _FilaUnidad(
                unidad: unidades[i],
                onTap: () => setState(() => _abierta = i),
              ),
              SizedBox(height: t.space.sm),
            ],
          ],
        ],
      );
    }

    final cuerpo = docs.when(
      loading: () => ListView(
        padding: EdgeInsets.all(t.space.md),
        children: const [
          SCard(child: SSkeleton(height: 140)),
          SizedBox(height: 24),
          SCard(child: SSkeleton(height: 72)),
        ],
      ),
      error: (_, _) => ListView(
        padding: EdgeInsets.all(t.space.md),
        children: [
          SErrorState(
            title: 'No pudimos cargar tus facturas',
            onRetry: () => ref.invalidate(documentsProvider),
          ),
        ],
      ),
      data: (data) => ListView(
        padding: portal
            ? EdgeInsets.only(top: t.space.lg, bottom: t.space.xl)
            : EdgeInsets.fromLTRB(t.space.md, 0, t.space.md, t.space.xl),
        children: [
          if (portal) ...[
            const PortalPageHeader(
              title: 'Facturas',
              subtitle: 'Comprobantes fiscales de tus unidades',
            ),
            SizedBox(height: t.space.lg),
          ],
          contenido(data),
        ],
      ),
    );

    if (portal) {
      return Scaffold(backgroundColor: Colors.transparent, body: cuerpo);
    }
    return Scaffold(
      appBar: const PortalTopBar(title: 'Facturas'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(documentsProvider);
          try {
            await ref.read(documentsProvider.future);
          } catch (_) {
            // el estado de error lo pinta la UI
          }
        },
        child: ContentFrame(child: cuerpo),
      ),
    );
  }
}

/// Fila de la lista de unidades: nombre y cuántas facturas tiene.
class _FilaUnidad extends StatelessWidget {
  final _Unidad unidad;
  final VoidCallback onTap;

  const _FilaUnidad({required this.unidad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;
    final n = unidad.total;
    return SPressable(
      onTap: onTap,
      borderRadius: t.radius.lgBorder,
      hoverLift: true,
      child: SCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: t.radius.mdBorder,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 20,
                color: c.primaryHover,
              ),
            ),
            SizedBox(width: t.space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unidad.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.label.copyWith(color: c.fg),
                  ),
                  Text(
                    n == 1 ? '1 factura' : '$n facturas',
                    style: t.text.caption.copyWith(color: c.fgMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: c.fgSubtle),
          ],
        ),
      ),
    );
  }
}

/// Facturas de una unidad, en dos secciones: la de la unidad y las de
/// mantenimiento, que solo existen cuando ya se entregó.
class _DetalleUnidad extends StatelessWidget {
  final _Unidad unidad;
  final VoidCallback? onVolver;

  const _DetalleUnidad({required this.unidad, required this.onVolver});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final mant = unidad.mantenimiento;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onVolver != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: SButton.link(
              label: 'Todas las unidades',
              icon: Icons.arrow_back,
              isNavigation: true,
              onPressed: onVolver,
            ),
          ),
          SizedBox(height: t.space.xs),
        ],
        Text(unidad.nombre, style: t.text.h3.copyWith(color: t.color.fg)),
        SizedBox(height: t.space.lg),

        const SSectionLabel.heading(
          icon: Icons.home_outlined,
          text: 'Factura de la unidad',
        ),
        if (unidad.compra == null)
          const SEmptyState.card(
            icon: Icons.receipt_outlined,
            title: 'Sin factura de compra todavía.',
          )
        else
          _FilaFactura(
            titulo: 'Factura de compra',
            subtitulo: unidad.nombre,
            pdf: unidad.compra!.pdf,
            xml: unidad.compra!.xml,
          ),

        SizedBox(height: t.space.lg),
        SSectionLabel.heading(
          icon: Icons.build_outlined,
          text: mant.isEmpty
              ? 'Facturas de mantenimiento'
              : 'Facturas de mantenimiento (${mant.length})',
        ),
        if (mant.isEmpty)
          const SEmptyState.card(
            icon: Icons.build_outlined,
            title: 'Sin facturas de mantenimiento.',
            message:
                'Se generan por cada pago de mantenimiento, a partir de que se '
                'entrega la unidad.',
          )
        else
          for (final f in mant) ...[
            _FilaFactura(
              titulo: f.fecha != null
                  ? 'Mantenimiento · ${formatDate(f.fecha)}'
                  : 'Mantenimiento',
              subtitulo: f.monto != null ? formatMXN(f.monto!) : null,
              pdf: f.pdf,
              xml: f.xml,
            ),
            SizedBox(height: t.space.sm),
          ],
      ],
    );
  }
}

/// Una factura con sus dos archivos. El XML es el CFDI válido ante el SAT y el
/// PDF su representación impresa: se ofrecen los dos, nunca uno solo.
class _FilaFactura extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final String? pdf;
  final String? xml;

  const _FilaFactura({
    required this.titulo,
    required this.subtitulo,
    required this.pdf,
    required this.xml,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;
    return SCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.text.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.fg,
                  ),
                ),
                if (subtitulo != null)
                  Text(
                    subtitulo!,
                    style: t.text.caption.copyWith(color: c.fgMuted),
                  ),
              ],
            ),
          ),
          SizedBox(width: t.space.xs),
          _Archivo(label: 'PDF', url: pdf),
          SizedBox(width: t.space.xs),
          _Archivo(label: 'XML', url: xml),
        ],
      ),
    );
  }
}

/// Botón de un archivo. Deshabilitado y atenuado si no llegó: que se vea que
/// falta es más útil que esconderlo.
class _Archivo extends StatelessWidget {
  final String label;
  final String? url;

  const _Archivo({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;
    final hay = url != null && url!.isNotEmpty;
    return SPressable(
      onTap: hay ? () => openDoc(context, url) : null,
      borderRadius: t.radius.mdBorder,
      semanticLabel: hay ? 'Abrir $label' : '$label no disponible',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.sm,
          vertical: t.space.xxs,
        ),
        decoration: BoxDecoration(
          borderRadius: t.radius.mdBorder,
          border: Border.all(color: hay ? c.primaryBorder : c.borderSoft),
        ),
        child: Text(
          label,
          style: t.text.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: hay ? c.primaryHover : c.fgSubtle,
          ),
        ),
      ),
    );
  }
}
