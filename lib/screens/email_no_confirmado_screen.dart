import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/api_client.dart';
import '../providers/auth_provider.dart';
import 'auth_widgets.dart';

/// Ruta de la pantalla de bloqueo por correo sin confirmar. Vive aquí (y no en
/// router.dart) para que el login pueda navegar a ella sin importar el router.
const emailNoConfirmadoPath = '/confirma-tu-correo';

/// Bloqueo para los roles de portal (`roles.requiere_confirmacion_email`) cuyo
/// correo todavía no está verificado. Espejo del `EmailNoConfirmado.tsx` del
/// portal web, adaptado al hecho de que aquí la sesión YA está cerrada: el gate
/// hace `signOut()` y deja el correo en `AuthController.emailBloqueado`, así que
/// esta pantalla no puede releer el perfil ("Ya confirmé mi correo" no aplica) y
/// devuelve al login para que el usuario entre de nuevo.
class EmailNoConfirmadoScreen extends ConsumerStatefulWidget {
  const EmailNoConfirmadoScreen({super.key});

  @override
  ConsumerState<EmailNoConfirmadoScreen> createState() =>
      _EmailNoConfirmadoScreenState();
}

class _EmailNoConfirmadoScreenState
    extends ConsumerState<EmailNoConfirmadoScreen> {
  bool _enviando = false;
  bool _enviado = false;
  String? _mensaje;
  bool _mensajeEsError = false;

  void _volverALogin() {
    // Limpiar primero: el router mantiene esta pantalla mientras el bloqueo
    // esté puesto.
    ref.read(authProvider).limpiarBloqueo();
    if (mounted) context.go('/login');
  }

  Future<void> _reenviar(String email) async {
    setState(() {
      _enviando = true;
      _mensaje = null;
    });

    var ok = false;
    String? motivo;
    try {
      final res = await invokeAnonFunction(
        'reenviar-confirmacion-email',
        body: {'email': email},
      );
      ok = res.status >= 200 && res.status < 300 && res.body['success'] != false;
      final msg = res.body['message'];
      if (msg is String && msg.isNotEmpty) motivo = msg;
    } catch (_) {
      // Sin red o gateway caído: mensaje genérico abajo.
    }

    if (!mounted) return;
    setState(() {
      _enviando = false;
      _enviado = ok;
      _mensajeEsError = !ok;
      _mensaje = ok
          ? 'Te enviamos un correo nuevo. Revisa tu bandeja de entrada y la '
                'carpeta de spam.'
          : (motivo ?? 'No pudimos reenviar el correo. Contacta a soporte.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authProvider).emailBloqueado;

    return AuthScaffold(
      child: AuthCard(
        children: [
          const AuthLogo(),
          const SizedBox(height: 28),
          const Icon(
            Icons.mark_email_unread_outlined,
            size: 56,
            color: AuthColors.warnText,
          ),
          const SizedBox(height: 16),
          const AuthTitle('Confirma tu correo'),
          const SizedBox(height: 12),
          AuthSubtitle(
            email == null || email.isEmpty
                ? 'Para entrar necesitas verificar tu correo. Abre el enlace '
                      'que te enviamos y vuelve a iniciar sesión.'
                : 'Para entrar necesitas verificar $email. Abre el enlace que '
                      'te enviamos por correo; si ya no lo tienes, pide uno '
                      'nuevo aquí.',
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
                    'Revisa tu bandeja de entrada (y la carpeta de spam). Al '
                    'confirmar podrás definir tu contraseña y entrar con ella.',
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

          if (_mensaje != null) ...[
            const SizedBox(height: 16),
            AuthAlert(
              kind: _mensajeEsError ? AuthAlertKind.error : AuthAlertKind.info,
              icon: _mensajeEsError
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
              message: _mensaje!,
            ),
          ],

          if (email != null && email.isNotEmpty && !_enviado) ...[
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: 'Reenviar correo de confirmación',
              icon: Icons.forward_to_inbox,
              loading: _enviando,
              loadingLabel: 'Enviando...',
              onPressed: _enviando ? null : () => _reenviar(email),
            ),
          ],

          const SizedBox(height: 20),
          Center(
            child: AuthLink(
              label: 'Volver al inicio de sesión',
              icon: Icons.arrow_back,
              onPressed: _volverALogin,
            ),
          ),
        ],
      ),
    );
  }
}
