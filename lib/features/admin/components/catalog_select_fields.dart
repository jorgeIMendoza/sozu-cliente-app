import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Lienzo del diálogo del selector múltiple. Alto fijo para que la lista
/// scrollee en vez de estirar el diálogo.
const double _kSelectorDialogWidth = 380;
const double _kSelectorDialogHeight = 420;

/// Lado del icono al final de los campos que abren un selector. Igual que el
/// del prefijo de `STextField`.
const double _kSelectorIconSize = 20;

/// Señal del selector MÚLTIPLE: abre un diálogo con buscador y casillas, no un
/// menú. Sin flecha a propósito: prometía un desplegable que el toque no abre
/// (mismo motivo por el que `SAutocompleteField` no la lleva).
const IconData _kMultiSelectIcon = Icons.checklist;

/// Señal del selector de UNA opción: aquí el menú sí se despliega bajo el campo.
const IconData _kSingleSelectIcon = Icons.expand_more;

/// Cuántos nombres se enumeran en el resumen antes de cortar con "+N".
const int _kSummaryMaxNames = 3;

/// "informativa" -> "Informativa". Los catálogos vienen en minúsculas.
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
class CatalogMultiSelectField extends StatefulWidget {
  final String label;
  final List<CatalogoItem> items;
  final Set<int> selected;
  final String placeholder;
  final String prefix;
  final bool enabled;
  final ValueChanged<Set<int>> onChanged;

  const CatalogMultiSelectField({
    super.key,
    required this.label,
    required this.items,
    required this.selected,
    required this.placeholder,
    required this.onChanged,
    this.prefix = '',
    this.enabled = true,
  });

  @override
  State<CatalogMultiSelectField> createState() =>
      _CatalogMultiSelectFieldState();
}

class _CatalogMultiSelectFieldState extends State<CatalogMultiSelectField> {
  late final TextEditingController _summaryController = TextEditingController(
    text: _summary,
  );

  /// No se compara contra `oldWidget`: la pantalla muta SIEMPRE el mismo `Set`,
  /// así que los dos widgets comparten la selección y nunca difieren.
  ///
  /// TRAMPA: la escritura va DESPUÉS del frame. Hacerla aquí notifica a los
  /// listeners del controller en plena fase de build y el `Form` de arriba muere
  /// con "setState() called during build".
  @override
  void didUpdateWidget(covariant CatalogMultiSelectField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_summaryController.text == _summary) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _summaryController.text != _summary) {
        _summaryController.text = _summary;
      }
    });
  }

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  /// Vacío sin selección: ahí lo que se ve es el `hint` del campo.
  String get _summary {
    if (widget.selected.isEmpty) return '';
    final names = widget.items
        .where((e) => widget.selected.contains(e.id))
        .map((e) => '${widget.prefix}${e.nombre}')
        .toList();
    if (names.length <= _kSummaryMaxNames) return names.join(', ');
    final shown = names.take(_kSummaryMaxNames).join(', ');
    return '$shown +${names.length - _kSummaryMaxNames}';
  }

  Future<void> _openDialog() async {
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) => _MultiSelectDialog(
        label: widget.label,
        items: widget.items,
        prefix: widget.prefix,
        initial: widget.selected,
      ),
    );
    if (result != null) widget.onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final canOpen = widget.enabled && widget.items.isNotEmpty;
    return InkWell(
      onTap: canOpen ? _openDialog : null,
      borderRadius: t.radius.mdBorder,
      // Ver la nota de `CatalogSelectField`: el campo no puede quedarse el toque.
      child: IgnorePointer(
        child: STextField(
          controller: _summaryController,
          label: widget.label,
          hint: widget.placeholder,
          enabled: widget.enabled,
          readOnly: true,
          size: STextFieldSize.md,
          suffix: Icon(
            _kMultiSelectIcon,
            size: _kSelectorIconSize,
            color: t.color.fgSubtle,
          ),
        ),
      ),
    );
  }
}

class _MultiSelectDialog extends StatefulWidget {
  final String label;
  final List<CatalogoItem> items;
  final String prefix;
  final Set<int> initial;

  const _MultiSelectDialog({
    required this.label,
    required this.items,
    required this.prefix,
    required this.initial,
  });

  @override
  State<_MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<_MultiSelectDialog> {
  late final Set<int> _selection = {...widget.initial};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final filtered = _query.trim().isEmpty
        ? widget.items
        : widget.items
              .where(
                (e) => e.nombre.toLowerCase().contains(
                  _query.trim().toLowerCase(),
                ),
              )
              .toList();
    return AlertDialog(
      title: Text(widget.label),
      contentPadding: EdgeInsets.fromLTRB(
        t.space.lg,
        t.space.sm,
        t.space.lg,
        0,
      ),
      content: SizedBox(
        width: _kSelectorDialogWidth,
        height: _kSelectorDialogHeight,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Buscar…',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            SizedBox(height: t.space.xxs),
            Row(
              children: [
                Text(
                  '${_selection.length} seleccionados',
                  style: t.text.caption.copyWith(color: tone.fgSubtle),
                ),
                const Spacer(),
                // Opera sobre los resultados visibles (respeta la búsqueda).
                SButton.ghost(
                  label:
                      filtered.isNotEmpty &&
                          filtered.every((e) => _selection.contains(e.id))
                      ? 'Deseleccionar todos'
                      : 'Seleccionar todos',
                  onPressed: filtered.isEmpty
                      ? null
                      : () => setState(() {
                          final allChecked = filtered.every(
                            (e) => _selection.contains(e.id),
                          );
                          if (allChecked) {
                            _selection.removeAll(filtered.map((e) => e.id));
                          } else {
                            _selection.addAll(filtered.map((e) => e.id));
                          }
                        }),
                ),
              ],
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Sin resultados',
                        style: t.text.body.copyWith(color: tone.fgSubtle),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final item = filtered[i];
                        return CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${widget.prefix}${item.nombre}',
                            style: t.text.body,
                          ),
                          value: _selection.contains(item.id),
                          onChanged: (v) => setState(() {
                            v == true
                                ? _selection.add(item.id)
                                : _selection.remove(item.id);
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      // Una fila, no `actions`: el `OverflowBar` de `AlertDialog` los apila en
      // vertical cuando no caben, y apilados quedaban pegados y sin jerarquia.
      // Los tres al mismo tamano (`sm`); lo que los distingue es la variante.
      actionsPadding: EdgeInsets.fromLTRB(
        t.space.md,
        t.space.xs,
        t.space.md,
        t.space.md,
      ),
      actions: [
        Row(
          children: [
            SButton.ghost(
              label: 'Limpiar',
              size: SButtonSize.sm,
              onPressed: _selection.isEmpty
                  ? null
                  : () => setState(() => _selection.clear()),
            ),
            const Spacer(),
            SButton.secondary(
              label: 'Cancelar',
              size: SButtonSize.sm,
              fullWidth: false,
              onPressed: () => Navigator.pop(context),
            ),
            SizedBox(width: t.space.xs),
            SButton(
              label: 'Aplicar',
              size: SButtonSize.sm,
              fullWidth: false,
              onPressed: () => Navigator.pop(context, _selection),
            ),
          ],
        ),
      ],
    );
  }
}
