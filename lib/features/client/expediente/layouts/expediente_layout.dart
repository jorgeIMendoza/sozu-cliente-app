import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Envoltorio de la pantalla del expediente: ancho máximo, scroll, el enlace
/// de volver y la tarjeta con su encabezado.
///
/// `isPortalMode` a propósito aunque esté deprecado: decide si el shell del
/// portal ya pinta el fondo, y ese shell solo existe en WEB de escritorio. Con
/// `context.bp` una tablet nativa ancha se creería portal y quedaría sin fondo.
class ExpedienteLayout extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final VoidCallback onVolver;

  /// Accion principal de la pantalla, a la DERECHA del "Volver". Ahi se ve sin
  /// escanear la pagina; hundida entre las tarjetas hay que buscarla.
  final Widget? accion;
  final Widget child;

  const ExpedienteLayout({
    super.key,
    required this.titulo,
    required this.descripcion,
    required this.onVolver,
    this.accion,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final portal = isPortalMode(context);

    return Scaffold(
      backgroundColor: portal ? Colors.transparent : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: portal
                  ? EdgeInsets.only(
                      top: context.s.space.lg,
                      bottom: context.s.space.xl,
                    )
                  : EdgeInsets.fromLTRB(
                      context.s.space.md,
                      context.s.space.sm,
                      context.s.space.md,
                      context.s.space.xl,
                    ),
              children: [
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onVolver,
                      style: TextButton.styleFrom(
                        foregroundColor: tone.fgMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        textStyle: context.s.text.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back, size: 15),
                      label: const Text('Volver al Perfil'),
                    ),
                    const Spacer(),
                    if (accion != null) accion!,
                  ],
                ),
                SizedBox(height: context.s.space.xs),
                SCard(
                  padding: EdgeInsets.all(context.s.space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: context.s.text.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tone.fg,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        descripcion,
                        style: context.s.text.bodySmall.copyWith(
                          color: tone.fgMuted,
                        ),
                      ),
                      SizedBox(height: context.s.space.md),
                      child,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
