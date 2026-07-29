import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/providers/auth_provider.dart';
import 'package:sozu_cliente_app/widgets/password_rules.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_alert.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_brand_image.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_buttons.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_header.dart';
import 'package:sozu_cliente_app/features/auth/layouts/auth_layout.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_text_field.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Cambio OBLIGATORIO de contraseña temporal (debe_cambiar_password=true).
/// Réplica del card del portal admin (`auth/ChangePassword.tsx`): misma tarjeta
/// blanca de auth, logo SOZU, textos y checklist de requisitos.
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
                  SizedBox(height: t.space.md),
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
                      color: context.s.color.fgMuted,
                    ),
                    onPressed: () => setState(() => _showPwd = !_showPwd),
                  ),
                  validator: (v) => passwordValida(v ?? '')
                      ? null
                      : 'Cumple todas las reglas',
                ),
                SizedBox(height: t.space.md),

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
                      color: context.s.color.fgMuted,
                    ),
                    onPressed: () =>
                        setState(() => _showConfirm = !_showConfirm),
                  ),
                  validator: (v) =>
                      v == _pwd.text ? null : 'Las contraseñas no coinciden',
                ),
                SizedBox(height: t.space.md),

                // Checklist de requisitos con encabezado (como el portal).
                Text(
                  'Requisitos:',
                  style: context.s.text.label.copyWith(
                    color: context.s.color.fgMuted,
                  ),
                ),
                SizedBox(height: t.space.xs),
                PasswordRulesChecklist(value: _pwdValue),
                SizedBox(height: t.space.md),

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
          SizedBox(height: t.space.md),
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
