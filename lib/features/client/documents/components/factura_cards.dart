import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/core/format.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Facturas de una unidad: la de compra y las de mantenimiento.
///
/// Es el modelo de la pantalla, no del backend: junta las dos listas que
/// llegan sueltas de `cliente-documentos`.
@immutable
class UnidadFacturas {
  /// Cuenta PADRE. `null` en el grupo de las que aún no traen unidad.
  final int? idCuenta;
  final String nombre;
  final FacturaDocumento? compra;
  final List<FacturaMantenimientoDoc> mantenimiento;

  const UnidadFacturas({
    required this.idCuenta,
    required this.nombre,
    required this.compra,
    required this.mantenimiento,
  });

  int get total => (compra == null ? 0 : 1) + mantenimiento.length;
}

/// Fila de la lista de unidades: nombre y cuántas facturas tiene.
class UnidadFacturasCard extends StatelessWidget {
  final UnidadFacturas unidad;
  final VoidCallback onTap;

  const UnidadFacturasCard({
    super.key,
    required this.unidad,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;
    final n = unidad.total;
    return SPressable(
      onTap: onTap,
      borderRadius: t.radius.lgBorder,
      hoverLift: true,
      child: SCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: t.radius.mdBorder,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 20,
                color: c.primaryHover,
              ),
            ),
            SizedBox(width: t.space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unidad.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.label.copyWith(color: c.fg),
                  ),
                  Text(
                    n == 1 ? '1 factura' : '$n facturas',
                    style: t.text.caption.copyWith(color: c.fgMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: c.fgSubtle),
          ],
        ),
      ),
    );
  }
}

/// Facturas de una unidad, en dos secciones: la de la unidad y las de
/// mantenimiento, que solo existen cuando ya se entregó.
class UnidadFacturasDetalle extends StatelessWidget {
  final UnidadFacturas unidad;

  /// `null` cuando no hay a dónde volver (el cliente tiene una sola unidad).
  final VoidCallback? onVolver;
  final ValueChanged<String> onAbrir;

  const UnidadFacturasDetalle({
    super.key,
    required this.unidad,
    required this.onVolver,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final mant = unidad.mantenimiento;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onVolver != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: SButton.link(
              label: 'Todas las unidades',
              icon: Icons.arrow_back,
              isNavigation: true,
              onPressed: onVolver,
            ),
          ),
          SizedBox(height: t.space.xs),
        ],
        Text(unidad.nombre, style: t.text.h3.copyWith(color: t.color.fg)),
        SizedBox(height: t.space.lg),

        const SSectionLabel.heading(
          icon: Icons.home_outlined,
          text: 'Factura de la unidad',
        ),
        if (unidad.compra == null)
          const SEmptyState.card(
            icon: Icons.receipt_outlined,
            title: 'Sin factura de compra todavía.',
          )
        else
          FacturaCard(
            titulo: 'Factura de compra',
            subtitulo: unidad.nombre,
            pdf: unidad.compra!.pdf,
            xml: unidad.compra!.xml,
            onAbrir: onAbrir,
          ),

        SizedBox(height: t.space.lg),
        SSectionLabel.heading(
          icon: Icons.build_outlined,
          text: mant.isEmpty
              ? 'Facturas de mantenimiento'
              : 'Facturas de mantenimiento (${mant.length})',
        ),
        if (mant.isEmpty)
          const SEmptyState.card(
            icon: Icons.build_outlined,
            title: 'Sin facturas de mantenimiento.',
            message:
                'Se generan por cada pago de mantenimiento, a partir de que se '
                'entrega la unidad.',
          )
        else
          for (final f in mant) ...[
            FacturaCard(
              titulo: f.fecha != null
                  ? 'Mantenimiento · ${formatDate(f.fecha)}'
                  : 'Mantenimiento',
              subtitulo: f.monto != null ? formatMXN(f.monto!) : null,
              pdf: f.pdf,
              xml: f.xml,
              onAbrir: onAbrir,
            ),
            SizedBox(height: t.space.sm),
          ],
      ],
    );
  }
}

/// Una factura con sus dos archivos. El XML es el CFDI válido ante el SAT y el
/// PDF su representación impresa: se ofrecen los dos, nunca uno solo.
class FacturaCard extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final String? pdf;
  final String? xml;

  /// Recibe la URL del archivo tocado. La pantalla decide cómo abrirlo.
  final ValueChanged<String> onAbrir;

  const FacturaCard({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.pdf,
    required this.xml,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;
    return SCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.text.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.fg,
                  ),
                ),
                if (subtitulo != null)
                  Text(
                    subtitulo!,
                    style: t.text.caption.copyWith(color: c.fgMuted),
                  ),
              ],
            ),
          ),
          SizedBox(width: t.space.xs),
          _Archivo(label: 'PDF', url: pdf, onAbrir: onAbrir),
          SizedBox(width: t.space.xs),
          _Archivo(label: 'XML', url: xml, onAbrir: onAbrir),
        ],
      ),
    );
  }
}

/// Botón de un archivo. Deshabilitado y atenuado si no llegó: que se vea que
/// falta es más útil que esconderlo.
class _Archivo extends StatelessWidget {
  final String label;
  final String? url;
  final ValueChanged<String> onAbrir;

  const _Archivo({
    required this.label,
    required this.url,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;
    final valor = url;
    final hay = valor != null && valor.isNotEmpty;
    return SPressable(
      onTap: hay ? () => onAbrir(valor) : null,
      borderRadius: t.radius.mdBorder,
      semanticLabel: hay ? 'Abrir $label' : '$label no disponible',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.sm,
          vertical: t.space.xxs,
        ),
        decoration: BoxDecoration(
          borderRadius: t.radius.mdBorder,
          border: Border.all(color: hay ? c.primaryBorder : c.borderSoft),
        ),
        child: Text(
          label,
          style: t.text.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: hay ? c.primaryHover : c.fgSubtle,
          ),
        ),
      ),
    );
  }
}
