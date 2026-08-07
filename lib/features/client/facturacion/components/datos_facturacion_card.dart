import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/profile/components/perfil_section_card.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Datos fiscales con los que se timbran las facturas. Vive aquí porque es
/// viendo la factura cuando el cliente nota que su RFC está mal;
/// [onModificar] lleva a la sección de Perfil que los edita.
class DatosFacturacionCard extends StatelessWidget {
  /// `null` mientras el perfil carga: la tarjeta muestra su esqueleto.
  final ClientePerfil? perfil;
  final VoidCallback onModificar;

  const DatosFacturacionCard({
    super.key,
    required this.perfil,
    required this.onModificar,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final p = perfil;

    return SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tus datos de facturación',
                      style: t.text.label.copyWith(color: t.color.fg),
                    ),
                    Text(
                      'Con estos se timbran tus facturas',
                      style: t.text.caption.copyWith(color: t.color.fgMuted),
                    ),
                  ],
                ),
              ),
              SButton.secondary(
                label: 'Modificar',
                icon: Icons.edit_outlined,
                size: SButtonSize.sm,
                fullWidth: false,
                onPressed: onModificar,
              ),
            ],
          ),
          SizedBox(height: t.space.sm),
          if (p == null)
            const SSkeleton(height: 96)
          else ...[
            PerfilInfoRow(label: 'RFC', value: p.rfc, mono: true),
            PerfilInfoRow(label: 'Régimen fiscal', value: p.regimenDisplay),
            PerfilInfoRow(label: 'Uso CFDI', value: p.usoCfdiDisplay),
            PerfilInfoRow(
              label: 'Código postal',
              value: p.cp,
              mono: true,
              isLast: true,
            ),
          ],
        ],
      ),
    );
  }
}
