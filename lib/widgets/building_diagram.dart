import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Diagrama "¿Dónde está tu unidad?" — réplica del BuildingDiagram del Portal
/// del Cliente (FichaTecnicaSection.tsx de sozu-admin).
///
/// Dos columnas:
///  - Izquierda "NIVEL EN EL EDIFICIO": lista vertical de niveles (del más alto
///    hacia abajo, PLANTA BAJA en oscuro al fondo) con el nivel del cliente
///    resaltado en verde y una flecha "◄ Tú".
///  - Derecha "UBICACIÓN EN EL NIVEL": rejilla tipo planta con las unidades del
///    piso y la del cliente resaltada en verde.
///
/// Cuando no se conoce el total de niveles o el número de unidades por piso se
/// usa un rango razonable centrado en el nivel del cliente y el número de
/// unidad para ubicarla en la rejilla (igual que el portal).
class BuildingDiagram extends StatelessWidget {
  final int numeroPiso;
  final int? totalPisos;

  /// Identificador de la unidad tal cual viene en la ficha (p.ej. "707").
  final String unidad;

  const BuildingDiagram({
    super.key,
    required this.numeroPiso,
    this.totalPisos,
    required this.unidad,
  });

  // ── Niveles a mostrar (descendente), ventana compacta centrada en el piso ──
  List<int> _niveles() {
    final total = (totalPisos != null && totalPisos! >= numeroPiso && totalPisos! > 0)
        ? totalPisos!
        : numeroPiso;
    const maxVisible = 8;
    late int top;
    late int bottom;
    if (total <= maxVisible) {
      top = total;
      bottom = 1;
    } else {
      // Ventana de `maxVisible` niveles que siempre contiene el del cliente.
      top = (numeroPiso + 3).clamp(maxVisible, total);
      bottom = (top - maxVisible + 1).clamp(1, total);
    }
    return [for (int f = top; f >= bottom; f--) f];
  }

  /// Posición de la unidad dentro del piso a partir de su número.
  /// Convención `piso*100 + posición` (707 → piso 7, posición 7); si no aplica,
  /// se usan los últimos dos dígitos.
  int _posicionEnPiso() {
    final digits = int.tryParse(unidad.replaceAll(RegExp(r'[^0-9]'), ''));
    if (digits == null) return 1;
    final byFloor = digits - numeroPiso * 100;
    if (byFloor >= 1 && byFloor <= 40) return byFloor;
    final last2 = digits % 100;
    return last2 >= 1 ? last2 : 1;
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final niveles = _niveles();
    final total = (totalPisos != null && totalPisos! >= numeroPiso && totalPisos! > 0)
        ? totalPisos!
        : numeroPiso;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿DÓNDE ESTÁ TU UNIDAD?',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
            color: tone.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna izquierda — niveles del edificio.
              Expanded(
                child: _Columna(
                  label: 'NIVEL EN EL EDIFICIO',
                  tone: tone,
                  child: _ListaNiveles(
                    niveles: niveles,
                    total: total,
                    numeroPiso: numeroPiso,
                    tone: tone,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Columna derecha — unidades del nivel.
              Expanded(
                child: _Columna(
                  label: 'UBICACIÓN EN EL NIVEL',
                  tone: tone,
                  child: _RejillaUnidades(
                    numeroPiso: numeroPiso,
                    unidad: unidad,
                    posicion: _posicionEnPiso(),
                    tone: tone,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: tone.primary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Tu unidad',
              style: TextStyle(fontSize: 11, color: tone.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class _Columna extends StatelessWidget {
  final String label;
  final SozuTone tone;
  final Widget child;

  const _Columna({required this.label, required this.tone, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
            color: tone.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: tone.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tone.border),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _ListaNiveles extends StatelessWidget {
  final List<int> niveles;
  final int total;
  final int numeroPiso;
  final SozuTone tone;

  const _ListaNiveles({
    required this.niveles,
    required this.total,
    required this.numeroPiso,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Techo (triángulo) del edificio.
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: CustomPaint(
            size: const Size(double.infinity, 12),
            painter: _TechoPainter(tone.textPrimary.withValues(alpha: 0.8)),
          ),
        ),
        for (final n in niveles) ...[
          _FilaNivel(
            texto: 'NIVEL $n',
            resaltado: n == numeroPiso,
            oscuro: false,
            tone: tone,
          ),
          const SizedBox(height: 4),
        ],
        _FilaNivel(
          texto: 'PLANTA BAJA',
          resaltado: false,
          oscuro: true,
          tone: tone,
        ),
        const SizedBox(height: 3),
        // Base del edificio.
        Container(height: 4, color: tone.textPrimary),
      ],
    );
  }
}

class _FilaNivel extends StatelessWidget {
  final String texto;
  final bool resaltado;
  final bool oscuro;
  final SozuTone tone;

  const _FilaNivel({
    required this.texto,
    required this.resaltado,
    required this.oscuro,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final Color fondo = resaltado
        ? tone.primary
        : oscuro
            ? tone.textPrimary
            : tone.surfaceAlt;
    final Color texColor = resaltado
        ? Colors.white
        : oscuro
            ? tone.surface
            : tone.textSecondary;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: resaltado ? tone.primary : tone.border,
              ),
            ),
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: texColor,
              ),
            ),
          ),
        ),
        // Espacio reservado para la flecha "◄ Tú" (mantiene alineadas las filas).
        SizedBox(
          width: 30,
          child: resaltado
              ? Row(
                  children: [
                    const SizedBox(width: 3),
                    Icon(Icons.play_arrow, size: 12, color: tone.primary),
                    Text(
                      'Tú',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: tone.primary,
                      ),
                    ),
                  ],
                )
              : null,
        ),
      ],
    );
  }
}

class _RejillaUnidades extends StatelessWidget {
  final int numeroPiso;
  final String unidad;
  final int posicion;
  final SozuTone tone;

  const _RejillaUnidades({
    required this.numeroPiso,
    required this.unidad,
    required this.posicion,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    const cols = 4;
    final filas = math.max(2, (posicion / cols).ceil());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int r = 0; r < filas; r++) ...[
          Row(
            children: [
              for (int c = 0; c < cols; c++) ...[
                Expanded(child: _celda(r * cols + c + 1)),
                if (c < cols - 1) const SizedBox(width: 6),
              ],
            ],
          ),
          if (r < filas - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _celda(int i) {
    final resaltado = i == posicion;
    final etiqueta = resaltado ? unidad : '${numeroPiso * 100 + i}';
    return AspectRatio(
      aspectRatio: 1.35,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: resaltado ? tone.primary : tone.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: resaltado ? tone.primary : tone.border),
        ),
        child: Text(
          etiqueta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: resaltado ? Colors.white : tone.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _TechoPainter extends CustomPainter {
  final Color color;

  _TechoPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width * 0.16, size.height)
      ..lineTo(size.width * 0.5, 0)
      ..lineTo(size.width * 0.84, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TechoPainter oldDelegate) =>
      oldDelegate.color != color;
}
