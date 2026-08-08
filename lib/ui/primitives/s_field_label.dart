import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Etiqueta de un campo de formulario, con su marca de requerido.
///
/// Va ARRIBA del control y no flotando dentro, para que el alto del campo no
/// cambie entre vacío y enfocado. Usa `caption`: en un formulario denso una
/// etiqueta del tamaño del contenido compite con él.
///
/// `STextField` pinta su propia etiqueta con `text.label` (16). En formularios
/// densos (hojas de carga, revisión de documentos) se le pasa `label: null` y
/// se usa esta.
class SFieldLabel extends StatelessWidget {
  final String texto;

  /// Agrega el asterisco.
  final bool requerido;

  /// Etiqueta de un control deshabilitado: se apaga.
  final bool habilitado;

  const SFieldLabel(
    this.texto, {
    super.key,
    this.requerido = false,
    this.habilitado = true,
  });

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return Padding(
      padding: EdgeInsets.only(bottom: context.s.space.xxs),
      child: Text(
        requerido ? '$texto *' : texto,
        style: context.s.text.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: habilitado ? tone.fg : tone.fgSubtle,
        ),
      ),
    );
  }
}
