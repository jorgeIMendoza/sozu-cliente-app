import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/providers/auth_provider.dart';
import 'package:sozu_cliente_app/widgets/password_rules.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_alert.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_brand_image.dart';
import 'package:sozu_cliente_app/features/auth/components/biometric_setup_sheet.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_header.dart';
import 'package:sozu_cliente_app/features/auth/layouts/auth_layout.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Cambio OBLIGATORIO de contraseña temporal (debe_cambiar_password=true).
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
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
    // deja de exigir el cambio, el redirect abandona esta ruta y se llevaría el
    // sheet de biometría a medias.
    auth.authFlowInProgress = true;
    try {
      await auth.updatePassword(_pwd.text);
      // Pide guardar la contrasena nueva. Sin esto el gestor se queda con la
      // temporal, que ya no sirve para entrar.
      TextInput.finishAutofillContext();
      // Recién ahora se ofrece la huella: la credencial ya es la definitiva.
      // Aplica igual a cliente y a administrador.
      if (mounted) await offerBiometricSetup(context, auth);
      auth.authFlowInProgress = false;
      // Se conserva la sesión a propósito: no hay signOut tras el cambio.
      // A /inicio para los dos: el router manda al administrador a
      // /seleccionar-cliente por su permiso de rol.
      if (mounted) context.go('/inicio');
    } catch (_) {
      auth.authFlowInProgress = false;
      setState(() {
        _formError = 'No pudimos actualizar la contraseña. Intenta de nuevo.';
        _submitting = false;
      });
    }
  }

  Future<void> _cerrarSesion() async {
    await ref.read(authProvider).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return AuthLayout(
      brand: const AuthBrandImage(),
      child: AuthFormBody(
        children: [
          const AuthLogo(),
          SizedBox(height: t.space.lg),
          const AuthTitle('Cambiar Contraseña'),
          SizedBox(height: t.space.xs),
          const AuthSubtitle(
            'Por seguridad, debes cambiar tu contraseña temporal antes de '
            'continuar',
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
                    validator: (v) => passwordValida(v ?? '')
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
                    style: context.s.text.label.copyWith(
                      color: context.s.color.fgMuted,
                    ),
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
              onPressed: _cerrarSesion,
            ),
          ),
        ],
      ),
    );
  }
}
