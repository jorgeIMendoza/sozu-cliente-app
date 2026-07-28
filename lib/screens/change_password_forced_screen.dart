import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../widgets/password_rules.dart';
import 'auth_widgets.dart';

/// Cambio OBLIGATORIO de contraseña temporal (debe_cambiar_password=true).
/// Réplica del card del portal admin (`auth/ChangePassword.tsx`): misma tarjeta
/// blanca de auth, logo SOZU, textos y checklist de requisitos.
class ChangePasswordForcedScreen extends ConsumerStatefulWidget {
  const ChangePasswordForcedScreen({super.key});

  @override
  ConsumerState<ChangePasswordForcedScreen> createState() =>
      _ChangePasswordForcedScreenState();
}

class _ChangePasswordForcedScreenState
    extends ConsumerState<ChangePasswordForcedScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pwd = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;
  String? _formError;
  String _pwdValue = '';
  bool _showPwd = false;
  bool _showConfirm = false;

  @override
  void initState() {
    super.initState();
    // El checklist de reglas se actualiza en vivo; AuthTextField no expone
    // onChanged, así que escuchamos el controller directamente.
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
    try {
      await ref.read(authProvider).updatePassword(_pwd.text);
      // Divergencia intencional con el portal admin: allá se hace
      // signOut → /login tras cambiar la contraseña. Aquí la app conserva la
      // sesión por diseño (SecureSessionStorage / biometría), así que tras el
      // éxito entramos directo a /inicio sin cerrar sesión.
      if (mounted) context.go('/inicio');
    } catch (_) {
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
    return AuthScaffold(
      child: AuthCard(
        children: [
          const AuthLogo(),
          const SizedBox(height: 28),
          const AuthTitle('Cambiar Contraseña'),
          const SizedBox(height: 10),
          const AuthSubtitle(
            'Por seguridad, debes cambiar tu contraseña temporal antes de '
            'continuar',
          ),
          const SizedBox(height: 28),
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
                  const SizedBox(height: 16),
                ],

                const AuthFieldLabel('Nueva contraseña'),
                AuthTextField(
                  controller: _pwd,
                  hintText: '••••••••',
                  obscureText: !_showPwd,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  suffixIcon: IconButton(
                    tooltip: _showPwd
                        ? 'Ocultar contraseña'
                        : 'Mostrar contraseña',
                    icon: Icon(
                      _showPwd
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: AuthColors.textMuted,
                    ),
                    onPressed: () => setState(() => _showPwd = !_showPwd),
                  ),
                  validator: (v) =>
                      passwordValida(v ?? '') ? null : 'Cumple todas las reglas',
                ),
                const SizedBox(height: 16),

                const AuthFieldLabel('Confirmar contraseña'),
                AuthTextField(
                  controller: _confirm,
                  hintText: '••••••••',
                  obscureText: !_showConfirm,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  suffixIcon: IconButton(
                    tooltip: _showConfirm
                        ? 'Ocultar contraseña'
                        : 'Mostrar contraseña',
                    icon: Icon(
                      _showConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: AuthColors.textMuted,
                    ),
                    onPressed: () =>
                        setState(() => _showConfirm = !_showConfirm),
                  ),
                  validator: (v) =>
                      v == _pwd.text ? null : 'Las contraseñas no coinciden',
                ),
                const SizedBox(height: 20),

                // Checklist de requisitos con encabezado (como el portal).
                const Text(
                  'Requisitos:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AuthColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                PasswordRulesChecklist(value: _pwdValue),
                const SizedBox(height: 20),

                AuthPrimaryButton(
                  label: 'Cambiar Contraseña',
                  icon: Icons.vpn_key_outlined,
                  loading: _submitting,
                  loadingLabel: 'Cambiando contraseña...',
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: AuthLink(
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
