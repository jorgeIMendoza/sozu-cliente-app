import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/portal_theme.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../providers/impersonation_provider.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';
import '../widgets/perfil_section_card.dart';
import '../widgets/perfil_sheets.dart';
import '../widgets/portal_widgets.dart';

/// Vistas de detalle del Perfil (espejo de las vistas personal/fiscal/cuentas
/// de ClientePerfil.tsx del portal). En móvil se abren con Navigator.push
/// desde la pantalla de Perfil ("Ver todo" / "Ver cuentas"); en modo portal
/// (web ≥1024) se muestran como diálogos centrados (max ~560px) vía
/// [showPortalDialog], por lo que cada pantalla pinta su variante
/// [PortalDialogShell] en lugar del Scaffold fullscreen.

/// Detalle de información personal: identificación y contacto.
class PerfilPersonalScreen extends ConsumerWidget {
  /// En modo portal, si se provee, la vista se pinta inline (con "← Volver al
  /// Perfil") en lugar de un diálogo centrado — paridad con setView del portal.
  final VoidCallback? onBack;

  const PerfilPersonalScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(clientePerfilProvider);
    final impersonating = ref.watch(impersonationProvider).active;
    final p = perfil.valueOrNull;

    final filas = <Widget>[
      PerfilInfoRow(label: 'Tipo de persona', value: p?.tipoPersonaLabel),
      PerfilInfoRow(label: 'Nombre completo', value: p?.nombreLegal),
      PerfilInfoRow(label: 'RFC con homoclave', value: p?.rfc, mono: true),
      PerfilInfoRow(label: 'CURP', value: p?.curp, mono: true),
      PerfilInfoRow(
          label: 'Teléfono',
          value: p?.telefono != null
              ? '${p?.clavePaisTelefono ?? '+52'} ${p?.telefono}'
              : null),
      PerfilInfoRow(
          label: 'Correo electrónico',
          value: p?.email,
          note: 'No editable',
          isLast: true),
    ];

    if (isPortalMode(context)) {
      final actions = [
        if (!impersonating && p != null)
          PortalOutlineButton(
            label: 'Editar',
            onPressed: () => showEditPersonalSheet(context, p),
          ),
      ];
      // El portal no muestra la nota "Tus datos serán validados…" en esta vista.
      final child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (perfil.isLoading)
            const _DetalleSkeleton()
          else if (perfil.hasError)
            ErrorCard(
              title: 'No pudimos cargar tu información',
              onRetry: () => ref.invalidate(clientePerfilProvider),
            )
          else
            ...filas,
        ],
      );
      if (onBack != null) {
        return _PerfilDetalleInline(
          title: 'Información personal',
          subtitle: 'Identificación y datos de contacto',
          actions: actions,
          onBack: onBack!,
          child: child,
        );
      }
      return PortalDialogShell(
        title: 'Información personal',
        subtitle: 'Identificación y datos de contacto',
        actions: actions,
        child: child,
      );
    }
    final tone = SozuTone.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Información personal')),
      body: ContentFrame(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            AppCard(
              child: perfil.isLoading
                  ? const _DetalleSkeleton()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DetalleHeader(
                          title: 'Información personal',
                          subtitle: 'Identificación y datos de contacto',
                          onEdit: (!impersonating && p != null)
                              ? () => showEditPersonalSheet(context, p)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        PerfilInfoRow(
                            label: 'Tipo de persona',
                            value: p?.tipoPersonaLabel),
                        PerfilInfoRow(
                            label: 'Nombre completo',
                            value: p?.nombreLegal),
                        PerfilInfoRow(
                            label: 'RFC con homoclave',
                            value: p?.rfc,
                            mono: true),
                        PerfilInfoRow(label: 'CURP', value: p?.curp, mono: true),
                        PerfilInfoRow(
                            label: 'Teléfono',
                            value: p?.telefono != null
                                ? '${p?.clavePaisTelefono ?? '+52'} ${p?.telefono}'
                                : null),
                        PerfilInfoRow(
                            label: 'Correo electrónico',
                            value: p?.email,
                            note: 'No editable',
                            isLast: true),
                      ],
                    ),
            ),
            if (perfil.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ErrorCard(
                  title: 'No pudimos cargar tu información',
                  onRetry: () => ref.invalidate(clientePerfilProvider),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Tus datos serán validados por el área correspondiente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: tone.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detalle de información fiscal: régimen, CFDI y dirección fiscal.
class PerfilFiscalScreen extends ConsumerWidget {
  final VoidCallback? onBack;

  const PerfilFiscalScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(clientePerfilProvider);
    final impersonating = ref.watch(impersonationProvider).active;
    final p = perfil.valueOrNull;

    if (isPortalMode(context)) {
      final actions = [
        if (!impersonating && p != null)
          PortalOutlineButton(
            label: 'Editar',
            onPressed: () => showEditFiscalSheet(context, p),
          ),
      ];
      final child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AmberInfoBanner(
              text: 'Tus datos serán validados por el área correspondiente.'),
          const SizedBox(height: 12),
          if (perfil.isLoading)
            const _DetalleSkeleton()
          else if (perfil.hasError)
            ErrorCard(
              title: 'No pudimos cargar tu información',
              onRetry: () => ref.invalidate(clientePerfilProvider),
            )
          else ...[
            PerfilInfoRow(label: 'Régimen fiscal', value: p?.regimenDisplay),
            PerfilInfoRow(label: 'Uso CFDI', value: p?.usoCfdiDisplay),
            PerfilInfoRow(label: 'Código postal', value: p?.cp, mono: true),
            PerfilInfoRow(label: 'Calle', value: p?.calle),
            PerfilInfoRow(label: 'Núm. exterior', value: p?.numExt),
            PerfilInfoRow(label: 'Núm. interior', value: p?.numInt),
            PerfilInfoRow(label: 'Colonia', value: p?.colonia, isLast: true),
          ],
        ],
      );
      if (onBack != null) {
        return _PerfilDetalleInline(
          title: 'Información fiscal',
          subtitle: 'Régimen, CFDI y dirección fiscal',
          actions: actions,
          onBack: onBack!,
          child: child,
        );
      }
      return PortalDialogShell(
        title: 'Información fiscal',
        subtitle: 'Régimen, CFDI y dirección fiscal',
        actions: actions,
        child: child,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Información fiscal')),
      body: ContentFrame(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const _AmberInfoBanner(
                text: 'Tus datos serán validados por el área correspondiente.'),
            const SizedBox(height: 12),
            AppCard(
              child: perfil.isLoading
                  ? const _DetalleSkeleton()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DetalleHeader(
                          title: 'Información fiscal',
                          subtitle: 'Régimen, CFDI y dirección fiscal',
                          onEdit: (!impersonating && p != null)
                              ? () => showEditFiscalSheet(context, p)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        PerfilInfoRow(
                            label: 'Régimen fiscal',
                            value: p?.regimenDisplay),
                        PerfilInfoRow(
                            label: 'Uso CFDI', value: p?.usoCfdiDisplay),
                        PerfilInfoRow(
                            label: 'Código postal', value: p?.cp, mono: true),
                        PerfilInfoRow(label: 'Calle', value: p?.calle),
                        PerfilInfoRow(
                            label: 'Núm. exterior', value: p?.numExt),
                        PerfilInfoRow(
                            label: 'Núm. interior', value: p?.numInt),
                        PerfilInfoRow(
                            label: 'Colonia', value: p?.colonia, isLast: true),
                      ],
                    ),
            ),
            if (perfil.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ErrorCard(
                  title: 'No pudimos cargar tu información',
                  onRetry: () => ref.invalidate(clientePerfilProvider),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Detalle de cuentas bancarias de dispersión.
class PerfilCuentasScreen extends ConsumerWidget {
  final VoidCallback? onBack;

  const PerfilCuentasScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = SozuTone.of(context);
    final perfil = ref.watch(clientePerfilProvider);
    final impersonating = ref.watch(impersonationProvider).active;
    final cuentas = perfil.valueOrNull?.cuentasBancarias ?? [];

    if (isPortalMode(context)) {
      final child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _BlueInfoBanner(
              text:
                  'Por tu seguridad, toda alta o cambio de cuenta se notifica de inmediato.'),
          const SizedBox(height: 12),
          if (perfil.isLoading)
            const _DetalleSkeleton()
          else if (perfil.hasError)
            ErrorCard(
              title: 'No pudimos cargar tus cuentas',
              onRetry: () => ref.invalidate(clientePerfilProvider),
            )
          else if (cuentas.isEmpty)
            const EmptyCard(
              icon: Icons.credit_card_off_outlined,
              text:
                  'Sin cuentas registradas.\nAgrega tu primera cuenta bancaria.',
            )
          else
            for (final c in cuentas) ...[
              _CuentaCard(
                cuenta: c,
                onEdit: impersonating
                    ? null
                    : () => showCuentaBancariaSheet(context, cuenta: c),
              ),
              const SizedBox(height: 10),
            ],
          if (!impersonating) ...[
            const SizedBox(height: 6),
            PortalBlockButton(
              label: 'Agregar cuenta bancaria',
              onPressed: () => showCuentaBancariaSheet(context),
            ),
          ],
        ],
      );
      if (onBack != null) {
        return _PerfilDetalleInline(
          title: 'Cuentas bancarias',
          subtitle: 'SOZU deposita directamente a estas cuentas.',
          actions: const [],
          onBack: onBack!,
          child: child,
        );
      }
      return PortalDialogShell(
        title: 'Cuentas bancarias',
        subtitle: 'SOZU deposita directamente a estas cuentas.',
        child: child,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cuentas bancarias')),
      body: ContentFrame(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: tone.primarySoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: SozuColors.emerald500.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined,
                      size: 15, color: tone.primaryDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Por tu seguridad, toda alta o cambio de cuenta se notifica de inmediato.',
                      style: TextStyle(
                          fontSize: 12.5, color: tone.primaryDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (perfil.isLoading)
              const AppCard(child: _DetalleSkeleton())
            else if (cuentas.isEmpty)
              const EmptyCard(
                icon: Icons.credit_card_off_outlined,
                text:
                    'Sin cuentas registradas.\nAgrega tu primera cuenta bancaria.',
              )
            else
              for (final c in cuentas) ...[
                _CuentaCard(
                  cuenta: c,
                  onEdit: impersonating
                      ? null
                      : () => showCuentaBancariaSheet(context, cuenta: c),
                ),
                const SizedBox(height: 10),
              ],
            if (perfil.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: ErrorCard(
                  title: 'No pudimos cargar tus cuentas',
                  onRetry: () => ref.invalidate(clientePerfilProvider),
                ),
              ),
            const SizedBox(height: 6),
            if (!impersonating)
              FilledButton(
                onPressed: () => showCuentaBancariaSheet(context),
                child: const Text('Agregar cuenta bancaria'),
              ),
            const SizedBox(height: 12),
            Text(
              'SOZU deposita directamente a estas cuentas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: tone.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shell inline del portal ("← Volver al Perfil" + card a 920px) ───────────

/// Vista de detalle inline del Perfil en modo portal: botón "← Volver al
/// Perfil" + card ancho con header (título/subtítulo + acciones) y cuerpo.
/// Réplica de las vistas personal/fiscal/cuentas de ClientePerfil.tsx (que
/// usan `setView` en lugar de un diálogo centrado).
class _PerfilDetalleInline extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback onBack;
  final Widget child;

  const _PerfilDetalleInline({
    required this.title,
    required this.onBack,
    required this.child,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onBack,
            style: TextButton.styleFrom(
              foregroundColor: PortalColors.mutedForeground,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            icon: const Icon(Icons.arrow_back, size: 15),
            label: const Text('Volver al Perfil'),
          ),
        ),
        const SizedBox(height: 8),
        PortalCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style:
                                portalText(size: 18, weight: FontWeight.w700)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(subtitle!,
                              style: portalText(
                                  size: 13.5,
                                  color: PortalColors.mutedForeground)),
                        ],
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Piezas internas ─────────────────────────────────────────────────────────

class _DetalleHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onEdit;

  const _DetalleHeader({
    required this.title,
    required this.subtitle,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: tone.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style:
                      TextStyle(fontSize: 13, color: tone.textSecondary)),
            ],
          ),
        ),
        if (onEdit != null)
          OutlinedButton(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(
              foregroundColor: tone.textPrimary,
              side: BorderSide(color: tone.border),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            child: const Text('Editar'),
          ),
      ],
    );
  }
}

class _AmberInfoBanner extends StatelessWidget {
  final String text;
  const _AmberInfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: tone.pendingSoft,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: SozuColors.amber500.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              size: 15, color: SozuColors.amber600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12.5, color: SozuColors.amber600)),
          ),
        ],
      ),
    );
  }
}

/// Banner informativo azul del diálogo de cuentas en modo portal (espejo del
/// aviso de seguridad de la vista "cuentas" de ClientePerfil.tsx).
class _BlueInfoBanner extends StatelessWidget {
  final String text;
  const _BlueInfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    const fg = Color(0xFF2C5D8A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4FB),
        borderRadius: BorderRadius.circular(kPortalRadiusSm),
        border: Border.all(color: const Color(0xFFCFE0F3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, size: 14, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style:
                  portalText(size: 12.5, weight: FontWeight.w500, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

class _CuentaCard extends StatelessWidget {
  final CuentaBancariaPerfil cuenta;
  final VoidCallback? onEdit;

  const _CuentaCard({required this.cuenta, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tone.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.credit_card_outlined,
                size: 19, color: tone.primaryDark),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cuenta.banco,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: tone.textPrimary)),
                if (cuenta.clabeMasked != null)
                  Text(cuenta.clabeMasked!,
                      style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          color: tone.textSecondary)),
                if (cuenta.titular != null)
                  Text(cuenta.titular!,
                      style: TextStyle(
                          fontSize: 12, color: tone.textMuted)),
              ],
            ),
          ),
          const StatusBadge(label: 'Activa', tone: BadgeTone.positive),
          if (onEdit != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  size: 18, color: tone.textSecondary),
              onPressed: onEdit,
              tooltip: 'Editar cuenta',
            ),
          ],
        ],
      ),
    );
  }
}

class _DetalleSkeleton extends StatelessWidget {
  const _DetalleSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Skeleton(width: 180, height: 18),
        SizedBox(height: 16),
        Skeleton(height: 14),
        SizedBox(height: 12),
        Skeleton(height: 14),
        SizedBox(height: 12),
        Skeleton(height: 14),
        SizedBox(height: 12),
        Skeleton(width: 200, height: 14),
      ],
    );
  }
}
