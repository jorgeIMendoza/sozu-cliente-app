import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../providers/data_providers.dart';

/// Encabezado de sección: título + campana con punto de no leídas.
class PortalTopBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;

  const PortalTopBar({super.key, required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = SozuTone.of(context);
    final notif = ref.watch(clienteNotificacionesProvider);
    final hasUnread = notif.valueOrNull != null && notif.value!.noLeidas > 0;

    return AppBar(
      title: Text(title),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: Icon(Icons.notifications_outlined, color: tone.textSecondary),
              onPressed: () => context.push('/notificaciones'),
            ),
            if (hasUnread)
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: tone.negative,
                    shape: BoxShape.circle,
                    border: Border.all(color: tone.surface, width: 1),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
