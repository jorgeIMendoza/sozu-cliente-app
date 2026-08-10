import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/shared/providers/theme_provider.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Selector de tema: Claro · Oscuro · Auto (sigue al sistema).
///
/// "Auto" es el valor por defecto y una opción de primera clase: hay gente con
/// el móvil en oscuro por horario.
///
/// Solo manda dentro del portal: el área de acceso va con candado a claro
/// (`AuthAreaLightLock` en main.dart).
class ThemeSelector extends ConsumerWidget {
  const ThemeSelector({super.key});

  static const _opciones = <(ThemeMode, String, IconData)>[
    (ThemeMode.light, 'Claro', Icons.wb_sunny_outlined),
    (ThemeMode.dark, 'Oscuro', Icons.nightlight_outlined),
    (ThemeMode.system, 'Auto', Icons.smartphone_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final t = context.s;

    return Row(
      children: [
        for (final (mode, label, icon) in _opciones) ...[
          if (mode != _opciones.first.$1) SizedBox(width: t.space.xs),
          Expanded(
            child: _Opcion(
              label: label,
              icon: icon,
              seleccionado: theme.mode == mode,
              onTap: () => theme.setMode(mode),
            ),
          ),
        ],
      ],
    );
  }
}

class _Opcion extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool seleccionado;
  final VoidCallback onTap;

  const _Opcion({
    required this.label,
    required this.icon,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    return SPressable(
      onTap: onTap,
      semanticLabel: 'Tema $label',
      borderRadius: t.radius.lgBorder,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: t.space.sm),
        decoration: BoxDecoration(
          color: seleccionado ? tone.primarySoft : tone.surfaceAlt,
          borderRadius: t.radius.lgBorder,
          border: Border.all(color: seleccionado ? tone.primary : tone.border),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: seleccionado ? tone.primary : tone.fgSubtle,
            ),
            SizedBox(height: t.space.xxs),
            Text(
              label,
              style: t.text.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: seleccionado ? tone.primaryHover : tone.fgMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
