import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_alert.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_brand_image.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_header.dart';
import 'package:sozu_cliente_app/features/auth/layouts/auth_layout.dart';
import 'package:sozu_cliente_app/features/auth/ports/auth_port.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Recuperar contraseña, con estado de éxito "Revisa tu correo". La respuesta
/// es neutra: no revela si el correo existe.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _submitting = false;
  bool _sent = false;
  String? _formError;

  /// El backend topó su límite y NO envió este correo. Es un estado normal (la
  /// llamada responde 200), no un error: cambia el mensaje de éxito, no lo pinta
  /// como fallo.
  bool _rateLimited = false;
  int? _retryAfterMinutes;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _backToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _formError = null;
    });
    final PasswordResetResult result;
    try {
      result = await ref.read(authProvider).resetPassword(_email.text);
    } catch (e) {
      // Solo llegan fallos REALES (red o servidor): el backend responde éxito
      // genérico exista o no la cuenta, así que mostrarlos no filtra nada.
      // Tragarlos era peor que el riesgo que evitaban: un SMTP caído se veía
      // idéntico a un envío exitoso y el usuario esperaba un correo que nunca
      // salió.
      if (!mounted) return;
      setState(() {
        _formError = AuthController.resetPasswordErrorMessage(e);
        _submitting = false;
      });
      return;
    }
    if (mounted) {
      setState(() {
        _sent = true;
        _rateLimited = result.rateLimited;
        _retryAfterMinutes = result.retryAfterMinutes;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      brand: const AuthBrandImage(),
      child: AuthFormBody(
        children: _sent ? _successChildren() : _formChildren(),
      ),
    );
  }

  List<Widget> _formChildren() {
    final t = context.s;
    return [
      const AuthLogo(),
      SizedBox(height: t.space.lg),
      const AuthTitle('Recuperar contraseña'),
      SizedBox(height: t.space.xs),
      const AuthSubtitle(
        'Ingresa tu correo electrónico para restablecer tu contraseña',
      ),
      SizedBox(height: t.space.lg),
      Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_formError != null) ...[
              AuthAlert(
                kind: AuthAlertKind.error,
                icon: Icons.error_outline,
                message: _formError!,
              ),
              SizedBox(height: t.space.md),
            ],
            STextField(
              controller: _email,
              label: 'Correo electrónico',
              hint: 'tucorreo@ejemplo.com',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: (v) {
                final email = v?.trim() ?? '';
                if (email.isEmpty) return 'Ingresa tu correo';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return 'Correo no válido';
                }
                return null;
              },
            ),
            SizedBox(height: t.space.md),
            // lg: acción principal, al mismo alto que el campo.
            SButton(
              label: 'Validar',
              size: SButtonSize.lg,
              loading: _submitting,
              loadingLabel: 'Validando...',
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
      SizedBox(height: t.space.md),
      Center(
        child: SButton.link(
          label: 'Volver al inicio de sesión',
          icon: Icons.arrow_back,
          // Navega a otra pantalla: se anuncia como enlace, no como botón.
          isNavigation: true,
          onPressed: _backToLogin,
        ),
      ),
    ];
  }

  List<Widget> _successChildren() {
    // Ojo: `context.s` no puede ir dentro de una expresion `const`.
    final t = context.s;
    final c = t.color;
    // Tope de envíos alcanzado: este correo NO salió, así que decir "revisa tu
    // correo" mandaba al usuario a esperar algo que no iba a llegar y a pedir
    // más enlaces. Sigue siendo neutro: el límite se evalúa antes de buscar la
    // cuenta, así que un correo desconocido topa igual y ve lo mismo.
    final minutes = _retryAfterMinutes ?? 15;
    return [
      const AuthLogo(),
      SizedBox(height: t.space.lg),
      Icon(
        _rateLimited ? Icons.mark_email_unread_outlined : Icons.check_circle,
        size: 56,
        color: _rateLimited ? c.warning : c.primaryHover,
      ),
      SizedBox(height: t.space.md),
      AuthTitle(
        _rateLimited ? 'Usa el enlace que ya tienes' : 'Revisa tu correo',
      ),
      SizedBox(height: t.space.sm),
      AuthSubtitle(
        _rateLimited
            ? 'Ya pediste varios enlaces, así que este último no se envió.'
            : 'Si existe una cuenta activa con ese correo, te enviamos un '
                  'enlace para confirmar tu identidad.',
      ),
      SizedBox(height: t.space.md),
      Container(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.md,
          vertical: t.space.sm,
        ),
        decoration: BoxDecoration(
          color: _rateLimited ? c.warningSoft : c.infoSoft,
          borderRadius: t.radius.mdBorder,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _rateLimited ? Icons.schedule : Icons.mail_outline,
              size: 20,
              color: _rateLimited ? c.warning : c.info,
            ),
            SizedBox(width: t.space.sm),
            Expanded(
              child: Text(
                _rateLimited
                    ? 'Abre el correo más reciente que ya recibiste: ese enlace '
                          'sigue siendo válido. Si ya no lo tienes, espera '
                          '$minutes minutos y vuelve a intentar.'
                    : 'Abre el enlace desde tu bandeja de entrada (revisa '
                          'también la carpeta de spam). Al confirmarlo '
                          'recibirás un segundo correo con tu contraseña '
                          'temporal: entra con ella y la app te pedirá definir '
                          'la definitiva. El enlace es de un solo uso.',
                style: t.text.body.copyWith(
                  color: _rateLimited ? c.warningFg : c.infoFg,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: t.space.lg),
      SButton(
        label: 'Volver al inicio de sesión',
        size: SButtonSize.lg,
        icon: Icons.arrow_back,
        onPressed: _backToLogin,
      ),
    ];
  }
}
