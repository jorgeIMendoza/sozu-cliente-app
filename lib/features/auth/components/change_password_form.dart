import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/features/auth/components/auth_alert.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_header.dart';
import 'package:sozu_cliente_app/features/auth/components/password_rules.dart';
import 'package:sozu_cliente_app/features/auth/layouts/auth_layout.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Formulario del cambio OBLIGATORIO de contraseña. Al terminar cierra la
/// sesión y devuelve al login: la contraseña temporal la conoce quien la envió.
class ChangePasswordForm extends ConsumerStatefulWidget {
  const ChangePasswordForm({super.key});

  @override
  ConsumerState<ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends ConsumerState<ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _pwd = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;
  String? _formError;
  String _pwdValue = '';

  @override
  void initState() {
    super.initState();
    // Se escucha el CONTROLLER y no `onChanged`: el controller también avisa de
    // los cambios que no vienen del teclado (autocompletado del gestor).
    _pwd.addListener(() {
      if (_pwdValue != _pwd.text) {
        setState(() => _pwdValue = _pwd.text);
      }
    });
  }

  @override
  void dispose() {
    _pwd.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _formError = null;
    });
    final auth = ref.read(authProvider);
    // El candado tiene que ponerse ANTES de updatePassword: en cuanto el perfil
    // deja de exigir el cambio, el redirect abandona esta ruta y el cierre de
    // sesión quedaría a medias.
    auth.authFlowInProgress = true;
    try {
      await auth.updatePassword(_pwd.text);
      // Pide guardar la contrasena nueva. Sin esto el gestor se queda con la
      // temporal, que ya no sirve para entrar.
      TextInput.finishAutofillContext();
      // Se CIERRA la sesión a propósito: la contraseña temporal la conoce quien
      // la mandó por correo, así que la sesión que abrió con ella no se hereda.
      // El usuario vuelve a entrar con la definitiva y ahí (login_form) recibe
      // la oferta de biometría, ya atada a la credencial buena.
      await auth.signOut();
      ref.read(passwordChangedProvider.notifier).state = true;
      auth.authFlowInProgress = false;
      if (mounted) context.go('/login');
    } catch (e) {
      auth.authFlowInProgress = false;
      if (!mounted) return;
      setState(() {
        _formError = AuthController.changePasswordErrorMessage(e);
        _submitting = false;
      });
    }
  }

  Future<void> _signOut() async {
    await ref.read(authProvider).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return AuthFormBody(
      children: [
        const AuthLogo(),
        SizedBox(height: t.space.lg),
        const AuthTitle('Cambiar Contraseña'),
        SizedBox(height: t.space.xs),
        // "Tu contraseña temporal" ya no siempre es cierto: quien abre el
        // enlace de recuperación aterriza aquí conservando la suya (el modo
        // público de reset-user-password no toca la cuenta a propósito), y
        // hablarle de una temporal lo empujaba a teclear la que ya tenía, que
        // el backend rechaza. Neutral sirve para los dos caminos.
        const AuthSubtitle(
          'Por seguridad, define una contraseña nueva antes de continuar',
        ),
        SizedBox(height: t.space.lg),
        // No quitar: sin AutofillGroup el gestor de contrasenas no reconoce
        // el formulario ni ofrece guardar la contrasena NUEVA.
        AutofillGroup(
          child: Form(
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

                STextField.password(
                  controller: _pwd,
                  label: 'Nueva contraseña',
                  hint: '••••••••',
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  validator: (v) => isValidPassword(v ?? '')
                      ? null
                      : 'Cumple todas las reglas',
                ),
                SizedBox(height: t.space.md),

                STextField.password(
                  controller: _confirm,
                  label: 'Confirmar contraseña',
                  hint: '••••••••',
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: (v) =>
                      v == _pwd.text ? null : 'Las contraseñas no coinciden',
                ),
                SizedBox(height: t.space.md),

                Text(
                  'Requisitos:',
                  style: t.text.label.copyWith(color: t.color.fgMuted),
                ),
                SizedBox(height: t.space.xs),
                PasswordRulesChecklist(value: _pwdValue),
                SizedBox(height: t.space.md),

                // lg: acción principal, al mismo alto que los campos.
                SButton(
                  label: 'Cambiar Contraseña',
                  size: SButtonSize.lg,
                  icon: Icons.vpn_key_outlined,
                  loading: _submitting,
                  loadingLabel: 'Cambiando contraseña...',
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: t.space.md),
        Center(
          child: SButton.link(
            label: 'Cerrar sesión',
            icon: Icons.logout,
            onPressed: _signOut,
          ),
        ),
      ],
    );
  }
}
