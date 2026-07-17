import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'common.dart';

/// Tarjetas de sección del Perfil (espejo de SectionCard en ClientePerfil.tsx
/// del portal): icono, título/subtítulo, semáforo de estado, filas
/// label→valor y botones de acción apilados.

/// Acción de una tarjeta de sección del perfil.
class PerfilCardAction {
  final String label;
  final VoidCallback onTap;

  /// secondary = outline; primary = verde sólido; danger = rojo claro.
  final PerfilActionStyle style;
  final IconData? icon;

  const PerfilCardAction({
    required this.label,
    required this.onTap,
    this.style = PerfilActionStyle.primary,
    this.icon,
  });
}

enum PerfilActionStyle { primary, secondary, danger }

/// Fila label → valor ("Sin dato" en cursiva si viene vacío).
class PerfilInfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool mono;
  final bool isLast;
  final String? note;

  const PerfilInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.mono = false,
    this.isLast = false,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final hasValue = value != null && value!.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: tone.border.withValues(alpha: 0.6),
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: tone.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  hasValue ? value! : 'Sin dato',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                    fontFamily: hasValue && mono ? 'monospace' : null,
                    color: hasValue ? tone.textPrimary : tone.textMuted,
                  ),
                ),
                if (note != null)
                  Text(
                    note!,
                    style: TextStyle(fontSize: 10.5, color: tone.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de sección: header con icono + semáforo, filas y CTAs.
class PerfilSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String statusLabel;
  final bool statusOk;
  final List<Widget> rows;
  final List<PerfilCardAction> actions;

  const PerfilSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.statusLabel,
    required this.statusOk,
    required this.rows,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final statusColor = statusOk ? tone.positive : tone.textMuted;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tone.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: tone.primaryDark),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: tone.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style:
                          TextStyle(fontSize: 12, color: tone.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: statusOk ? tone.positive : tone.border,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...rows,
          const SizedBox(height: 14),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: 7),
            _actionButton(context, actions[i]),
          ],
        ],
      ),
    );
  }

  Widget _actionButton(BuildContext context, PerfilCardAction a) {
    final tone = SozuTone.of(context);
    switch (a.style) {
      case PerfilActionStyle.primary:
        return FilledButton(
          onPressed: a.onTap,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            textStyle:
                const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          child: Text(a.label),
        );
      case PerfilActionStyle.secondary:
        return OutlinedButton(
          onPressed: a.onTap,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            foregroundColor: tone.textPrimary,
            side: BorderSide(color: tone.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle:
                const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          child: Text(a.label),
        );
      case PerfilActionStyle.danger:
        return OutlinedButton.icon(
          onPressed: a.onTap,
          icon: a.icon != null
              ? Icon(a.icon, size: 15, color: tone.negative)
              : const SizedBox.shrink(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            foregroundColor: tone.negative,
            backgroundColor: tone.negative.withValues(alpha: 0.05),
            side: BorderSide(color: tone.negative.withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle:
                const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          label: Text(a.label),
        );
    }
  }
}

/// Banner ámbar "Perfil casi completo / Completa tu perfil" con CTA.
class PerfilBannerCompletar extends StatelessWidget {
  final int perfilCompletado;
  final VoidCallback onCompletar;

  const PerfilBannerCompletar({
    super.key,
    required this.perfilCompletado,
    required this.onCompletar,
  });

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: tone.pendingSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: SozuColors.amber500.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.error_outline,
                size: 15, color: SozuColors.amber600),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  perfilCompletado < 50
                      ? 'Completa tu perfil para continuar'
                      : 'Perfil casi completo',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: SozuColors.amber600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sube tus documentos y llena tus datos personales y fiscales.',
                  style: TextStyle(
                    fontSize: 12,
                    color: SozuColors.amber600.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: onCompletar,
            style: OutlinedButton.styleFrom(
              foregroundColor: SozuColors.amber600,
              side: BorderSide(
                color: SozuColors.amber500.withValues(alpha: 0.5),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
            child: const Text('Completar'),
          ),
        ],
      ),
    );
  }
}
