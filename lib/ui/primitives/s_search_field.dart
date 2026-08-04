import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/primitives/s_text_field.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Campo de búsqueda con lupa y botón de limpiar.
///
/// El botón de limpiar aparece solo cuando hay texto y se resuelve solo: escucha
/// al `controller` con un `ValueListenableBuilder`, sin pedirle a la pantalla un
/// `setState` por tecla.
class SSearchField extends StatelessWidget {
  final TextEditingController controller;

  /// Etiqueta arriba del campo. Sin ella el buscador queda sin titulo al lado de
  /// campos que si lo tienen.
  final String? label;

  final String hintText;
  final ValueChanged<String>? onChanged;

  /// Se llama al presionar la X, después de vaciar el controller.
  final VoidCallback? onCleared;

  final bool autofocus;

  const SSearchField({
    super.key,
    required this.controller,
    this.label,
    this.hintText = 'Buscar…',
    this.onChanged,
    this.onCleared,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        // `STextField` y no un `TextField` con `InputDecoration`: comparte borde,
        // anillo de foco y alto con el resto de los campos.
        return STextField(
          controller: controller,
          autofocus: autofocus,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          label: label,
          hint: hintText,
          prefixIcon: Icons.search,
          size: STextFieldSize.md,
          suffix: value.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  color: t.color.fgSubtle,
                  tooltip: 'Limpiar',
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
                    onCleared?.call();
                  },
                ),
        );
      },
    );
  }
}
