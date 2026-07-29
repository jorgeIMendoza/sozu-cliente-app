import 'package:flutter/material.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Widgets base del sistema de diseño SOZU (espejo de src/components del RN).

/// Tarjeta con esquinas redondeadas y sombra suave.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(16),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
        boxShadow: [
          BoxShadow(
            color: SozuNeutral.n900.withValues(alpha: 0.08),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: child,
    );
  }
}

enum BadgeTone { positive, pending, negative, neutral }

/// Etiqueta de estatus (Pagado / Pendiente / Vencido / otros).
class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeTone tone;

  const StatusBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s.color;
    final (bg, fg) = switch (tone) {
      BadgeTone.positive => (t.primarySoft, t.primaryHover),
      BadgeTone.pending => (t.warningSoft, SozuAmber.strong),
      BadgeTone.negative => (t.danger.withValues(alpha: 0.1), t.danger),
      BadgeTone.neutral => (t.surfaceAlt, t.fgMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

/// Avatar circular verde con iniciales.
class SozuAvatar extends StatelessWidget {
  final String iniciales;
  final double size;

  const SozuAvatar({super.key, required this.iniciales, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: SozuBrand.green500,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        iniciales,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}

/// Duración del llenado de la barra de progreso.
///
/// Queda fuera de la escala de movimiento a propósito. Los tokens cubren
/// transiciones de estado y se topan en 380 ms; esto es un barrido que recorre
/// todo el ancho de la barra y cuyo punto es que se vea avanzar - a 380 ms el
/// avance se pierde y la barra aparece llena. Es el mismo criterio que
/// `CountUpMoney` en widgets/fx.dart: la duración es el efecto, no el costo de
/// cambiar de estado.
const Duration _progressFillDuration = Duration(milliseconds: 700);

/// Barra de progreso verde animada. percent: 0-100.
class SozuProgressBar extends StatelessWidget {
  final double percent;

  const SozuProgressBar({super.key, required this.percent});

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final clamped = percent.clamp(0, 100) / 100;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: clamped.toDouble()),
        duration: _progressFillDuration,
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => LinearProgressIndicator(
          value: value,
          minHeight: 10,
          backgroundColor: tone.surfaceAlt,
          valueColor: const AlwaysStoppedAnimation(SozuBrand.green500),
        ),
      ),
    );
  }
}

/// Bloque de carga con efecto shimmer (barrido de luz).
///
/// Ya no implementa nada: delega en [SSkeleton], el placeholder global del
/// design system. Existe SOLO para no tocar de golpe los sitios de uso que
/// todavía la nombran; su API pública se conserva idéntica (`width`, `height`,
/// `radius`) para que la delegación sea invisible en cada pantalla. Al migrar un
/// archivo, cambiar `Skeleton(...)` por `SSkeleton(...)`.
@Deprecated('Usar SSkeleton de lib/ui/primitives/.')
class Skeleton extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const Skeleton({super.key, this.width, this.height = 16, this.radius = 8});

  @override
  Widget build(BuildContext context) =>
      SSkeleton(width: width, height: height, radius: radius);
}

/// Título de sección con icono.
class SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? trailing;

  const SectionTitle({
    super.key,
    required this.icon,
    required this.text,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: SozuBrand.green600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: tone.fg,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Estado vacío en tarjeta.
class EmptyCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const EmptyCard({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 36, color: tone.fgSubtle),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: tone.fgMuted),
          ),
        ],
      ),
    );
  }
}

/// Estado de error con reintento.
class ErrorCard extends StatelessWidget {
  final String title;
  final VoidCallback onRetry;

  const ErrorCard({super.key, required this.title, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return AppCard(
      child: Column(
        children: [
          Icon(Icons.cloud_off_outlined, size: 40, color: tone.fgSubtle),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tone.fg,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(minimumSize: const Size(160, 44)),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
