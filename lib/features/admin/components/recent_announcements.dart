import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/admin/providers/admin_providers.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Avisos por página. Paginado y no scroll infinito: así el alto de la pantalla
/// no depende de cuántos avisos haya.
const int _kAnnouncementsPerPage = 5;

/// Lista paginada de avisos ya creados, con la acción de cancelar los
/// programados.
class RecentAnnouncements extends ConsumerStatefulWidget {
  const RecentAnnouncements({super.key});

  @override
  ConsumerState<RecentAnnouncements> createState() =>
      _RecentAnnouncementsState();
}

class _RecentAnnouncementsState extends ConsumerState<RecentAnnouncements> {
  int _pagina = 0;

  Future<void> _cancelar(AvisoApp a) async {
    try {
      final ok = await ref.read(adminPortProvider).cancelAnnouncement(a.id);
      _aviso(ok ? 'Aviso cancelado.' : 'Ya no se puede cancelar.');
      ref.invalidate(adminAnnouncementsProvider);
    } catch (_) {
      _aviso('No se pudo cancelar.');
    }
  }

  void _aviso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final avisos = ref.watch(adminAnnouncementsProvider);
    final lista = avisos.valueOrNull ?? const <AvisoApp>[];
    final total = lista.length;
    final paginas = (total / _kAnnouncementsPerPage).ceil();
    // Se acota al pintar: si la lista se acorta, la pagina guardada puede
    // quedar fuera de rango.
    final pagina = _pagina.clamp(0, paginas == 0 ? 0 : paginas - 1);
    final visibles = lista
        .skip(pagina * _kAnnouncementsPerPage)
        .take(_kAnnouncementsPerPage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SSectionLabel.heading(
          icon: Icons.history_outlined,
          text: 'Avisos recientes',
          trailing: total > 0
              ? Text(
                  '$total en total',
                  style: t.text.caption.copyWith(color: t.color.fgMuted),
                )
              : null,
        ),
        if (avisos.isLoading)
          const SSkeleton(height: 80, radius: 16)
        else if (lista.isEmpty)
          const SEmptyState.card(
            icon: Icons.campaign_outlined,
            title: 'Aún no hay avisos',
          )
        else ...[
          for (final a in visibles) ...[
            _AnnouncementRow(a: a, onCancel: () => _cancelar(a)),
            SizedBox(height: t.space.sm),
          ],
          if (paginas > 1)
            _Paginador(
              pagina: pagina,
              paginas: paginas,
              onCambio: (p) => setState(() => _pagina = p),
            ),
        ],
      ],
    );
  }
}

class _AnnouncementRow extends StatelessWidget {
  final AvisoApp a;
  final VoidCallback onCancel;

  const _AnnouncementRow({required this.a, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final (badge, badgeTone) = switch (a.estado) {
      'enviado' => ('Enviado', SBadgeTone.positive),
      'pendiente' => ('Programado', SBadgeTone.pending),
      'cancelado' => ('Cancelado', SBadgeTone.neutral),
      _ => ('Error', SBadgeTone.negative),
    };
    String formatDate(String? iso) {
      final d = iso != null ? DateTime.tryParse(iso)?.toLocal() : null;
      return d != null ? DateFormat('dd/MM/yyyy HH:mm').format(d) : '-';
    }

    return SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  a.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.text.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tone.fg,
                  ),
                ),
              ),
              SBadge(label: badge, tone: badgeTone),
            ],
          ),
          SizedBox(height: t.space.xxs),
          Text(
            a.mensaje,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.text.bodySmall.copyWith(color: tone.fgMuted),
          ),
          SizedBox(height: t.space.xs),
          Text(
            [
              'Canales: ${a.canales.join(", ")}',
              if (a.estado == 'pendiente')
                'Envío: ${formatDate(a.programadoPara)}'
              else
                'Creado: ${formatDate(a.fechaCreacion)}',
              if (a.totalDestinatarios != null)
                '${a.totalDestinatarios} destinatarios',
            ].join(' · '),
            style: t.text.caption.copyWith(color: tone.fgSubtle),
          ),
          if (a.estado == 'pendiente')
            Align(
              alignment: Alignment.centerRight,
              child: SButton.ghost(
                label: 'Cancelar envío',
                color: tone.danger,
                onPressed: onCancel,
              ),
            ),
        ],
      ),
    );
  }
}

/// Paginador: anterior · "N de M" · siguiente.
class _Paginador extends StatelessWidget {
  const _Paginador({
    required this.pagina,
    required this.paginas,
    required this.onCambio,
  });

  final int pagina;
  final int paginas;
  final ValueChanged<int> onCambio;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    // `Wrap` y no `Row`: en la columna estrecha de escritorio los dos botones
    // mas el contador no caben en una linea, y `Row` recorta lo que sobra.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: t.space.sm,
      runSpacing: t.space.xs,
      children: [
        SButton.ghost(
          label: 'Anterior',
          icon: Icons.chevron_left,
          onPressed: pagina > 0 ? () => onCambio(pagina - 1) : null,
        ),
        Text(
          '${pagina + 1} de $paginas',
          style: t.text.caption.copyWith(color: t.color.fgMuted),
        ),
        SButton.ghost(
          label: 'Siguiente',
          trailingIcon: Icons.chevron_right,
          onPressed: pagina < paginas - 1 ? () => onCambio(pagina + 1) : null,
        ),
      ],
    );
  }
}
