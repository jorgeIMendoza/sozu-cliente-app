import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/biometric_service.dart';
import '../core/theme.dart';
import '../core/version.dart';
import '../providers/auth_provider.dart';
import 'auth_widgets.dart';

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
  bool _bioDisponible = false;
  bool _bioEnCurso = false;

  @override
  void initState() {
    super.initState();
    _prepararBiometria();
  }

  /// true si se puede ofrecer la entrada biométrica: con el candado puesto
  /// basta que esté habilitada (la sesión sigue viva, no se necesita token);
  /// sin sesión se requiere además el refresh token guardado.
  Future<bool> _bioParaLogin() async {
    if (ref.read(authProvider).locked) {
      return BiometricService.instance.habilitada();
    }
    return BiometricService.instance.disponibleParaLogin();
  }

  /// Si la biometría está habilitada, muestra el botón y dispara el prompt
  /// automáticamente (el botón queda como reintento).
  Future<void> _prepararBiometria() async {
    final disponible = await _bioParaLogin();
    if (!disponible || !mounted) return;
    setState(() => _bioDisponible = true);
    _loginBiometrico(auto: true);
  }

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
      // Acceso administrador: por permiso del rol (administrar_app_clientes),
      // ya no por el nombre "super administrador".
      final esAdmin = perfil?.administrarAppClientes ?? false;
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
      if (perfil!.debeCambiarPassword) {
        auth.loginEnCurso = false;
        if (!mounted) return;
        context.go('/change-password');
        return;
      }
      // Oferta de biometría ANTES de navegar y con loginEnCurso aún true:
      // el router no debe sacar al usuario de /login mientras el sheet está
      // abierto (cualquier notify re-evaluaría el redirect).
      if (await auth.debeOfrecerBiometria()) {
        if (mounted) await _ofrecerActivarBiometria();
      }
      auth.loginEnCurso = false;
      if (!mounted) return;
      context.go('/inicio');
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

  /// Bottom sheet post-login: activar el acceso con huella/rostro.
  /// "Ahora no" (o cerrar el sheet) no vuelve a insistir en esta ejecución.
  Future<void> _ofrecerActivarBiometria() async {
    final tone = SozuTone.of(context);
    final activar = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: tone.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          28,
          24,
          24 + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.fingerprint,
              size: 48,
              color: SozuColors.emerald500,
            ),
            const SizedBox(height: 16),
            Text(
              'Entra más rápido',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: tone.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '¿Quieres usar tu huella o rostro para entrar más rápido '
              'la próxima vez?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: tone.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Activar'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Ahora no',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: tone.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (activar == true) {
      final ok = await BiometricService.instance.habilitar();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo activar la biometría. Puedes hacerlo desde Perfil.',
            ),
          ),
        );
      }
    } else {
      BiometricService.instance.ofertaRechazada = true;
    }
  }

  /// Login con huella/rostro. [auto] = disparado al montar: si falla o se
  /// cancela no muestra error (queda el form y el botón como reintento).
  Future<void> _loginBiometrico({bool auto = false}) async {
    if (_bioEnCurso || _submitting) return;
    ref.read(inactivityLogoutProvider.notifier).state = false;
    setState(() {
      _bioEnCurso = true;
      _formError = null;
    });
    final auth = ref.read(authProvider);
    auth.loginEnCurso = true;
    // Con candado la sesión nunca se cerró: solo se desbloquea. El camino
    // con setSession (token guardado) queda como fallback cuando la sesión
    // local ya no existe (p.ej. Supabase no pudo restaurarla al arrancar).
    final ok = auth.locked
        ? await auth.unlockConBiometria()
        : await BiometricService.instance.loginBiometrico();
    if (!ok) {
      auth.loginEnCurso = false;
      // El token pudo haberse invalidado: re-evaluar si el botón sigue.
      final disponible = await _bioParaLogin();
      if (!mounted) return;
      setState(() {
        _bioEnCurso = false;
        _bioDisponible = disponible;
        if (!auto) {
          _formError = 'No pudimos validar tu identidad. '
              'Ingresa tu contraseña.';
        }
      });
      return;
    }
    try {
      final perfil = await auth.refreshProfile();
      if (perfil?.rolNombre != 'Cliente') {
        await auth.signOut();
        auth.loginEnCurso = false;
        if (!mounted) return;
        setState(() {
          _bioEnCurso = false;
          _formError = 'Correo o contraseña incorrectos.';
        });
        return;
      }
      auth.loginEnCurso = false;
      if (!mounted) return;
      context.go(perfil!.debeCambiarPassword ? '/change-password' : '/inicio');
    } catch (_) {
      await auth.signOut();
      auth.loginEnCurso = false;
      if (!mounted) return;
      setState(() {
        _bioEnCurso = false;
        _formError = 'No pudimos verificar tu cuenta. Intenta de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final porInactividad = ref.watch(inactivityLogoutProvider);
    return Focus(
      canRequestFocus: false,
      onKeyEvent: _onKeyEvent,
      child: AuthScaffold(
        child: Form(
          key: _formKey,
          child: AuthCard(
            children: [
              const AuthLogo(),
              const SizedBox(height: 28),
              const AuthTitle('Iniciar sesión'),
              const SizedBox(height: 10),
              _portalBadge(),
              const SizedBox(height: 10),
              const AuthSubtitle(
                'Ingresa tus credenciales para acceder al sistema',
              ),
              const SizedBox(height: 28),

              if (porInactividad) ...[
                const AuthAlert(
                  kind: AuthAlertKind.warning,
                  icon: Icons.schedule,
                  message: 'Tu sesión se cerró por inactividad. '
                      'Vuelve a iniciar sesión.',
                ),
                const SizedBox(height: 16),
              ],

              const AuthFieldLabel('Correo electrónico'),
              AuthTextField(
                controller: _email,
                hintText: 'tucorreo@ejemplo.com',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'Ingresa tu correo';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                    return 'Correo no válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              const AuthFieldLabel('Contraseña'),
              AuthTextField(
                controller: _password,
                hintText: '••••••••',
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword
                      ? 'Mostrar contraseña'
                      : 'Ocultar contraseña',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: AuthColors.textMuted,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
              ),

              if (_formError != null) ...[
                const SizedBox(height: 16),
                AuthAlert(
                  kind: AuthAlertKind.error,
                  icon: Icons.error_outline,
                  message: _formError!,
                ),
              ],

              const SizedBox(height: 20),
              AuthPrimaryButton(
                label: 'Iniciar sesión',
                icon: Icons.login,
                loading: _submitting,
                loadingLabel: 'Iniciando sesión...',
                onPressed: _submitting ? null : _submit,
              ),
              if (_bioDisponible) ...[
                const SizedBox(height: 12),
                AuthOutlineButton(
                  label: 'Entrar con huella o rostro',
                  loading: _bioEnCurso,
                  onPressed: (_submitting || _bioEnCurso)
                      ? null
                      : _loginBiometrico,
                  icon: _bioEnCurso
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AuthColors.focusRing,
                          ),
                        )
                      : const Icon(Icons.fingerprint),
                ),
              ],

              const SizedBox(height: 20),
              Center(
                child: AuthLink(
                  label: '¿Olvidaste tu contraseña?',
                  onPressed: () => context.push('/forgot-password'),
                ),
              ),

              const SizedBox(height: 20),
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AuthColors.separator),
                  ),
                ),
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  appVersionLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                    color: AuthColors.textMuted.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pastilla bajo el título: "Portal del cliente" por defecto; en modo
  /// administrador (Ctrl+Alt+A en web) cambia a "Acceso administrador".
  Widget _portalBadge() {
    final admin = _adminMode;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: admin ? const Color(0xFF334155) : AuthColors.gradientStart,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              admin ? Icons.admin_panel_settings_outlined : Icons.person_outline,
              size: 13,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              admin ? 'Acceso administrador' : 'Portal del cliente',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
