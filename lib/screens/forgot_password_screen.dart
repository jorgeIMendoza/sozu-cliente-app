import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import 'auth_widgets.dart';

/// Recuperar contraseña. Réplica del card del portal admin: misma tarjeta,
/// logo, textos y estado de éxito "Revisa tu correo". Respuesta neutra (no
/// revela si el correo existe).
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

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _volverALogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ref.read(authProvider).resetPassword(_email.text);
    } catch (_) {
      // mismo mensaje neutro: no filtrar existencia de cuentas
    }
    if (mounted) {
      setState(() {
        _sent = true;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: AuthCard(
        children: _sent ? _successChildren() : _formChildren(),
      ),
    );
  }

  List<Widget> _formChildren() {
    return [
      const AuthLogo(),
      const SizedBox(height: 28),
      const AuthTitle('Recuperar contraseña'),
      const SizedBox(height: 10),
      const AuthSubtitle(
        'Ingresa tu correo electrónico para restablecer tu contraseña',
      ),
      const SizedBox(height: 28),
      Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthFieldLabel('Correo electrónico'),
            AuthTextField(
              controller: _email,
              hintText: 'tucorreo@ejemplo.com',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Ingresa tu correo';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                  return 'Correo no válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: 'Validar',
              icon: Icons.mail_outline,
              loading: _submitting,
              loadingLabel: 'Validando...',
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Center(
        child: AuthLink(
          label: 'Volver al inicio de sesión',
          icon: Icons.arrow_back,
          onPressed: _volverALogin,
        ),
      ),
    ];
  }

  List<Widget> _successChildren() {
    return [
      const AuthLogo(),
      const SizedBox(height: 28),
      const Icon(Icons.check_circle, size: 56, color: AuthColors.success),
      const SizedBox(height: 16),
      const AuthTitle('Revisa tu correo'),
      const SizedBox(height: 12),
      const AuthSubtitle(
        'Si existe una cuenta activa con ese correo, te enviamos un enlace '
        'para restablecer tu contraseña.',
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AuthColors.infoBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.mail_outline, size: 20, color: AuthColors.infoIcon),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Abre el enlace desde tu bandeja de entrada (revisa también la '
                'carpeta de spam) para verificar tu identidad y definir una '
                'nueva contraseña. El enlace es de un solo uso.',
                style: TextStyle(
                  fontSize: 14,
                  color: AuthColors.infoText,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      AuthPrimaryButton(
        label: 'Volver al inicio de sesión',
        icon: Icons.arrow_back,
        onPressed: _volverALogin,
      ),
    ];
  }
}
