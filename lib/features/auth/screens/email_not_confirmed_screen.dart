import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/features/auth/components/auth_alert.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_header.dart';
import 'package:sozu_cliente_app/features/auth/layouts/auth_layout.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Ruta de la pantalla de bloqueo por correo sin confirmar. Vive aquí (y no en
/// router.dart) para que el login pueda navegar a ella sin importar el router.
const emailNotConfirmedPath = '/confirma-tu-correo';

/// Bloqueo para los roles de portal (`roles.requiere_confirmacion_email`) cuyo
/// correo todavía no está verificado. Espejo del `EmailNoConfirmado.tsx` del
/// portal web, adaptado al hecho de que aquí la sesión YA está cerrada: el gate
/// hace `signOut()` y deja el correo en `AuthController.blockedEmail`, así que
/// esta pantalla no puede releer el perfil ("Ya confirmé mi correo" no aplica) y
/// devuelve al login para que el usuario entre de nuevo.
class EmailNotConfirmedScreen extends ConsumerStatefulWidget {
  const EmailNotConfirmedScreen({super.key});

  @override
  ConsumerState<EmailNotConfirmedScreen> createState() =>
      _EmailNotConfirmedScreenState();
}

class _EmailNotConfirmedScreenState
    extends ConsumerState<EmailNotConfirmedScreen> {
  bool _sending = false;
  bool _sent = false;
  String? _message;
  bool _messageIsError = false;

  void _backToLogin() {
    // Limpiar primero: el router mantiene esta pantalla mientras el bloqueo
    // esté puesto.
    ref.read(authProvider).clearAccessBlock();
    if (mounted) context.go('/login');
  }

  Future<void> _resend(String email) async {
    setState(() {
      _sending = true;
      _message = null;
    });

    String? error;
    try {
      await ref.read(authProvider).resendEmailConfirmation(email);
    } catch (e) {
      error = AuthController.resendConfirmationErrorMessage(e);
    }

    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = error == null;
      _messageIsError = error != null;
      _message =
          error ??
          'Te enviamos un correo nuevo. Revisa tu bandeja de entrada y la '
              'carpeta de spam.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;
    final email = ref.watch(authProvider).blockedEmail;

    return AuthLayout(
      child: AuthFormBody(
        children: [
          const AuthLogo(),
          SizedBox(height: t.space.lg),
          Icon(Icons.mark_email_unread_outlined, size: 56, color: c.warningFg),
          SizedBox(height: t.space.md),
          const AuthTitle('Confirma tu correo'),
          SizedBox(height: t.space.sm),
          AuthSubtitle(
            email == null || email.isEmpty
                ? 'Para entrar necesitas verificar tu correo. Abre el enlace '
                      'que te enviamos y vuelve a iniciar sesión.'
                : 'Para entrar necesitas verificar $email. Abre el enlace que '
                      'te enviamos por correo; si ya no lo tienes, pide uno '
                      'nuevo aquí.',
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
                    'Revisa tu bandeja de entrada (y la carpeta de spam). Al '
                    'confirmar podrás definir tu contraseña y entrar con ella.',
                    style: t.text.body.copyWith(color: c.infoFg, height: 1.35),
                  ),
                ),
              ],
            ),
          ),

          if (_message != null) ...[
            SizedBox(height: t.space.md),
            AuthAlert(
              kind: _messageIsError ? AuthAlertKind.error : AuthAlertKind.info,
              icon: _messageIsError
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
              message: _message!,
            ),
          ],

          if (email != null && email.isNotEmpty && !_sent) ...[
            SizedBox(height: t.space.md),
            SButton(
              label: 'Reenviar correo de confirmación',
              size: SButtonSize.lg,
              icon: Icons.forward_to_inbox,
              loading: _sending,
              loadingLabel: 'Enviando...',
              onPressed: _sending ? null : () => _resend(email),
            ),
          ],

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
        ],
      ),
    );
  }
}
