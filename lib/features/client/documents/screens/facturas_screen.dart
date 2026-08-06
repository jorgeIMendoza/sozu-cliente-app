import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/core/open_document.dart';
import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/documents/components/datos_facturacion_card.dart';
import 'package:sozu_cliente_app/features/client/documents/components/factura_cards.dart';
import 'package:sozu_cliente_app/features/client/documents/providers/documents_providers.dart';
import 'package:sozu_cliente_app/features/client/layouts/portal_top_bar.dart';
import 'package:sozu_cliente_app/features/client/profile/providers/profile_providers.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:sozu_cliente_app/widgets/fx.dart';
import 'package:sozu_cliente_app/widgets/portal_widgets.dart';

/// Etiqueta de las facturas que no traen unidad. Desaparece cuando el backend
/// manda `id_cuenta` en las de mantenimiento.
const _sinUnidad = 'Sin unidad asignada';

/// Agrupa las dos listas del backend por unidad.
///
/// La clave es `id_cuenta` (la PADRE en las dos): el nombre de la propiedad se
/// escribe distinto según de dónde venga y agrupar por texto parte la unidad en
/// dos.
List<UnidadFacturas> _agrupar(ClienteDocumentos data) {
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

  final unidades = <UnidadFacturas>[
    for (final id in {...compras.keys, ...mantenimiento.keys})
      UnidadFacturas(
        idCuenta: id,
        nombre: nombres[id] ?? 'Unidad $id',
        compra: compras[id],
        mantenimiento: (mantenimiento[id] ?? [])
          ..sort((a, b) => (b.fecha ?? '').compareTo(a.fecha ?? '')),
      ),
  ]..sort((a, b) => a.nombre.compareTo(b.nombre));

  if (huerfanas.isNotEmpty) {
    unidades.add(
      UnidadFacturas(
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
            UnidadFacturasDetalle(
              unidad: unidades[abierta],
              // Con una sola unidad no hay a dónde volver.
              onVolver: unidades.length == 1
                  ? null
                  : () => setState(() => _abierta = null),
              onAbrir: (url) => openDoc(context, url),
            )
          else ...[
            SSectionLabel.heading(
              icon: Icons.apartment_outlined,
              text: 'Tus unidades (${unidades.length})',
            ),
            for (var i = 0; i < unidades.length; i++) ...[
              UnidadFacturasCard(
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
