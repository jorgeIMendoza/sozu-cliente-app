import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/push_service.dart';
import '../core/theme.dart';
import '../data/api_client.dart';
import '../data/models.dart';
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
import 'perfil_detalle_screens.dart';

/// Perfil del cliente (espejo de ClientePerfil.tsx del portal web): identidad
/// con % de perfil completado y estatus de verificación, tarjetas de
/// información personal / fiscal / cuentas bancarias / seguridad, más las
/// secciones propias del app (tema, push, biometría).
class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = SozuTone.of(context);
    final auth = ref.watch(authProvider);
    final perfil = ref.watch(clientePerfilProvider);
    final impersonating = ref.watch(impersonationProvider).active;

    final p = perfil.valueOrNull;
    final nombre = p?.nombreLegal ?? auth.profile?.nombre ?? 'Cliente';
    final cuentas = p?.cuentasBancarias ?? const <CuentaBancariaPerfil>[];
    final completado = p?.perfilCompletado ?? 0;
    final estatus = p?.estatusPerfil ?? 'incomplete';

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
        if (context.mounted) context.go('/login');
      }
    }

    void pushDetalle(Widget screen) {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));
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

            // EXPEDIENTE_CARD_SLOT — tarjeta "Tu expediente" (se auto-oculta si
            // el backend aún no expone cliente-expediente).
            const ExpedienteCard(),

            const SizedBox(height: 16),

            // ── Tarjetas de sección (2 columnas en ancho, 1 en angosto) ─────
            ResponsiveCardGrid(
              minCardWidth: 330,
              children: [
                PerfilSectionCard(
                  title: 'Información personal',
                  subtitle: 'Identificación y contacto',
                  icon: Icons.person_outline,
                  statusOk: (p?.nombreLegal ?? '').isNotEmpty && p != null,
                  statusLabel: (p?.nombreLegal ?? '').isNotEmpty && p != null
                      ? 'Completo'
                      : 'Pendiente',
                  rows: [
                    PerfilInfoRow(label: 'Nombre', value: p?.nombreLegal),
                    PerfilInfoRow(label: 'RFC', value: p?.rfc, mono: true),
                    PerfilInfoRow(
                        label: 'CURP', value: p?.curp, mono: true, isLast: true),
                  ],
                  actions: [
                    if (!impersonating && p != null)
                      PerfilCardAction(
                        label: 'Editar',
                        style: PerfilActionStyle.secondary,
                        onTap: () => showEditPersonalSheet(context, p),
                      ),
                    PerfilCardAction(
                      label: 'Ver todo',
                      onTap: () =>
                          pushDetalle(const PerfilPersonalScreen()),
                    ),
                  ],
                ),
                PerfilSectionCard(
                  title: 'Información fiscal',
                  subtitle: 'Régimen, CFDI y dirección',
                  icon: Icons.business_outlined,
                  statusOk: p?.regimen != null,
                  statusLabel: p?.regimen != null ? 'Completo' : 'Pendiente',
                  rows: [
                    PerfilInfoRow(
                        label: 'Régimen', value: p?.regimenDisplay),
                    PerfilInfoRow(
                        label: 'Uso CFDI', value: p?.usoCfdiDisplay),
                    PerfilInfoRow(
                        label: 'CP', value: p?.cp, mono: true, isLast: true),
                  ],
                  actions: [
                    if (!impersonating && p != null)
                      PerfilCardAction(
                        label: 'Editar',
                        style: PerfilActionStyle.secondary,
                        onTap: () => showEditFiscalSheet(context, p),
                      ),
                    PerfilCardAction(
                      label: 'Ver todo',
                      onTap: () => pushDetalle(const PerfilFiscalScreen()),
                    ),
                  ],
                ),
                PerfilSectionCard(
                  title: 'Cuentas bancarias',
                  subtitle: 'Cuentas de dispersión',
                  icon: Icons.credit_card_outlined,
                  statusOk: cuentas.isNotEmpty,
                  statusLabel: cuentas.isNotEmpty
                      ? '${cuentas.length} cuenta${cuentas.length > 1 ? 's' : ''}'
                      : 'Sin cuentas',
                  rows: [
                    if (cuentas.isEmpty)
                      const PerfilInfoRow(
                          label: 'Cuentas registradas',
                          value: null,
                          isLast: true)
                    else
                      for (var i = 0; i < cuentas.length && i < 3; i++)
                        PerfilInfoRow(
                          label: cuentas[i].banco,
                          value: cuentas[i].clabeMasked,
                          mono: true,
                          isLast:
                              i == cuentas.length - 1 || i == 2,
                        ),
                  ],
                  actions: [
                    if (!impersonating)
                      PerfilCardAction(
                        label: 'Agregar cuenta',
                        style: PerfilActionStyle.secondary,
                        onTap: () => showCuentaBancariaSheet(context),
                      ),
                    PerfilCardAction(
                      label: 'Ver cuentas',
                      onTap: () => pushDetalle(const PerfilCuentasScreen()),
                    ),
                  ],
                ),
                PerfilSectionCard(
                  title: 'Seguridad',
                  subtitle: 'Contraseña y sesión',
                  icon: Icons.shield_outlined,
                  statusOk: true,
                  statusLabel: 'Activo',
                  rows: [
                    const PerfilInfoRow(
                        label: 'Contraseña', value: '•••••••••', mono: true),
                    PerfilInfoRow(
                        label: 'Sesión',
                        value: 'Activa',
                        isLast: true),
                  ],
                  actions: [
                    if (!impersonating)
                      PerfilCardAction(
                        label: 'Cambiar contraseña',
                        style: PerfilActionStyle.secondary,
                        onTap: () => context.push('/cambiar-password'),
                      ),
                    PerfilCardAction(
                      label: 'Cerrar sesión',
                      style: PerfilActionStyle.danger,
                      icon: Icons.logout,
                      onTap: confirmarSalir,
                    ),
                  ],
                ),
              ],
            ),

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
          ],
        ),
      ),
    );
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
