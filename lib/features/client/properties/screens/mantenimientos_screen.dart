import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/core/format.dart';
import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/layouts/portal_top_bar.dart';
import 'package:sozu_cliente_app/features/client/properties/providers/properties_providers.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:sozu_cliente_app/widgets/fx.dart';
import 'package:sozu_cliente_app/widgets/portal_widgets.dart';

/// Mantenimientos por unidad: saldo pendiente y próximo cargo. El dato ya
/// venía en `cliente-propiedades`, enterrado al final de "En adquisición".
class MantenimientosScreen extends ConsumerWidget {
  const MantenimientosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.s;
    final props = ref.watch(propertiesProvider);

    Widget contenido(ClientePropiedades data) {
      if (data.mantenimiento.isEmpty) {
        return const SEmptyState.card(
          icon: Icons.build_outlined,
          title: 'No tienes cuentas de mantenimiento.',
          message:
              'Aparecen cuando una de tus unidades se entrega y empieza a '
              'generar cuota.',
        );
      }
      final pendientes = data.mantenimiento
          .where((m) => m.saldoPendiente > 0)
          .fold<double>(0, (a, m) => a + m.saldoPendiente);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pendientes > 0) ...[
            SCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SALDO DE MANTENIMIENTO',
                    style: t.text.overline.copyWith(color: t.color.fgSubtle),
                  ),
                  SizedBox(height: t.space.xxs),
                  Text(
                    formatMXN(pendientes),
                    style: t.text.h2.copyWith(
                      fontWeight: FontWeight.w700,
                      color: t.color.warningFg,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: t.space.md),
          ],
          for (final m in data.mantenimiento) ...[
            _MantenimientoRow(m: m),
            SizedBox(height: t.space.sm),
          ],
        ],
      );
    }

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
                  title: 'Mantenimientos',
                  subtitle: 'Cuotas y saldos por unidad',
                ),
                SizedBox(height: 20),
                SCard(child: SSkeleton(height: 72)),
              ],
            ),
          ),
          error: (_, __) => ListView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            children: [
              SErrorState(
                title: 'No pudimos cargar tus mantenimientos',
                onRetry: () => ref.invalidate(propertiesProvider),
              ),
            ],
          ),
          data: (data) => SingleChildScrollView(
            padding: const EdgeInsets.only(top: 24, bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PortalPageHeader(
                  title: 'Mantenimientos',
                  subtitle: 'Cuotas y saldos por unidad',
                ),
                SizedBox(height: t.space.lg),
                contenido(data),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const PortalTopBar(title: 'Mantenimientos'),
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
            children: const [SCard(child: SSkeleton(height: 72))],
          ),
          error: (_, __) => ListView(
            padding: EdgeInsets.all(t.space.md),
            children: [
              SErrorState(
                title: 'No pudimos cargar tus mantenimientos',
                onRetry: () => ref.invalidate(propertiesProvider),
              ),
            ],
          ),
          data: (data) => ContentFrame(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                t.space.md,
                0,
                t.space.md,
                t.space.xl,
              ),
              children: [contenido(data)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de una cuenta de mantenimiento: propiedad, próximo cargo y saldo.
class _MantenimientoRow extends StatelessWidget {
  final MantenimientoCard m;

  const _MantenimientoRow({required this.m});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final alDia = m.saldoPendiente <= 0;
    return SCard(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: alDia ? tone.primarySoft : tone.warningSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.build_outlined,
              size: 18,
              color: alDia ? tone.primaryHover : tone.warningFg,
            ),
          ),
          SizedBox(width: t.space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.propiedad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.text.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tone.fg,
                  ),
                ),
                Text(
                  alDia ? 'Al día' : 'Próximo: ${formatDate(m.proximoPago)}',
                  style: t.text.caption.copyWith(color: tone.fgMuted),
                ),
              ],
            ),
          ),
          if (alDia)
            const SBadge(label: 'Al día', tone: SBadgeTone.positive)
          else
            Text(
              formatMXN(m.saldoPendiente),
              style: t.text.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: tone.warningFg,
              ),
            ),
        ],
      ),
    );
  }
}
