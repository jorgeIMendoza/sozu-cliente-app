import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/portal_theme.dart';
import '../core/push_service.dart';
import '../core/theme.dart';
import '../data/api_client.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../providers/impersonation_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/biometric_tile.dart';
import '../widgets/common.dart';
import '../widgets/expediente_card.dart';
import '../widgets/fx.dart';
import '../widgets/perfil_section_card.dart';
import '../widgets/perfil_sheets.dart';
import '../widgets/portal_widgets.dart';
import 'perfil_detalle_screens.dart';

/// Perfil del cliente (espejo de ClientePerfil.tsx del portal web): identidad
/// con % de perfil completado y estatus de verificación, tarjetas de
/// información personal / fiscal / cuentas bancarias / seguridad, más las
/// secciones propias del app (tema, push, biometría).
/// Sección del Perfil abierta inline en modo portal ("Ver todo").
enum _PerfilSeccion { personal, fiscal, cuentas }

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
    final tone = SozuTone.of(context);
    final auth = ref.watch(authProvider);
    final perfil = ref.watch(clientePerfilProvider);
    final impersonating = ref.watch(impersonationProvider).active;

    final p = perfil.valueOrNull;
    final nombre = p?.nombreLegal ?? auth.profile?.nombre ?? 'Cliente';
    final completado = p?.perfilCompletado ?? 0;
    final estatus = p?.estatusPerfil ?? 'incomplete';
    // Estado de las 4 secciones del overview (docs + personal + fiscal +
    // cuentas), derivado del perfil y el expediente igual que el portal.
    final expediente = ref.watch(clienteExpedienteProvider);
    final estadoSecciones =
        computePerfilSeccionesEstado(p, expediente.valueOrNull);

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
              child: Text('Cerrar sesión',
                  style: TextStyle(color: tone.negative)),
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
      // En modo portal los "Ver todo" se abren inline (con "← Volver al
      // Perfil"), como el `setView` del portal; en móvil siguen siendo
      // pantallas fullscreen por Navigator.
      if (portal) {
        setState(() => _detalle = seccion);
        return;
      }
      final screen = switch (seccion) {
        _PerfilSeccion.personal => const PerfilPersonalScreen(),
        _PerfilSeccion.fiscal => const PerfilFiscalScreen(),
        _PerfilSeccion.cuentas => const PerfilCuentasScreen(),
      };
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));
    }

    // ── Overview espejo del portal: hero "motor" + estado de secciones y las
    //    filas "Secciones de tu perfil" (compartido entre móvil y portal). ──
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
                  color: tone.textMuted,
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
          onTap: () => portal
              ? showCambiarPasswordDialog(context)
              : context.push('/cambiar-password'),
        ),
    ];

    // Filas con separación uniforme de 10px.
    final seccionRowsColumn = <Widget>[
      for (var i = 0; i < seccionRows.length; i++) ...[
        if (i > 0) const SizedBox(height: 10),
        seccionRows[i],
      ],
    ];

    // Botón "Cerrar sesión" (solo móvil; en portal vive en el menú del avatar
    // de la topbar). Reemplaza el que estaba en la tarjeta "Seguridad".
    final cerrarSesionButton = OutlinedButton.icon(
      onPressed: confirmarSalir,
      icon: Icon(Icons.logout, size: 18, color: tone.negative),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: tone.negative,
        backgroundColor: tone.negative.withValues(alpha: 0.05),
        side: BorderSide(color: tone.negative.withValues(alpha: 0.3)),
      ),
      label: const Text('Cerrar sesión'),
    );

    // ── Modo portal (web ≥1024): layout ancho de ClientePerfil.tsx ──────────
    if (portal) {
      // Header de identidad: avatar + nombre + estatus a la izquierda,
      // "Perfil completado N%" con barra a la derecha (220px como el portal).
      final identidad = PortalCard(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: PortalColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    // El portal usa una sola inicial (displayName.charAt(0)).
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
                              ? const Skeleton(width: 32, height: 12)
                              : Text(
                                  '$completado%',
                                  style: portalText(
                                      size: 12, weight: FontWeight.w700),
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
                              widthFactor:
                                  (completado / 100).clamp(0.0, 1.0),
                              child:
                                  Container(color: PortalColors.primary),
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

      // Preferencias propias del app (el portal web no las tiene):
      // agrupadas discretas al final para conservarlas accesibles.
      final preferencias = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 24, bottom: 8),
            child: PortalSectionLabel('Preferencias de la app'),
          ),
          PortalCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Apariencia',
                  style: portalText(size: 13, weight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  'El portal web siempre se muestra en tema claro; esta '
                  'preferencia aplica a la app móvil.',
                  style: portalText(
                      size: 11, color: PortalColors.mutedForeground),
                ),
                const SizedBox(height: 10),
                _ThemeSelector(tone: tone),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  height: 1,
                  color: PortalColors.border,
                ),
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
                                size: 13, weight: FontWeight.w600),
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
          const BiometricSettingTile(),
        ],
      );

      // Detalle inline ("Ver todo"): sustituye el overview a 920px con
      // "← Volver al Perfil", como el `setView` del portal.
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
              // El portal centra el Perfil a 920px dentro del shell.
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
                      child: ErrorCard(
                        title: 'No pudimos cargar tu perfil',
                        onRetry: () => ref.invalidate(clientePerfilProvider),
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
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth >= 560;
                      final identity = Row(
                        children: [
                          SozuAvatar(
                              iniciales: p?.iniciales ?? initials(nombre),
                              size: 52),
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
                                      color: tone.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment:
                                      WrapCrossAlignment.center,
                                  children: [
                                    _estatusBadge(estatus),
                                    Text(
                                      p?.tipoPersonaLabel ??
                                          'Persona física',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: tone.textSecondary),
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
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Perfil completado',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: tone.textSecondary)),
                              perfil.isLoading
                                  ? const Skeleton(width: 32, height: 12)
                                  : Text('$completado%',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: tone.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          SozuProgressBar(percent: completado.toDouble()),
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
                  // Banner ámbar "completa tu perfil" (igual que el portal,
                  // se oculta con el perfil verificado ≥85 %).
                  if (p != null && completado < 85) ...[
                    const SizedBox(height: 14),
                    PerfilBannerCompletar(
                      perfilCompletado: completado,
                      // "Completar" lleva al expediente (subir documentos).
                      onCompletar: () => context.push('/expediente'),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Hero "motor" del expediente + estado de secciones (una columna).
            motorHero,

            const SizedBox(height: 20),

            // ── Secciones de tu perfil (filas: abren su vista) ──────────────
            seccionesLabel(),
            const SizedBox(height: 10),
            ...seccionRowsColumn,

            if (perfil.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ErrorCard(
                  title: 'No pudimos cargar tu perfil',
                  onRetry: () => ref.invalidate(clientePerfilProvider),
                ),
              ),

            // ── Secciones propias del app (no existen en el portal) ─────────
            _sectionLabel(tone, 'Apariencia'),
            AppCard(child: _ThemeSelector(tone: tone)),

            _sectionLabel(tone, 'Notificaciones'),
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined,
                          size: 20, color: SozuColors.emerald600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Notificaciones push',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: tone.textPrimary)),
                            const SizedBox(height: 2),
                            // Estado de diagnóstico (útil para soporte en campo).
                            ValueListenableBuilder<String>(
                              valueListenable: PushService.estado,
                              builder: (_, estado, __) => Text(estado,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: tone.textSecondary)),
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
            const BiometricSettingTile(),

            // Cerrar sesión (en móvil no hay menú de avatar en la topbar).
            const SizedBox(height: 24),
            cerrarSesionButton,
          ],
        ),
      ),
    );
  }

  /// Chip de verificación en modo portal (colores del header de
  /// ClientePerfil.tsx: verde / ámbar / rojo con icono).
  Widget _portalEstatusChip(String estatus) {
    return switch (estatus) {
      'verified' => const PortalStatusChip(
          label: 'Perfil verificado',
          icon: Icons.check_circle_outline,
          background: PortalColors.primarySoft10,
          foreground: PortalColors.primary,
        ),
      'review' => const PortalStatusChip(
          label: 'En revisión',
          icon: Icons.schedule,
          background: PortalColors.warningSoft10,
          foreground: Color(0xFF92400E),
        ),
      _ => const PortalStatusChip(
          label: 'Información incompleta',
          icon: Icons.error_outline,
          background: PortalColors.destructiveSoft10,
          foreground: PortalColors.destructive,
        ),
    };
  }

  /// Chip de verificación (mismos umbrales que el portal: ≥85 verificado,
  /// ≥50 en revisión, resto incompleto).
  Widget _estatusBadge(String estatus) {
    return switch (estatus) {
      'verified' =>
        const StatusBadge(label: 'Perfil verificado', tone: BadgeTone.positive),
      'review' =>
        const StatusBadge(label: 'En revisión', tone: BadgeTone.pending),
      _ => const StatusBadge(
          label: 'Información incompleta', tone: BadgeTone.negative),
    };
  }

  Widget _sectionLabel(SozuTone tone, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(text,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tone.textSecondary)),
    );
  }
}

/// Switch "Recibir notificaciones push": la preferencia vive en BD y el
/// dispatch de push la respeta (los tokens NO se dan de baja al desactivar).
class _PushPrefSwitch extends StatefulWidget {
  const _PushPrefSwitch();

  @override
  State<_PushPrefSwitch> createState() => _PushPrefSwitchState();
}

class _PushPrefSwitchState extends State<_PushPrefSwitch> {
  bool _activo = true;
  bool _cargando = true;
  // false si pref_get falló (p. ej. backend sin la acción): switch visible
  // con el default pero deshabilitado — degradación limpia.
  bool _disponible = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final activo = await fetchPushPref();
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
      await setPushPref(valor);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(valor
            ? 'Notificaciones activadas'
            : 'Notificaciones desactivadas'),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _activo = anterior);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se pudo guardar la preferencia. Intenta de nuevo.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Row(
      children: [
        Expanded(
          child: Text('Recibir notificaciones push',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tone.textPrimary)),
        ),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          Switch(
            value: _activo,
            onChanged: _disponible ? _cambiar : null,
          ),
      ],
    );
  }
}

class _ThemeSelector extends ConsumerWidget {
  final SozuTone tone;

  const _ThemeSelector({required this.tone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final opciones = [
      (ThemeMode.light, 'Claro', Icons.wb_sunny_outlined),
      (ThemeMode.dark, 'Oscuro', Icons.nightlight_outlined),
      (ThemeMode.system, 'Auto', Icons.smartphone_outlined),
    ];
    return Row(
      children: [
        for (final (mode, label, icon) in opciones) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => theme.setMode(mode),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: theme.mode == mode ? tone.primarySoft : tone.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.mode == mode
                        ? SozuColors.emerald500
                        : tone.border,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(icon,
                        size: 20,
                        color: theme.mode == mode
                            ? SozuColors.emerald600
                            : tone.textMuted),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.mode == mode
                            ? tone.primaryDark
                            : tone.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (mode != ThemeMode.system) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
