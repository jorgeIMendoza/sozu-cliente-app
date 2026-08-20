import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/features/admin/components/admin_header_bar.dart';
import 'package:sozu_cliente_app/features/admin/components/client_selector.dart';
import 'package:sozu_cliente_app/features/admin/layouts/admin_layout.dart';
import 'package:sozu_cliente_app/features/admin/providers/client_filters_provider.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/shared/components/theme_mode_button.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Selector de cliente para administradores: elige uno y navega el portal
/// viendo sus datos. Sirve en web y en móvil.
///
/// Con Proyecto + Unidad se listan solo los dueños de esa unidad; sin filtro se
/// busca por nombre o correo. Los filtros viven en `clientFiltersProvider`.
class SelectClientScreen extends ConsumerWidget {
  const SelectClientScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.s;
    final auth = ref.watch(authProvider);

    return AdminLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminHeaderBar(
            title: 'Selecciona un cliente',
            subtitle:
                'Acceso administrador · '
                '${auth.profile?.displayName ?? auth.profile?.email ?? ''}',
            actions: [
              const ThemeModeButton(),
              SizedBox(width: t.space.xxs),
              AdminHeaderAction(
                label: 'Enviar avisos',
                icon: Icons.campaign_outlined,
                onPressed: () => context.push('/admin-avisos'),
              ),
              AdminHeaderAction(
                label: 'Cerrar sesión',
                isDanger: true,
                onPressed: () {
                  // Los filtros son contexto de trabajo de ESTA sesión: si no
                  // se limpian, el siguiente admin que entre en la misma
                  // máquina hereda el proyecto y la unidad del anterior. Basta
                  // con vaciar el store: los controladores de texto mueren con
                  // el componente al salir, y al volver se siembran de aquí.
                  ref.read(clientFiltersProvider).clear();
                  ref.read(authProvider).signOut();
                },
              ),
            ],
          ),
          SizedBox(height: t.space.md),
          const ClientSelector(),
        ],
      ),
    );
  }
}
