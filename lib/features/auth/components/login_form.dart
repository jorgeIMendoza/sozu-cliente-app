import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sozu_cliente_app/core/biometric_service.dart';
import 'package:sozu_cliente_app/core/version.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_alert.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_header.dart';
import 'package:sozu_cliente_app/features/auth/layouts/auth_layout.dart';
import 'package:sozu_cliente_app/providers/auth_provider.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Formulario de acceso: correo + contraseña, biometría, modo administrador y la
/// navegación posterior al login.
///
/// Concentra TODO el estado y la lógica del acceso. La pantalla
/// (`screens/login_screen.dart`) solo lo coloca dentro del andamio, así que este
/// widget se puede montar aislado en un test o reubicar sin arrastrar el layout.
///
/// Tras autenticar valida el rol Cliente (perfil vía RPC); si no es cliente,
/// cierra sesión.
///
/// Solo web: Ctrl+Shift+A (o Ctrl+Alt+A) alterna el acceso de administrador
/// (impersonación de clientes vía selector). Ver [_onKeyEvent].
class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  String? _formError;
  bool _isAdminMode = false;
  bool _isBiometricAvailable = false;
  bool _isBiometricRunning = false;

  @override
  void initState() {
    super.initState();
    // Handler global del teclado: no depende de que algún widget tenga el foco
    // (ver [_onKeyEvent]).
    if (kIsWeb) HardwareKeyboard.instance.addHandler(_onKeyEvent);
    _prepareBiometrics();
  }

  @override
  void dispose() {
    if (kIsWeb) HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Biometría
  // -------------------------------------------------------------------------

  /// true si se puede ofrecer la entrada biométrica: con el candado puesto basta
  /// que esté habilitada (la sesión sigue viva, no se necesita token); sin sesión
  /// se requiere además el refresh token guardado.
  Future<bool> _canUseBiometricLogin() async {
    if (ref.read(authProvider).locked) {
      return BiometricService.instance.habilitada();
    }
    return BiometricService.instance.disponibleParaLogin();
  }

  /// Si la biometría está habilitada, muestra el botón y dispara el prompt
  /// automáticamente (el botón queda como reintento).
  Future<void> _prepareBiometrics() async {
    final isAvailable = await _canUseBiometricLogin();
    if (!isAvailable || !mounted) return;
    setState(() => _isBiometricAvailable = true);
    // Fire-and-forget a proposito: el prompt biometrico corre en paralelo y el
    // formulario ya esta usable mientras el usuario decide.
    unawaited(_signInWithBiometrics(isAutomatic: true));
  }

  // -------------------------------------------------------------------------
  // Atajo de modo administrador
  // -------------------------------------------------------------------------

  /// Alterna el modo administrador con **Ctrl+Shift+A** o **Ctrl+Alt+A**.
  ///
  /// Va montado en `HardwareKeyboard` (handler global) y no en un `Focus`: un
  /// `Focus` solo recibe teclas cuando él o un descendiente tienen el foco, así
  /// que al cargar el login -con nada enfocado todavía- el atajo se perdía.
  ///
  /// Chrome/Edge se quedan Ctrl+Shift+A para su buscador de pestañas y la página
  /// no puede cancelarlo; por eso Ctrl+Alt+A queda como equivalente.
  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final keyboard = HardwareKeyboard.instance;
    final isKeyA =
        event.logicalKey == LogicalKeyboardKey.keyA ||
        event.physicalKey == PhysicalKeyboardKey.keyA;
    if (!isKeyA || !keyboard.isControlPressed) return false;
    if (!keyboard.isShiftPressed && !keyboard.isAltPressed) return false;
    if (mounted) setState(() => _isAdminMode = !_isAdminMode);
    return true; // consumido: no llega al campo de texto enfocado
  }

  // -------------------------------------------------------------------------
  // Acceso con contraseña
  // -------------------------------------------------------------------------

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(inactivityLogoutProvider.notifier).state = false;
    setState(() {
      _isSubmitting = true;
      _formError = null;
    });
    final auth = ref.read(authProvider);
    auth.loginEnCurso = true;
    try {
      await auth.signIn(_emailController.text, _passwordController.text);
      // Cierra el contexto de autofill PIDIENDO guardar. Es la mitad que faltaba:
      // `AutofillGroup` + `autofillHints` hacen que el gestor de contrasenas
      // RECONOZCA el formulario, pero el "quieres guardar esta contrasena?" solo
      // aparece cuando la app avisa que la credencial se uso con exito.
      //
      // Va aqui y no en el `finally`: solo se guarda lo que de verdad funciono.
      // Guardar tras un fallo entrenaria al gestor con una contrasena mala.
      TextInput.finishAutofillContext();
    } catch (e) {
      auth.loginEnCurso = false;
      setState(() {
        _formError = AuthController.mensajeErrorAcceso(e);
        _isSubmitting = false;
      });
      return;
    }

    try {
      final profile = await auth.refreshProfile();
      // Acceso administrador: por permiso del rol (administrar_app_clientes),
      // ya no por el nombre "super administrador".
      final isAdmin = profile?.administrarAppClientes ?? false;
      if (_isAdminMode && isAdmin) {
        auth.loginEnCurso = false;
        if (!mounted) return;
        context.go(
          profile!.debeCambiarPassword
              ? '/change-password'
              : '/seleccionar-cliente',
        );
        return;
      }
      if (profile?.rolNombre != 'Cliente') {
        // Rol no permitido en este acceso (incluye admin sin modo admin):
        // mensaje genérico para no revelar cuentas existentes.
        await auth.signOut();
        auth.loginEnCurso = false;
        if (!mounted) return;
        setState(() {
          _formError = 'Correo o contraseña incorrectos.';
          _isSubmitting = false;
        });
        return;
      }
      if (profile!.debeCambiarPassword) {
        auth.loginEnCurso = false;
        if (!mounted) return;
        context.go('/change-password');
        return;
      }
      // Oferta de biometría ANTES de navegar y con loginEnCurso aún true: el
      // router no debe sacar al usuario de /login mientras el sheet está abierto
      // (cualquier notify re-evaluaría el redirect).
      if (await auth.debeOfrecerBiometria()) {
        if (mounted) await _offerBiometricSetup();
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
        _isSubmitting = false;
      });
    }
  }

  /// Bottom sheet post-login: activar el acceso con huella/rostro.
  /// "Ahora no" (o cerrar el sheet) no vuelve a insistir en esta ejecución.
  Future<void> _offerBiometricSetup() async {
    final t = context.s;
    final shouldEnable = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: t.color.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(t.radius.card),
        ),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          t.space.lg,
          t.space.lg + 4,
          t.space.lg,
          t.space.lg + MediaQuery.of(sheetContext).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.fingerprint, size: 48, color: t.color.primary),
            SizedBox(height: t.space.md),
            Text(
              'Entra más rápido',
              textAlign: TextAlign.center,
              style: t.text.h3.copyWith(color: t.color.fg),
            ),
            SizedBox(height: t.space.xs),
            Text(
              '¿Quieres usar tu huella o rostro para entrar más rápido '
              'la próxima vez?',
              textAlign: TextAlign.center,
              style: t.text.bodySmall.copyWith(color: t.color.fgMuted),
            ),
            SizedBox(height: t.space.lg),
            FilledButton(
              onPressed: () => Navigator.pop(sheetContext, true),
              child: const Text('Activar'),
            ),
            SizedBox(height: t.space.xs),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext, false),
              child: Text(
                'Ahora no',
                style: t.text.label.copyWith(color: t.color.fgMuted),
              ),
            ),
          ],
        ),
      ),
    );
    if (shouldEnable == true) {
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

  /// Login con huella/rostro. [isAutomatic] = disparado al montar: si falla o se
  /// cancela no muestra error (queda el formulario y el botón como reintento).
  Future<void> _signInWithBiometrics({bool isAutomatic = false}) async {
    if (_isBiometricRunning || _isSubmitting) return;
    ref.read(inactivityLogoutProvider.notifier).state = false;
    setState(() {
      _isBiometricRunning = true;
      _formError = null;
    });
    final auth = ref.read(authProvider);
    auth.loginEnCurso = true;
    // Con candado la sesión nunca se cerró: solo se desbloquea. El camino con
    // setSession (token guardado) queda como fallback cuando la sesión local ya
    // no existe (p.ej. Supabase no pudo restaurarla al arrancar).
    final ok = auth.locked
        ? await auth.unlockConBiometria()
        : await BiometricService.instance.loginBiometrico();
    if (!ok) {
      auth.loginEnCurso = false;
      // El token pudo haberse invalidado: re-evaluar si el botón sigue.
      final isAvailable = await _canUseBiometricLogin();
      if (!mounted) return;
      setState(() {
        _isBiometricRunning = false;
        _isBiometricAvailable = isAvailable;
        if (!isAutomatic) {
          _formError =
              'No pudimos validar tu identidad. Ingresa tu contraseña.';
        }
      });
      return;
    }
    try {
      final profile = await auth.refreshProfile();
      if (profile?.rolNombre != 'Cliente') {
        await auth.signOut();
        auth.loginEnCurso = false;
        if (!mounted) return;
        setState(() {
          _isBiometricRunning = false;
          _formError = 'Correo o contraseña incorrectos.';
        });
        return;
      }
      auth.loginEnCurso = false;
      if (!mounted) return;
      context.go(profile!.debeCambiarPassword ? '/change-password' : '/inicio');
    } catch (_) {
      await auth.signOut();
      auth.loginEnCurso = false;
      if (!mounted) return;
      setState(() {
        _isBiometricRunning = false;
        _formError = 'No pudimos verificar tu cuenta. Intenta de nuevo.';
      });
    }
  }

  /// Abre el onboarding de registro de propiedad (portal de propietarios).
  Future<void> _openPropertyRegistration() async {
    final uri = Uri.parse('https://propietarios.sozu.com/registrar-propiedad');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el registro.')),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final loggedOutByInactivity = ref.watch(inactivityLogoutProvider);
    final isSplit = context.bp.isDesktop;

    // AutofillGroup es lo que le dice a la plataforma "estos campos son UNA
    // credencial". Sin el, `autofillHints` en los campos no alcanza: el navegador
    // no reconoce el par correo+contrasena como formulario de acceso, asi que ni
    // autocompleta ni ofrece guardar. En Flutter web, este widget es el que hace
    // que el motor emita los inputs nativos ocultos que el gestor de contrasenas
    // necesita ver.
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: AuthFormBody(
          children: [
            const AuthLogo(),
            SizedBox(height: isSplit ? 0 : t.space.lg),
            const AuthTitle('Iniciar sesión'),
            SizedBox(height: t.space.xs),
            const AuthSubtitle('Entra a tu portal para seguir tu inversión.'),

            // La pastilla solo aparece cuando el atajo activa el modo
            // administrador, que es cuando de verdad comunica algo.
            if (_isAdminMode) ...[
              SizedBox(height: t.space.sm),
              const _AdminModeBadge(),
            ],

            SizedBox(height: t.space.lg),

            if (loggedOutByInactivity) ...[
              const AuthAlert(
                kind: AuthAlertKind.warning,
                icon: Icons.schedule,
                message:
                    'Tu sesión se cerró por inactividad. '
                    'Vuelve a iniciar sesión.',
              ),
              SizedBox(height: t.space.md),
            ],

            STextField(
              controller: _emailController,
              label: 'Correo electrónico',
              hint: 'tucorreo@ejemplo.com',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              // Solo en escritorio: en móvil dispararía el teclado al entrar.
              autofocus: isSplit,
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return 'Ingresa tu correo';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return 'Correo no válido';
                }
                return null;
              },
            ),
            SizedBox(height: t.space.sm),

            // El ojo de mostrar/ocultar lo trae el propio campo: la pantalla no
            // guarda ningún `bool` de visibilidad.
            STextField.password(
              controller: _passwordController,
              label: 'Contraseña',
              hint: '••••••••',
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Ingresa tu contraseña'
                  : null,
            ),

            if (_formError != null) ...[
              SizedBox(height: t.space.sm),
              AuthAlert(
                kind: AuthAlertKind.error,
                icon: Icons.error_outline,
                message: _formError!,
              ),
            ],

            SizedBox(height: t.space.md),
            // lg: es la acción principal del formulario y empareja el alto de los
            // campos (52 px). Con el tamaño por defecto (44) quedaría más bajo que
            // el campo que tiene encima.
            SButton(
              label: 'Iniciar sesión',
              size: SButtonSize.lg,
              loading: _isSubmitting,
              loadingLabel: 'Iniciando sesión...',
              onPressed: _isSubmitting ? null : _submit,
            ),

            if (_isBiometricAvailable) ...[
              SizedBox(height: t.space.xs),
              // El spinner de carga lo pone `loading`: el icono se queda como
              // `IconData` y el botón decide cuándo lo reemplaza.
              SButton.secondary(
                label: 'Entrar con huella o rostro',
                size: SButtonSize.lg,
                icon: Icons.fingerprint,
                loading: _isBiometricRunning,
                onPressed: (_isSubmitting || _isBiometricRunning)
                    ? null
                    : _signInWithBiometrics,
              ),
            ],

            SizedBox(height: t.space.xs),
            const Align(
              alignment: kAuthAlignment,
              child: _ForgotPasswordLink(),
            ),

            SizedBox(height: t.space.md),
            _RegistrationLine(onTap: _openPropertyRegistration),

            SizedBox(height: t.space.lg),
            Text(
              appVersionLabel,
              textAlign: TextAlign.center,
              style: t.text.overline.copyWith(
                color: t.color.fgSubtle.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForgotPasswordLink extends StatelessWidget {
  const _ForgotPasswordLink();

  @override
  Widget build(BuildContext context) => SButton.link(
    label: '¿Olvidaste tu contraseña?',
    // Navega a otra pantalla: se anuncia como enlace, no como botón.
    isNavigation: true,
    onPressed: () => context.push('/forgot-password'),
  );
}

/// Pastilla de "Acceso administrador". Solo se pinta cuando el atajo
/// (Ctrl+Shift+A / Ctrl+Alt+A) activa el modo admin: es el único indicio de que
/// surtió efecto, así que tiene que ser inequívoco.
class _AdminModeBadge extends StatelessWidget {
  const _AdminModeBadge();

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Align(
      alignment: kAuthAlignment,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.sm,
          vertical: t.space.xxs + 2,
        ),
        decoration: BoxDecoration(
          color: t.color.fg,
          borderRadius: t.radius.mdBorder,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.admin_panel_settings_outlined,
              size: 14,
              color: t.color.surface,
            ),
            SizedBox(width: t.space.xxs + 2),
            Text(
              'Acceso administrador',
              style: t.text.overline.copyWith(color: t.color.surface),
            ),
          ],
        ),
      ),
    );
  }
}

/// Línea de registro de propietarios: texto plano + enlace, sin caja.
///
/// Una acción secundaria no necesita tarjeta, icono ni bajada; con eso pesaba
/// visualmente más que el botón de entrar.
class _RegistrationLine extends StatelessWidget {
  const _RegistrationLine({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final linkColor = t.color.primaryHover;

    return Semantics(
      link: true,
      label:
          'Registrar mi propiedad. Abre el portal de dueños en una ventana '
          'nueva.',
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: '¿Ya eres dueño de una propiedad SOZU? '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onTap,
                  child: Text(
                    'Regístrala',
                    style: t.text.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: linkColor,
                      decoration: TextDecoration.underline,
                      decorationColor: linkColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        style: t.text.bodySmall.copyWith(color: t.color.fgMuted),
      ),
    );
  }
}
