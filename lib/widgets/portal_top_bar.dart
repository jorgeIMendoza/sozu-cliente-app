import 'package:flutter/material.dart';

import 'notification_bell.dart';

/// Encabezado de sección: título + campana con contador de no leídas.
class PortalTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const PortalTopBar({super.key, required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: const [NotificationBell()],
    );
  }
}
