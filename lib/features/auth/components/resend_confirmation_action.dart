import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/features/auth/components/auth_alert.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Botón de "reenviar correo de confirmación" con su resultado.
///
/// Al enviarse bien el botón desaparece y queda el aviso: pedir enlaces en
/// cadena solo invalida el anterior y hace creer que ninguno llegó.
class ResendConfirmationAction extends ConsumerStatefulWidget {
  const ResendConfirmationAction({super.key, required this.email});

  /// Correo bloqueado. Sin él no hay a dónde reenviar y el botón no se pinta.
  final String email;

  @override
  ConsumerState<ResendConfirmationAction> createState() =>
      _ResendConfirmationActionState();
}

class _ResendConfirmationActionState
    extends ConsumerState<ResendConfirmationAction> {
  bool _sending = false;
  bool _sent = false;
  String? _message;
  bool _messageIsError = false;

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _message = null;
    });

    String? error;
    try {
      await ref.read(authProvider).resendEmailConfirmation(widget.email);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        if (!_sent) ...[
          SizedBox(height: t.space.md),
          SButton(
            label: 'Reenviar correo de confirmación',
            size: SButtonSize.lg,
            icon: Icons.forward_to_inbox,
            loading: _sending,
            loadingLabel: 'Enviando...',
            onPressed: _sending ? null : _resend,
          ),
        ],
      ],
    );
  }
}
