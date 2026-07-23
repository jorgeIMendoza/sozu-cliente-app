import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../core/portal_theme.dart';
import '../core/theme.dart';
import '../data/api_client.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../providers/impersonation_provider.dart';
import 'portal_widgets.dart';
import 'whatsapp_icon.dart';

/// Ancho del drawer lateral del portal (`max-w-[520px]`, usamos 460-480).
const double _kDrawerWidth = 468;

/// Plazos disponibles para el crédito hipotecario (años).
const _plazosAnios = [10, 15, 20];

/// Abre el flujo "Pago final" como DRAWER lateral derecho del portal (réplica
/// de `PagoFinalSheet.tsx` en escritorio) — en lugar de la pantalla completa
/// `PagoFinalScreen`. Reutiliza toda la lógica/estado de bancos y selección
/// (bancos con convenio, saldo, tipo_financiamiento, crear_solicitud y la
/// regla de no cambiar de banco con solicitud vigente).
///
/// Solo debe usarse en modo portal (web ancho); en móvil se conserva la
/// pantalla completa. El shell del portal es claro, por eso se envuelve en
/// `Theme(sozuLightTheme())`.
Future<void> showCreditoHipotecarioDrawer(
  BuildContext context, {
  required int cuentaId,
  required String unidad,
  required String proyecto,
  required double saldo,
  int? acuerdoId,
  String? tipoFinanciamiento,
  SolicitudCredito? solicitud,
  AgenteComercial? agente,

  /// Se invoca (tras cerrar el drawer) cuando el cliente elige recursos
  /// propios: el padre navega a las instrucciones de transferencia STP.
  void Function(int? acuerdoId)? onRecursosPropios,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, anim, secondary) {
      final height = MediaQuery.sizeOf(ctx).height;
      return Align(
        alignment: Alignment.centerRight,
        child: Theme(
          data: sozuLightTheme(),
          child: Material(
            color: PortalColors.surface,
            child: SizedBox(
              width: math.min(_kDrawerWidth, MediaQuery.sizeOf(ctx).width),
              height: height,
              child: _CreditoHipotecarioDrawer(
                cuentaId: cuentaId,
                unidad: unidad,
                proyecto: proyecto,
                saldo: saldo,
                acuerdoId: acuerdoId,
                tipoFinanciamiento: tipoFinanciamiento,
                solicitud: solicitud,
                agente: agente,
                onRecursosPropios: onRecursosPropios,
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, secondary, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

enum _Paso { seleccion, banco, precalificacion, estatusCredito }

class _CreditoHipotecarioDrawer extends ConsumerStatefulWidget {
  final int cuentaId;
  final String unidad;
  final String proyecto;
  final double saldo;
  final int? acuerdoId;
  final String? tipoFinanciamiento;
  final SolicitudCredito? solicitud;
  final AgenteComercial? agente;
  final void Function(int? acuerdoId)? onRecursosPropios;

  const _CreditoHipotecarioDrawer({
    required this.cuentaId,
    required this.unidad,
    required this.proyecto,
    required this.saldo,
    this.acuerdoId,
    this.tipoFinanciamiento,
    this.solicitud,
    this.agente,
    this.onRecursosPropios,
  });

  @override
  ConsumerState<_CreditoHipotecarioDrawer> createState() =>
      _CreditoHipotecarioDrawerState();
}

class _CreditoHipotecarioDrawerState
    extends ConsumerState<_CreditoHipotecarioDrawer> {
  _Paso _paso = _Paso.seleccion;
  String? _metodo; // RECURSOS_PROPIOS | CREDITO_HIPOTECARIO
  BancoConvenio? _bancoSel;
  bool _guardando = false;

  Future<List<BancoConvenio>>? _bancosFuture;
  SolicitudCredito? _solicitud;

  ({double monto, int plazoAnios, double? mensualidad, double? tasa})?
  _resumenEnviado;

  late final TextEditingController _montoCtrl;
  int _plazoAnios = 20;
  bool _enviando = false;
  bool _consiente = false;

  @override
  void initState() {
    super.initState();
    _solicitud = widget.solicitud;
    _montoCtrl = TextEditingController(
      text: widget.saldo > 0 ? widget.saldo.round().toString() : '',
    );
    // Hydrate igual que PagoFinalScreen / PagoFinalSheet.
    if (widget.tipoFinanciamiento == 'CREDITO_HIPOTECARIO') {
      _metodo = 'CREDITO_HIPOTECARIO';
      if (widget.solicitud != null) {
        _paso = _Paso.estatusCredito;
      } else {
        _paso = _Paso.banco;
        _cargarBancos();
      }
    }
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    super.dispose();
  }

  void _cargarBancos() {
    _bancosFuture ??= fetchBancosConvenio(
      impersonate: ref.read(impersonationProvider).idPersona,
    );
  }

  double get _monto =>
      double.tryParse(_montoCtrl.text.replaceAll(',', '')) ?? 0;

  bool get _montoValido => _monto > 0 && _monto <= widget.saldo;

  double _mensualidad(double principal, double tasaAnual, int anios) {
    if (principal <= 0 || anios <= 0) return 0;
    final i = tasaAnual / 100 / 12;
    final n = anios * 12;
    if (i == 0) return principal / n;
    final factor = math.pow(1 + i, n).toDouble();
    return principal * i * factor / (factor - 1);
  }

  void _cerrar() => Navigator.of(context).maybePop();

  /// [PortalBlockButton] con estado deshabilitado (atenuado + sin toque),
  /// que el widget base no expone.
  Widget _ctaButton({
    required String label,
    IconData? icon,
    PortalBlockButtonStyle style = PortalBlockButtonStyle.primary,
    bool enabled = true,
    required VoidCallback onPressed,
  }) {
    final btn = PortalBlockButton(
      label: label,
      icon: icon,
      style: style,
      onPressed: enabled ? onPressed : () {},
    );
    if (enabled) return btn;
    return Opacity(
      opacity: 0.55,
      child: IgnorePointer(child: btn),
    );
  }

  void _snack(String mensaje) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// Recursos propios: persiste la elección, cierra el drawer y delega la
  /// navegación a instrucciones STP en el padre.
  Future<void> _elegirRecursosPropios() async {
    setState(() => _guardando = true);
    try {
      await setPagoFinal(
        widget.cuentaId,
        'RECURSOS_PROPIOS',
        impersonate: ref.read(impersonationProvider).idPersona,
      );
      ref.invalidate(propiedadDetalleProvider(widget.cuentaId));
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onRecursosPropios?.call(widget.acuerdoId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _snack('No pudimos guardar tu elección. Intenta de nuevo.');
    }
  }

  /// Selecciona un banco con convenio (tarjeta clickeable): persiste
  /// tipo+banco y avanza a precalificación — misma acción que el portal.
  Future<void> _seleccionarBanco(BancoConvenio banco) async {
    setState(() {
      _bancoSel = banco;
      _guardando = true;
    });
    try {
      await setPagoFinal(
        widget.cuentaId,
        'CREDITO_HIPOTECARIO',
        idBanco: banco.id,
        impersonate: ref.read(impersonationProvider).idPersona,
      );
      ref.invalidate(propiedadDetalleProvider(widget.cuentaId));
      if (!mounted) return;
      setState(() {
        _paso = _Paso.precalificacion;
        _guardando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _snack('No pudimos guardar tu elección. Intenta de nuevo.');
    }
  }

  Future<void> _enviarSolicitud() async {
    final banco = _bancoSel;
    if (banco == null || !_montoValido) return;
    setState(() => _enviando = true);
    try {
      final solicitud = await crearSolicitudCredito(
        idCuenta: widget.cuentaId,
        idBanco: banco.id,
        montoCredito: _monto,
        plazoMeses: _plazoAnios * 12,
        impersonate: ref.read(impersonationProvider).idPersona,
      );
      ref.invalidate(propiedadDetalleProvider(widget.cuentaId));
      if (!mounted) return;
      setState(() {
        _solicitud = solicitud ?? _solicitud;
        _resumenEnviado = (
          monto: _monto,
          plazoAnios: _plazoAnios,
          mensualidad: banco.tasaDesde != null
              ? _mensualidad(_monto, banco.tasaDesde!, _plazoAnios)
              : null,
          tasa: banco.tasaDesde,
        );
        _paso = _Paso.estatusCredito;
        _enviando = false;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _snack(
        e.code == 'solicitud_vigente'
            ? 'Tu solicitud sigue vigente con el banco. Podrás cambiar '
                  'cuando el banco responda o venza el plazo.'
            : 'No pudimos enviar tu solicitud. Intenta de nuevo.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _snack('No pudimos enviar tu solicitud. Intenta de nuevo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        Container(height: 1, color: PortalColors.border),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: [
              ..._cuerpo(),
              if (widget.saldo > 0) _asesorBloque(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PortalColors.primarySoft10,
              borderRadius: BorderRadius.circular(kPortalRadiusMd),
            ),
            child: const Icon(
              Icons.credit_card_outlined,
              size: 18,
              color: PortalColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pago final',
                  style: portalText(size: 16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.proyecto} · U-${widget.unidad}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: portalText(
                    size: 12,
                    color: PortalColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          PortalIconBtn(
            icon: Icons.close,
            tooltip: 'Cerrar',
            onTap: _cerrar,
          ),
        ],
      ),
    );
  }

  List<Widget> _cuerpo() {
    if (widget.saldo <= 0) return _unidadLiquidada();
    return [
      // Saldo a liquidar (monto grande a la derecha).
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Saldo a liquidar',
            style: portalText(size: 13, color: PortalColors.mutedForeground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '${formatMXN(widget.saldo)} MXN',
                style: portalText(
                  size: 20,
                  weight: FontWeight.w700,
                  tabular: true,
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      ...switch (_paso) {
        _Paso.seleccion => _seleccion(),
        _Paso.banco => _bancoSelector(),
        _Paso.precalificacion => _precalificacion(),
        _Paso.estatusCredito => _estatusCredito(),
      },
    ];
  }

  // ── Unidad liquidada ──
  List<Widget> _unidadLiquidada() => [
    const SizedBox(height: 12),
    Center(
      child: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: PortalColors.primarySoft10,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.verified_outlined,
          size: 32,
          color: PortalColors.primary,
        ),
      ),
    ),
    const SizedBox(height: 16),
    Center(
      child: Text(
        'Unidad liquidada',
        style: portalText(size: 18, weight: FontWeight.w700),
      ),
    ),
    const SizedBox(height: 6),
    Center(
      child: Text(
        '${widget.proyecto} U-${widget.unidad} está 100% pagada. Ya puedes '
        'agendar tu cita de escrituración y entrega.',
        textAlign: TextAlign.center,
        style: portalText(size: 13, color: PortalColors.mutedForeground),
      ),
    ),
    const SizedBox(height: 20),
    _ctaButton(
      label: 'Agendar cita de escrituración',
      icon: Icons.event_available_outlined,
      enabled: false,
      onPressed: () {},
    ),
  ];

  // ── Paso 1: método de pago ──
  List<Widget> _seleccion() => [
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PortalColors.mutedSoft30,
        borderRadius: BorderRadius.circular(kPortalRadiusLg),
        border: Border.all(color: PortalColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 16,
            color: PortalColors.mutedForeground,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Requisito para escrituración y entrega',
                  style: portalText(size: 13, weight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Para agendar tu cita de escrituración y entrega del '
                  'departamento, tu unidad debe estar liquidada en su totalidad.',
                  style: portalText(
                    size: 12,
                    color: PortalColors.mutedForeground,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 18),
    Text(
      '¿Cómo terminarás de pagar tu departamento?',
      style: portalText(size: 14, weight: FontWeight.w600),
    ),
    const SizedBox(height: 4),
    Text(
      'Tu elección nos permitirá preparar correctamente el proceso de '
      'escrituración.',
      style: portalText(
        size: 12,
        color: PortalColors.mutedForeground,
        height: 1.4,
      ),
    ),
    const SizedBox(height: 14),
    _opcionMetodo(
      valor: 'RECURSOS_PROPIOS',
      icono: Icons.account_balance_outlined,
      titulo: 'Recursos propios',
      subtitulo: 'Transferencia interbancaria por STP',
    ),
    const SizedBox(height: 10),
    _opcionMetodo(
      valor: 'CREDITO_HIPOTECARIO',
      icono: Icons.account_balance_wallet_outlined,
      titulo: 'Crédito hipotecario',
      subtitulo: 'Financiamiento con una institución bancaria',
    ),
    const SizedBox(height: 18),
    _ctaButton(
      label: _metodo == null
          ? 'Selecciona un método de pago'
          : _metodo == 'RECURSOS_PROPIOS'
          ? 'Ver instrucciones de pago'
          : 'Continuar',
      icon: _metodo == null ? null : Icons.chevron_right,
      enabled: _metodo != null && !_guardando,
      onPressed: () {
        if (_metodo == 'RECURSOS_PROPIOS') {
          _elegirRecursosPropios();
        } else {
          _cargarBancos();
          setState(() => _paso = _Paso.banco);
        }
      },
    ),
  ];

  Widget _opcionMetodo({
    required String valor,
    required IconData icono,
    required String titulo,
    required String subtitulo,
  }) {
    final activo = _metodo == valor;
    return PortalHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: () => setState(() => _metodo = valor),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: activo ? PortalColors.primarySoft6 : PortalColors.surface,
            borderRadius: BorderRadius.circular(kPortalRadiusLg),
            border: Border.all(
              color: activo
                  ? PortalColors.primary
                  : hovered
                  ? PortalColors.primaryBorder30
                  : PortalColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                activo
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: activo
                    ? PortalColors.primary
                    : PortalColors.mutedForeground,
              ),
              const SizedBox(width: 12),
              Icon(icono, size: 18, color: PortalColors.mutedForeground),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: portalText(size: 13, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitulo,
                      style: portalText(
                        size: 11,
                        color: PortalColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Paso 2: selector de banco (tarjetas clickeables, estilo portal) ──
  List<Widget> _bancoSelector() => [
    Row(
      children: [
        const Icon(Icons.auto_awesome, size: 13, color: PortalColors.primary),
        const SizedBox(width: 8),
        Text(
          'BANCOS ALIADOS CON SOZU',
          style: portalText(
            size: 11,
            weight: FontWeight.w600,
            color: PortalColors.primary,
            letterSpacing: 0.55,
          ),
        ),
      ],
    ),
    const SizedBox(height: 6),
    Text(
      '¿Con qué banco tramitarás tu crédito?',
      style: portalText(size: 14, weight: FontWeight.w600),
    ),
    const SizedBox(height: 14),
    FutureBuilder<List<BancoConvenio>>(
      future: _bancosFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: PortalColors.primary,
                ),
              ),
            ),
          );
        }
        final bancos = snap.data ?? const <BancoConvenio>[];
        if (bancos.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kPortalRadiusLg),
              border: Border.all(color: PortalColors.border),
            ),
            child: Text(
              snap.hasError
                  ? 'No pudimos cargar los bancos con convenio. Intenta de '
                        'nuevo más tarde.'
                  : 'No hay bancos con convenio disponibles por ahora.',
              textAlign: TextAlign.center,
              style: portalText(
                size: 12,
                color: PortalColors.mutedForeground,
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final b in bancos) ...[
              _bancoCard(b),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    ),
    const SizedBox(height: 6),
    Center(
      child: PortalHoverBuilder(
        builder: (context, hovered) => GestureDetector(
          onTap: _guardando
              ? null
              : () => setState(() => _paso = _Paso.seleccion),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Cambiar método de pago',
              style: portalText(
                size: 12,
                weight: FontWeight.w500,
                color: hovered
                    ? PortalColors.foreground
                    : PortalColors.mutedForeground,
              ),
            ),
          ),
        ),
      ),
    ),
  ];

  Widget _bancoCard(BancoConvenio b) {
    final color = _parseColor(b.color);
    final subt = [
      if (b.producto != null) b.producto!,
      if (b.tasaDesde != null) 'desde ${_pct(b.tasaDesde!)}%',
    ].join(' · ');
    return PortalHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: _guardando ? null : () => _seleccionarBanco(b),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PortalColors.surface,
            borderRadius: BorderRadius.circular(kPortalRadiusLg),
            border: Border.all(
              color: hovered
                  ? PortalColors.primaryBorder30
                  : PortalColors.border,
            ),
            boxShadow: hovered
                ? const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      offset: Offset(0, 1),
                      blurRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color ?? PortalColors.muted,
                  borderRadius: BorderRadius.circular(kPortalRadiusMd),
                ),
                child: color != null
                    ? Text(
                        _siglas(b.nombre),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      )
                    : const Icon(
                        Icons.account_balance_outlined,
                        size: 20,
                        color: PortalColors.mutedForeground,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            b.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: portalText(
                              size: 13,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: PortalColors.mutedForeground,
                        ),
                      ],
                    ),
                    if (subt.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: portalText(
                          size: 11,
                          color: PortalColors.mutedForeground,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: PortalColors.primarySoft10,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            size: 11,
                            color: PortalColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Aliado SOZU',
                            style: portalText(
                              size: 10,
                              weight: FontWeight.w500,
                              color: PortalColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Paso 3: precalificación ──
  List<Widget> _precalificacion() {
    final banco = _bancoSel;
    if (banco == null) return _bancoSelector();
    final estimacion = banco.tasaDesde != null && _montoValido
        ? _mensualidad(_monto, banco.tasaDesde!, _plazoAnios)
        : null;
    return [
      Text(
        'Crédito hipotecario con ${banco.nombre}',
        style: portalText(
          size: 11,
          weight: FontWeight.w600,
          color: PortalColors.primary,
          letterSpacing: 0.4,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        '¿Cuánto necesitas financiar?',
        style: portalText(size: 14, weight: FontWeight.w600),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kPortalRadiusLg),
          border: Border.all(color: PortalColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monto a financiar (MXN)',
              style: portalText(
                size: 12,
                color: PortalColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              cursorColor: PortalColors.primary,
              style: portalText(
                size: 18,
                weight: FontWeight.w700,
                tabular: true,
              ),
              decoration: const InputDecoration(
                prefixText: r'$ ',
                isDense: true,
                border: UnderlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              _monto > widget.saldo
                  ? 'El monto no puede ser mayor a tu saldo pendiente '
                        '(${formatMXN(widget.saldo)} MXN).'
                  : 'El resto lo cubrirías con recursos propios al escriturar. '
                        'Tu saldo pendiente es de ${formatMXN(widget.saldo)} MXN.',
              style: portalText(
                size: 11,
                color: _monto > widget.saldo
                    ? PortalColors.destructive
                    : PortalColors.mutedForeground,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Text('Plazo', style: portalText(size: 12, weight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final p in _plazosAnios)
            PortalHoverBuilder(
              builder: (context, hovered) => GestureDetector(
                onTap: () => setState(() => _plazoAnios = p),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: _plazoAnios == p
                        ? PortalColors.primarySoft10
                        : PortalColors.surface,
                    borderRadius: BorderRadius.circular(kPortalRadiusLg),
                    border: Border.all(
                      color: _plazoAnios == p
                          ? PortalColors.primary
                          : hovered
                          ? PortalColors.primaryBorder30
                          : PortalColors.border,
                    ),
                  ),
                  child: Text(
                    '$p años',
                    style: portalText(
                      size: 12,
                      weight: FontWeight.w600,
                      color: _plazoAnios == p
                          ? PortalColors.primary
                          : PortalColors.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 14),
      if (estimacion != null) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PortalColors.primarySoft5,
            borderRadius: BorderRadius.circular(kPortalRadiusLg),
            border: Border.all(color: PortalColors.primaryBorder30),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu mensualidad estimada sería desde',
                style: portalText(
                  size: 11,
                  color: PortalColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${formatMXN(estimacion)} MXN/mes',
                  style: portalText(
                    size: 20,
                    weight: FontWeight.w700,
                    tabular: true,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Durante $_plazoAnios años, con tasa fija anual desde '
                '${_pct(banco.tasaDesde!)}%.',
                style: portalText(
                  size: 11,
                  color: PortalColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Estimación referencial con la tasa de ${banco.nombre}. La '
                'tasa y CAT definitivos los determina el banco al revisar tu '
                'perfil. No constituye una oferta vinculante.',
                style: portalText(
                  size: 10,
                  color: PortalColors.textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ] else if (banco.tasaDesde == null) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kPortalRadiusLg),
            border: Border.all(color: PortalColors.border),
          ),
          child: Text(
            '${banco.nombre} te compartirá la tasa y mensualidad al revisar '
            'tu solicitud.',
            style: portalText(size: 11, color: PortalColors.textMuted),
          ),
        ),
        const SizedBox(height: 14),
      ],
      // Consentimiento LFPDPPP.
      GestureDetector(
        onTap: _enviando
            ? null
            : () => setState(() => _consiente = !_consiente),
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                _consiente
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 18,
                color: _consiente
                    ? PortalColors.primary
                    : PortalColors.mutedForeground,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Autorizo a SOZU compartir mis datos con ${banco.nombre} para '
                'iniciar mi crédito hipotecario, conforme al Aviso de '
                'Privacidad (LFPDPPP).',
                style: portalText(
                  size: 11,
                  color: PortalColors.mutedForeground,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _ctaButton(
        label: _enviando ? 'Enviando…' : 'Enviar a ${banco.nombre}',
        icon: Icons.send_outlined,
        enabled: _montoValido && _consiente && !_enviando,
        onPressed: _enviarSolicitud,
      ),
      const SizedBox(height: 8),
      _ctaButton(
        label: 'Cambiar banco',
        style: PortalBlockButtonStyle.secondary,
        enabled: !_enviando,
        onPressed: () => setState(() => _paso = _Paso.banco),
      ),
    ];
  }

  // ── Paso 4: estatus del crédito ──
  List<Widget> _estatusCredito() {
    final s = _solicitud;
    final bancoNombre = s?.bancoNombre;
    final info = s != null ? _estatusInfo(s.estatus) : null;
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: info?.bg ?? PortalColors.primarySoft5,
          borderRadius: BorderRadius.circular(kPortalRadiusLg),
          border: Border.all(
            color: (info?.fg ?? PortalColors.primary).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (info?.fg ?? PortalColors.primary).withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(kPortalRadiusMd),
              ),
              child: Icon(
                info?.icon ?? Icons.verified_outlined,
                size: 18,
                color: info?.fg ?? PortalColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (info != null)
                    Text(
                      info.label.toUpperCase(),
                      style: portalText(
                        size: 10,
                        weight: FontWeight.w600,
                        color: info.fg,
                        letterSpacing: 0.5,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    bancoNombre != null
                        ? 'Crédito hipotecario · $bancoNombre'
                        : 'Crédito hipotecario registrado',
                    style: portalText(size: 13, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info?.descripcion ??
                        'Registramos que liquidarás tu unidad con crédito '
                            'hipotecario. Tu asesor dará seguimiento al '
                            'proceso con el banco.',
                    style: portalText(
                      size: 11,
                      color: PortalColors.mutedForeground,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (_resumenEnviado != null) ...[
        const SizedBox(height: 12),
        _resumenEnviadoCard(bancoNombre),
      ],
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PortalColors.mutedSoft30,
          borderRadius: BorderRadius.circular(kPortalRadiusLg),
          border: Border.all(color: PortalColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PortalSectionLabel('Lo que sigue'),
            const SizedBox(height: 10),
            for (final (idx, paso) in [
              s != null
                  ? 'Tu solicitud de crédito fue enviada a '
                        '${bancoNombre ?? 'tu banco'}'
                        '${s.fechaSolicitud != null ? ' el ${formatDate(s.fechaSolicitud)}' : ''}.'
                  : bancoNombre != null
                  ? '$bancoNombre evalúa y autoriza tu crédito.'
                  : 'El banco evalúa y autoriza tu crédito.',
              'El banco revisará tu solicitud y te contactará con un broker '
                  'dedicado.',
              'SOZU coordinará con ${bancoNombre ?? 'el banco'} y el notario '
                  'para tu escrituración.',
            ].indexed) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: PortalColors.foreground,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${idx + 1}',
                      style: portalText(
                        size: 10,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      paso,
                      style: portalText(
                        size: 11,
                        color: PortalColors.mutedForeground,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (s != null && s.puedeCambiar) ...[
        PortalBlockButton(
          label: 'Cambiar banco',
          icon: Icons.refresh,
          style: PortalBlockButtonStyle.secondary,
          onPressed: () => setState(() {
            _cargarBancos();
            _bancoSel = null;
            _paso = _Paso.banco;
          }),
        ),
        const SizedBox(height: 8),
      ],
      PortalBlockButton(
        label: 'Cerrar',
        style: PortalBlockButtonStyle.secondary,
        onPressed: _cerrar,
      ),
    ];
  }

  Widget _resumenEnviadoCard(String? bancoNombre) {
    final r = _resumenEnviado!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kPortalRadiusLg),
        border: Border.all(color: PortalColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortalSectionLabel(
            bancoNombre != null
                ? 'Estimación enviada a $bancoNombre'
                : 'Estimación enviada',
          ),
          const SizedBox(height: 10),
          if (r.mensualidad != null) ...[
            Text(
              'Mensualidad estimada',
              style: portalText(size: 10, color: PortalColors.mutedForeground),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'desde ${formatMXN(r.mensualidad!)} MXN/mes',
                style: portalText(
                  size: 18,
                  weight: FontWeight.w700,
                  tabular: true,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _dato('Monto a financiar', formatMXN(r.monto)),
              _dato('Plazo', '${r.plazoAnios} años'),
              if (r.tasa != null)
                _dato('Tasa fija anual', 'desde ${_pct(r.tasa!)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dato(String label, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: portalText(size: 10, color: PortalColors.mutedForeground),
        ),
        const SizedBox(height: 2),
        Text(valor, style: portalText(size: 12, weight: FontWeight.w600)),
      ],
    );
  }

  // ── Bloque de asesor (AdvisorCard del portal) ──
  // Degradación: el backend solo expone `agente_comercial`; se usa como asesor
  // de esta fase. Si no hay agente con WhatsApp, el bloque se oculta.
  Widget _asesorBloque() {
    final a = widget.agente;
    if (a == null || (a.whatsapp ?? '').trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final asunto = '${widget.proyecto} U-${widget.unidad}';
    final firstName = a.nombre.split(' ').first;
    final mensaje =
        'Hola $firstName, soy cliente SOZU.\n\n'
        'Contexto: $asunto · Pago Final\n\nMi consulta:';
    final waUrl =
        'https://wa.me/${a.whatsapp!.trim()}'
        '?text=${Uri.encodeComponent(mensaje)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Container(height: 1, color: PortalColors.border),
        const SizedBox(height: 18),
        const PortalSectionLabel('¿Necesitas ayuda con esta decisión?'),
        const SizedBox(height: 12),
        PortalCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: PortalColors.primarySoft10,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      initials(a.nombre),
                      style: portalText(
                        size: 14,
                        weight: FontWeight.w700,
                        color: PortalColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tu asesor en esta fase',
                          style: portalText(
                            size: 10,
                            weight: FontWeight.w600,
                            color: PortalColors.mutedForeground,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: portalText(size: 13, weight: FontWeight.w600),
                        ),
                        Text(
                          a.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: portalText(
                            size: 11,
                            color: PortalColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _botonWhatsApp(waUrl),
            ],
          ),
        ),
      ],
    );
  }

  Widget _botonWhatsApp(String url) {
    return PortalHoverBuilder(
      builder: (context, hovered) => GestureDetector(
        onTap: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hovered ? PortalColors.primaryHover : PortalColors.primary,
            borderRadius: BorderRadius.circular(kPortalRadiusLg),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const WhatsAppIcon(size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Contactar por WhatsApp',
                style: portalText(
                  size: 13,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──
  ({String label, String descripcion, Color bg, Color fg, IconData icon})
  _estatusInfo(String estatus) {
    ({String label, String descripcion, Color bg, Color fg, IconData icon}) pos(
      String l,
      String d,
    ) => (
      label: l,
      descripcion: d,
      bg: PortalColors.primarySoft5,
      fg: PortalColors.primary,
      icon: Icons.check_circle_outline,
    );
    ({String label, String descripcion, Color bg, Color fg, IconData icon})
    pend(String l, String d) => (
      label: l,
      descripcion: d,
      bg: PortalColors.warningSoft10,
      fg: PortalColors.warning,
      icon: Icons.schedule,
    );
    ({String label, String descripcion, Color bg, Color fg, IconData icon}) neg(
      String l,
      String d,
    ) => (
      label: l,
      descripcion: d,
      bg: PortalColors.destructiveSoft10,
      fg: PortalColors.destructive,
      icon: Icons.error_outline,
    );
    return switch (estatus) {
      'nuevo' => pend(
        'Solicitud enviada',
        'Solicitud enviada. El broker se pondrá en contacto contigo lo antes '
            'posible.',
      ),
      'asignado' => pend(
        'Ejecutivo asignado',
        'Un ejecutivo del banco fue asignado a tu solicitud.',
      ),
      'contactado' => pend(
        'Contactado',
        'El banco ya hizo el primer contacto contigo.',
      ),
      'en_evaluacion' || 'en_revision' => pend(
        'En evaluación',
        'El banco está evaluando tu solicitud.',
      ),
      'pre_aprobado' => pos(
        'Pre-aprobado',
        '¡Pre-aprobado! El banco continuará con los siguientes pasos.',
      ),
      'oferta_vinculante' => pos(
        'Oferta vinculante',
        'El banco emitió tu oferta vinculante.',
      ),
      'en_coordinacion' => pos(
        'En coordinación',
        'Coordinando notario y fecha de firma con el banco.',
      ),
      'formalizado' => pos(
        'Crédito formalizado',
        'Crédito formalizado. Listo para escriturar.',
      ),
      'rechazado' => neg(
        'Solicitud rechazada',
        'El banco declinó la solicitud. Puedes elegir otro banco.',
      ),
      'expirada' => neg(
        'Solicitud expirada',
        'Venció el plazo de respuesta del banco. Puedes elegir otro banco.',
      ),
      'desistido' => pend(
        'Solicitud desistida',
        'Solicitud cancelada. Puedes elegir otro banco.',
      ),
      _ => pend(
        'En proceso',
        'Tu asesor dará seguimiento al proceso con el banco.',
      ),
    };
  }

  String _pct(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  String _siglas(String nombre) {
    final limpio = nombre
        .replaceAll(RegExp(r'\s*(México|Banco)\s*', caseSensitive: false), '')
        .trim();
    final base = limpio.isEmpty ? nombre : limpio;
    return base.substring(0, math.min(4, base.length)).toUpperCase();
  }

  Color? _parseColor(String? hex) {
    if (hex == null) return null;
    final h = hex.replaceFirst('#', '').trim();
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }
}
