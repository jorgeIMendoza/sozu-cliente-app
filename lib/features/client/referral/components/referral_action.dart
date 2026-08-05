import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:sozu_cliente_app/widgets/portal_widgets.dart';

/// Portal de Embajadores: el cliente se loguea ahí con su misma cuenta.
const _kEmbajadoresUrl = 'https://embajadores.sozu.com/login';

/// Pasos del programa de Embajadores (icono + título + descripción).
const List<(IconData, String, String)> _kSteps = [
  (
    Icons.person_add_alt_1_outlined,
    '1. Refieres',
    'Registras a tu conocido como referido con su consentimiento.',
  ),
  (
    Icons.groups_2_outlined,
    '2. SOZU da seguimiento',
    'Un asesor interno contacta, presenta y acompaña la venta. Tú no negocias '
        'ni cierras.',
  ),
  (
    Icons.verified_outlined,
    '3. Se concreta la venta',
    'Cuando tu referido compra y la operación se valida, se genera tu comisión.',
  ),
  (
    Icons.account_balance_wallet_outlined,
    '4. Comisión autorizada',
    'Administración autoriza el pago de tu comisión.',
  ),
  (
    Icons.receipt_long_outlined,
    '5. Subes tu factura',
    'En la sección Pagos cargas tu factura para que podamos liquidar.',
  ),
  (
    Icons.task_alt_outlined,
    '6. Te pagamos',
    'Realizamos el pago y obtienes tu recibo en el portal.',
  ),
];

/// Botón "Referir" de la topbar: abre el modal que explica el programa de
/// Embajadores y la redirección. Compacto para caber junto a la campana.
class ReferralButton extends StatelessWidget {
  const ReferralButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SButton.secondary(
      label: 'Referir',
      icon: Icons.card_giftcard_outlined,
      size: SButtonSize.sm,
      fullWidth: false,
      isNavigation: true,
      tooltip: 'Referir e ir al portal de Embajadores',
      onPressed: () => showReferralDialog(context),
    );
  }
}

/// Abre el modal del programa de Embajadores. En portal (web ancho) va como
/// diálogo centrado; en móvil como bottom sheet.
Future<void> showReferralDialog(BuildContext context) {
  if (isPortalMode(context)) {
    return showPortalDialog<void>(
      context,
      maxWidth: 520,
      child: const PortalDialogShell(
        title: '¿Cómo funciona el programa de Embajadores?',
        subtitle: 'Refiere, nosotros vendemos, tú ganas.',
        child: _ReferralContent(),
      ),
    );
  }
  final t = context.s;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: t.color.surface,
    isScrollControlled: true,
    // El contenido es alto (6 pasos): que la hoja pueda ocupar casi todo.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(t.radius.lg)),
    ),
    builder: (_) => const SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: _ReferralContent(showTitle: true),
      ),
    ),
  );
}

/// Cuerpo del modal: encabezado (móvil), los 6 pasos, la nota de redirección y
/// los CTA. [showTitle] pinta el encabezado; en portal lo pone
/// [PortalDialogShell].
class _ReferralContent extends StatelessWidget {
  final bool showTitle;

  const _ReferralContent({this.showTitle = false});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) ...[
          Text(
            '¿Cómo funciona el programa de Embajadores?',
            style: t.text.h3,
          ),
          SizedBox(height: t.space.xxs),
          Text(
            'Refiere, nosotros vendemos, tú ganas.',
            style: t.text.bodySmall.copyWith(color: t.color.fgMuted),
          ),
          SizedBox(height: t.space.lg),
        ],
        for (final (icon, title, desc) in _kSteps) ...[
          _Step(icon: icon, title: title, description: desc),
          SizedBox(height: t.space.md),
        ],
        SizedBox(height: t.space.xs),
        // Nota de redirección + login.
        Container(
          padding: EdgeInsets.all(t.space.md),
          decoration: BoxDecoration(
            color: t.color.primarySoft,
            borderRadius: BorderRadius.circular(t.radius.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.open_in_new, size: 18, color: t.color.primary),
              SizedBox(width: t.space.sm),
              Expanded(
                child: Text(
                  'Al continuar te llevaremos al portal de Embajadores de SOZU. '
                  'Inicia sesión con esta misma cuenta y contraseña para acceder.',
                  style: t.text.bodySmall.copyWith(color: t.color.fg),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: t.space.lg),
        Row(
          children: [
            Expanded(
              child: SButton.secondary(
                label: 'Cancelar',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            SizedBox(width: t.space.sm),
            Expanded(
              child: SButton(
                label: 'Ir al portal',
                trailingIcon: Icons.open_in_new,
                isNavigation: true,
                onPressed: () => _openEmbajadores(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Una fila de paso: icono en círculo suave + título + descripción.
class _Step extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _Step({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: t.color.primarySoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: t.color.primary),
        ),
        SizedBox(width: t.space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: t.text.body.copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: t.space.xxs),
              Text(
                description,
                style: t.text.bodySmall.copyWith(color: t.color.fgMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _openEmbajadores(BuildContext context) async {
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final ok = await launchUrl(
    Uri.parse(_kEmbajadoresUrl),
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
  if (nav.canPop()) nav.pop();
  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('No se pudo abrir el portal de Embajadores.'),
      ),
    );
  }
}
