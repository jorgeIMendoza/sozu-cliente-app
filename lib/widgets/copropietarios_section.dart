import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models.dart';
import 'common.dart';

/// Sección "Copropietarios" del detalle de propiedad: lista cada
/// copropietario (avatar con iniciales, nombre y email si está disponible)
/// con su porcentaje de copropiedad. Solo se renderiza cuando la cuenta
/// tiene más de un propietario; con un único dueño devuelve un widget vacío.
class CopropietariosSection extends StatelessWidget {
  final List<Copropietario> copropietarios;

  const CopropietariosSection({super.key, required this.copropietarios});

  @override
  Widget build(BuildContext context) {
    if (copropietarios.length < 2) return const SizedBox.shrink();
    final tone = SozuTone.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          icon: Icons.group_outlined,
          text: 'Copropietarios · ${copropietarios.length}',
        ),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < copropietarios.length; i++) ...[
                if (i > 0) Divider(height: 24, color: tone.border),
                _CopropietarioRow(c: copropietarios[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CopropietarioRow extends StatelessWidget {
  final Copropietario c;

  const _CopropietarioRow({required this.c});

  /// Iniciales del nombre (primeras letras de las dos primeras palabras),
  /// mismo criterio que el backend (`iniciales` de _shared/cliente.ts).
  String get _iniciales {
    final parts = c.nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final ini =
        (parts.isNotEmpty ? parts[0][0] : '') +
        (parts.length > 1 ? parts[1][0] : '');
    return ini.isEmpty ? '?' : ini.toUpperCase();
  }

  /// Porcentaje sin ceros de sobra: 50 → "50%", 33.33 → "33.33%".
  String get _porcentaje {
    var s = c.porcentaje.toStringAsFixed(2);
    s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    return '$s%';
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final email = c.email;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tone.primarySoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            _iniciales,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SozuColors.emerald600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tone.textPrimary,
                ),
              ),
              if (email != null && email.trim().isNotEmpty)
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: tone.textSecondary),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _porcentaje,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: tone.textPrimary,
              ),
            ),
            Text(
              'copropiedad',
              style: TextStyle(fontSize: 10, color: tone.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}
