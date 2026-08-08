import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/primitives/s_field_label.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Opción de un [SSelectField]: el valor que sale y lo que se lee.
typedef SSelectOption<T> = ({T value, String label});

/// Selección de un catálogo cerrado, con la misma piel que [STextField].
///
/// Existe porque un `DropdownButtonFormField` pelón trae el borde, el relleno
/// y el error de Material, que no son los del sistema: al lado de un
/// `STextField` se notan dos formularios distintos en la misma hoja.
///
/// Para elegir entre valores abiertos o largos va `SAutocompleteField`; esto es
/// para listas cortas (tipo de documento, sexo, régimen).
class SSelectField<T> extends StatelessWidget {
  final List<SSelectOption<T>> opciones;
  final T? value;
  final ValueChanged<T?>? onChanged;

  /// Etiqueta arriba del control; null la omite.
  final String? label;
  final bool requerido;

  /// Texto cuando no hay nada elegido.
  final String hint;

  /// Mensaje de error bajo el control; null lo oculta.
  final String? errorText;

  const SSelectField({
    super.key,
    required this.opciones,
    required this.value,
    required this.onChanged,
    this.label,
    this.requerido = false,
    this.hint = 'Elige una opción',
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final habilitado = onChanged != null;
    // Un valor que no está en la lista no se pinta: dejarlo revienta el
    // Dropdown con "no items with that value".
    final valor = opciones.any((o) => o.value == value) ? value : null;
    final hayError = errorText != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          SFieldLabel(label!, requerido: requerido, habilitado: habilitado),
        // El borde y el relleno los pinta este contenedor, NO el Dropdown:
        // así queda la misma piel que STextField (44 px, borde de 1 px).
        Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: EdgeInsets.symmetric(horizontal: t.space.sm),
          decoration: BoxDecoration(
            color: habilitado ? tone.surface : tone.muted,
            borderRadius: t.radius.mdBorder,
            border: Border.all(color: hayError ? tone.danger : tone.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: valor,
              isExpanded: true,
              borderRadius: t.radius.mdBorder,
              dropdownColor: tone.surface,
              icon: Icon(
                Icons.expand_more,
                size: 20,
                color: habilitado ? tone.fgMuted : tone.fgSubtle,
              ),
              style: t.text.bodySmall.copyWith(color: tone.fg),
              hint: Text(
                hint,
                style: t.text.bodySmall.copyWith(color: tone.fgSubtle),
              ),
              items: [
                for (final o in opciones)
                  DropdownMenuItem<T>(value: o.value, child: Text(o.label)),
              ],
              onChanged: onChanged,
              menuMaxHeight: 320,
            ),
          ),
        ),
        if (hayError)
          Padding(
            padding: EdgeInsets.only(top: t.space.xxs),
            child: Text(
              errorText!,
              style: t.text.caption.copyWith(color: tone.danger),
            ),
          ),
      ],
    );
  }
}
