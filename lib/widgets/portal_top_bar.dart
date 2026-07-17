import 'package:flutter/material.dart';

import '../core/portal_theme.dart';
import 'notification_bell.dart';

/// Encabezado de sección: título + campana con contador de no leídas.
class PortalTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const PortalTopBar({super.key, required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // En modo portal (web ≥1024px) el shell ya pinta el título de la sección
    // y la campana en su topbar: este AppBar se colapsa para no duplicarse
    // (Scaffold usa la altura real del appBar, no preferredSize).
    if (isPortalMode(context)) return const SizedBox.shrink();
    return AppBar(title: Text(title), actions: const [NotificationBell()]);
  }
}
