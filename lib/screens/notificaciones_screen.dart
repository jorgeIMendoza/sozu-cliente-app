import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/api_client.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../widgets/common.dart';

/// Notificaciones del cliente: lista, marcar leída, marcar todas.
class NotificacionesScreen extends ConsumerWidget {
  const NotificacionesScreen({super.key});

  Future<void> _marcar(WidgetRef ref, {String? action, int? id}) async {
    try {
      await fetchClienteNotificaciones(action: action, id: id);
    } catch (_) {}
    ref.invalidate(clienteNotificacionesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = SozuTone.of(context);
    final notif = ref.watch(clienteNotificacionesProvider);
    final noLeidas = notif.valueOrNull?.noLeidas ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (noLeidas > 0)
            TextButton(
              onPressed: () => _marcar(ref, action: 'marcar_todas'),
              child: Text('Marcar todas',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: tone.primaryDark)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(clienteNotificacionesProvider);
          try {
            await ref.read(clienteNotificacionesProvider.future);
          } catch (_) {}
        },
        child: notif.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 18),
                    SizedBox(height: 8),
                    Skeleton(width: 200, height: 14),
                  ],
                ),
              ),
            ],
          ),
          error: (_, __) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ErrorCard(
                title: 'No pudimos cargar tus notificaciones',
                onRetry: () => ref.invalidate(clienteNotificacionesProvider),
              ),
            ],
          ),
          data: (data) {
            if (data.notificaciones.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 60),
                  Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                            color: tone.primarySoft, shape: BoxShape.circle),
                        child: const Icon(Icons.notifications_off_outlined,
                            size: 30, color: SozuColors.emerald600),
                      ),
                      const SizedBox(height: 16),
                      Text('Sin notificaciones',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: tone.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Aquí verás tus avisos SOZU.',
                          style: TextStyle(
                              fontSize: 14, color: tone.textSecondary)),
                    ],
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                for (final n in data.notificaciones) ...[
                  _NotifRow(
                    n: n,
                    onTap: n.leida
                        ? null
                        : () => _marcar(ref, action: 'marcar_leida', id: n.id),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  final Notificacion n;
  final VoidCallback? onTap;

  const _NotifRow({required this.n, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final (color, icon) = switch (n.tipo) {
      'urgente' => (tone.negative, Icons.error_outline),
      'accionable' => (SozuColors.amber600, Icons.flash_on_outlined),
      'exito' => (SozuColors.emerald600, Icons.check_circle_outline),
      _ => (SozuColors.emerald600, Icons.info_outline),
    };
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: n.leida ? 0.7 : 1,
        child: AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(n.titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: tone.textPrimary)),
                        ),
                        if (!n.leida)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: SozuColors.emerald500,
                                shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(n.descripcion,
                        style: TextStyle(
                            fontSize: 12, color: tone.textSecondary)),
                    const SizedBox(height: 4),
                    Text(formatDate(n.fecha),
                        style:
                            TextStyle(fontSize: 11, color: tone.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
