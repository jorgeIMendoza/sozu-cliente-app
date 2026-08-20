import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/ui.dart';

/// Lado del icono al final de los campos que abren un selector. Igual que el
/// del prefijo de `STextField`.
const double _kSelectorIconSize = 20;

/// Señal del selector de UNA opción: aquí el menú sí se despliega bajo el campo.
const IconData _kSingleSelectIcon = Icons.expand_more;

String capitalizarOpcion(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Campo de una sola opción con la etiqueta ARRIBA: se ve igual que los demás
/// campos del formulario y al tocarlo despliega el menú bajo el campo.
///
/// `DropdownButtonFormField` no sirve: su etiqueta va dentro de su propio
/// `InputDecoration`, así que solo puede ser flotante.
class CatalogSelectField extends StatefulWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const CatalogSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  State<CatalogSelectField> createState() => _CatalogSelectFieldState();
}

class _CatalogSelectFieldState extends State<CatalogSelectField> {
  /// [STextField] es un campo de texto real, así que el valor visible vive en un
  /// controller.
  late final TextEditingController _controller = TextEditingController(
    text: capitalizarOpcion(widget.value),
  );

  /// TRAMPA: el texto se sincroniza DESPUÉS del frame. Escribir en el controller
  /// dentro de `didUpdateWidget` notifica a sus listeners en plena fase de build
  /// y el `Form` de arriba muere con "setState() called during build".
  @override
  void didUpdateWidget(covariant CatalogSelectField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text == capitalizarOpcion(widget.value)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final visible = capitalizarOpcion(widget.value);
      if (_controller.text != visible) _controller.text = visible;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    // Dos trampas del PopupMenuButton de Material: sin `clipBehavior` y sin
    // `menuPadding` los items se pintan cuadrados sobre las esquinas del
    // `shape`.
    return LayoutBuilder(
      builder: (context, constraints) => PopupMenuButton<String>(
        initialValue: widget.value,
        tooltip: 'Elegir ${widget.label.toLowerCase()}',
        position: PopupMenuPosition.under,
        color: tone.surface,
        clipBehavior: Clip.antiAlias,
        menuPadding: EdgeInsets.zero,
        borderRadius: t.radius.mdBorder,
        shape: RoundedRectangleBorder(
          borderRadius: t.radius.mdBorder,
          side: BorderSide(color: tone.border),
        ),
        // El menú mide lo mismo que el campo, como el de `SAutocompleteField`.
        constraints: constraints.hasBoundedWidth
            ? BoxConstraints(minWidth: constraints.maxWidth)
            : null,
        onSelected: widget.onChanged,
        itemBuilder: (context) => [
          for (final o in widget.options)
            PopupMenuItem<String>(
              value: o,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      capitalizarOpcion(o),
                      style: t.text.body.copyWith(
                        color: o == widget.value ? tone.primaryHover : tone.fg,
                        fontWeight: o == widget.value
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (o == widget.value)
                    Icon(
                      Icons.check,
                      size: _kSelectorIconSize,
                      color: tone.primaryHover,
                    ),
                ],
              ),
            ),
        ],
        // El campo NO debe recibir el toque: si lo recibe se enfoca y el menú no
        // abre. El gesto y el foco de teclado los da el `PopupMenuButton`.
        child: IgnorePointer(
          child: STextField(
            controller: _controller,
            label: widget.label,
            readOnly: true,
            size: STextFieldSize.md,
            suffix: Icon(
              _kSingleSelectIcon,
              size: _kSelectorIconSize,
              color: tone.fgSubtle,
            ),
          ),
        ),
      ),
    );
  }
}

/// Selector múltiple con buscador en tiempo real: campo de solo lectura con la
/// etiqueta ARRIBA que resume la selección y abre un diálogo con búsqueda +
/// casillas.
