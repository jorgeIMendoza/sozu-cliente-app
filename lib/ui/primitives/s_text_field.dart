import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Tamaño del campo: define alto mínimo, tipografía y padding interno.
///
/// Solo hay dos porque son las dos situaciones reales: un formulario que es el
/// contenido principal de la pantalla ([lg]) y un campo que convive con otras
/// cosas en una fila o un filtro ([md]). Un tercer tamaño intermedio no se
/// distinguiría de sus vecinos y solo obligaría a elegir sin criterio.
enum STextFieldSize {
  /// ~44 px. Campos dentro de filas, filtros, formularios densos.
  md,

  /// ~52 px. Formularios que son el contenido principal (acceso, pago, perfil).
  lg,
}

extension _STextFieldSizeMetrics on STextFieldSize {
  /// Alto mínimo del campo.
  ///
  /// 44 px es el piso, no una preferencia estética: es el target táctil mínimo
  /// de WCAG 2.5.5 y de las HIG de Apple. Por debajo de eso el campo se falla al
  /// tocar en móvil. [STextFieldSize.lg] sube a 52 porque un formulario que es
  /// TODA la pantalla necesita presencia en escritorio, donde 44 px se ve
  /// apretado al lado de un botón primario.
  double get minHeight => switch (this) {
    STextFieldSize.md => 44,
    STextFieldSize.lg => 52,
  };
}

/// Campo de texto global del design system.
///
/// **Superficie lisa con borde de 1 px que se tiñe de verde al enfocar, más un
/// anillo de foco.** Ese es el comportamiento heredado del campo de acceso y la
/// razón de que sea así está medida: la alternativa -relleno gris con sombra
/// difusa- hacía que el formulario completo se leyera DESACTIVADO sobre fondo
/// claro, porque el gris apagado es el mismo lenguaje visual que un control
/// deshabilitado. El borde que se tiñe deja la superficie al mismo nivel que la
/// card que lo contiene y mueve toda la señal de estado al contorno.
///
/// ### Por qué la etiqueta va ARRIBA y no flotante
///
/// Con `floatingLabel` de Material la etiqueta vive dentro del campo y sube al
/// enfocarse. Eso cambia el alto útil del campo entre estado vacío y estado
/// enfocado, así que la columna del formulario SALTA cuando el usuario pasa de
/// un campo al siguiente. Aquí la etiqueta es un `Text` propio, fuera del
/// campo: el alto es el mismo siempre. De paso queda legible en reposo, que es
/// el problema conocido del label flotante (el placeholder desaparece al
/// escribir y el usuario ya no sabe qué campo es).
///
/// ### Por qué el borde lo pinta el contenedor y no el `InputDecoration`
///
/// El `TextFormField` va con `border: InputBorder.none` y `filled: false`: si el
/// campo también rellenara, se verían dos capas de color y el radio de una no
/// coincide con el de la otra. Además `InputDecorator` anima el color de su
/// borde con una duración fija propia, y el anillo de foco (un `BoxShadow` de
/// `spreadRadius` sin blur) no se puede expresar con un `InputBorder`.
///
/// Por dentro es un `TextFormField` para que funcione dentro de un `Form`
/// (`Form.validate()` lo ve y falla si su validator falla).
///
/// ### Cerrado a modificación, abierto a extensión
///
/// Todo lo que varía entre pantallas es un parámetro. Si una pantalla necesita
/// algo que no está aquí, se agrega un parámetro con default -nunca una copia
/// del widget ni un `if (esPantallaDePagos)` dentro.
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
  /// Existe porque el toggle es estado del propio campo: pedirle a cada
  /// pantalla un `bool _obscure` + `setState` era duplicar la misma lógica en
  /// login, cambio de contraseña y perfil. Tres copias de la misma cosa es
  /// también tres oportunidades de que el tooltip o el icono se desincronicen.
  ///
  /// No acepta [suffix] ni [obscureText]: el sufijo es el ojo y la visibilidad
  /// la maneja el campo. Tampoco [maxLines] (una contraseña es de una línea) ni
  /// [readOnly] (un campo de contraseña de solo lectura no tiene caso).
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

  /// Etiqueta ARRIBA del campo, como texto propio. Ver docstring de la clase.
  final String? label;

  /// Texto de placeholder dentro del campo. No sustituye a [label]: desaparece
  /// al escribir.
  final String? hint;

  /// Texto de ayuda debajo del campo. Lo tapa el error mientras haya error: dos
  /// líneas de texto chico debajo del mismo campo compiten y ninguna se lee.
  final String? helper;

  /// Error explícito. **Gana sobre [validator]** y se muestra de inmediato, sin
  /// esperar un `Form.validate()`.
  ///
  /// Es el caso del error que viene del backend ("Credenciales inválidas"): no
  /// lo puede calcular un validator local porque depende de la respuesta.
  final String? errorText;

  /// Icono al inicio del campo.
  ///
  /// Es `IconData` y no `Widget` a propósito: así el componente decide tamaño y
  /// color, y todos los campos de la app se ven iguales. Con `Widget` cada sitio
  /// de uso elegiría su propio `size`/`color` - exactamente la fragmentación que
  /// el design system existe para evitar. Mismo criterio que
  /// [SAutocompleteField.prefixIcon].
  ///
  /// Si algún día hace falta un prefijo que no sea icono (una bandera, un "$"),
  /// se agrega un parámetro `prefix` aparte; no se afloja este.
  final IconData? prefixIcon;

  /// Widget libre al final del campo (unidad, botón de acción, indicador).
  ///
  /// Este sí es `Widget` porque varía de verdad: un `IconButton`, un chip, un
  /// texto de unidad. No hay una forma canónica que imponer.
  final Widget? suffix;

  final bool obscureText;
  final bool enabled;
  final bool readOnly;

  /// Solo para escritorio: enfocar al cargar. En móvil abriría el teclado
  /// encima del formulario apenas entra el usuario.
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

  /// `FocusNode` externo, para cuando la pantalla necesita mover el foco (pasar
  /// al siguiente campo al enviar). Si no se pasa, el campo crea y destruye el
  /// suyo.
  final FocusNode? focusNode;

  /// Marca de que se construyó con [STextField.password]. Privado porque es
  /// detalle de implementación: quien usa el widget elige por constructor.
  final bool _isPassword;

  @override
  State<STextField> createState() => _STextFieldState();
}

/// Grosor del borde en reposo y enfocado.
///
/// El salto de 1 a 1.5 es lo que hace que el foco se note sin mover el layout:
/// el borde es parte de la decoración, no del tamaño del contenedor, así que
/// engrosarlo NO desplaza el contenido.
const double _borderWidth = 1;
const double _focusedBorderWidth = 1.5;

/// Grosor del anillo de foco, en píxeles hacia afuera del borde.
///
/// 3 px es el máximo que cabe sin invadir el campo de al lado: la separación
/// entre campos de un formulario es `space.xs` (8), y dos anillos de 3 px
/// dejarían 2 px de aire entre ellos.
const double _focusRingSpread = 3;

/// Opacidad del anillo de foco. Suficiente para leerse como halo de la marca,
/// insuficiente para competir con el borde teñido, que es la señal principal.
const double _focusRingAlpha = 0.16;

/// Tamaño del icono del ojo. Un `IconButton` con el tamaño por defecto (48 px de
/// target) haría crecer el campo por encima de su alto mínimo, así que va
/// acotado al alto del propio campo.
const double _suffixIconSize = 20;

/// Tamaño del icono de prefijo. Mismo valor que [SAutocompleteField] y
/// [SSearchField] para que los tres campos se lean como el mismo componente.
const double _prefixIconSize = 20;

class _STextFieldState extends State<STextField> {
  /// Solo se crea si la pantalla no trajo el suyo. Se guarda aparte para no
  /// hacer `dispose()` de un nodo que no es nuestro.
  FocusNode? _ownedFocusNode;
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  bool _isFocused = false;

  /// Visibilidad del texto en [STextField.password]. Arranca oculto: mostrar la
  /// contraseña por defecto la expondría a quien esté viendo la pantalla.
  bool _obscure = true;

  /// Último mensaje devuelto por [STextField.validator].
  ///
  /// Se guarda aquí porque el borde y el texto de error los pinta este widget,
  /// no el `InputDecorator`, y el resultado del validator solo existe dentro del
  /// `FormFieldState`. El `setState` va en un post-frame porque el validator
  /// corre durante el `Form.validate()`, que ya está dentro de un ciclo de
  /// build: llamar `setState` ahí revienta.
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
  /// corre. Un validator que sobrescribiera el error del backend dejaría al
  /// usuario sin saber por qué falló el envío.
  String? _validate(String? value) {
    if (widget.errorText != null) return widget.errorText;
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

    // El error manda sobre el foco: si el campo es inválido, eso es lo que el
    // usuario tiene que ver, aunque tenga el cursor dentro.
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
        // AnimatedContainer: ahí `constraints` es una propiedad animada, así que
        // el campo interpolaría su ALTO -no solo su color- cada vez que cambia
        // de tamaño. Animar el alto es justo lo que este widget evita.
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: widget.size.minHeight),
          child: AnimatedContainer(
            duration: t.motion.fast,
            curve: t.motion.standard,
            decoration: BoxDecoration(
              // Deshabilitado sí usa relleno apagado: ahí el gris SÍ es la
              // señal correcta, es exactamente lo que el campo activo no debe
              // parecer.
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
            // Center, no solo `textAlignVertical`: cuando el sobrante es
            // grande (tamano `md` deja 7 px libres) el InputDecorator NO lo
            // reparte y el texto queda pegado arriba - medido: 2.5 px sobre el
            // centro. El Align centra el campo completo dentro del alto que fija
            // el ConstrainedBox, sin importar cuanto sobre.
            //
            // Con `maxLines > 1` el campo es mas alto que el minimo y esto no
            // hace nada, que es lo correcto.
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
      // El mensaje lo pinta la Column de afuera. Si el `InputDecorator` también
      // lo pintara, saldría DENTRO del borde y el campo cambiaría de alto al
      // fallar la validación.
      errorBuilder: (_, _) => const SizedBox.shrink(),
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      textInputAction: widget.textInputAction,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      cursorColor: c.primary,
      // Centra el contenido en el alto disponible.
      //
      // Hace falta porque el alto lo fija un `ConstrainedBox(minHeight)` de
      // afuera, y con `isDense: true` el `InputDecorator` NO rellena el sobrante:
      // el texto medía ~49 px (24.8 de línea + 24 de padding) dentro de una caja
      // de 52 y quedaba pegado arriba, con el hueco abajo. Sin esto, el texto se
      // ve descentrado en el tamaño `lg`, que es el de todos los formularios.
      textAlignVertical: TextAlignVertical.center,
      style: textStyle.copyWith(color: widget.enabled ? c.fg : c.fgSubtle),
      decoration: InputDecoration(
        isDense: true,
        // El relleno lo pinta el AnimatedContainer de arriba; si el campo
        // también rellenara, se verían dos capas de color.
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
        // El contador de Material va en la fila de subtexto, que aquí queda
        // dentro del borde. Ninguna pantalla lo necesita hoy; [maxLength] se usa
        // para limitar la entrada, no para mostrar la cuenta.
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
      // El alto se descuenta el borde ENFOCADO (el más grueso), no el de
      // reposo: si el botón midiera el alto completo del campo, al enfocar el
      // borde crecería 0.5 px por lado y el campo entero ganaría 1 px de alto.
      // Un salto de 1 px al entrar a un campo se ve, y es acumulativo en un
      // formulario.
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
