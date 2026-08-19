import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/features/client/home/components/notificaciones_fx.dart';
import 'package:sozu_cliente_app/features/client/layouts/client_shell.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Barra inferior flotante del cliente (móvil): tarjeta redondeada con sombra
/// suave, respetando SafeArea. Muestra los primeros ítems del menú y agrupa el
/// resto tras el botón "Más" (…). El ítem activo se resuelve por la ruta actual
/// (un detalle como `/productos/:id` resalta su tab padre). Los tabs cambian de
/// sección con `context.go` (preservan el estado del IndexedStack); las
/// secundarias del menú "Más" se abren con `context.push` para que quede stack
/// y aparezca la flecha de regresar.
class ClientBottomNav extends ConsumerWidget {
  final String currentPath;

  const ClientBottomNav({required this.currentPath});

  /// Rutas que corresponden a ramas del StatefulShellRoute: siempre se navegan
  /// con `context.go` (nunca push) para conservar el estado de la rama.
  static const _branchRoutes = {
    '/inicio',
    '/propiedades',
    '/facturas',
    '/perfil',
  };

  /// Activo por prefijo de ruta; "Inicio" solo con match exacto.
  bool _isActive(String route, String path) {
    if (route == '/inicio') return path == '/inicio';
    return path == route || path.startsWith('$route/');
  }

  String _shortLabel(String label) =>
      label == 'Mantenimientos' ? 'Manto.' : label;

  void _navigateTo(BuildContext context, String route, {required bool push}) {
    if (_branchRoutes.contains(route)) {
      context.go(route); // preserva el estado de la rama
    } else if (push) {
      context.push(route); // stack → flecha de regresar
    } else {
      context.go(route);
    }
  }

  void _mostrarMasMenu(
    BuildContext context,
    List<({IconData icon, String label, String route})> items,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final it in items)
              ListTile(
                leading: Icon(it.icon),
                title: Text(it.label),
                selected: _isActive(it.route, currentPath),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  // Secundarias con push (stack); ramas con go.
                  _navigateTo(context, it.route, push: true);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = context.s.color;
    // Menú completo del portal (misma resolución/orden/permisos que el sidebar,
    // vía cliente-menu con degradación). Los primeros ítems como tabs; el resto
    // tras "Más" (…) para que TODOS sean alcanzables aunque no quepan.
    final menu = clienteMenuTabs();
    const maxTabs = 4; // 4 tabs + "Más" cuando hay más de 5 ítems
    final hasOverflow = menu.length > 5;
    final tabs = hasOverflow ? menu.take(maxTabs).toList() : menu;
    final overflow = hasOverflow
        ? menu.skip(maxTabs).toList()
        : <({IconData icon, String label, String route})>[];

    final selected = tabs.indexWhere((t) => _isActive(t.route, currentPath));
    // "Más" resaltado cuando la pantalla actual no es ninguno de los tabs
    // visibles (estás en una secundaria o en un ítem del overflow).
    final masActive = hasOverflow && selected < 0;
    // Destino de la animación de llegada (NotificacionesFx) cuando no hay
    // campana visible: el ítem "Notificaciones" si es una pestaña visible, o
    // el botón "Más" (…) si vive dentro del overflow.
    final notifTabIdx = tabs.indexWhere((t) => t.route == '/notificaciones');
    final notifEnMas =
        notifTabIdx < 0 && overflow.any((t) => t.route == '/notificaciones');

    return Container(
      color: tone.background,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Container(
            decoration: BoxDecoration(
              color: tone.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: tone.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    _NavBarItem(
                      key: i == notifTabIdx ? notifNavKey : null,
                      icon: tabs[i].icon,
                      label: _shortLabel(tabs[i].label),
                      active: i == selected,
                      onTap: () =>
                          _navigateTo(context, tabs[i].route, push: false),
                    ),
                  if (hasOverflow)
                    _NavBarItem(
                      key: notifEnMas ? notifNavKey : null,
                      icon: Icons.more_horiz,
                      label: 'Más',
                      active: masActive,
                      onTap: () => _mostrarMasMenu(context, overflow),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ítem de la barra inferior flotante: icono + etiqueta, resaltado en verde
/// cuando está activo.
class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavBarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final color = active ? tone.primary : tone.fgSubtle;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Franja de impersonación: "Super admin {admin} · Viendo como: {cliente}"
/// + cambiar / salir.
