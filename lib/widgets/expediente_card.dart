import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/portal_theme.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';

/// Tarjeta "Tu expediente · el motor de tu perfil" del Perfil (espejo del
/// hero del Expediente en ClientePerfil.tsx del portal web).
///
/// Se auto-oculta (SizedBox.shrink) mientras carga o si el backend aún no
/// expone `cliente-expediente` — degradación segura.
class ExpedienteCard extends ConsumerWidget {
  const ExpedienteCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exp = ref.watch(clienteExpedienteProvider);
    final data = exp.valueOrNull;
    if (data == null || data.slots.isEmpty) return const SizedBox.shrink();

    final tone = SozuTone.of(context);
    // En modo portal el shell fuerza tema claro: la card usa el estilo del
    // portal (radio 24 de las cards del portal, botón verde #239F6D).
    final portal = isPortalMode(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? tone.primarySoft : const Color(0xFFEEF7F1);
    final border = dark ? SozuColors.emerald700 : const Color(0xFFD8ECDF);

    final completo = data.requeridosTotal > 0 &&
        data.requeridosAprobados >= data.requeridosTotal;
    final sinDocs = data.subidos == 0;
    final titulo = sinDocs
        ? 'Comienza con tu Constancia fiscal'
        : completo
            ? '¡Expediente completo!'
            : 'Sigue completando tu expediente';
    final cuerpo = sinDocs
        ? 'Con ese documento poblamos la mayoría de tu información.'
        : 'Cada documento que subas nos permite verificar tu identidad.';

    // Mini-lista: 4 documentos ordenados alfabéticamente (como el portal).
    final miniSlots = [...data.slots]
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    final visibles = miniSlots.take(4).toList();

    final izquierda = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: dark ? SozuColors.emerald700 : const Color(0xFFD4EADB),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'TU EXPEDIENTE · EL MOTOR DE TU PERFIL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: dark ? SozuColors.emerald100 : const Color(0xFF3F8F5C),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          titulo,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: tone.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          cuerpo,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.5,
            color: tone.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 14,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () => context.push('/expediente'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                backgroundColor: portal ? PortalColors.primary : null,
                shape: portal
                    ? RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(kPortalRadiusMd),
                      )
                    : null,
              ),
              icon: const Icon(Icons.upload_outlined, size: 16),
              label: Text(sinDocs ? 'Subir documentos' : 'Ver expediente'),
            ),
            Text(
              '${data.requeridosAprobados} de ${data.requeridosTotal} requeridos',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tone.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );

    final miniLista = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in visibles) ...[
          _MiniDocRow(slot: s),
          const SizedBox(height: 7),
        ],
        OutlinedButton(
          onPressed: () => context.go('/documentos'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 36),
            side: BorderSide(
              color: dark ? SozuColors.emerald700 : const Color(0xFFC8E6D0),
            ),
            foregroundColor:
                dark ? SozuColors.emerald400 : const Color(0xFF3F8F5C),
            textStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ver todos los documentos'),
              SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 14),
            ],
          ),
        ),
      ],
    );

    return Container(
      margin: EdgeInsets.only(top: portal ? 16 : 24),
      padding: portal
          ? const EdgeInsets.fromLTRB(24, 22, 24, 22)
          : const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius:
            BorderRadius.circular(portal ? kPortalRadiusCard : 16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ancho = constraints.maxWidth >= 620;
          if (ancho) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: izquierda),
                const SizedBox(width: 24),
                SizedBox(width: 250, child: miniLista),
              ],
            );
          }
          // En angosto la mini-lista va debajo.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              izquierda,
              const SizedBox(height: 18),
              miniLista,
            ],
          );
        },
      ),
    );
  }
}

class _MiniDocRow extends StatelessWidget {
  final ExpedienteSlot slot;

  const _MiniDocRow({required this.slot});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final st = expedienteEstatusStyle(slot.estatus, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: tone.surface,
        border: Border.all(color: tone.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: st.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              slot.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tone.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: st.bg,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              st.label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: st.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estilo (punto/chip) por estatus del expediente, compartido entre la
/// tarjeta del Perfil y la pantalla Expediente. Espejo de los colores del
/// portal: Aprobado verde · En revisión/Expirado ámbar · Rechazado rojo ·
/// Pendiente/Opcional neutro.
({Color dot, Color bg, Color fg, String label}) expedienteEstatusStyle(
  String estatus,
  SozuTone tone,
) {
  switch (estatus) {
    case 'aprobado':
      return (
        dot: SozuColors.emerald500,
        bg: tone.primarySoft,
        fg: tone.primaryDark,
        label: 'Aprobado',
      );
    case 'revision':
      return (
        dot: SozuColors.amber500,
        bg: tone.pendingSoft,
        fg: SozuColors.amber600,
        label: 'En revisión',
      );
    case 'expirado':
      return (
        dot: SozuColors.amber500,
        bg: tone.pendingSoft,
        fg: SozuColors.amber600,
        label: 'Expirado',
      );
    case 'rechazado':
      return (
        dot: tone.negative,
        bg: tone.negative.withValues(alpha: 0.1),
        fg: tone.negative,
        label: 'Rechazado',
      );
    case 'opcional':
      return (
        dot: SozuColors.slate300,
        bg: tone.surfaceAlt,
        fg: tone.textSecondary,
        label: 'Opcional',
      );
    default: // pendiente
      return (
        dot: SozuColors.slate300,
        bg: tone.surfaceAlt,
        fg: tone.textSecondary,
        label: 'Pendiente',
      );
  }
}
