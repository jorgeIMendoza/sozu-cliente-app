import 'package:flutter/material.dart';

import '../core/theme.dart';

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
    final tone = SozuTone.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(16),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
        boxShadow: [
          BoxShadow(
            color: SozuColors.slate900.withValues(alpha: 0.08),
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

  const StatusBadge({super.key, required this.label, this.tone = BadgeTone.neutral});

  @override
  Widget build(BuildContext context) {
    final t = SozuTone.of(context);
    final (bg, fg) = switch (tone) {
      BadgeTone.positive => (t.primarySoft, t.primaryDark),
      BadgeTone.pending => (t.pendingSoft, SozuColors.amber600),
      BadgeTone.negative => (t.negative.withValues(alpha: 0.1), t.negative),
      BadgeTone.neutral => (t.surfaceAlt, t.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
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
        color: SozuColors.emerald500,
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

/// Barra de progreso verde animada. percent: 0–100.
class SozuProgressBar extends StatelessWidget {
  final double percent;

  const SozuProgressBar({super.key, required this.percent});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final clamped = percent.clamp(0, 100) / 100;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: clamped.toDouble()),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => LinearProgressIndicator(
          value: value,
          minHeight: 10,
          backgroundColor: tone.surfaceAlt,
          valueColor: const AlwaysStoppedAnimation(SozuColors.emerald500),
        ),
      ),
    );
  }
}

/// Bloque de carga con efecto shimmer (barrido de luz).
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const Skeleton({super.key, this.width, this.height = 16, this.radius = 8});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? SozuColors.slate700 : SozuColors.slate200;
    final highlight = dark ? SozuColors.slate600 : SozuColors.slate100;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            colors: [base, highlight, base],
            stops: const [0.25, 0.5, 0.75],
            transform: _SlideGradient(_c.value),
          ),
        ),
      ),
    );
  }
}

/// Desliza el gradiente de izquierda a derecha (t: 0–1).
class _SlideGradient extends GradientTransform {
  final double t;

  const _SlideGradient(this.t);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 3 - 1.5), 0, 0);
}

/// Título de sección con icono.
class SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? trailing;

  const SectionTitle({super.key, required this.icon, required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: SozuColors.emerald600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: tone.textPrimary,
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
    final tone = SozuTone.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 36, color: tone.textMuted),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: tone.textSecondary),
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
    final tone = SozuTone.of(context);
    return AppCard(
      child: Column(
        children: [
          Icon(Icons.cloud_off_outlined, size: 40, color: tone.textMuted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tone.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              minimumSize: const Size(160, 44),
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
