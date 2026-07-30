import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Tamaño del campo: define alto mínimo, tipografía y padding interno.
enum STextFieldSize {
  /// ~44 px. Campos dentro de filas, filtros, formularios densos.
  md,

  /// ~52 px. Formularios que son el contenido principal (acceso, pago, perfil).
  lg,
}

extension _STextFieldSizeMetrics on STextFieldSize {
  /// Alto mínimo del campo. 44 px es el PISO por target táctil (WCAG 2.5.5 y
  /// HIG de Apple): no bajarlo.
  double get minHeight => switch (this) {
    STextFieldSize.md => 44,
    STextFieldSize.lg => 52,
  };
}

/// Campo de texto global del design system.
///
/// **Superficie lisa con borde de 1 px que se tiñe de verde al enfocar, más un
/// anillo de foco.** La etiqueta es un `Text` propio ARRIBA del campo y no un
/// label flotante, para que el alto no cambie entre vacío y enfocado.
///
/// El borde, el relleno y el mensaje de error los pinta este widget, NO el
/// `InputDecoration` (`border: InputBorder.none`, `filled: false`). Por dentro
/// es un `TextFormField`, así que `Form.validate()` lo ve.
///
/// ```dart
/// STextField(
///   controller: _emailCtrl,
///   label: 'Correo',
///   hint: 'tu@correo.com',
///   keyboardType: TextInputType.emailAddress,
///   validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
/// )
/// ```
class STextField extends StatefulWidget {
  const STextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.maxLength,
    this.size = STextFieldSize.lg,
    this.focusNode,
  }) : _isPassword = false;

  /// Campo de contraseña con el ojo de mostrar/ocultar YA resuelto.
  ///
  /// No acepta [suffix], [obscureText], [maxLines] ni [readOnly]: el sufijo es
  /// el ojo y la visibilidad la maneja el campo.
  const STextField.password({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.prefixIcon,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.maxLength,
    this.size = STextFieldSize.lg,
    this.focusNode,
  }) : _isPassword = true,
       obscureText = true,
       suffix = null,
       readOnly = false,
       keyboardType = null,
       maxLines = 1;

  final TextEditingController controller;

  /// Etiqueta ARRIBA del campo, como texto propio.
  final String? label;

  /// Placeholder dentro del campo; no sustituye a [label].
  final String? hint;

  /// Texto de ayuda debajo del campo. Lo tapa el error mientras haya error.
  final String? helper;

  /// Error explícito (el que viene del backend). **Gana sobre [validator]** y se
  /// muestra de inmediato, sin esperar un `Form.validate()`.
  final String? errorText;

  /// Icono al inicio del campo. Es `IconData` y NO `Widget` a propósito: el
  /// componente decide tamaño y color.
  final IconData? prefixIcon;

  /// Widget libre al final del campo (unidad, botón de acción, indicador).
  final Widget? suffix;

  final bool obscureText;
  final bool enabled;
  final bool readOnly;

  /// Solo para escritorio: en móvil abre el teclado encima del formulario.
  final bool autofocus;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final int? maxLength;
  final STextFieldSize size;

  /// `FocusNode` externo, para cuando la pantalla mueve el foco. Si no se pasa,
  /// el campo crea y destruye el suyo.
  final FocusNode? focusNode;

  /// Marca de que se construyó con [STextField.password].
  final bool _isPassword;

  @override
  State<STextField> createState() => _STextFieldState();
}

/// Grosor del borde en reposo y enfocado; engrosarlo no desplaza el contenido.
const double _borderWidth = 1;
const double _focusedBorderWidth = 1.5;

/// Anillo de foco, hacia afuera del borde. No subirlo: 3 px es el máximo que
/// cabe sin invadir el campo de al lado.
const double _focusRingSpread = 3;

/// Opacidad del anillo de foco.
const double _focusRingAlpha = 0.16;

/// Tamaño del icono del ojo, acotado al alto del campo.
const double _suffixIconSize = 20;

/// Tamaño del icono de prefijo. Igual en los tres campos del sistema.
const double _prefixIconSize = 20;

class _STextFieldState extends State<STextField> {
  /// Solo se crea si la pantalla no trajo el suyo. Se guarda aparte para NO
  /// hacer `dispose()` de un nodo ajeno.
  FocusNode? _ownedFocusNode;
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  bool _isFocused = false;

  /// Visibilidad del texto en [STextField.password]. Arranca oculto.
  bool _obscure = true;

  /// Último mensaje devuelto por [STextField.validator]. Su `setState` va en un
  /// post-frame: el validator corre dentro del ciclo de build de
  /// `Form.validate()`.
  String? _validatorError;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(STextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChange);
      _ownedFocusNode?.removeListener(_onFocusChange);
      _focusNode.addListener(_onFocusChange);
      _isFocused = _focusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_onFocusChange);
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted && _isFocused != _focusNode.hasFocus) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  /// [STextField.errorText] gana: si viene un error explícito, el validator ni
  /// corre.
  String? _validate(String? value) {
    if (widget.errorText != null) {
      // Se descarta el error viejo del validator: si no, al limpiarse el
      // `errorText` reaparece un mensaje que ya no corresponde al valor actual.
      if (_validatorError != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _validatorError = null);
        });
      }
      return widget.errorText;
    }
    final result = widget.validator?.call(value);
    if (result != _validatorError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _validatorError = result);
      });
    }
    return result;
  }

  bool get _effectiveObscure =>
      widget._isPassword ? _obscure : widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;
    final error = widget.errorText ?? _validatorError;
    final hasError = error != null;
    final interactive = widget.enabled;

    // El error manda sobre el foco.
    final Color borderColor;
    if (!interactive) {
      borderColor = c.borderSoft;
    } else if (hasError) {
      borderColor = c.danger;
    } else if (_isFocused) {
      borderColor = c.primary;
    } else {
      borderColor = c.border;
    }

    final ringColor = hasError ? c.danger : c.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null)
          Padding(
            padding: EdgeInsets.only(bottom: t.space.xs),
            child: Text(
              widget.label!,
              style: t.text.label.copyWith(
                color: interactive ? c.fg : c.fgSubtle,
              ),
            ),
          ),
        // El alto mínimo va en un ConstrainedBox aparte y NO en el
        // AnimatedContainer, donde `constraints` es una propiedad animada.
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: widget.size.minHeight),
          child: AnimatedContainer(
            duration: t.motion.fast,
            curve: t.motion.standard,
            decoration: BoxDecoration(
              color: interactive ? c.surface : c.muted,
              borderRadius: t.radius.mdBorder,
              border: Border.all(
                color: borderColor,
                width: _isFocused && interactive
                    ? _focusedBorderWidth
                    : _borderWidth,
              ),
              boxShadow: _isFocused && interactive
                  ? [
                      BoxShadow(
                        color: ringColor.withValues(alpha: _focusRingAlpha),
                        blurRadius: 0,
                        spreadRadius: _focusRingSpread,
                      ),
                    ]
                  : null,
            ),
            // Align y no solo `textAlignVertical`: el InputDecorator no reparte
            // el sobrante del ConstrainedBox y el texto queda pegado arriba.
            child: Align(child: _buildField(t)),
          ),
        ),
        if (hasError)
          Padding(
            padding: EdgeInsets.only(top: t.space.xs),
            child: Text(error, style: t.text.caption.copyWith(color: c.danger)),
          )
        else if (widget.helper != null)
          Padding(
            padding: EdgeInsets.only(top: t.space.xs),
            child: Text(
              widget.helper!,
              style: t.text.caption.copyWith(color: c.fgMuted),
            ),
          ),
      ],
    );
  }

  Widget _buildField(SozuTheme t) {
    final c = t.color;
    final isLarge = widget.size == STextFieldSize.lg;
    final textStyle = isLarge ? t.text.bodyLarge : t.text.body;
    final horizontal = isLarge ? t.space.md : t.space.sm;
    final vertical = isLarge ? t.space.sm : t.space.xs;

    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      keyboardType: widget.keyboardType,
      obscureText: _effectiveObscure,
      autofillHints: widget.autofillHints,
      validator: _validate,
      // El mensaje lo pinta la Column de afuera; aquí caería dentro del borde.
      errorBuilder: (_, _) => const SizedBox.shrink(),
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      textInputAction: widget.textInputAction,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      cursorColor: c.primary,
      // Con `isDense: true` el `InputDecorator` no reparte el sobrante.
      textAlignVertical: TextAlignVertical.center,
      style: textStyle.copyWith(color: widget.enabled ? c.fg : c.fgSubtle),
      decoration: InputDecoration(
        isDense: true,
        // El relleno lo pinta el AnimatedContainer de arriba.
        filled: false,
        hintText: widget.hint,
        hintStyle: textStyle.copyWith(color: c.fgSubtle),
        contentPadding: EdgeInsets.symmetric(
          horizontal: horizontal,
          vertical: vertical,
        ),
        prefixIcon: widget.prefixIcon == null
            ? null
            : Icon(widget.prefixIcon, size: _prefixIconSize, color: c.fgSubtle),
        suffixIcon: widget._isPassword
            ? _buildPasswordToggle(t)
            : widget.suffix,
        // [maxLength] limita la entrada; el contador caería dentro del borde.
        counterText: '',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
      ),
    );
  }

  Widget _buildPasswordToggle(SozuTheme t) {
    final visible = !_obscure;
    return IconButton(
      icon: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: _suffixIconSize,
      ),
      color: t.color.fgMuted,
      tooltip: visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
      padding: EdgeInsets.zero,
      // Se descuenta el borde ENFOCADO (el más grueso): con el alto completo del
      // campo, al enfocar el campo entero ganaría 1 px.
      constraints: BoxConstraints.tightFor(
        width: widget.size.minHeight,
        height: widget.size.minHeight - 2 * _focusedBorderWidth,
      ),
      onPressed: widget.enabled
          ? () => setState(() => _obscure = !_obscure)
          : null,
    );
  }
}
