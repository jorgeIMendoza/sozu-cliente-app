import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sozu_cliente_app/features/auth/services/biometric_service.dart';
import 'package:sozu_cliente_app/features/auth/services/portal_access.dart';
import 'package:sozu_cliente_app/features/auth/components/biometric_setup_sheet.dart';
import 'package:sozu_cliente_app/core/version.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_alert.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_header.dart';
import 'package:sozu_cliente_app/features/auth/layouts/auth_layout.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/features/auth/screens/email_not_confirmed_screen.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Formulario de acceso: correo + contraseña, biometría y la navegación
/// posterior al login. Concentra el estado y la lógica del acceso.
///
/// Tras autenticar valida el acceso al portal con el perfil (vía RPC): rol
/// Cliente o comprador activo ([PortalAccess]). Si no lo tiene, cierra sesión.
///
/// El destino sale del PERFIL, no de un gesto ni de la plataforma: con
/// `canManageClientApp` va al selector de clientes, si no al portal. Mismo flujo
/// en web y en móvil.
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
  bool _isBiometricAvailable = false;
  bool _isBiometricRunning = false;

  /// Modo administrador. Solo se puede activar en web de ESCRITORIO, con
  /// Ctrl+Alt+A (ver [_onKeyEvent]). En app nativa y en web-móvil nunca es true.
  bool _isAdminMode = false;

  @override
  void initState() {
    super.initState();
    // Handler global del teclado: no depende de que un widget tenga el foco.
    // Solo en web (en nativo no hay atajo de admin); el ancho de escritorio se
    // exige dentro de [_onKeyEvent].
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

  /// El botón depende solo de que haya un enrolamiento en este dispositivo.
  ///
  /// No hace falta esconderlo para administradores: solo se enrola quien tiene
  /// acceso al portal ([AuthController.shouldOfferBiometrics]), y un
  /// enrolamiento viejo de una cuenta no-cliente se apaga al entrar
  /// (`disableIfOwnedBy`).
  bool get _showBiometricButton => _isBiometricAvailable && !_isAdminMode;

  // -------------------------------------------------------------------------
  // Modo administrador: long-press del sello (toda plataforma) o Ctrl+Alt+A
  // (solo web de escritorio). Encenderlo no concede nada: el acceso lo decide
  // `canManageClientApp` del perfil.
  // -------------------------------------------------------------------------

  /// Único punto que enciende/apaga el modo administrador.
  void _toggleAdminMode() {
    if (mounted) setState(() => _isAdminMode = !_isAdminMode);
  }

  /// Alterna el modo administrador con Ctrl+Shift+A o Ctrl+Alt+A, SOLO en web de
  /// escritorio (en web-móvil el atajo no hace nada; el nativo ni lo instala).
  ///
  /// Va en `HardwareKeyboard` (global), NO en un `Focus`: con nada enfocado el
  /// atajo se perdería. Ctrl+Alt+A existe porque Chrome/Edge se reservan
  /// Ctrl+Shift+A y la página no puede cancelarlo.
  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!context.bp.isDesktop) return false; // nunca en web-móvil
    final keyboard = HardwareKeyboard.instance;
    final isKeyA =
        event.logicalKey == LogicalKeyboardKey.keyA ||
        event.physicalKey == PhysicalKeyboardKey.keyA;
    if (!isKeyA || !keyboard.isControlPressed) return false;
    if (!keyboard.isShiftPressed && !keyboard.isAltPressed) return false;
    _toggleAdminMode();
    return true; // consumido: no llega al campo de texto enfocado
  }

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
    // Con un bloqueo de cuenta pendiente (baja detectada al rehidratar la
    // sesión al abrir la app) NO se dispara el prompt solo: taparía el aviso y
    // el token guardado ya no sirve porque el gate cerró la sesión. El botón
    // queda visible como reintento manual.
    if (ref.read(authProvider).blockedAccess != null) return;
    if (!await _canAutoStartBiometricLogin() || !mounted) return;
    // Fire-and-forget a proposito: el formulario sigue usable mientras corre.
    unawaited(_signInWithBiometrics(silentOnFailure: true));
  }

  // -------------------------------------------------------------------------
  // Acceso con contraseña
  // -------------------------------------------------------------------------

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(inactivityLogoutProvider.notifier).state = false;
    ref.read(passwordChangedProvider.notifier).state = false;
    final auth = ref.read(authProvider);
    // Reintento: olvidar el bloqueo anterior para que su aviso no quede pegado.
    auth.clearAccessBlock();
    setState(() {
      _isSubmitting = true;
      _formError = null;
    });
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
      // Gate de cuenta ANTES del acceso administrador: una cuenta dada de baja
      // (o de un rol de portal con el correo sin confirmar) no entra por
      // ninguna de las dos puertas. El gate ya cerró la sesión.
      final block = await auth.applyAccessGates();
      if (block != null) {
        auth.authFlowInProgress = false;
        if (!mounted) return;
        if (block == AccessBlock.emailNotConfirmed) {
          context.go(emailNotConfirmedPath);
          return;
        }
        // Cuenta desactivada: el aviso lo pinta el banner de bloqueo del build.
        setState(() => _isSubmitting = false);
        return;
      }
      // Acceso administrador: requiere el permiso del rol (canManageClientApp)
      // Y el modo admin activo. Sin el modo activo, un rol que administra apps
      // NO entra: cae en el mensaje genérico. Con el modo activo, va al selector
      // de clientes.
      final isAdminAccess =
          _isAdminMode && (profile?.canManageClientApp ?? false);
      if (!PortalAccess.allows(profile) && !isAdminAccess) {
        // Ni usuario del portal (rol Cliente o comprador) ni administrador de
        // la app: mensaje genérico para no revelar cuentas existentes.
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
      // El cambio cierra la sesión, así que la oferta llega en el login
      // siguiente, ya con la contraseña definitiva.
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
    ref.read(passwordChangedProvider.notifier).state = false;
    final auth = ref.read(authProvider);
    auth.clearAccessBlock();
    setState(() {
      _isBiometricRunning = true;
      _formError = null;
    });
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
      // Mismo gate que el login por contraseña: la huella no puede saltárselo.
      final block = await auth.applyAccessGates();
      if (block != null) {
        auth.authFlowInProgress = false;
        // El signOut del gate invalidó el refresh token guardado: sin botón
        // biométrico hasta que vuelva a entrar por contraseña.
        final isEnabled = await _isBiometricEnabled();
        if (!mounted) return;
        if (block == AccessBlock.emailNotConfirmed) {
          context.go(emailNotConfirmedPath);
          return;
        }
        setState(() {
          _isBiometricRunning = false;
          _isBiometricAvailable = isEnabled;
        });
        return;
      }
      if (!PortalAccess.allows(profile)) {
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
    final passwordJustChanged = ref.watch(passwordChangedProvider);
    final isSplit = context.bp.isDesktop;
    // Bloqueo de cuenta detectado por el gate, sea en este login o al rehidratar
    // la sesión al abrir la app (en ese caso el router trae al usuario aquí).
    // El correo sin confirmar tiene pantalla propia, así que aquí solo la baja.
    final isAccountDeactivated =
        ref.watch(authProvider).blockedAccess == AccessBlock.deactivated;

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

            if (passwordJustChanged) ...[
              const AuthAlert(
                kind: AuthAlertKind.success,
                icon: Icons.check_circle_outline,
                message:
                    'Contraseña actualizada. Inicia sesión de nuevo con tu '
                    'nueva contraseña para entrar.',
              ),
              SizedBox(height: t.space.md),
            ],

            if (isAccountDeactivated) ...[
              AuthAlert(
                kind: AuthAlertKind.error,
                icon: Icons.block,
                message: accessBlockMessage(AccessBlock.deactivated),
              ),
              SizedBox(height: t.space.md),
            ],

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
            // Ctrl+Alt+A lo duplica en escritorio: sostener con el ratón es
            // un gesto que nadie busca.
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

/// Umbral del long-press que enciende el modo admin. Más largo que el default
/// (500 ms) para que sea deliberado y no un toque accidental.
const Duration _kAdminHoldDuration = Duration(milliseconds: 1500);

/// Cuánto puede moverse el dedo sin cancelar el gesto. Generoso a propósito: en
/// 1.5 s la mano siempre deriva unos píxeles.
const double _kAdminHoldSlop = 24;

/// Sello de versión del pie. Con [onHold], mantenerlo pulsado
/// [_kAdminHoldDuration] enciende el modo administrador; sin él es texto
/// inerte.
///
/// Usa [Listener] y NO un reconocedor de gestos: el sello vive dentro de un
/// scroll, y en la arena el arrastre vertical gana en cuanto el dedo pasa el
/// touch slop, así que el long-press moría antes de cumplirse. Con eventos
/// crudos el gesto no compite, y el scroll sigue funcionando porque nadie
/// reclama el puntero.
class _VersionStamp extends StatefulWidget {
  final VoidCallback? onHold;

  const _VersionStamp({this.onHold});

  @override
  State<_VersionStamp> createState() => _VersionStampState();
}

class _VersionStampState extends State<_VersionStamp> {
  Timer? _timer;
  Offset? _origen;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _cancelar() {
    _timer?.cancel();
    _timer = null;
    _origen = null;
  }

  void _iniciar(PointerDownEvent e) {
    _origen = e.position;
    _timer = Timer(_kAdminHoldDuration, () {
      _cancelar();
      widget.onHold?.call();
    });
  }

  void _mover(PointerMoveEvent e) {
    final origen = _origen;
    // Se movió: el usuario está haciendo scroll, no sosteniendo.
    if (origen != null && (e.position - origen).distance > _kAdminHoldSlop) {
      _cancelar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final label = Text(
      appVersionLabel,
      textAlign: TextAlign.center,
      style: t.text.overline.copyWith(
        color: t.color.fgSubtle.withValues(alpha: 0.6),
      ),
    );
    if (widget.onHold == null) return label;
    return Listener(
      onPointerDown: _iniciar,
      onPointerMove: _mover,
      onPointerUp: (_) => _cancelar(),
      onPointerCancel: (_) => _cancelar(),
      child: label,
    );
  }
}

/// Pastilla que indica que el modo administrador está activo.
class _AdminModeBadge extends StatelessWidget {
  const _AdminModeBadge();

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.md,
          vertical: t.space.xs,
        ),
        decoration: BoxDecoration(
          color: t.color.primarySoft,
          borderRadius: BorderRadius.circular(t.radius.lg),
          border: Border.all(color: t.color.primary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.admin_panel_settings_outlined,
              size: 16,
              color: t.color.primary,
            ),
            SizedBox(width: t.space.xs),
            Text(
              'Modo administrador',
              style: t.text.bodySmall.copyWith(
                color: t.color.primary,
                fontWeight: FontWeight.w600,
              ),
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
          'Registrar una propiedad SOZU comprada a otro dueño, no a SOZU. Abre '
          'el portal de dueños en una ventana nueva.',
      // excludeSemantics: sin esto el lector anuncia el label de arriba Y el
      // texto crudo del Text.rich, o sea dos veces lo mismo.
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: '¿Compraste tu propiedad a otro dueño? '),
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
