import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sozu_cliente_app/features/auth/services/biometric_service.dart';
import 'package:sozu_cliente_app/features/auth/components/biometric_setup_sheet.dart';
import 'package:sozu_cliente_app/core/version.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_alert.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_header.dart';
import 'package:sozu_cliente_app/features/auth/layouts/auth_layout.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Formulario de acceso: correo + contraseña, biometría, modo administrador y la
/// navegación posterior al login. Concentra el estado y la lógica del acceso.
///
/// Tras autenticar valida el rol Cliente (perfil vía RPC); si no es cliente,
/// cierra sesión.
///
/// El modo administrador (impersonación de clientes) se alterna por dos vías,
/// ambas vía [_toggleAdminMode]: long-press de 1.5 s sobre el sello de versión
/// ([_VersionStamp], todas las plataformas) y Ctrl+Shift+A / Ctrl+Alt+A (solo
/// web, ver [_onKeyEvent]).
///
/// El gesto NO es una frontera de seguridad: solo pinta la pastilla y cambia el
/// destino post-login. La autorización real la da el backend
/// (`administrar_app_clientes` en el perfil).
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
    // Handler global del teclado: no depende de que algún widget tenga el foco.
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

  /// La pastilla de administrador puesta significa que quien entra NO es un
  /// cliente, y la biometría es solo para clientes: se esconde el botón. Es la
  /// única señal disponible antes de autenticar, porque el token guardado es
  /// opaco y el rol solo se sabe con el perfil ya cargado.
  bool get _showBiometricButton => _isBiometricAvailable && !_isAdminMode;

  /// El botón se ofrece con que el usuario haya activado la biometría, aunque el
  /// token guardado ya no sirva: en ese caso el intento falla y pide contraseña,
  /// pero el botón sigue ahí. Que desaparezca se lee como que se rompió.
  Future<bool> _isBiometricEnabled() => BiometricService.instance.isEnabled();

  /// true si el prompt automático puede llegar a entrar de verdad: con el candado
  /// puesto basta que esté habilitada (la sesión sigue viva, no se necesita
  /// token); sin sesión hace falta además el refresh token guardado.
  Future<bool> _canAutoStartBiometricLogin() {
    if (ref.read(authProvider).locked) {
      return BiometricService.instance.isEnabled();
    }
    return BiometricService.instance.canSignIn();
  }

  /// Muestra el botón si la biometría está activada y, si además puede entrar,
  /// pide la huella de una (el botón queda como reintento).
  Future<void> _prepareBiometrics() async {
    if (!await _isBiometricEnabled() || !mounted) return;
    setState(() => _isBiometricAvailable = true);
    if (!await _canAutoStartBiometricLogin() || !mounted) return;
    // Fire-and-forget a proposito: el formulario sigue usable mientras corre.
    unawaited(_signInWithBiometrics(silentOnFailure: true));
  }

  // -------------------------------------------------------------------------
  // Modo administrador (atajo de teclado + long-press del sello de versión)
  // -------------------------------------------------------------------------

  /// Único punto que enciende y apaga el modo administrador: lo comparten el
  /// atajo de teclado y el long-press del sello de versión.
  ///
  /// No dispara la huella: el administrador entra siempre con correo y
  /// contraseña (ver [_signInWithBiometrics]).
  void _toggleAdminMode() {
    if (!mounted) return;
    setState(() => _isAdminMode = !_isAdminMode);
    if (_isHapticPlatform) HapticFeedback.mediumImpact();
  }

  /// Solo Android/iOS: en web y escritorio no hay vibración que dar.
  bool get _isHapticPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Alterna el modo administrador con Ctrl+Shift+A o Ctrl+Alt+A (solo web).
  ///
  /// Debe ir en `HardwareKeyboard` (global), NO en un `Focus`: con nada
  /// enfocado el atajo se pierde. Ctrl+Alt+A existe porque Chrome/Edge se
  /// reservan Ctrl+Shift+A y la página no puede cancelarlo.
  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final keyboard = HardwareKeyboard.instance;
    final isKeyA =
        event.logicalKey == LogicalKeyboardKey.keyA ||
        event.physicalKey == PhysicalKeyboardKey.keyA;
    if (!isKeyA || !keyboard.isControlPressed) return false;
    if (!keyboard.isShiftPressed && !keyboard.isAltPressed) return false;
    _toggleAdminMode();
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
    auth.authFlowInProgress = true;
    try {
      await auth.signIn(_emailController.text, _passwordController.text);
      // Cierra el contexto de autofill PIDIENDO guardar: sin esto el gestor de
      // contrasenas nunca ofrece guardar la credencial. Va aqui y no en un
      // `finally` para no guardar contrasenas que fallaron.
      TextInput.finishAutofillContext();
    } catch (e) {
      auth.authFlowInProgress = false;
      if (!mounted) return;
      setState(() {
        _formError = AuthController.signInErrorMessage(e);
        _isSubmitting = false;
      });
      return;
    }

    try {
      final profile = await auth.refreshProfile();
      // Acceso administrador: por el permiso del rol (roles.apps.administrar
      // incluye "clientes" => canManageClientApp). NO requiere el modo admin
      // manual (Ctrl+Alt+A): cualquier rol que administre la app entra directo
      // al selector de clientes. El toggle _isAdminMode ya solo afecta la UI.
      final isAdminAccess = profile?.canManageClientApp ?? false;
      if (!AuthController.isClientRole(profile) && !isAdminAccess) {
        // Rol no permitido en este acceso (incluye admin sin modo admin):
        // mensaje genérico para no revelar cuentas existentes.
        await auth.signOut();
        auth.authFlowInProgress = false;
        if (!mounted) return;
        setState(() {
          _formError = 'Correo o contraseña incorrectos.';
          _isSubmitting = false;
        });
        return;
      }
      // Acceso administrador: esta cuenta no usa biometría, así que si quedó un
      // enrolamiento suyo (de antes de la restricción) se apaga aquí. No toca el
      // de otra cuenta que use el mismo teléfono.
      if (isAdminAccess) {
        final userId = auth.session?.userId;
        if (userId != null) {
          await BiometricService.instance.disableIfOwnedBy(userId);
        }
      }
      // Con contraseña temporal pendiente NO se ofrece la biometría: enrolar
      // ahí ataría la huella a una credencial que el usuario esta por cambiar.
      // La oferta la hace ChangePasswordScreen al terminar el cambio.
      if (profile!.requiresPasswordChange) {
        auth.authFlowInProgress = false;
        if (!mounted) return;
        context.go('/change-password');
        return;
      }
      // Un solo punto de salida para el resto: la oferta va igual para cliente y
      // para administrador. Cuando cada destino navegaba por su cuenta, cada
      // rama nueva volvía a olvidarse de ofrecerla.
      await _offerBiometricsThenGo(
        auth,
        isAdminAccess ? '/seleccionar-cliente' : '/inicio',
      );
    } catch (_) {
      await auth.signOut();
      auth.authFlowInProgress = false;
      if (!mounted) return;
      setState(() {
        _formError = 'No pudimos verificar tu cuenta. Intenta de nuevo.';
        _isSubmitting = false;
      });
    }
  }

  /// Ofrece activar la biometría y navega a [route]. Lo comparten el acceso de
  /// cliente y el de administrador: sin esto el admin nunca recibía la oferta,
  /// porque su rama navegaba antes de llegar aquí.
  ///
  /// La oferta va ANTES de navegar y con `authFlowInProgress` aún en true: si no,
  /// el router saca al usuario de /login mientras el sheet está abierto.
  Future<void> _offerBiometricsThenGo(AuthController auth, String route) async {
    await offerBiometricSetup(context, auth);
    auth.authFlowInProgress = false;
    if (!mounted) return;
    context.go(route);
  }

  /// Login con huella/rostro, SOLO para clientes. El administrador entra siempre
  /// con correo y contraseña: su sesión puede impersonar a cualquier cliente, y
  /// dejarla detrás de la huella enrolada en un teléfono la vuelve tan fuerte
  /// como ese teléfono.
  ///
  /// Con [silentOnFailure] una cancelación no muestra error (el prompt lo disparó
  /// el app al montar, no un toque del usuario). Los otros fallos SÍ se muestran
  /// aunque sea silencioso: si el acceso rápido expiró, callarlo deja un botón
  /// que parece roto.
  Future<void> _signInWithBiometrics({bool silentOnFailure = false}) async {
    if (_isBiometricRunning || _isSubmitting) return;
    ref.read(inactivityLogoutProvider.notifier).state = false;
    setState(() {
      _isBiometricRunning = true;
      _formError = null;
    });
    final auth = ref.read(authProvider);
    auth.authFlowInProgress = true;
    // Con candado la sesión nunca se cerró: solo se desbloquea. El login con
    // token guardado es el fallback cuando la sesión local ya no existe.
    final result = auth.locked
        ? (await auth.unlockWithBiometrics()
              ? BiometricLoginResult.success
              : BiometricLoginResult.cancelled)
        : await BiometricService.instance.signIn();
    if (result != BiometricLoginResult.success) {
      auth.authFlowInProgress = false;
      // El botón se queda mientras la biometría siga activada: un token
      // invalidado no lo esconde, porque el siguiente login por contraseña lo
      // vuelve a alimentar. Lo que cambia es el mensaje.
      final isEnabled = await _isBiometricEnabled();
      if (!mounted) return;
      setState(() {
        _isBiometricRunning = false;
        _isBiometricAvailable = isEnabled;
        _formError = switch (result) {
          BiometricLoginResult.cancelled =>
            silentOnFailure
                ? null
                : 'No pudimos validar tu identidad. Ingresa tu contraseña.',
          BiometricLoginResult.networkError =>
            'Sin conexión. Intenta de nuevo en un momento.',
          BiometricLoginResult.sessionExpired =>
            'Tu acceso rápido expiró. Entra con tu correo y contraseña una vez '
                'y la huella queda lista de nuevo.',
          BiometricLoginResult.success => null,
        };
      });
      return;
    }
    try {
      final profile = await auth.refreshProfile();
      if (!AuthController.isClientRole(profile)) {
        // Enrolamiento viejo de una cuenta no-cliente: se apaga aquí. Dejarlo
        // activo daría acceso a la consola de administración con solo la huella
        // del teléfono.
        await BiometricService.instance.disable();
        await auth.signOut();
        auth.authFlowInProgress = false;
        if (!mounted) return;
        setState(() {
          _isBiometricRunning = false;
          _isBiometricAvailable = false;
          _formError =
              'El acceso con huella es solo para clientes. Entra con tu correo '
              'y contraseña.';
        });
        return;
      }
      auth.authFlowInProgress = false;
      if (!mounted) return;
      context.go(
        profile!.requiresPasswordChange ? '/change-password' : '/inicio',
      );
    } catch (_) {
      await auth.signOut();
      auth.authFlowInProgress = false;
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

    // No quitar: sin AutofillGroup, `autofillHints` en los campos no alcanza y
    // el gestor de contrasenas ni autocompleta ni ofrece guardar.
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
            // lg: acción principal, al mismo alto que los campos (52 px).
            SButton(
              label: 'Iniciar sesión',
              size: SButtonSize.lg,
              loading: _isSubmitting,
              loadingLabel: 'Iniciando sesión...',
              onPressed: _isSubmitting ? null : _submit,
            ),

            if (_showBiometricButton) ...[
              SizedBox(height: t.space.xs),
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
            _VersionStamp(onHold: _toggleAdminMode),
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

/// Cuánto hay que sostener el sello de versión para alternar el modo
/// administrador. Umbral de gesto, no de animación: no sale de
/// `context.s.motion`.
const Duration _kAdminHoldDuration = Duration(milliseconds: 1500);

/// Sello de versión del pie. A la vista, texto inerte; sostenido
/// [_kAdminHoldDuration], el interruptor del modo administrador.
///
/// No cambiar por `GestureDetector` (su `onLongPress` fija 500 ms y no se puede
/// subir) ni por `SPressable` (pinta hover, ripple y cursor de mano, y el sello
/// no debe verse pulsable).
class _VersionStamp extends StatelessWidget {
  const _VersionStamp({required this.onHold});

  final VoidCallback onHold;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return RawGestureDetector(
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                duration: _kAdminHoldDuration,
                debugOwner: this,
              ),
              (recognizer) => recognizer.onLongPress = onHold,
            ),
      },
      child: Text(
        appVersionLabel,
        textAlign: TextAlign.center,
        style: t.text.overline.copyWith(
          color: t.color.fgSubtle.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

/// Pastilla de "Acceso administrador": único indicio visual de que el modo
/// admin quedó encendido.
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
      // excludeSemantics: sin esto el lector anuncia el label de arriba Y el
      // texto crudo del Text.rich, o sea dos veces lo mismo.
      excludeSemantics: true,
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
