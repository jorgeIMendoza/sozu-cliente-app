import 'package:flutter/material.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Etiqueta de campo.
class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Padding(
      padding: EdgeInsets.only(bottom: t.space.xs),
      child: Text(text, style: t.text.label.copyWith(color: t.color.fg)),
    );
  }
}

/// Campo de texto del acceso: superficie lisa con borde de 1 px que se tiñe de
/// verde al enfocar, más un anillo de foco.
///
/// El borde que se tiñe (en vez de un relleno gris con sombra difusa) es lo que
/// evita que el formulario se lea desactivado sobre fondo claro.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints,
    this.validator,
    this.suffixIcon,
    this.onFieldSubmitted,
    this.textInputAction,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final void Function(String)? onFieldSubmitted;
  final TextInputAction? textInputAction;

  /// Solo para escritorio: enfocar al cargar. En móvil abriría el teclado encima
  /// del formulario apenas entra el usuario.
  final bool autofocus;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  final _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: t.radius.mdBorder,
        border: Border.all(
          color: _isFocused ? c.primary : c.border,
          width: _isFocused ? 1.5 : 1,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: c.primary.withValues(alpha: 0.16),
                  blurRadius: 0,
                  spreadRadius: 3,
                ),
              ]
            : null,
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        keyboardType: widget.keyboardType,
        obscureText: widget.obscureText,
        autofillHints: widget.autofillHints,
        validator: widget.validator,
        onFieldSubmitted: widget.onFieldSubmitted,
        textInputAction: widget.textInputAction,
        cursorColor: c.primary,
        style: t.text.bodyLarge.copyWith(color: c.fg),
        decoration: InputDecoration(
          isDense: true,
          // El relleno lo pinta el AnimatedContainer de arriba; si el campo
          // también rellenara, se verían dos capas de color.
          filled: false,
          hintText: widget.hintText,
          hintStyle: t.text.bodyLarge.copyWith(color: c.fgSubtle),
          // 17 de alto interno → 52 px de campo: cómodo al tacto y con
          // presencia en escritorio.
          contentPadding: EdgeInsets.symmetric(
            horizontal: t.space.md,
            vertical: 17,
          ),
          suffixIcon: widget.suffixIcon,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          errorStyle: t.text.caption.copyWith(color: c.danger),
        ),
      ),
    );
  }
}
