import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/features/admin/providers/admin_providers.dart';
import 'package:sozu_cliente_app/features/client/home/components/animacion_llegada.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Lado del spinner que sustituye al desplegable mientras se guarda. No es
/// espaciado: iguala el alto del control al que reemplaza.
const double _kSpinnerSize = 18;

/// Animación de la campana al llegar una notificación, con vista previa.
/// Aplica a todos los clientes; guarda al elegir y revierte si el backend
/// falla.
class BellAnimationSettings extends ConsumerStatefulWidget {
  const BellAnimationSettings({super.key});

  @override
  ConsumerState<BellAnimationSettings> createState() =>
      _BellAnimationSettingsState();
}

class _BellAnimationSettingsState extends ConsumerState<BellAnimationSettings> {
  /// Valor mostrado mientras la escritura está en vuelo; `null` = manda el
  /// provider. Sin esto el desplegable salta al valor viejo entre elegir y
  /// recibir respuesta.
  String? _optimista;
  bool _guardando = false;

  Future<void> _guardar(String? value) async {
    final actual = ref.read(adminBellAnimationProvider).valueOrNull;
    if (value == null || value == actual) return;
    setState(() {
      _optimista = value;
      _guardando = true;
    });
    try {
      await ref.read(adminPortProvider).setBellAnimation(value);
      ref.invalidate(adminBellAnimationProvider);
      _aviso('Animación actualizada para todos los clientes.');
    } catch (_) {
      if (mounted) setState(() => _optimista = null);
      _aviso('No se pudo guardar la animación.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _aviso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    final actual =
        _optimista ?? ref.watch(adminBellAnimationProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Animación al llegar una notificación',
                      style: t.text.label.copyWith(color: tone.fg),
                    ),
                    Text(
                      'Aplica a todos los clientes (configuración general, '
                      'no por notificación).',
                      style: t.text.caption.copyWith(color: tone.fgMuted),
                    ),
                  ],
                ),
              ),
              SizedBox(width: t.space.sm),
              if (_guardando)
                const SizedBox(
                  width: _kSpinnerSize,
                  height: _kSpinnerSize,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else
                DropdownButton<String>(
                  value: AnimacionCampana.desde(actual).clave,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final a in AnimacionCampana.values)
                      DropdownMenuItem(
                        value: a.clave,
                        child: Text(a.etiqueta, style: t.text.label),
                      ),
                  ],
                  onChanged: _guardar,
                ),
            ],
          ),
        ),
        SizedBox(height: t.space.sm),
        _AnimationPreview(variant: AnimacionCampana.desde(actual)),
      ],
    );
  }
}

/// Vista previa de la animación de llegada, con el mismo motor que la campana
/// real. Se reproduce al cambiar de variante y con el botón de replay.
class _AnimationPreview extends StatefulWidget {
  final AnimacionCampana variant;

  const _AnimationPreview({required this.variant});

  @override
  State<_AnimationPreview> createState() => _AnimationPreviewState();
}

class _AnimationPreviewState extends State<_AnimationPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: kDuracionAnimacion,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void didUpdateWidget(covariant _AnimationPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variant != widget.variant) _play();
  }

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  void _play() {
    _flight
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;
    return SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Vista previa · ${widget.variant.etiqueta}',
                  style: t.text.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tone.fgMuted,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Reproducir de nuevo',
                onPressed: _play,
                icon: Icon(Icons.replay, color: tone.primaryHover),
              ),
            ],
          ),
          SizedBox(height: t.space.xxs),
          ClipRRect(
            borderRadius: t.radius.lgBorder,
            child: Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: tone.surface,
                border: Border.all(color: tone.border),
                borderRadius: t.radius.lgBorder,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final target = Offset(w - 36, 30); // centro de la campana
                  final center = Offset(w / 2, 175);
                  return AnimatedBuilder(
                    animation: _flight,
                    builder: (_, __) => Stack(
                      children: [
                        // Campana destino (portería durante el gol).
                        Positioned(
                          right: 20,
                          top: 16,
                          child: CampanaDestino(
                            variante: widget.variant,
                            animando: _flight.isAnimating,
                            v: _flight.value,
                            color: tone.fgMuted,
                          ),
                        ),
                        if (_flight.isAnimating)
                          frameAnimacionLlegada(
                            variante: widget.variant,
                            v: _flight.value,
                            centro: center,
                            destino: target,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
