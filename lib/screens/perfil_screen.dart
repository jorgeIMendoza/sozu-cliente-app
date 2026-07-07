import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../providers/theme_provider.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';

/// Perfil: datos del cliente (nombre, email, teléfono), tema, cambio de
/// contraseña y cierre de sesión.
class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = SozuTone.of(context);
    final auth = ref.watch(authProvider);
    final perfil = ref.watch(clientePerfilProvider);

    final nombre =
        perfil.valueOrNull?.nombreLegal ?? auth.profile?.nombre ?? 'Cliente';
    final email = perfil.valueOrNull?.email ??
        auth.profile?.email ??
        auth.session?.user.email ??
        '—';
    final telefono = perfil.valueOrNull?.telefono;

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
        await ref.read(authProvider).signOut();
        if (context.mounted) context.go('/login');
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ContentFrame(
        maxWidth: 720,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                SozuAvatar(
                    iniciales:
                        perfil.valueOrNull?.iniciales ?? initials(nombre),
                    size: 72),
                const SizedBox(height: 12),
                Text(nombre,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: tone.textPrimary)),
                if (auth.profile?.rolNombre != null) ...[
                  const SizedBox(height: 8),
                  StatusBadge(
                      label: auth.profile!.rolNombre!,
                      tone: BadgeTone.positive),
                ],
              ],
            ),
          ),

          _sectionLabel(tone, 'Contacto'),
          AppCard(
            child: Column(
              children: [
                _InfoRow(
                    icon: Icons.mail_outline,
                    label: 'Correo',
                    value: email,
                    loading: perfil.isLoading),
                Divider(color: tone.border, height: 24),
                _InfoRow(
                    icon: Icons.call_outlined,
                    label: 'Teléfono',
                    value: telefono ?? 'No registrado',
                    loading: perfil.isLoading),
              ],
            ),
          ),

          _sectionLabel(tone, 'Apariencia'),
          AppCard(child: _ThemeSelector(tone: tone)),

          _sectionLabel(tone, 'Seguridad'),
          GestureDetector(
            onTap: () => context.push('/cambiar-password'),
            child: AppCard(
              child: Row(
                children: [
                  const Icon(Icons.lock_outline,
                      size: 20, color: SozuColors.emerald600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Cambiar contraseña',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: tone.textPrimary)),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: tone.textMuted),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          GestureDetector(
            onTap: confirmarSalir,
            child: AppCard(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, size: 20, color: tone.negative),
                  const SizedBox(width: 8),
                  Text('Cerrar sesión',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: tone.negative)),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool loading;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: tone.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: tone.textMuted)),
              const SizedBox(height: 2),
              loading
                  ? const Skeleton(width: 160, height: 14)
                  : Text(value,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: tone.textPrimary)),
            ],
          ),
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
