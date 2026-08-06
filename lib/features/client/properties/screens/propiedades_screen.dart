import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/layouts/portal_top_bar.dart';
import 'package:sozu_cliente_app/features/client/properties/components/portal_property_card.dart';
import 'package:sozu_cliente_app/features/client/properties/components/property_card.dart';
import 'package:sozu_cliente_app/features/client/properties/providers/properties_providers.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:sozu_cliente_app/widgets/fx.dart';
import 'package:sozu_cliente_app/widgets/portal_widgets.dart';

/// Filtro del listado. "En adquisición" y "Entregadas" son la MISMA lista de
/// propiedades en dos momentos: antes y después de la entrega.
enum PropiedadesFiltro { todas, adquisicion, entregadas }

extension on PropiedadesFiltro {
  String get label => switch (this) {
    PropiedadesFiltro.todas => 'Todas',
    PropiedadesFiltro.adquisicion => 'En adquisición',
    PropiedadesFiltro.entregadas => 'Entregadas',
  };
}

/// Propiedades del cliente en UNA pantalla con filtros. Antes eran dos
/// pestañas y había que saber en cuál buscar la unidad propia.
class PropiedadesScreen extends ConsumerStatefulWidget {
  /// Filtro con el que abre. Las rutas viejas entran preseleccionando el suyo.
  final PropiedadesFiltro filtroInicial;

  const PropiedadesScreen({
    super.key,
    this.filtroInicial = PropiedadesFiltro.todas,
  });

  @override
  ConsumerState<PropiedadesScreen> createState() => _PropiedadesScreenState();
}

class _PropiedadesScreenState extends ConsumerState<PropiedadesScreen> {
  late PropiedadesFiltro _filtro = widget.filtroInicial;
  final _busquedaCtrl = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  List<PropiedadCard> _propiedades(ClientePropiedades data) =>
      switch (_filtro) {
        PropiedadesFiltro.todas => [
          ...data.enAdquisicion,
          ...data.patrimonioActivo,
        ],
        PropiedadesFiltro.adquisicion => data.enAdquisicion,
        PropiedadesFiltro.entregadas => data.patrimonioActivo,
      };

  List<PropiedadCard> _filtrar(List<PropiedadCard> items) {
    final q = _busqueda.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where(
          (p) => '${p.proyecto} ${p.nombre} ${p.ubicacion ?? ''}'
              .toLowerCase()
              .contains(q),
        )
        .toList();
  }

  /// Conteo por filtro: la pastilla dice si vale la pena cambiarlo.
  int _conteo(ClientePropiedades data, PropiedadesFiltro f) => switch (f) {
    PropiedadesFiltro.todas =>
      data.enAdquisicion.length + data.patrimonioActivo.length,
    PropiedadesFiltro.adquisicion => data.enAdquisicion.length,
    PropiedadesFiltro.entregadas => data.patrimonioActivo.length,
  };

  Widget _filtros(ClientePropiedades data) {
    final t = context.s;
    return Wrap(
      spacing: t.space.xs,
      runSpacing: t.space.xs,
      children: [
        for (final f in PropiedadesFiltro.values)
          SChoiceChip(
            label: '${f.label} (${_conteo(data, f)})',
            selected: _filtro == f,
            // Grupo excluyente: se ignora el valor y se fija la opción.
            onSelected: (_) => setState(() => _filtro = f),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final props = ref.watch(propertiesProvider);

    // Modo portal (web ≥1024): sin AppBar propio, la topbar la pinta el shell.
    if (isPortalMode(context)) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: props.when(
          loading: () => const SingleChildScrollView(
            padding: EdgeInsets.only(top: 24, bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PortalPageHeader(
                  title: 'Propiedades',
                  subtitle: 'Tus unidades, en adquisición y entregadas',
                ),
                SizedBox(height: 20),
                PortalCardGrid(
                  children: [PortalCardSkeleton(), PortalCardSkeleton()],
                ),
              ],
            ),
          ),
          error: (_, __) => ListView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            children: [
              SErrorState(
                title: 'No pudimos cargar tus propiedades',
                onRetry: () => ref.invalidate(propertiesProvider),
              ),
            ],
          ),
          data: (data) {
            final filtradas = _filtrar(_propiedades(data));
            return SingleChildScrollView(
              padding: const EdgeInsets.only(top: 24, bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PortalPageHeader(
                    title: 'Propiedades',
                    subtitle: 'Tus unidades, en adquisición y entregadas',
                  ),
                  SizedBox(height: t.space.md),
                  _filtros(data),
                  SizedBox(height: t.space.md),
                  SSearchField(
                    controller: _busquedaCtrl,
                    hintText: 'Buscar propiedad…',
                    onChanged: (v) => setState(() => _busqueda = v),
                    onCleared: () => setState(() => _busqueda = ''),
                  ),
                  SizedBox(height: t.space.lg),
                  if (filtradas.isEmpty)
                    _vacio()
                  else
                    PortalCardGrid(
                      minItemWidth: 320,
                      children: [
                        for (final it in filtradas)
                          PortalPropertyCard(
                            item: it,
                            onTap: () => context.push('/propiedad/${it.id}'),
                          ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: const PortalTopBar(title: 'Propiedades'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(propertiesProvider);
          try {
            await ref.read(propertiesProvider.future);
          } catch (_) {
            // el estado de error lo pinta la UI
          }
        },
        child: props.when(
          loading: () => ListView(
            padding: EdgeInsets.all(t.space.md),
            children: const [
              SCard(child: SSkeleton(height: 220)),
              SizedBox(height: 16),
              SCard(child: SSkeleton(height: 220)),
            ],
          ),
          error: (_, __) => ListView(
            padding: EdgeInsets.all(t.space.md),
            children: [
              SErrorState(
                title: 'No pudimos cargar tus propiedades',
                onRetry: () => ref.invalidate(propertiesProvider),
              ),
            ],
          ),
          data: (data) {
            final filtradas = _filtrar(_propiedades(data));
            return ContentFrame(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  t.space.md,
                  0,
                  t.space.md,
                  t.space.xl,
                ),
                children: [
                  _filtros(data),
                  SizedBox(height: t.space.md),
                  SSearchField(
                    controller: _busquedaCtrl,
                    hintText: 'Buscar propiedad…',
                    onChanged: (v) => setState(() => _busqueda = v),
                    onCleared: () => setState(() => _busqueda = ''),
                  ),
                  SizedBox(height: t.space.md),
                  if (filtradas.isEmpty)
                    _vacio()
                  else
                    ResponsiveCardGrid(
                      children: [
                        for (final it in filtradas)
                          PropertyCardWidget(
                            item: it,
                            onTap: () => context.push('/propiedad/${it.id}'),
                          ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// El vacío por búsqueda se arregla borrando texto; el de filtro, no.
  Widget _vacio() {
    if (_busqueda.trim().isNotEmpty) {
      return const SEmptyState.card(
        icon: Icons.search_off_outlined,
        title: 'Sin resultados',
      );
    }
    return SEmptyState.card(
      icon: Icons.apartment_outlined,
      title: switch (_filtro) {
        PropiedadesFiltro.todas => 'Aún no tienes propiedades.',
        PropiedadesFiltro.adquisicion =>
          'No tienes propiedades en proceso de compra.',
        PropiedadesFiltro.entregadas => 'Aún no tienes propiedades entregadas.',
      },
    );
  }
}
