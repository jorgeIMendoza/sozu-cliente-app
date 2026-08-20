import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/features/auth/components/auth_alert.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_header.dart';
import 'package:sozu_cliente_app/features/auth/layouts/auth_layout.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Canjea el token del enlace de confirmación y pinta el avance.
///
/// Solo tiene dos estados visibles: canjeando y error. El éxito no se pinta
/// porque navega, y detenerse a decir "listo" con la sesión ya abierta solo
/// agrega un toque.
class EmailConfirmationStatus extends ConsumerStatefulWidget {
  const EmailConfirmationStatus({
    super.key,
    this.tokenHash,
    this.type,
    this.email,
    this.nombre,
  });

  final String? tokenHash;
  final String? type;
  final String? email;
  final String? nombre;

  @override
  ConsumerState<EmailConfirmationStatus> createState() =>
      _EmailConfirmationStatusState();
}

enum _Estado { verificando, error }

class _EmailConfirmationStatusState
    extends ConsumerState<EmailConfirmationStatus> {
  _Estado _estado = _Estado.verificando;
  String _mensaje = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _confirmar());
  }

  Future<void> _confirmar() async {
    final auth = ref.read(authProvider);
    final token = widget.tokenHash;
    if (token == null || token.isEmpty) {
      _fallar(
        'El enlace está incompleto. Pide uno nuevo desde "¿Olvidaste tu '
        'contraseña?".',
      );
      return;
    }

    // El candado evita que el guard del router se lleve la pantalla en cuanto
    // verifyOtp abra la sesión, a media confirmación.
    auth.authFlowInProgress = true;
    try {
      await auth.confirmEmailLink(
        tokenHash: token,
        type: widget.type ?? 'magiclink',
        email: widget.email,
        nombre: widget.nombre,
      );
    } catch (e) {
      auth.authFlowInProgress = false;
      _fallar(AuthController.confirmEmailErrorMessage(e));
      return;
    }
    auth.authFlowInProgress = false;
    if (!mounted) return;
    // Con la sesión abierta y `debe_cambiar_password` en true, el guard manda
    // solo a /change-password; se navega a /inicio y él decide.
    context.go('/inicio');
  }

  void _fallar(String mensaje) {
    if (!mounted) return;
    setState(() {
      _estado = _Estado.error;
      _mensaje = mensaje;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return AuthFormBody(
      children: [
        const AuthLogo(),
        SizedBox(height: t.space.lg),
        if (_estado == _Estado.verificando) ...[
          const Center(child: CircularProgressIndicator()),
          SizedBox(height: t.space.lg),
          const AuthTitle('Confirmando tu correo'),
          SizedBox(height: t.space.xs),
          const AuthSubtitle('Esto tarda solo un momento.'),
        ] else ...[
          Icon(Icons.error_outline, size: 56, color: t.color.danger),
          SizedBox(height: t.space.md),
          const AuthTitle('No pudimos confirmar tu correo'),
          SizedBox(height: t.space.md),
          AuthAlert(
            kind: AuthAlertKind.error,
            icon: Icons.error_outline,
            message: _mensaje,
          ),
          SizedBox(height: t.space.lg),
          SButton(
            label: 'Ir a iniciar sesión',
            size: SButtonSize.lg,
            onPressed: () => context.go('/login'),
          ),
        ],
      ],
    );
  }
}
