import 'package:flutter/material.dart';

/// Widgets de la pantalla de acceso (login / recuperar contraseña).
///
/// Réplica fiel del login del portal admin (sozu-admin): tarjeta blanca
/// centrada sobre un fondo con gradiente radial verde muy suave, logo SOZU en
/// negro, inputs rellenos con anillo de foco verde, y botón primario con
/// gradiente esmeralda. El diseño es siempre claro (igual que el admin), por lo
/// que los colores están fijados y no dependen del tema claro/oscuro del
/// dispositivo — así el logo negro y la tarjeta blanca se ven idénticos.
class AuthColors {
  // Superficies y texto (escala de grises del admin).
  static const page = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE8E8E8); // hsl(0 0% 91%)
  static const radial = Color(0xFFF1F9F4); // hsl(145 40% 96%)
  static const textPrimary = Color(0xFF0D0D0D); // hsl(0 0% 5%)
  static const textMuted = Color(0xFF737373); // hsl(0 0% 45%)
  static const placeholder = Color(0xFF999999); // hsl(0 0% 60%)
  static const inputBg = Color(0xFFF7F7F7); // hsl(0 0% 97%)
  static const separator = Color(0xFFEDEDED); // hsl(0 0% 93%)

  // Verdes de marca.
  static const gradientStart = Color(0xFF49A26E); // hsl(145 38% 46%)
  static const gradientEnd = Color(0xFF5BB98D); // hsl(152 40% 54%)
  static const focusRing = Color(0xFF56AE7B); // hsl(145 35% 51%)
  static const link = Color(0xFF3D8F5F); // hsl(145 40% 40%)
  static const success = Color(0xFF45A16B); // hsl(145 40% 45%)

  // Alertas.
  static const errorText = Color(0xFFBC1010); // hsl(0 84% 40%)
  static const errorBg = Color(0xFFFEF1F1); // hsl(0 84% 97%)
  static const warnText = Color(0xFF8A670F); // hsl(43 80% 30%)
  static const warnBg = Color(0xFFFCF7E8); // hsl(43 80% 95%)
  static const infoText = Color(0xFF3D4D5C); // hsl(210 20% 30%)
  static const infoBg = Color(0xFFF2F5F8); // hsl(210 30% 96%)
  static const infoIcon = Color(0xFF3380CC); // hsl(210 60% 50%)
}

/// Fondo de la pantalla de acceso: página blanca con gradiente radial verde
/// suave centrado en la parte superior, y la [child] (la tarjeta) centrada,
/// desplazable y con ancho máximo de 24rem como en el admin.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.page,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            // Elipse ancha y poco alta, desplazada hacia arriba (50% 30%).
            center: Alignment(0, -0.55),
            radius: 0.9,
            colors: [AuthColors.radial, AuthColors.page],
            stops: [0.0, 0.75],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 384),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta blanca con borde y sombra suave (`.login-card` del admin).
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AuthColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuthColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 48,
            spreadRadius: -8,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Logo SOZU negro centrado (altura 40, igual que `h-10` del admin).
class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/sozu-logo-black.png',
        height: 40,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Título grande y negro centrado (`text-2xl font-black`).
class AuthTitle extends StatelessWidget {
  const AuthTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
        color: AuthColors.textPrimary,
        height: 1.2,
      ),
    );
  }
}

/// Subtítulo gris centrado.
class AuthSubtitle extends StatelessWidget {
  const AuthSubtitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 14, color: AuthColors.textMuted),
    );
  }
}

/// Etiqueta de campo (`label` en negrita).
class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AuthColors.textPrimary,
        ),
      ),
    );
  }
}

/// Input relleno sin borde con anillo de foco verde animado (réplica de
/// `.login-input` + `:focus`). Al enfocarse, la sombra pasa de una sombra sutil
/// a un anillo verde (box-shadow 0 0 0 2px verde@25%).
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

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: AuthColors.inputBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AuthColors.focusRing.withValues(alpha: 0.25),
                  blurRadius: 0,
                  spreadRadius: 2,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        keyboardType: widget.keyboardType,
        obscureText: widget.obscureText,
        autofillHints: widget.autofillHints,
        validator: widget.validator,
        onFieldSubmitted: widget.onFieldSubmitted,
        textInputAction: widget.textInputAction,
        cursorColor: AuthColors.focusRing,
        style: const TextStyle(fontSize: 14, color: AuthColors.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          hintText: widget.hintText,
          hintStyle: const TextStyle(color: AuthColors.placeholder),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          suffixIcon: widget.suffixIcon,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          errorStyle: const TextStyle(
            color: AuthColors.errorText,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// Botón primario con gradiente esmeralda, glow verde y opacidad al pasar el
/// cursor (`.login-btn-primary`). Muestra spinner + [loadingLabel] mientras
/// [loading] es true.
class AuthPrimaryButton extends StatefulWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.loadingLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final String? loadingLabel;

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.loading;
    final content = widget.loading
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.2,
                ),
              ),
              const SizedBox(width: 8),
              Text(widget.loadingLabel ?? widget.label),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(widget.label),
            ],
          );

    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: disabled ? null : widget.onPressed,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: disabled ? 0.6 : (_hover ? 0.9 : 1),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AuthColors.gradientStart, AuthColors.gradientEnd],
              ),
              boxShadow: [
                BoxShadow(
                  color: AuthColors.focusRing.withValues(alpha: 0.30),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón secundario con contorno (`.login-btn-outline`): borde 2px, verde al
/// pasar el cursor. Usado para la entrada biométrica.
class AuthOutlineButton extends StatefulWidget {
  const AuthOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool loading;

  @override
  State<AuthOutlineButton> createState() => _AuthOutlineButtonState();
}

class _AuthOutlineButtonState extends State<AuthOutlineButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.loading;
    final active = _hover && !disabled;
    final color = active ? AuthColors.focusRing : AuthColors.textPrimary;
    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: disabled ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? AuthColors.focusRing : AuthColors.cardBorder,
              width: 2,
            ),
          ),
          child: Opacity(
            opacity: disabled ? 0.6 : 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  IconTheme.merge(
                    data: IconThemeData(color: color, size: 20),
                    child: widget.icon!,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Caja de alerta con icono (variantes error / advertencia / info / éxito),
/// réplica de los avisos `rounded-xl px-4 py-3` del admin.
enum AuthAlertKind { error, warning, info, success }

class AuthAlert extends StatelessWidget {
  const AuthAlert({
    super.key,
    required this.kind,
    required this.icon,
    required this.message,
    this.spinIcon = false,
  });

  final AuthAlertKind kind;
  final IconData icon;
  final String message;
  final bool spinIcon;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    switch (kind) {
      case AuthAlertKind.error:
        bg = AuthColors.errorBg;
        fg = AuthColors.errorText;
      case AuthAlertKind.warning:
        bg = AuthColors.warnBg;
        fg = AuthColors.warnText;
      case AuthAlertKind.info:
        bg = AuthColors.infoBg;
        fg = AuthColors.infoText;
      case AuthAlertKind.success:
        bg = AuthColors.warnBg; // no usado directamente; ver pantallas
        fg = AuthColors.success;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 14, color: fg, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Enlace de texto verde (`¿Olvidaste tu contraseña?`, `Volver...`).
class AuthLink extends StatelessWidget {
  const AuthLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AuthColors.link,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: AuthColors.link),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AuthColors.link,
            ),
          ),
        ],
      ),
    );
  }
}
