import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/features/admin/components/admin_header_bar.dart';
import 'package:sozu_cliente_app/features/admin/components/announcement_form.dart';
import 'package:sozu_cliente_app/features/admin/components/bell_animation_settings.dart';
import 'package:sozu_cliente_app/features/admin/components/recent_announcements.dart';
import 'package:sozu_cliente_app/features/admin/layouts/admin_layout.dart';
import 'package:sozu_cliente_app/features/admin/providers/admin_providers.dart';
import 'package:sozu_cliente_app/shared/components/theme_mode_button.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Envío de avisos a clientes del app (solo super admin). Espejo ligero de
/// "Administrar avisos" de sozu-admin, sobre la edge function
/// `admin-avisos-app`.
class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.s;

    return AdminLayout(
      onRefresh: () async {
        ref.invalidate(adminAnnouncementsProvider);
        await ref.read(adminAnnouncementsProvider.future);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminHeaderBar(
            title: 'Enviar avisos',
            subtitle: 'A clientes del app · push, correo y WhatsApp',
            actions: [
              const ThemeModeButton(),
              SizedBox(width: t.space.xxs),
              AdminHeaderAction(
                label: 'Volver',
                icon: Icons.arrow_back,
                onPressed: () => context.pop(),
              ),
            ],
          ),
          SizedBox(height: t.space.sm),
          STabs(
            tabs: const ['Nuevo aviso', 'Configuración'],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          SizedBox(height: t.space.md),
          if (_tab == 0) const _NuevoAviso() else const BellAnimationSettings(),
        ],
      ),
    );
  }
}

/// Formulario y avisos recientes: lado a lado en escritorio, apilados en
/// teléfono.
class _NuevoAviso extends StatelessWidget {
  const _NuevoAviso();

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    if (!context.bp.isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AnnouncementForm(),
          SizedBox(height: t.space.lg),
          const RecentAnnouncements(),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 3:2 y no mitades: con menos ancho los campos del formulario, que van
        // en dos columnas, vuelven a apilarse.
        const Expanded(flex: 3, child: AnnouncementForm()),
        SizedBox(width: t.space.lg),
        const Expanded(flex: 2, child: RecentAnnouncements()),
      ],
    );
  }
}
