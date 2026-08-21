import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/core/format.dart';
import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/core/push_service.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/features/client/expediente/providers/expediente_providers.dart';
import 'package:sozu_cliente_app/features/client/profile/components/theme_selector.dart';
import 'package:sozu_cliente_app/features/client/profile/providers/profile_providers.dart';
import 'package:sozu_cliente_app/features/client/providers/client_providers.dart';
import 'package:sozu_cliente_app/features/admin/providers/impersonation_provider.dart';
import 'package:sozu_cliente_app/shared/providers/shared_providers.dart';
import 'package:sozu_cliente_app/features/auth/components/biometric_toggle_card.dart';
import 'package:sozu_cliente_app/features/client/expediente/components/expediente_card.dart';
import 'package:sozu_cliente_app/widgets/fx.dart';
import 'package:sozu_cliente_app/features/client/profile/components/perfil_section_card.dart';
import 'package:sozu_cliente_app/features/client/profile/components/perfil_sheets.dart';
import 'package:sozu_cliente_app/widgets/portal_widgets.dart';
import 'package:sozu_cliente_app/features/client/profile/screens/perfil_detalle_screens.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Sección del Perfil abierta inline en modo portal ("Ver todo").
enum _PerfilSeccion { personal, fiscal, cuentas }

/// Perfil del cliente: identidad con % completado y estatus, filas de sección
/// (documentos, personal, fiscal, cuentas, seguridad) y preferencias del app.
class PerfilScreen extends ConsumerStatefulWidget {
  const PerfilScreen({super.key});

  @override
  ConsumerState<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends ConsumerState<PerfilScreen> {
  /// En modo portal, sección abierta inline con "← Volver al Perfil"
  /// (null = overview). En móvil no se usa (las vistas van por Navigator).
  _PerfilSeccion? _detalle;

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final auth = ref.watch(authProvider);
    final perfil = ref.watch(profileProvider);
    final impersonating = ref.watch(impersonationProvider).active;

    final p = perfil.valueOrNull;
    final nombre = p?.nombreLegal ?? auth.profile?.displayName ?? 'Cliente';
    final completado = p?.perfilCompletado ?? 0;
    final estatus = p?.estatusPerfil ?? 'incomplete';
    final expediente = ref.watch(identityFileProvider);
    final estadoSecciones = computePerfilSeccionesEstado(
      p,
      expediente.valueOrNull,
    );

    Future<void> confirmarSalir() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Seguro que quieres salir?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Cerrar sesión',
                style: TextStyle(color: tone.danger),
              ),
            ),
          ],
        ),
      );
      if (ok == true) {
        // Con biometría habilitada solo bloquea (la huella re-entra sin
        // contraseña); sin biometría es un signOut real.
        await ref.read(authProvider).lockOrSignOut();
        // Limpia la impersonación y la caché de datos del cliente para que la
        // próxima sesión (otro cliente) no herede el resumen/perfil del anterior.
        ref.read(impersonationProvider).clear();
        invalidateAllData(ref);
        if (context.mounted) context.go('/login');
      }
    }

    final portal = isPortalMode(context);

    void abrirDetalle(_PerfilSeccion seccion) {
      // Portal: inline con "← Volver al Perfil". Móvil: fullscreen.
      if (portal) {
        setState(() => _detalle = seccion);
        return;
      }
      final screen = switch (seccion) {
        _PerfilSeccion.personal => const PerfilPersonalScreen(),
        _PerfilSeccion.fiscal => const PerfilFiscalScreen(),
        _PerfilSeccion.cuentas => const PerfilCuentasScreen(),
      };
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => screen));
    }

    // Overview compartido entre móvil y portal: hero del expediente + filas
    // "Secciones de tu perfil".
    final motorHero = ExpedienteCard(
      estado: estadoSecciones,
      onGestionarDocumentos: () => context.push('/expediente'),
    );

    PerfilPillEstado pill(bool ok) =>
        ok ? PerfilPillEstado.completo : PerfilPillEstado.pendiente;

    Widget seccionesLabel() => Text(
      'SECCIONES DE TU PERFIL',
      style: portal
          ? portalText(
              size: 10.5,
              weight: FontWeight.w700,
              color: const Color(0xFF9AA3AD),
              letterSpacing: 1,
            )
          : TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: tone.fgSubtle,
              letterSpacing: 1,
            ),
    );

    final seccionRows = <Widget>[
      PerfilSectionRow(
        title: 'Documentos',
        description: 'Sube y consulta tus documentos',
        estado: pill(estadoSecciones.documentosCompleto),
        onTap: () => context.push('/expediente'),
      ),
      PerfilSectionRow(
        title: 'Información personal',
        description: 'Identificación y contacto',
        estado: pill(estadoSecciones.personalCompleto),
        onTap: () => abrirDetalle(_PerfilSeccion.personal),
      ),
      PerfilSectionRow(
        title: 'Información fiscal',
        description: 'Régimen, CFDI y dirección',
        estado: pill(estadoSecciones.fiscalCompleto),
        onTap: () => abrirDetalle(_PerfilSeccion.fiscal),
      ),
      PerfilSectionRow(
        title: 'Cuentas bancarias',
        description: 'Cuentas de dispersión',
        estado: pill(estadoSecciones.cuentasCompleto),
        onTap: () => abrirDetalle(_PerfilSeccion.cuentas),
      ),
      if (!impersonating)
        PerfilSectionRow(
          title: 'Seguridad',
          description: 'Acceso y contraseña',
          // La modal sirve en los dos formatos: sheet en móvil, diálogo en web.
          onTap: () => showCambiarPasswordDialog(context),
        ),
    ];

    // Filas con separación uniforme de 10px.
    final seccionRowsColumn = <Widget>[
      for (var i = 0; i < seccionRows.length; i++) ...[
        if (i > 0) const SizedBox(height: 10),
        seccionRows[i],
      ],
    ];

    // Solo móvil: en portal vive en el menú del avatar de la topbar.
    final cerrarSesionButton = OutlinedButton.icon(
      onPressed: confirmarSalir,
      icon: Icon(Icons.logout, size: 18, color: tone.danger),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: tone.danger,
        backgroundColor: tone.danger.withValues(alpha: 0.05),
        side: BorderSide(color: tone.danger.withValues(alpha: 0.3)),
      ),
      label: const Text('Cerrar sesión'),
    );

    // ── Modo portal (web ≥1024): layout ancho ───────────────────────────────
    if (portal) {
      // Identidad: avatar + nombre + estatus, y "Perfil completado N%" con su
      // barra a la derecha.
      final identidad = SCard(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _PerfilAvatar(
                  fotoUrl: p?.fotoPerfilUrl,
                  size: 52,
                  showBadge: p != null && !impersonating,
                  onTap: p != null ? () => showAvatarSheet(context, p) : null,
                  fallback: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: PortalColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      // En portal el avatar lleva una sola inicial.
                      nombre.trim().isNotEmpty
                          ? nombre.trim()[0].toUpperCase()
                          : '?',
                      style: portalText(
                        size: 22,
                        weight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: portalText(size: 20, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _portalEstatusChip(estatus),
                          Text(
                            p?.tipoPersonaLabel ?? 'Persona física',
                            style: portalText(
                              size: 12,
                              weight: FontWeight.w500,
                              color: PortalColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Perfil completado',
                            style: portalText(
                              size: 12,
                              weight: FontWeight.w600,
                              color: PortalColors.mutedForeground,
                            ),
                          ),
                          perfil.isLoading
                              ? const SSkeleton(width: 32, height: 12)
                              : Text(
                                  '$completado%',
                                  style: portalText(
                                    size: 12,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          height: 7,
                          color: PortalColors.muted,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: (completado / 100).clamp(0.0, 1.0),
                              child: Container(color: PortalColors.primary),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (p != null && completado < 85) ...[
              const SizedBox(height: 14),
              PerfilBannerCompletar(
                perfilCompletado: completado,
                onCompletar: () => context.push('/expediente'),
              ),
            ],
          ],
        ),
      );

      // Preferencias propias del app, al final para no competir con el perfil.
      final preferencias = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 20 y sin `bottom`: SSectionLabel ya aporta 4 arriba y 8 abajo.
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: SSectionLabel(text: 'Preferencias de la app'),
          ),
          SCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      size: 18,
                      color: PortalColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notificaciones push',
                            style: portalText(
                              size: 13,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          ValueListenableBuilder<String>(
                            valueListenable: PushService.estado,
                            builder: (_, estado, __) => Text(
                              estado,
                              style: portalText(
                                size: 11,
                                color: PortalColors.mutedForeground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (PushService.soportado) ...[
                  const SizedBox(height: 8),
                  const _PushPrefSwitch(),
                ],
              ],
            ),
          ),
          // Solo móvil con biometría; en web se colapsa sola.
          const BiometricToggleCard(),
        ],
      );

      // Detalle inline ("Ver todo"): sustituye el overview a 920px.
      if (_detalle != null) {
        void cerrar() => setState(() => _detalle = null);
        final detalle = switch (_detalle!) {
          _PerfilSeccion.personal => PerfilPersonalScreen(onBack: cerrar),
          _PerfilSeccion.fiscal => PerfilFiscalScreen(onBack: cerrar),
          _PerfilSeccion.cuentas => PerfilCuentasScreen(onBack: cerrar),
        };
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 24, bottom: 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: detalle,
              ),
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 24, bottom: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identidad,
                  const SizedBox(height: 16),
                  // Hero "motor" del expediente + estado de secciones.
                  motorHero,
                  const SizedBox(height: 20),
                  seccionesLabel(),
                  const SizedBox(height: 10),
                  ...seccionRowsColumn,
                  if (perfil.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SErrorState(
                        title: 'No pudimos cargar tu perfil',
                        onRetry: () => ref.invalidate(profileProvider),
                      ),
                    ),
                  preferencias,
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ContentFrame(
        maxWidth: 920,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            // ── Identidad: avatar, nombre, estatus, % completado ─────────────
            SCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth >= 560;
                      final identity = Row(
                        children: [
                          _PerfilAvatar(
                            fotoUrl: p?.fotoPerfilUrl,
                            size: 52,
                            showBadge: p != null && !impersonating,
                            onTap: p != null
                                ? () => showAvatarSheet(context, p)
                                : null,
                            fallback: SAvatar(
                              initials: p?.iniciales ?? initials(nombre),
                              size: 52,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: wide ? 20 : 16,
                                    fontWeight: FontWeight.w700,
                                    color: tone.fg,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    _estatusBadge(estatus),
                                    Text(
                                      p?.tipoPersonaLabel ?? 'Persona física',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: tone.fgMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                      final progreso = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Perfil completado',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: tone.fgMuted,
                                ),
                              ),
                              perfil.isLoading
                                  ? const SSkeleton(width: 32, height: 12)
                                  : Text(
                                      '$completado%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: tone.fg,
                                      ),
                                    ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          SProgressBar(
                            thickness: SProgressBarThickness.thick,
                            percent: completado.toDouble(),
                          ),
                        ],
                      );
                      if (wide) {
                        return Row(
                          children: [
                            Expanded(child: identity),
                            const SizedBox(width: 24),
                            SizedBox(width: 220, child: progreso),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          identity,
                          const SizedBox(height: 14),
                          progreso,
                        ],
                      );
                    },
                  ),
                  // Se oculta con el perfil verificado (≥85 %).
                  if (p != null && completado < 85) ...[
                    const SizedBox(height: 14),
                    PerfilBannerCompletar(
                      perfilCompletado: completado,
                      onCompletar: () => context.push('/expediente'),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            motorHero,

            const SizedBox(height: 20),

            seccionesLabel(),
            const SizedBox(height: 10),
            ...seccionRowsColumn,

            if (perfil.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SErrorState(
                  title: 'No pudimos cargar tu perfil',
                  onRetry: () => ref.invalidate(profileProvider),
                ),
              ),

            // ── Preferencias propias del app ────────────────────────────────
            // Apariencia solo en la vista móvil/angosta: en el portal ancho vive
            // en el menú del avatar. En web el selector se pinta apagado y con
            // el motivo, porque el tema está con candado a claro (main.dart).
            _sectionLabel(tone, 'Apariencia'),
            const SCard(child: ThemeSelector()),

            _sectionLabel(tone, 'Notificaciones'),
            SCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_outlined,
                        size: 20,
                        color: SozuBrand.green600,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notificaciones push',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: tone.fg,
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Diagnóstico, para soporte en campo.
                            ValueListenableBuilder<String>(
                              valueListenable: PushService.estado,
                              builder: (_, estado, __) => Text(
                                estado,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: tone.fgMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Preferencia solo donde hay push (en web vive la campana).
                  if (PushService.soportado) ...[
                    Divider(color: tone.border, height: 24),
                    const _PushPrefSwitch(),
                  ],
                ],
              ),
            ),

            // Solo móvil con biometría disponible; en web se colapsa sola.
            const SizedBox(height: 8),
            const BiometricToggleCard(),

            // Cerrar sesión (en móvil no hay menú de avatar en la topbar).
            const SizedBox(height: 24),
            cerrarSesionButton,
          ],
        ),
      ),
    );
  }

  /// Igual que [_estatusBadge] pero con icono, como el header del portal.
  Widget _portalEstatusChip(String estatus) {
    return switch (estatus) {
      'verified' => const SBadge(
        label: 'Perfil verificado',
        tone: SBadgeTone.positive,
        icon: Icons.check_circle_outline,
      ),
      'review' => const SBadge(
        label: 'En revisión',
        tone: SBadgeTone.pending,
        icon: Icons.schedule,
      ),
      _ => const SBadge(
        label: 'Información incompleta',
        tone: SBadgeTone.negative,
        icon: Icons.error_outline,
      ),
    };
  }

  /// Chip de verificación del perfil.
  Widget _estatusBadge(String estatus) {
    return switch (estatus) {
      'verified' => const SBadge(
        label: 'Perfil verificado',
        tone: SBadgeTone.positive,
      ),
      'review' => const SBadge(label: 'En revisión', tone: SBadgeTone.pending),
      _ => const SBadge(
        label: 'Información incompleta',
        tone: SBadgeTone.negative,
      ),
    };
  }

  Widget _sectionLabel(SozuColorRoles tone, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: tone.fgMuted,
        ),
      ),
    );
  }
}

/// Switch "Recibir notificaciones push": la preferencia vive en BD y el
/// dispatch de push la respeta (los tokens NO se dan de baja al desactivar).
class _PushPrefSwitch extends ConsumerStatefulWidget {
  const _PushPrefSwitch();

  @override
  ConsumerState<_PushPrefSwitch> createState() => _PushPrefSwitchState();
}

class _PushPrefSwitchState extends ConsumerState<_PushPrefSwitch> {
  bool _activo = true;
  bool _cargando = true;
  // false si pref_get falló (p. ej. backend sin la acción): switch visible
  // con el default pero deshabilitado - degradación limpia.
  bool _disponible = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final activo = await ref.read(pushPortProvider).enabled();
      if (!mounted) return;
      setState(() {
        _activo = activo;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _disponible = false;
      });
    }
  }

  Future<void> _cambiar(bool valor) async {
    final anterior = _activo;
    setState(() => _activo = valor); // optimista
    try {
      await ref.read(pushPortProvider).setEnabled(valor);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            valor ? 'Notificaciones activadas' : 'Notificaciones desactivadas',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _activo = anterior);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la preferencia. Intenta de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Recibir notificaciones push',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tone.fg,
            ),
          ),
        ),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          Switch(value: _activo, onChanged: _disponible ? _cambiar : null),
      ],
    );
  }
}

/// Avatar del header: la foto recortada en círculo, o [fallback] si no hay.
/// Con [showBadge] dibuja el badge de cámara y hace tappable el avatar; se
/// apaga al impersonar.
class _PerfilAvatar extends StatelessWidget {
  final String? fotoUrl;
  final Widget fallback;
  final double size;
  final bool showBadge;
  final VoidCallback? onTap;

  const _PerfilAvatar({
    required this.fotoUrl,
    required this.fallback,
    required this.size,
    required this.showBadge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final hasFoto = (fotoUrl ?? '').isNotEmpty;
    final img = hasFoto
        ? ClipOval(
            child: SizedBox(
              width: size,
              height: size,
              child: SNetworkImage(
                url: fotoUrl,
                placeholderIcon: Icons.person_outline,
              ),
            ),
          )
        : fallback;

    final content = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: img),
          if (showBadge)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: tone.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(Icons.photo_camera, size: 12, color: tone.fgMuted),
              ),
            ),
        ],
      ),
    );

    if (!showBadge || onTap == null) return content;
    return Semantics(
      button: true,
      label: 'Cambiar foto de perfil',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: content,
      ),
    );
  }
}
