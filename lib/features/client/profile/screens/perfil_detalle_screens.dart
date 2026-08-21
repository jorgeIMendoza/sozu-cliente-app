import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/shared/components/open_media.dart';
import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/profile/providers/profile_providers.dart';
import 'package:sozu_cliente_app/widgets/fx.dart';
import 'package:sozu_cliente_app/features/client/profile/components/perfil_section_card.dart';
import 'package:sozu_cliente_app/features/client/profile/components/perfil_sheets.dart';
import 'package:sozu_cliente_app/widgets/portal_widgets.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Detalle de información personal: identificación y contacto.
class PerfilPersonalScreen extends ConsumerWidget {
  /// En modo portal, si se provee, la vista se pinta inline en lugar de un
  /// diálogo centrado.
  final VoidCallback? onBack;

  const PerfilPersonalScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(profileProvider);
    final p = perfil.valueOrNull;

    final filas = <Widget>[
      PerfilInfoRow(label: 'Tipo de persona', value: p?.tipoPersonaLabel),
      PerfilInfoRow(
        label: (p?.esMoral ?? false) ? 'Razón social' : 'Nombre completo',
        value: p?.nombreLegal,
      ),
      PerfilInfoRow(label: 'RFC con homoclave', value: p?.rfc, mono: true),
      // Una persona moral no tiene CURP: la fila salía siempre "Sin dato".
      if (!(p?.esMoral ?? false))
        PerfilInfoRow(label: 'CURP', value: p?.curp, mono: true),
      PerfilInfoRow(
        label: 'Teléfono',
        value: p?.telefono != null
            ? '${p?.clavePaisTelefono ?? '+52'} ${p?.telefono}'
            : null,
      ),
      PerfilInfoRow(label: 'Ocupación', value: p?.ocupacion),
      PerfilInfoRow(
        label: 'Correo electrónico',
        value: p?.email,
        note: 'No editable',
        isLast: true,
      ),
    ];

    if (isPortalMode(context)) {
      final actions = [
        if (p != null)
          SButton.secondary(
            label: 'Editar',
            onPressed: () => showEditPersonalSheet(context, p),
            size: SButtonSize.sm,
            fullWidth: false,
          ),
      ];
      // El portal no muestra la nota "Tus datos serán validados…" en esta vista.
      final child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (perfil.isLoading)
            const _DetalleSkeleton()
          else if (perfil.hasError)
            SErrorState(
              title: 'No pudimos cargar tu información',
              onRetry: () => ref.invalidate(profileProvider),
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
    final tone = context.s.color;

    return Scaffold(
      appBar: AppBar(title: const Text('Información personal')),
      body: ContentFrame(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            SCard(
              child: perfil.isLoading
                  ? const _DetalleSkeleton()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DetalleHeader(
                          title: 'Información personal',
                          subtitle: 'Identificación y datos de contacto',
                          onEdit: (p != null)
                              ? () => showEditPersonalSheet(context, p)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        PerfilInfoRow(
                          label: 'Tipo de persona',
                          value: p?.tipoPersonaLabel,
                        ),
                        PerfilInfoRow(
                          label: (p?.esMoral ?? false)
                              ? 'Razón social'
                              : 'Nombre completo',
                          value: p?.nombreLegal,
                        ),
                        PerfilInfoRow(
                          label: 'RFC con homoclave',
                          value: p?.rfc,
                          mono: true,
                        ),
                        // Una persona moral no tiene CURP.
                        if (!(p?.esMoral ?? false))
                          PerfilInfoRow(
                            label: 'CURP',
                            value: p?.curp,
                            mono: true,
                          ),
                        PerfilInfoRow(
                          label: 'Teléfono',
                          value: p?.telefono != null
                              ? '${p?.clavePaisTelefono ?? '+52'} ${p?.telefono}'
                              : null,
                        ),
                        PerfilInfoRow(label: 'Ocupación', value: p?.ocupacion),
                        PerfilInfoRow(
                          label: 'Correo electrónico',
                          value: p?.email,
                          note: 'No editable',
                          isLast: true,
                        ),
                      ],
                    ),
            ),
            if (perfil.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SErrorState(
                  title: 'No pudimos cargar tu información',
                  onRetry: () => ref.invalidate(profileProvider),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Tus datos serán validados por el área correspondiente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: tone.fgSubtle),
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
    final perfil = ref.watch(profileProvider);
    final p = perfil.valueOrNull;

    if (isPortalMode(context)) {
      final actions = [
        if (p != null)
          SButton.secondary(
            label: 'Editar',
            onPressed: () => showEditFiscalSheet(context, p),
            size: SButtonSize.sm,
            fullWidth: false,
          ),
      ];
      final child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AmberInfoBanner(
            text: 'Tus datos serán validados por el área correspondiente.',
          ),
          const SizedBox(height: 12),
          if (perfil.isLoading)
            const _DetalleSkeleton()
          else if (perfil.hasError)
            SErrorState(
              title: 'No pudimos cargar tu información',
              onRetry: () => ref.invalidate(profileProvider),
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
              text: 'Tus datos serán validados por el área correspondiente.',
            ),
            const SizedBox(height: 12),
            SCard(
              child: perfil.isLoading
                  ? const _DetalleSkeleton()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DetalleHeader(
                          title: 'Información fiscal',
                          subtitle: 'Régimen, CFDI y dirección fiscal',
                          onEdit: (p != null)
                              ? () => showEditFiscalSheet(context, p)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        PerfilInfoRow(
                          label: 'Régimen fiscal',
                          value: p?.regimenDisplay,
                        ),
                        PerfilInfoRow(
                          label: 'Uso CFDI',
                          value: p?.usoCfdiDisplay,
                        ),
                        PerfilInfoRow(
                          label: 'Código postal',
                          value: p?.cp,
                          mono: true,
                        ),
                        PerfilInfoRow(label: 'Calle', value: p?.calle),
                        PerfilInfoRow(label: 'Núm. exterior', value: p?.numExt),
                        PerfilInfoRow(label: 'Núm. interior', value: p?.numInt),
                        PerfilInfoRow(
                          label: 'Colonia',
                          value: p?.colonia,
                          isLast: true,
                        ),
                      ],
                    ),
            ),
            if (perfil.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SErrorState(
                  title: 'No pudimos cargar tu información',
                  onRetry: () => ref.invalidate(profileProvider),
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
    final tone = context.s.color;
    final perfil = ref.watch(profileProvider);
    final cuentas = perfil.valueOrNull?.cuentasBancarias ?? [];

    // Solo lectura: el alta se hace en Documentos → Cuenta bancaria, así que
    // aquí no hay botón de "agregar".
    List<Widget> cuerpo() => [
      if (perfil.isLoading)
        const _DetalleSkeleton()
      else if (perfil.hasError)
        SErrorState(
          title: 'No pudimos cargar tus cuentas',
          onRetry: () => ref.invalidate(profileProvider),
        )
      else if (cuentas.isEmpty)
        const _CuentasEmptyBox()
      else
        for (final c in cuentas) ...[
          _CuentaCard(cuenta: c),
          const SizedBox(height: 10),
        ],
      const SizedBox(height: 4),
      const _CuentasFooterLink(),
    ];

    if (isPortalMode(context)) {
      final child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _BlueInfoBanner(
            text:
                'Por tu seguridad, toda alta o cambio de cuenta se notifica de inmediato.',
          ),
          const SizedBox(height: 12),
          ...cuerpo(),
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
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: tone.primarySoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: SozuBrand.green500.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 15,
                    color: tone.primaryHover,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Por tu seguridad, toda alta o cambio de cuenta se notifica de inmediato.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: tone.primaryHover,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...cuerpo(),
          ],
        ),
      ),
    );
  }
}

// ─── Shell inline del portal ("← Volver al Perfil" + card a 920px) ───────────

/// Detalle inline del Perfil en modo portal: botón "← Volver al Perfil" + card
/// ancho con header (título/subtítulo + acciones) y cuerpo.
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
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            icon: const Icon(Icons.arrow_back, size: 15),
            label: const Text('Volver al Perfil'),
          ),
        ),
        const SizedBox(height: 8),
        SCard(
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
                        Text(
                          title,
                          style: portalText(size: 18, weight: FontWeight.w700),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: portalText(
                              size: 13.5,
                              color: PortalColors.mutedForeground,
                            ),
                          ),
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
    final tone = context.s.color;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: tone.fg,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: tone.fgMuted),
              ),
            ],
          ),
        ),
        if (onEdit != null)
          OutlinedButton(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(
              foregroundColor: tone.fg,
              side: BorderSide(color: tone.border),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
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
    final tone = context.s.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: tone.warningSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SozuAmber.base.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 15, color: SozuAmber.strong),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, color: SozuAmber.strong),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner informativo azul del aviso de seguridad de cuentas.
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
              style: portalText(size: 12.5, weight: FontWeight.w500, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuenta bancaria: banco, número enmascarado, titular, estatus y las dos
/// acciones que faltaban, ver la carátula y corregir los datos.
class _CuentaCard extends StatelessWidget {
  final CuentaBancariaPerfil cuenta;

  const _CuentaCard({required this.cuenta});

  /// Sin carátula no puede ir a revisión → "Incompleto"; 2 validada, 3
  /// rechazada, el resto en revisión.
  (String, SBadgeTone) get _badge {
    if (cuenta.evidencia == null) return ('Incompleto', SBadgeTone.negative);
    if (cuenta.estatus == 2) return ('Validada', SBadgeTone.positive);
    if (cuenta.estatus == 3) return ('Rechazada', SBadgeTone.negative);
    return ('En revisión', SBadgeTone.pending);
  }

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final (label, badgeTone) = _badge;
    return SCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tone.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.credit_card_outlined,
              size: 19,
              color: tone.primaryHover,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cuenta.banco,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: tone.fg,
                  ),
                ),
                if (cuenta.cuentaMasked != null)
                  Text(
                    cuenta.cuentaMasked!,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: tone.fgMuted,
                    ),
                  ),
                if (cuenta.titular != null)
                  Text(
                    'Titular: ${cuenta.titular!}',
                    style: TextStyle(fontSize: 12, color: tone.fgSubtle),
                  ),
              ],
            ),
          ),
          SBadge(label: label, tone: badgeTone),
          SizedBox(width: context.s.space.xs),
          if (cuenta.evidencia != null)
            IconButton(
              tooltip: 'Ver carátula',
              iconSize: 18,
              color: tone.fgMuted,
              icon: const Icon(Icons.visibility_outlined),
              onPressed: () => openMedia(
                context,
                cuenta.evidencia,
                titulo: 'Carátula · ${cuenta.banco}',
              ),
            ),
          IconButton(
            tooltip: 'Editar cuenta',
            iconSize: 18,
            color: tone.fgMuted,
            icon: const Icon(Icons.edit_outlined),
            // Con la cuenta por delante la hoja EDITA; sin ella daba de alta
            // otra y el cliente terminaba con duplicados.
            onPressed: () => showCuentaBancariaSheet(context, cuenta: cuenta),
          ),
        ],
      ),
    );
  }
}

/// Estado vacío de cuentas, con la guía hacia Documentos → Cuenta bancaria.
class _CuentasEmptyBox extends StatelessWidget {
  const _CuentasEmptyBox();

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        color: tone.surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.border),
      ),
      child: Column(
        children: [
          Text(
            'Sin cuentas registradas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: tone.fg,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Regístrala en Documentos → Cuenta bancaria.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: tone.fgSubtle),
          ),
        ],
      ),
    );
  }
}

/// Pie de cuentas, siempre visible: enlace "Documentos → Cuenta bancaria" que
/// lleva al Expediente.
class _CuentasFooterLink extends StatelessWidget {
  const _CuentasFooterLink();

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final muted = TextStyle(fontSize: 12, color: tone.fgSubtle);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Para registrar una cuenta, ve a ', style: muted),
        InkWell(
          onTap: () => context.push('/expediente'),
          child: Text(
            'Documentos → Cuenta bancaria',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tone.primaryHover,
            ),
          ),
        ),
        Text('.', style: muted),
      ],
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
        SSkeleton(width: 180, height: 18),
        SizedBox(height: 16),
        SSkeleton(height: 14),
        SizedBox(height: 12),
        SSkeleton(height: 14),
        SizedBox(height: 12),
        SSkeleton(height: 14),
        SizedBox(height: 12),
        SSkeleton(width: 200, height: 14),
      ],
    );
  }
}
