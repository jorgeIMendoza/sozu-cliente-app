import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../core/version.dart';
import '../providers/auth_provider.dart';

/// Login: branding SOZU + email/contraseña. Tras autenticar valida rol
/// Cliente (perfil vía RPC); si no es cliente cierra sesión.
/// Solo web: Ctrl+Alt+A alterna el acceso de super administrador
/// (impersonación de clientes vía selector).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _formError;
  bool _adminMode = false;
  bool _obscurePassword = true;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (kIsWeb &&
        event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.keyA ||
            event.physicalKey == PhysicalKeyboardKey.keyA) &&
        HardwareKeyboard.instance.isControlPressed &&
        HardwareKeyboard.instance.isAltPressed) {
      setState(() => _adminMode = !_adminMode);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(inactivityLogoutProvider.notifier).state = false;
    setState(() {
      _submitting = true;
      _formError = null;
    });
    final auth = ref.read(authProvider);
    auth.loginEnCurso = true;
    try {
      await auth.signIn(_email.text, _password.text);
    } catch (_) {
      auth.loginEnCurso = false;
      setState(() {
        _formError = 'Correo o contraseña incorrectos.';
        _submitting = false;
      });
      return;
    }

    try {
      final perfil = await auth.refreshProfile();
      final esAdmin =
          (perfil?.rolNombre ?? '').trim().toLowerCase() ==
          'super administrador';
      if (_adminMode && esAdmin) {
        auth.loginEnCurso = false;
        if (!mounted) return;
        context.go(
          perfil!.debeCambiarPassword
              ? '/change-password'
              : '/seleccionar-cliente',
        );
        return;
      }
      if (perfil?.rolNombre != 'Cliente') {
        // Rol no permitido en este acceso (incluye admin sin modo admin):
        // mensaje genérico para no revelar cuentas existentes.
        await auth.signOut();
        auth.loginEnCurso = false;
        if (!mounted) return;
        setState(() {
          _formError = 'Correo o contraseña incorrectos.';
          _submitting = false;
        });
        return;
      }
      auth.loginEnCurso = false;
      if (!mounted) return;
      if (perfil!.debeCambiarPassword) {
        context.go('/change-password');
      } else {
        context.go('/inicio');
      }
    } catch (_) {
      await auth.signOut();
      auth.loginEnCurso = false;
      if (!mounted) return;
      setState(() {
        _formError = 'No pudimos verificar tu cuenta. Intenta de nuevo.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final porInactividad = ref.watch(inactivityLogoutProvider);
    return Scaffold(
      backgroundColor: tone.surface,
      body: Focus(
        canRequestFocus: false,
        onKeyEvent: _onKeyEvent,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Branding
                      Column(
                        children: [
                          Text(
                            'sozu',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1,
                              color: tone.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'PORTAL DEL CLIENTE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 3,
                              color: tone.textMuted,
                            ),
                          ),
                          if (_adminMode) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: tone.primarySoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.admin_panel_settings_outlined,
                                    size: 14,
                                    color: tone.primaryDark,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Acceso administrador',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: tone.primaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 40),

                      if (porInactividad) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: tone.primarySoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timer_off_outlined,
                                size: 18,
                                color: tone.primaryDark,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tu sesión se cerró por inactividad. '
                                  'Vuelve a iniciar sesión.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: tone.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Text('Correo electrónico', style: _labelStyle(tone)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          hintText: 'tucorreo@ejemplo.com',
                        ),
                        validator: (v) {
                          final t = v?.trim() ?? '';
                          if (t.isEmpty) return 'Ingresa tu correo';
                          if (!RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(t)) {
                            return 'Correo no válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      Text('Contraseña', style: _labelStyle(tone)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: tone.textMuted,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Ingresa tu contraseña'
                            : null,
                      ),

                      if (_formError != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: tone.negative.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _formError!,
                            style: TextStyle(
                              fontSize: 14,
                              color: tone.negative,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text('Iniciar sesión'),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        child: Text(
                          '¿Olvidaste tu contraseña?',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: tone.primaryDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        appVersionLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.5,
                          color: tone.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _labelStyle(SozuTone tone) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: tone.textSecondary,
  );
}
