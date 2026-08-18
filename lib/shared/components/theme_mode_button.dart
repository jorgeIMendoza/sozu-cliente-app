import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/shared/providers/theme_provider.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Selector de tema: Claro · Oscuro · Sistema.
///
/// La preferencia ya existía y se persistía en [ThemeController], pero no había
/// ningún control para cambiarla: el usuario quedaba a merced del ajuste del
/// sistema operativo.
///
/// **Sistema** es una opción de primera clase, no un extra: es el valor por
/// defecto y hay gente que tiene el móvil en oscuro automático por horario. Se
/// muestra qué modo está activo Y, cuando es `system`, qué resolvió - sin eso
/// "Sistema" no dice nada al mirar la pantalla.
class ThemeModeButton extends ConsumerWidget {
  /// `true` lo pinta como fila con etiqueta (para listas de ajustes).
  /// `false` (por defecto) lo pinta como icono compacto (para encabezados).
  final bool expanded;

  const ThemeModeButton({super.key, this.expanded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(themeProvider);
    final t = context.s;
    final modo = controller.mode;

    final button = PopupMenuButton<ThemeMode>(
      initialValue: modo,
      tooltip: 'Tema: ${_labelOf(modo)}',
      position: PopupMenuPosition.under,
      color: t.color.surface,
      // Sin esto, el fondo y el ripple del primer y ultimo item se pintan por
      // encima de las esquinas del `shape` y se ven cuadrados.
      clipBehavior: Clip.antiAlias,
      // Trampa: el menu trae 8 px de padding vertical por defecto
      // (`defaults.menuPadding`), asi que el highlight del primer y ultimo item
      // nunca llega al borde redondeado y se ve un hueco cuadrado arriba/abajo.
      menuPadding: EdgeInsets.zero,
      // El `child` va dentro de un `InkWell` que, sin esto, pinta el hover
      // cuadrado por detras del control redondeado.
      borderRadius: t.radius.mdBorder,
      shape: RoundedRectangleBorder(
        borderRadius: t.radius.lgBorder,
        side: BorderSide(color: t.color.border),
      ),
      onSelected: controller.setMode,
      // Ancho estable: sin esto el menu medía lo que midiera la opcion activa
      // (la unica que llevaba palomita), asi que cambiaba de tamaño al elegir.
      constraints: const BoxConstraints(minWidth: _menuMinWidth),
      itemBuilder: (context) => [
        for (final m in ThemeMode.values)
          PopupMenuItem<ThemeMode>(
            value: m,
            child: Row(
              children: [
                Icon(
                  _iconOf(m),
                  size: 18,
                  color: m == modo ? t.color.primaryHover : t.color.fgMuted,
                ),
                SizedBox(width: t.space.sm),
                Expanded(
                  child: Text(
                    _labelOf(m),
                    style: t.text.body.copyWith(
                      color: m == modo ? t.color.primaryHover : t.color.fg,
                      fontWeight: m == modo ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                // Aire antes de la palomita: pegada al texto se leia como parte
                // de la palabra.
                SizedBox(width: t.space.sm),
                // El hueco se reserva SIEMPRE, marcada o no: es lo que hace que
                // las tres opciones midan igual y el menu no salte.
                SizedBox(
                  width: _checkSize,
                  child: m == modo
                      ? Icon(
                          Icons.check,
                          size: _checkSize,
                          color: t.color.primaryHover,
                        )
                      : null,
                ),
              ],
            ),
          ),
      ],
      child: expanded ? _ExpandedRow(modo: modo) : _CompactIcon(modo: modo),
    );

    return button;
  }

  static String _labelOf(ThemeMode m) => switch (m) {
    ThemeMode.light => 'Claro',
    ThemeMode.dark => 'Oscuro',
    ThemeMode.system => 'Sistema',
  };

  static IconData _iconOf(ThemeMode m) => switch (m) {
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
    ThemeMode.system => Icons.brightness_auto_outlined,
  };
}

/// Lado del icono compacto. Los controles del encabezado de admin se alinean a
/// este valor (`kAdminHeaderControlHeight`) para que los hovers midan igual.
const double _compactSize = 36;

/// Lado de la palomita de "opcion activa". Se reserva en las tres opciones.
const double _checkSize = 16;

/// Ancho minimo del menu desplegable, para que no dependa de la etiqueta mas
/// larga ni de cual este activa.
const double _menuMinWidth = 180;

class _CompactIcon extends StatelessWidget {
  final ThemeMode modo;

  const _CompactIcon({required this.modo});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Container(
      width: _compactSize,
      height: _compactSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.color.surfaceAlt,
        borderRadius: t.radius.mdBorder,
        border: Border.all(color: t.color.border),
      ),
      child: Icon(
        ThemeModeButton._iconOf(modo),
        size: 18,
        color: t.color.fgMuted,
      ),
    );
  }
}

class _ExpandedRow extends StatelessWidget {
  final ThemeMode modo;

  const _ExpandedRow({required this.modo});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    // Con "Sistema" activo se aclara qué resolvió: si no, la etiqueta no dice
    // nada sobre lo que el usuario está viendo.
    final resolved = Theme.of(context).brightness == Brightness.dark
        ? 'oscuro'
        : 'claro';
    final detail = modo == ThemeMode.system
        ? '${ThemeModeButton._labelOf(modo)} · $resolved'
        : ThemeModeButton._labelOf(modo);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.sm,
        vertical: t.space.xs,
      ),
      child: Row(
        children: [
          Icon(ThemeModeButton._iconOf(modo), size: 18, color: t.color.fgMuted),
          SizedBox(width: t.space.xs),
          Text(detail, style: t.text.label.copyWith(color: t.color.fg)),
          SizedBox(width: t.space.xxs),
          Icon(Icons.expand_more, size: 16, color: t.color.fgSubtle),
        ],
      ),
    );
  }
}
