import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../providers/data_providers.dart';

/// Campana de notificaciones con contador de no leídas (badge numérico).
/// Se oculta el badge cuando no hay pendientes.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = SozuTone.of(context);
    final noLeidas =
        ref.watch(clienteNotificacionesProvider).valueOrNull?.noLeidas ?? 0;

    return IconButton(
      tooltip: 'Notificaciones',
      onPressed: () => context.push('/notificaciones'),
      icon: Badge.count(
        count: noLeidas,
        isLabelVisible: noLeidas > 0,
        backgroundColor: tone.negative,
        textColor: Colors.white,
        child: Icon(Icons.notifications_outlined, color: tone.textSecondary),
      ),
    );
  }
}
