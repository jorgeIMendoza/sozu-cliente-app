import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Campo de búsqueda con lupa y botón de limpiar.
///
/// El botón de limpiar aparece solo cuando hay texto y se resuelve solo: escucha
/// al `controller` con un `ValueListenableBuilder`, sin pedirle a la pantalla un
/// `setState` por tecla.
class SSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  /// Se llama al presionar la X, después de vaciar el controller.
  final VoidCallback? onCleared;

  final bool autofocus;

  const SSearchField({
    super.key,
    required this.controller,
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
        return TextField(
          controller: controller,
          autofocus: autofocus,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: t.text.body.copyWith(color: t.color.fg),
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText,
            prefixIcon: Icon(Icons.search, size: 20, color: t.color.fgSubtle),
            suffixIcon: value.text.isEmpty
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
          ),
        );
      },
    );
  }
}
