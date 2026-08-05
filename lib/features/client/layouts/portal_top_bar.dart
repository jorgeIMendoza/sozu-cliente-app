import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/features/app_download/components/app_download.dart';
import 'package:sozu_cliente_app/features/client/home/components/notification_bell.dart';
// Botón "Referir" oculto por ahora (a petición); restaurar junto con su uso.
// import 'package:sozu_cliente_app/features/client/referral/components/referral_action.dart';

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
    return AppBar(
      title: Text(title),
      // Botón "Referir" oculto por ahora (a petición). Restaurar:
      //   Padding(padding: EdgeInsets.symmetric(vertical: 8),
      //           child: ReferralButton()),
      //   SizedBox(width: 4),
      actions: [
        // "Descargar app" solo en web (móvil): lleva a la tienda por SO.
        if (kIsWeb)
          IconButton(
            tooltip: 'Descargar app',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => openAppStore(context),
          ),
        const NotificationBell(),
      ],
    );
  }
}
