import 'package:flutter/material.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Campo de selección **por escritura**, no por lista desplegable.
///
/// Comportamiento:
/// * Campo vacío → no se muestra nada; el `hintText` hace de instrucción.
/// * Al escribir → solo las coincidencias (máximo [maxVisible], con scroll).
/// * Sin coincidencias → fila de fallback con el texto buscado, que distingue
///   "no existe" de "se rompió".
/// * Con valor elegido → botón de limpiar.
///
/// Genérico sobre [T]: el texto visible sale de [labelOf] y la comparación de
/// [searchTextOf] (por defecto, el label).
class SAutocompleteField<T extends Object> extends StatefulWidget {
  const SAutocompleteField({
    super.key,
    required this.options,
    required this.labelOf,
    required this.onSelected,
    this.value,
    this.searchTextOf,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.noResultsLabel = 'Sin resultados para',
    this.maxVisible = 6,
    this.enabled = true,
  });

  final List<T> options;

  /// Texto que se muestra para una opción (y en el campo al elegirla).
  final String Function(T option) labelOf;

  /// `null` = se limpió la selección.
  final ValueChanged<T?> onSelected;

  /// Opción elegida actualmente.
  final T? value;

  /// Texto contra el que se filtra. Por defecto [labelOf].
  final String Function(T option)? searchTextOf;

  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;

  /// Prefijo del mensaje de fallback; se le concatena el texto buscado.
  final String noResultsLabel;

  /// Cuántas filas se ven sin hacer scroll.
  final int maxVisible;

  final bool enabled;

  @override
  State<SAutocompleteField<T>> createState() => _SAutocompleteFieldState<T>();
}

/// Fila del menú: o es una opción real, o el fallback de "sin resultados".
///
/// `RawAutocomplete` NO llama a `optionsViewBuilder` cuando la lista viene
/// vacía, así que el fallback tiene que viajar COMO una opción.
@immutable
class _Row<T extends Object> {
  const _Row.option(this.value) : isPlaceholder = false;
  const _Row.placeholder() : value = null, isPlaceholder = true;

  final T? value;
  final bool isPlaceholder;
}

class _SAutocompleteFieldState<T extends Object>
    extends State<SAutocompleteField<T>> {
  final _focusNode = FocusNode();
  TextEditingController? _controller;

  /// Última selección conocida. No se usa `widget.value` como fuente de verdad
  /// porque el padre puede no realimentarlo (uso no controlado).
  T? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.value;
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(SAutocompleteField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El valor puede cambiar desde fuera (reset de filtros).
    if (widget.value != oldWidget.value) {
      _selected = widget.value;
      if (_controller != null) {
        final text = _labelOrEmpty(_selected);
        if (_controller!.text != text) _controller!.text = text;
      }
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    // El controller lo crea este widget (`_controller ??=` en build), asi que
    // tambien lo libera. Sin esto fuga en cada montaje.
    _controller?.dispose();
    super.dispose();
  }

  /// Al salir del campo sin elegir nada, restaura el texto del valor vigente
  /// para no dejar un texto a medias que no corresponde a ninguna selección.
  void _onFocusChange() {
    if (_focusNode.hasFocus || _controller == null) return;
    final text = _labelOrEmpty(_selected);
    if (_controller!.text != text) _controller!.text = text;
    setState(() {});
  }

  String _labelOrEmpty(T? option) =>
      option == null ? '' : widget.labelOf(option);

  String _searchText(T option) =>
      (widget.searchTextOf ?? widget.labelOf)(option);

  Iterable<_Row<T>> _buildRows(TextEditingValue input) {
    final query = input.text.trim().toLowerCase();

    // Vacío: no se vuelca el catálogo.
    if (query.isEmpty) return const [];

    // El texto es el valor ya elegido: el usuario no está buscando.
    final current = _selected;
    if (current != null && query == widget.labelOf(current).toLowerCase()) {
      return const [];
    }

    final matches = widget.options
        .where((o) => _searchText(o).toLowerCase().contains(query))
        .map<_Row<T>>(_Row.option)
        .toList();

    return matches.isEmpty ? [_Row<T>.placeholder()] : matches;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;

    return RawAutocomplete<_Row<T>>(
      focusNode: _focusNode,
      textEditingController: _controller ??= TextEditingController(
        text: _labelOrEmpty(_selected),
      ),
      optionsBuilder: widget.enabled ? _buildRows : (_) => const [],
      displayStringForOption: (row) =>
          row.isPlaceholder ? '' : widget.labelOf(row.value!),
      onSelected: (row) {
        if (row.isPlaceholder) return; // el fallback no es seleccionable
        _selected = row.value;
        widget.onSelected(row.value);
        _focusNode.unfocus();
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          onSubmitted: (_) => onSubmitted(),
          style: t.text.body.copyWith(color: c.fg),
          decoration: InputDecoration(
            isDense: true,
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon, size: 20, color: c.fgSubtle),
            suffixIcon: _Suffix(
              hasValue: _selected != null || controller.text.isNotEmpty,
              onClear: () {
                controller.clear();
                setState(() => _selected = null);
                widget.onSelected(null);
              },
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, rows) {
        final list = rows.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: _Menu<T>(
            rows: list,
            labelOf: widget.labelOf,
            onSelected: onSelected,
            maxVisible: widget.maxVisible,
            noResultsText:
                '${widget.noResultsLabel} "${_controller?.text.trim() ?? ''}"',
          ),
        );
      },
    );
  }
}

/// Sufijo del campo: limpiar si hay algo, flecha si no.
class _Suffix extends StatelessWidget {
  const _Suffix({required this.hasValue, required this.onClear});

  final bool hasValue;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.s.color;
    if (!hasValue) {
      return Icon(Icons.keyboard_arrow_down, size: 20, color: c.fgSubtle);
    }
    return IconButton(
      icon: const Icon(Icons.close, size: 18),
      color: c.fgSubtle,
      tooltip: 'Limpiar',
      onPressed: onClear,
    );
  }
}

/// Menú de sugerencias. Alto acotado a `maxVisible` filas para que no tape la
/// pantalla con catálogos grandes.
class _Menu<T extends Object> extends StatelessWidget {
  const _Menu({
    required this.rows,
    required this.labelOf,
    required this.onSelected,
    required this.maxVisible,
    required this.noResultsText,
  });

  final List<_Row<T>> rows;
  final String Function(T) labelOf;
  final void Function(_Row<T>) onSelected;
  final int maxVisible;
  final String noResultsText;

  static const double _rowHeight = 44;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;
    final isPlaceholder = rows.length == 1 && rows.first.isPlaceholder;

    return Padding(
      padding: EdgeInsets.only(top: t.space.xxs),
      // El menu NO lleva ancho propio: `RawAutocomplete` ya lo monta con el
      // ancho del campo. Lo que lo encogia era un `maxWidth: 520` fijo, que en
      // escritorio dejaba el desplegable mas angosto que el input.
      //
      // La sombra va FUERA del Material que recorta: dentro, el `clipBehavior`
      // la recortaba hacia adentro y se pintaba como un degradado oscuro en los
      // bordes en vez de como sombra.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: t.radius.mdBorder,
          boxShadow: t.shadow.lg,
        ),
        child: Material(
          color: c.surface,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: t.radius.mdBorder,
            side: BorderSide(color: c.border),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: _rowHeight * maxVisible + t.space.xs * 2,
            ),
            child: isPlaceholder
                ? _NoResults(text: noResultsText)
                : ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: t.space.xxs),
                    shrinkWrap: true,
                    itemCount: rows.length,
                    itemBuilder: (context, i) => _OptionRow<T>(
                      label: labelOf(rows[i].value!),
                      onTap: () => onSelected(rows[i]),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _OptionRow<T extends Object> extends StatelessWidget {
  const _OptionRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return InkWell(
      onTap: onTap,
      hoverColor: t.color.surfaceAlt,
      child: Container(
        height: _Menu._rowHeight,
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: t.space.sm),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.text.body.copyWith(color: t.color.fg),
        ),
      ),
    );
  }
}

/// Fallback de "no hay coincidencias". Incluye QUÉ se buscó.
class _NoResults extends StatelessWidget {
  const _NoResults({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.sm,
        vertical: t.space.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.search_off_outlined, size: 18, color: c.fgSubtle),
          SizedBox(width: t.space.xs),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.text.bodySmall.copyWith(color: c.fgMuted),
            ),
          ),
        ],
      ),
    );
  }
}
