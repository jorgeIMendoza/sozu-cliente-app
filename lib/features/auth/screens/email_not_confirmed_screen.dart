import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/features/auth/components/auth_header.dart';
import 'package:sozu_cliente_app/features/auth/components/resend_confirmation_action.dart';
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
class EmailNotConfirmedScreen extends ConsumerWidget {
  const EmailNotConfirmedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.s;
    final c = t.color;
    final email = ref.watch(authProvider).blockedEmail;
    final hayCorreo = email != null && email.isNotEmpty;

    void backToLogin() {
      // Limpiar primero: el router mantiene esta pantalla mientras el bloqueo
      // esté puesto.
      ref.read(authProvider).clearAccessBlock();
      context.go('/login');
    }

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
            hayCorreo
                ? 'Para entrar necesitas verificar $email. Abre el enlace que '
                      'te enviamos por correo; si ya no lo tienes, pide uno '
                      'nuevo aquí.'
                : 'Para entrar necesitas verificar tu correo. Abre el enlace '
                      'que te enviamos y vuelve a iniciar sesión.',
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

          if (hayCorreo) ResendConfirmationAction(email: email),

          SizedBox(height: t.space.md),
          Center(
            child: SButton.link(
              label: 'Volver al inicio de sesión',
              icon: Icons.arrow_back,
              // Navega a otra pantalla: se anuncia como enlace, no como botón.
              isNavigation: true,
              onPressed: backToLogin,
            ),
          ),
        ],
      ),
    );
  }
}
