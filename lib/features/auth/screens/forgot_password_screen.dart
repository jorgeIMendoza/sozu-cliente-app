import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/providers/auth_provider.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_brand_image.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_buttons.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_header.dart';
import 'package:sozu_cliente_app/features/auth/layouts/auth_layout.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_text_field.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

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
            SizedBox(height: t.space.md),
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
      SizedBox(height: t.space.md),
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
    // Se lee una vez y se reutiliza: `context.s` no puede aparecer dentro de una
    // expresion `const`, y estos bloques lo eran.
    final t = context.s;
    final c = t.color;
    return [
      const AuthLogo(),
      SizedBox(height: t.space.lg),
      Icon(Icons.check_circle, size: 56, color: c.primaryHover),
      SizedBox(height: t.space.md),
      const AuthTitle('Revisa tu correo'),
      SizedBox(height: t.space.sm),
      const AuthSubtitle(
        'Si existe una cuenta activa con ese correo, te enviamos un enlace '
        'para restablecer tu contraseña.',
      ),
      SizedBox(height: t.space.md),
      Container(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.md,
          vertical: t.space.sm,
        ),
        decoration: BoxDecoration(
          color: c.infoSoft,
          borderRadius: t.radius.mdBorder,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.mail_outline, size: 20, color: c.info),
            SizedBox(width: t.space.sm),
            Expanded(
              child: Text(
                'Abre el enlace desde tu bandeja de entrada (revisa también la '
                'carpeta de spam) para verificar tu identidad y definir una '
                'nueva contraseña. El enlace es de un solo uso.',
                style: t.text.body.copyWith(color: c.infoFg, height: 1.35),
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: t.space.lg),
      AuthPrimaryButton(
        label: 'Volver al inicio de sesión',
        icon: Icons.arrow_back,
        onPressed: _volverALogin,
      ),
    ];
  }
}
