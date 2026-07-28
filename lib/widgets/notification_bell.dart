import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/portal_theme.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../screens/notificaciones_screen.dart';
import 'animacion_llegada.dart';
import 'notificaciones_fx.dart';
import 'portal_widgets.dart';

/// Campana de notificaciones con contador de no leídas.
///
/// Al subir el conteo corre la animación configurada por el admin (sobre /
/// gol / cohete — ver [AnimacionCampana]); el badge muestra el número nuevo
/// hasta que la animación "aterriza", con un pop. Bajadas del conteo (marcar
/// leídas) se reflejan sin animación.
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _vuelo = AnimationController(
    vsync: this,
    duration: kDuracionAnimacion,
  );
  OverlayEntry? _proyectil;

  /// Conteo que se muestra (va "atrasado" mientras corre la animación).
  int? _mostradas;
  bool _pop = false;
  bool _volando = false;
  AnimacionCampana _variante = AnimacionCampana.gol;

  @override
  void initState() {
    super.initState();
    _vuelo.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _quitarProyectil();
      _vuelo.reset();
      if (!mounted) return;
      setState(() {
        _mostradas =
            ref.read(clienteNotificacionesProvider).valueOrNull?.noLeidas ??
            _mostradas;
        _pop = true;
        _volando = false;
      });
      Future.delayed(const Duration(milliseconds: 220), () {
        if (mounted) setState(() => _pop = false);
      });
    });
  }

  @override
  void dispose() {
    NotifFx.instance.quitarCampana(this);
    _quitarProyectil();
    _vuelo.dispose();
    super.dispose();
  }

  void _quitarProyectil() {
    _proyectil?.remove();
    _proyectil = null;
  }

  void _animarLlegada() {
    if (_vuelo.isAnimating) return; // al terminar tomará el conteo más nuevo
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final box = context.findRenderObject() as RenderBox?;
    if (overlay == null || box == null || !box.attached) {
      setState(() {
        _mostradas =
            ref.read(clienteNotificacionesProvider).valueOrNull?.noLeidas ??
            _mostradas;
      });
      return;
    }
    final destino = box.localToGlobal(box.size.center(Offset.zero));
    final pantalla = MediaQuery.of(context).size;
    final centro = Offset(pantalla.width / 2, pantalla.height * 0.42);
    _variante = AnimacionCampana.desde(
      ref.read(clienteNotificacionesProvider).valueOrNull?.animacionCampana,
    );

    _quitarProyectil();
    setState(() => _volando = true);
    _proyectil = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _vuelo,
          builder: (_, __) => frameAnimacionLlegada(
            variante: _variante,
            v: _vuelo.value,
            centro: centro,
            destino: destino,
          ),
        ),
      ),
    );
    overlay.insert(_proyectil!);
    _vuelo.forward();
  }

  /// Abre la vista previa de notificaciones: popover anclado a la campana en
  /// web ancho (modo portal) y bottom-sheet en móvil/angosto. Réplica de
  /// NotificationPopover / NotificationSheet del portal.
  void _abrirPreview() {
    if (isPortalMode(context)) {
      _abrirPopover();
    } else {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetCtx) => _NotifPreviewPanel(
          sheet: true,
          onClose: () => Navigator.of(sheetCtx).pop(),
        ),
      );
    }
  }

  /// Popover anclado a la campana (web): se posiciona debajo y alineado al
  /// borde derecho de la campana (align="end", sideOffset 8 del portal). El
  /// barrier transparente lo cierra al tocar fuera.
  void _abrirPopover() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final pos = box.localToGlobal(Offset.zero);
    final screen = MediaQuery.sizeOf(context);
    final top = pos.dy + box.size.height + 8;
    final right =
        (screen.width - (pos.dx + box.size.width)).clamp(8.0, screen.width - 8);

    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogCtx) => Stack(
        children: [
          Positioned(
            top: top,
            right: right,
            child: _NotifPreviewPanel(
              sheet: false,
              onClose: () => Navigator.of(dialogCtx).pop(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);

    // Reporta al controlador global si esta campana está visible (pestaña
    // activa / topbar): si lo está, ella anima la llegada y NotificacionesFx no
    // duplica el disparo. `TickerMode.valuesOf` crea la dependencia, así que al
    // cambiar de pestaña se reconstruye y el registro queda al día.
    NotifFx.instance.reportarCampana(
      this,
      visible: TickerMode.valuesOf(context).enabled,
    );

    ref.listen(clienteNotificacionesProvider, (prev, next) {
      final nuevo = next.valueOrNull?.noLeidas;
      if (nuevo == null || !mounted) return;
      final actual = _mostradas;
      // Solo anima la campana visible (las tabs ocultas del shell quedan
      // en Offstage con tickers apagados).
      if (actual != null &&
          nuevo > actual &&
          TickerMode.valuesOf(context).enabled) {
        _animarLlegada();
      } else if (nuevo != actual && !_vuelo.isAnimating) {
        setState(() => _mostradas = nuevo);
      }
    });

    _mostradas ??=
        ref.watch(clienteNotificacionesProvider).valueOrNull?.noLeidas ?? 0;
    final noLeidas = _mostradas ?? 0;

    return IconButton(
      tooltip: 'Notificaciones',
      onPressed: _abrirPreview,
      icon: AnimatedScale(
        scale: _pop ? 1.3 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: Badge.count(
          count: noLeidas,
          isLabelVisible: noLeidas > 0,
          backgroundColor: tone.negative,
          textColor: Colors.white,
          child: AnimatedBuilder(
            animation: _vuelo,
            builder: (_, __) => CampanaDestino(
              variante: _variante,
              animando: _volando,
              v: _vuelo.value,
              color: tone.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Contenido de la vista previa de la campana (popover web / bottom-sheet
/// móvil): header con conteo + "Marcar todas", hasta 8 notificaciones y footer
/// "Ver todas". Réplica de NotificationPopover / NotificationSheet del portal,
/// incluido el toggle "marcar leída / no leída" de cada fila (useMarkAsUnread).
class _NotifPreviewPanel extends ConsumerWidget {
  final bool sheet;
  final VoidCallback onClose;

  const _NotifPreviewPanel({required this.sheet, required this.onClose});

  void _abrir(BuildContext context, WidgetRef ref, Notificacion n) {
    onClose();
    abrirNotificacion(context, ref, n);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(clienteNotificacionesProvider).valueOrNull;
    final preview =
        ordenarNotificaciones(data?.notificaciones ?? const []).take(8).toList();
    final noLeidas = data?.noLeidas ?? 0;

    final panel = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, ref, noLeidas),
        Flexible(
          child: preview.isEmpty
              ? _vacio()
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final n in preview)
                        NotifPreviewRow(
                          n: n,
                          onTap: () => _abrir(context, ref, n),
                          onDismiss: () => marcarNotificacion(
                            ref,
                            action: 'descartar',
                            id: n.id,
                          ),
                          onToggleLeida: () =>
                              alternarLeidaNotificacion(ref, n),
                        ),
                    ],
                  ),
                ),
        ),
        _footer(context),
      ],
    );

    final maxH = MediaQuery.sizeOf(context).height;

    if (sheet) {
      return SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(maxHeight: maxH * 0.85),
          decoration: const BoxDecoration(
            color: PortalColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: panel,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 360,
        constraints: BoxConstraints(maxHeight: maxH * 0.7),
        decoration: BoxDecoration(
          color: PortalColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PortalColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              offset: Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: panel,
      ),
    );
  }

  Widget _header(BuildContext context, WidgetRef ref, int noLeidas) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PortalColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notificaciones',
                  style: portalText(size: 14, weight: FontWeight.w600),
                ),
                if (noLeidas > 0)
                  Text(
                    '$noLeidas sin leer',
                    style: portalText(
                      size: 11,
                      color: PortalColors.mutedForeground,
                    ),
                  ),
              ],
            ),
          ),
          if (noLeidas > 0)
            PortalHoverBuilder(
              builder: (context, hovered) => GestureDetector(
                onTap: () => marcarNotificacion(ref, action: 'marcar_todas'),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check,
                          size: 13, color: PortalColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Marcar todas',
                        style: portalText(
                          size: 11,
                          weight: FontWeight.w500,
                          color: PortalColors.primary,
                        ).copyWith(
                          decoration:
                              hovered ? TextDecoration.underline : null,
                          decorationColor: PortalColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: PortalColors.border)),
      ),
      child: PortalHoverBuilder(
        builder: (context, hovered) => GestureDetector(
          onTap: () {
            onClose();
            context.push('/notificaciones');
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ver todas las notificaciones',
                  style: portalText(
                    size: 13,
                    weight: FontWeight.w500,
                    color: PortalColors.primary,
                  ).copyWith(
                    decoration: hovered ? TextDecoration.underline : null,
                    decorationColor: PortalColors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    size: 14, color: PortalColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vacio() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: PortalColors.muted,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_outlined,
                size: 18, color: PortalColors.mutedForeground),
          ),
          const SizedBox(height: 12),
          Text(
            'Estás al día',
            style: portalText(size: 13, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Sin notificaciones nuevas por ahora.',
            textAlign: TextAlign.center,
            style: portalText(size: 11, color: PortalColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}
