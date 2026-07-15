import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/api_client.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../providers/impersonation_provider.dart';
import '../widgets/common.dart';

/// Plazos disponibles para el crédito hipotecario (años).
const _plazosAnios = [10, 15, 20];

/// Flujo "Pago final" (espejo del portal-cliente de sozu-admin): el cliente
/// elige cómo liquidará su unidad — recursos propios (STP) o crédito
/// hipotecario (banco con convenio u otro). La elección se persiste vía
/// cliente-pago-final; recursos propios continúa a instrucciones de pago.
/// Con banco preferente sigue la precalificación (monto/plazo + estimación) y
/// el envío de la solicitud de crédito.
class PagoFinalScreen extends ConsumerStatefulWidget {
  final int cuentaId;
  final String unidad;
  final String proyecto;
  final double saldo;

  /// Acuerdo pendiente al que van las instrucciones STP (null = sin pendiente).
  final int? acuerdoId;

  /// Método ya elegido (RECURSOS_PROPIOS/CREDITO_HIPOTECARIO) o null.
  final String? tipoFinanciamiento;

  /// Solicitud de crédito vigente (viene de PropiedadDetalle.solicitudCredito);
  /// null = estatus genérico sin datos del banco.
  final SolicitudCredito? solicitud;

  const PagoFinalScreen({
    super.key,
    required this.cuentaId,
    required this.unidad,
    required this.proyecto,
    required this.saldo,
    this.acuerdoId,
    this.tipoFinanciamiento,
    this.solicitud,
  });

  @override
  ConsumerState<PagoFinalScreen> createState() => _PagoFinalScreenState();
}

enum _Paso { seleccion, banco, precalificacion, estatusCredito }

class _PagoFinalScreenState extends ConsumerState<PagoFinalScreen> {
  _Paso _paso = _Paso.seleccion;
  String? _metodo; // RECURSOS_PROPIOS | CREDITO_HIPOTECARIO
  int? _idBanco; // null = otro banco
  BancoConvenio? _bancoSel;
  bool _otroBanco = false;
  bool _guardando = false;

  /// Catálogo dinámico de bancos con convenio (se carga al entrar al selector).
  Future<List<BancoConvenio>>? _bancosFuture;

  /// Solicitud mostrada en el estatus: la creada en esta sesión o la recibida.
  SolicitudCredito? _solicitud;

  // — Precalificación —
  late final TextEditingController _montoCtrl;
  int _plazoAnios = 20;
  bool _enviando = false;

  /// Consentimiento LFPDPPP: el backend registra consentimiento_datos=true,
  /// por lo que la app DEBE recabarlo explícitamente antes de enviar.
  bool _consiente = false;

  @override
  void initState() {
    super.initState();
    _solicitud = widget.solicitud;
    _montoCtrl = TextEditingController(
      text: widget.saldo > 0 ? widget.saldo.round().toString() : '',
    );
    if (widget.tipoFinanciamiento == 'CREDITO_HIPOTECARIO') {
      _paso = _Paso.estatusCredito;
      _metodo = 'CREDITO_HIPOTECARIO';
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

  /// Pago mensual (amortización francesa) — port de
  /// mortgage-data.ts `calculateMonthlyPayment`.
  double _mensualidad(double principal, double tasaAnual, int anios) {
    if (principal <= 0 || anios <= 0) return 0;
    final i = tasaAnual / 100 / 12;
    final n = anios * 12;
    if (i == 0) return principal / n;
    final factor = math.pow(1 + i, n).toDouble();
    return principal * i * factor / (factor - 1);
  }

  Future<void> _continuar() async {
    if (_metodo == null) return;
    if (_metodo == 'CREDITO_HIPOTECARIO' && _paso == _Paso.seleccion) {
      _cargarBancos();
      setState(() => _paso = _Paso.banco);
      return;
    }
    await _guardar();
  }

  /// Confirma el banco elegido: "otro banco" solo persiste el tipo (flujo
  /// actual); banco preferente persiste tipo+banco y sigue a precalificación.
  Future<void> _confirmarBanco() async {
    if (_otroBanco) {
      await _guardar();
      return;
    }
    final banco = _bancoSel;
    if (banco == null) return;
    setState(() => _guardando = true);
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

  /// Envía la solicitud de precalificación al banco preferente.
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
        _paso = _Paso.estatusCredito;
        _enviando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _snack('No pudimos enviar tu solicitud. Intenta de nuevo.');
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final imp = ref.read(impersonationProvider).idPersona;
      await setPagoFinal(
        widget.cuentaId,
        _metodo!,
        idBanco: _metodo == 'CREDITO_HIPOTECARIO' && !_otroBanco
            ? _idBanco
            : null,
        impersonate: imp,
      );
      ref.invalidate(propiedadDetalleProvider(widget.cuentaId));
      if (!mounted) return;
      if (_metodo == 'RECURSOS_PROPIOS') {
        // Directo a las instrucciones de transferencia STP.
        if (widget.acuerdoId != null) {
          context.pushReplacement('/pagar?id=${widget.acuerdoId}');
        } else {
          Navigator.of(context).pop();
        }
      } else {
        setState(() {
          _paso = _Paso.estatusCredito;
          _guardando = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _snack('No pudimos guardar tu elección. Intenta de nuevo.');
    }
  }

  void _snack(String mensaje) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    // Unidad 100% pagada: no hay nada que elegir (ref PagoFinalSheet fully paid).
    if (widget.saldo <= 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pago final')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: _unidadLiquidada(tone),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Pago final')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${widget.proyecto} · U-${widget.unidad}',
            style: TextStyle(fontSize: 13, color: tone.textMuted),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saldo a liquidar',
                  style: TextStyle(fontSize: 14, color: tone.textSecondary),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${formatMXN(widget.saldo)} MXN',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: tone.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...switch (_paso) {
            _Paso.seleccion => _seleccion(tone),
            _Paso.banco => _bancoSelector(tone),
            _Paso.precalificacion => _precalificacion(tone),
            _Paso.estatusCredito => _estatusCredito(tone),
          },
        ],
      ),
    );
  }

  // ── Unidad liquidada ──

  List<Widget> _unidadLiquidada(SozuTone tone) => [
    Text(
      '${widget.proyecto} · U-${widget.unidad}',
      style: TextStyle(fontSize: 13, color: tone.textMuted),
    ),
    const SizedBox(height: 24),
    Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: tone.primarySoft,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.verified_outlined, size: 36, color: tone.primaryDark),
      ),
    ),
    const SizedBox(height: 16),
    Center(
      child: Text(
        'Unidad liquidada 🎉',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: tone.textPrimary,
        ),
      ),
    ),
    const SizedBox(height: 8),
    Center(
      child: Text(
        '${widget.proyecto} U-${widget.unidad} está 100% pagada. '
        'Ya puedes agendar tu cita de escrituración y entrega.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: tone.textSecondary),
      ),
    ),
    const SizedBox(height: 24),
    const FilledButton(
      onPressed: null,
      child: Text('Agendar cita de escrituración'),
    ),
    const SizedBox(height: 8),
    Center(
      child: Text(
        'Próximamente podrás agendar tu cita desde la app.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: tone.textMuted),
      ),
    ),
    const SizedBox(height: 16),
    OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Volver a mi propiedad'),
    ),
  ];

  // ── Paso 1: método de pago ──

  List<Widget> _seleccion(SozuTone tone) => [
    AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: tone.primaryDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Requisito para escrituración y entrega',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tone.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Para agendar tu cita de escrituración y entrega del '
                  'departamento, tu unidad debe estar liquidada en su totalidad.',
                  style: TextStyle(fontSize: 13, color: tone.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    Text(
      '¿Cómo terminarás de pagar tu departamento?',
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: tone.textPrimary,
      ),
    ),
    const SizedBox(height: 4),
    Text(
      'Tu elección nos permitirá preparar correctamente el proceso de '
      'escrituración.',
      style: TextStyle(fontSize: 13, color: tone.textSecondary),
    ),
    const SizedBox(height: 12),
    _opcionMetodo(
      tone,
      valor: 'RECURSOS_PROPIOS',
      icono: Icons.account_balance_outlined,
      titulo: 'Recursos propios',
      subtitulo: 'Transferencia interbancaria por STP',
    ),
    const SizedBox(height: 10),
    _opcionMetodo(
      tone,
      valor: 'CREDITO_HIPOTECARIO',
      icono: Icons.account_balance_wallet_outlined,
      titulo: 'Crédito hipotecario',
      subtitulo: 'Financiamiento con una institución bancaria',
    ),
    const SizedBox(height: 16),
    FilledButton(
      onPressed: _metodo == null || _guardando ? null : _continuar,
      child: _guardando
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Text(
              _metodo == null ? 'Selecciona un método de pago' : 'Continuar',
            ),
    ),
  ];

  Widget _opcionMetodo(
    SozuTone tone, {
    required String valor,
    required IconData icono,
    required String titulo,
    required String subtitulo,
  }) {
    final activo = _metodo == valor;
    return GestureDetector(
      onTap: () => setState(() => _metodo = valor),
      child: AppCard(
        borderColor: activo ? tone.primaryDark : null,
        child: Row(
          children: [
            Icon(
              activo
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: activo ? tone.primaryDark : tone.textMuted,
            ),
            const SizedBox(width: 12),
            Icon(icono, size: 20, color: tone.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tone.textPrimary,
                    ),
                  ),
                  Text(
                    subtitulo,
                    style: TextStyle(fontSize: 12, color: tone.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Paso 2: selector de banco (catálogo dinámico) ──

  List<Widget> _bancoSelector(SozuTone tone) => [
    Text(
      '¿Con qué banco tramitarás tu crédito?',
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: tone.textPrimary,
      ),
    ),
    const SizedBox(height: 4),
    Text(
      'Con bancos preferentes el seguimiento es más ágil.',
      style: TextStyle(fontSize: 13, color: tone.textSecondary),
    ),
    const SizedBox(height: 12),
    FutureBuilder<List<BancoConvenio>>(
      future: _bancosFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }
        final bancos = snap.data ?? const <BancoConvenio>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (bancos.isEmpty) ...[
              AppCard(
                child: Text(
                  snap.hasError
                      ? 'No pudimos cargar los bancos con convenio. '
                            'Puedes continuar con otro banco.'
                      : 'Por ahora no hay bancos con convenio disponibles. '
                            'Puedes continuar con otro banco.',
                  style: TextStyle(fontSize: 13, color: tone.textSecondary),
                ),
              ),
              const SizedBox(height: 10),
            ] else
              for (final b in bancos) ...[
                _bancoCard(tone, b),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    ),
    GestureDetector(
      onTap: () => setState(() {
        _otroBanco = true;
        _idBanco = null;
        _bancoSel = null;
      }),
      child: AppCard(
        borderColor: _otroBanco ? tone.primaryDark : null,
        child: Row(
          children: [
            Icon(
              _otroBanco
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: _otroBanco ? tone.primaryDark : tone.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Otro banco',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tone.textPrimary,
                    ),
                  ),
                  Text(
                    'Tu asesor te contactará para dar seguimiento.',
                    style: TextStyle(fontSize: 12, color: tone.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 16),
    FilledButton(
      onPressed: (_bancoSel == null && !_otroBanco) || _guardando
          ? null
          : _confirmarBanco,
      child: _guardando
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : const Text('Confirmar banco'),
    ),
    const SizedBox(height: 8),
    OutlinedButton(
      onPressed: () => setState(() => _paso = _Paso.seleccion),
      child: const Text('Regresar'),
    ),
  ];

  Widget _bancoCard(SozuTone tone, BancoConvenio b) {
    final activo = !_otroBanco && _idBanco == b.id;
    final color = _parseColor(b.color);
    return GestureDetector(
      onTap: () => setState(() {
        _idBanco = b.id;
        _bancoSel = b;
        _otroBanco = false;
      }),
      child: AppCard(
        borderColor: activo ? tone.primaryDark : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              activo
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: activo ? tone.primaryDark : tone.textMuted,
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color ?? tone.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: color != null
                  ? Text(
                      _siglas(b.nombre),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      Icons.account_balance_outlined,
                      size: 20,
                      color: tone.textSecondary,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.nombre,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tone.textPrimary,
                    ),
                  ),
                  if (b.producto != null || b.tasaDesde != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (b.producto != null) b.producto!,
                        if (b.tasaDesde != null)
                          'Tasa desde ${_pct(b.tasaDesde!)}%',
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: tone.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 6),
                  const Wrap(
                    children: [
                      StatusBadge(
                        label: 'Preferente',
                        tone: BadgeTone.positive,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Paso 3: precalificación (monto + plazo + estimación) ──

  List<Widget> _precalificacion(SozuTone tone) {
    final banco = _bancoSel;
    if (banco == null) return _bancoSelector(tone);
    final estimacion = banco.tasaDesde != null && _montoValido
        ? _mensualidad(_monto, banco.tasaDesde!, _plazoAnios)
        : null;
    return [
      Text(
        'Crédito hipotecario con ${banco.nombre}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: tone.primaryDark,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        '¿Cuánto necesitas financiar?',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: tone.textPrimary,
        ),
      ),
      const SizedBox(height: 12),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monto a financiar (MXN)',
              style: TextStyle(fontSize: 13, color: tone.textSecondary),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: tone.textPrimary,
              ),
              decoration: const InputDecoration(
                prefixText: r'$ ',
                isDense: true,
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
              style: TextStyle(
                fontSize: 12,
                color: _monto > widget.saldo ? tone.negative : tone.textMuted,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Plazo',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: tone.textSecondary,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final p in _plazosAnios)
            GestureDetector(
              onTap: () => setState(() => _plazoAnios = p),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _plazoAnios == p ? tone.primarySoft : tone.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _plazoAnios == p ? tone.primaryDark : tone.border,
                  ),
                ),
                child: Text(
                  '$p años',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _plazoAnios == p
                        ? tone.primaryDark
                        : tone.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (estimacion != null) ...[
        AppCard(
          borderColor: tone.primaryDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu mensualidad estimada sería desde',
                style: TextStyle(fontSize: 12, color: tone.textSecondary),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${formatMXN(estimacion)} MXN/mes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: tone.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Durante $_plazoAnios años, con tasa fija anual desde '
                '${_pct(banco.tasaDesde!)}%.',
                style: TextStyle(fontSize: 12, color: tone.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                'Estimación referencial con la tasa de ${banco.nombre}. La '
                'tasa y CAT definitivos los determina el banco al revisar tu '
                'perfil. No constituye una oferta vinculante.',
                style: TextStyle(fontSize: 11, color: tone.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ] else if (banco.tasaDesde == null) ...[
        AppCard(
          child: Text(
            '${banco.nombre} te compartirá la tasa y mensualidad al revisar '
            'tu solicitud.',
            style: TextStyle(fontSize: 12, color: tone.textMuted),
          ),
        ),
        const SizedBox(height: 12),
      ],
      CheckboxListTile(
        value: _consiente,
        onChanged: _enviando
            ? null
            : (v) => setState(() => _consiente = v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(
          'Autorizo a SOZU a compartir mis datos de contacto y de esta '
          'operación con el banco seleccionado para tramitar mi solicitud '
          'de crédito.',
          style: TextStyle(fontSize: 12, color: tone.textSecondary),
        ),
      ),
      const SizedBox(height: 4),
      FilledButton(
        onPressed: !_montoValido || !_consiente || _enviando
            ? null
            : _enviarSolicitud,
        child: _enviando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text('Enviar solicitud'),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: _enviando
            ? null
            : () => setState(() => _paso = _Paso.banco),
        child: const Text('Cambiar banco'),
      ),
    ];
  }

  // ── Paso 4: estatus del crédito ──

  List<Widget> _estatusCredito(SozuTone tone) {
    final s = _solicitud;
    final bancoNombre = s?.bancoNombre;
    final info = s != null ? _estatusInfo(s.estatus) : null;
    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 20,
                  color: tone.primaryDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bancoNombre != null
                        ? 'Crédito hipotecario · $bancoNombre'
                        : 'Crédito hipotecario registrado',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: tone.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (info != null) ...[
              const SizedBox(height: 10),
              Wrap(
                children: [StatusBadge(label: info.label, tone: info.tone)],
              ),
              const SizedBox(height: 8),
              Text(
                info.descripcion,
                style: TextStyle(fontSize: 13, color: tone.textSecondary),
              ),
              if (s!.fechaSolicitud != null || s.fechaExpiracion != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    if (s.fechaSolicitud != null)
                      _fechaDato(
                        tone,
                        'Solicitud enviada',
                        formatDate(s.fechaSolicitud),
                      ),
                    if (s.fechaExpiracion != null)
                      _fechaDato(
                        tone,
                        'Respuesta del banco antes de',
                        formatDate(s.fechaExpiracion),
                      ),
                  ],
                ),
              ],
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Registramos que liquidarás tu unidad con crédito '
                'hipotecario. Tu asesor dará seguimiento al proceso con el '
                'banco.',
                style: TextStyle(fontSize: 13, color: tone.textSecondary),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LO QUE SIGUE',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
                color: tone.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            for (final paso in [
              bancoNombre != null
                  ? '$bancoNombre evalúa y autoriza tu crédito.'
                  : 'El banco evalúa y autoriza tu crédito.',
              'SOZU coordina con el banco el pago de tu unidad.',
              'Agendamos tu cita de escrituración y entrega.',
            ]) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: tone.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      paso,
                      style: TextStyle(fontSize: 13, color: tone.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (s != null && s.puedeCambiar) ...[
        OutlinedButton(
          onPressed: () => setState(() {
            _cargarBancos();
            _idBanco = null;
            _bancoSel = null;
            _otroBanco = false;
            _paso = _Paso.banco;
          }),
          child: const Text('Cambiar banco'),
        ),
        const SizedBox(height: 8),
      ],
      OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Volver a mi propiedad'),
      ),
    ];
  }

  Widget _fechaDato(SozuTone tone, String label, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: tone.textMuted)),
        const SizedBox(height: 2),
        Text(
          valor,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: tone.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── Helpers ──

  /// Estatus de bancos_solicitudes → etiqueta legible + tono del badge
  /// (espejo de getPreValidationStatusInfo del portal).
  ({String label, String descripcion, BadgeTone tone}) _estatusInfo(
    String estatus,
  ) => switch (estatus) {
    'nuevo' => (
      label: 'Solicitud enviada',
      descripcion:
          'El banco está revisando tu solicitud. Un broker te contactará '
          'pronto.',
      tone: BadgeTone.pending,
    ),
    'asignado' || 'contactado' => (
      label: 'Broker asignado',
      descripcion:
          'Un broker del banco está dando seguimiento a tu solicitud.',
      tone: BadgeTone.pending,
    ),
    'en_evaluacion' || 'en_revision' => (
      label: 'En evaluación',
      descripcion: 'El banco está evaluando tu perfil crediticio.',
      tone: BadgeTone.pending,
    ),
    'pre_aprobado' => (
      label: 'Pre-aprobado',
      descripcion:
          'Tu broker dedicado se pondrá en contacto para los siguientes '
          'pasos.',
      tone: BadgeTone.positive,
    ),
    'oferta_vinculante' => (
      label: 'Oferta vinculante',
      descripcion: 'El banco emitió una oferta formal para tu crédito.',
      tone: BadgeTone.positive,
    ),
    'en_coordinacion' => (
      label: 'En coordinación',
      descripcion:
          'SOZU coordina con el banco y el notario tu escrituración.',
      tone: BadgeTone.positive,
    ),
    'formalizado' => (
      label: 'Crédito formalizado',
      descripcion:
          'Listo para coordinar la firma de escrituración con el notario.',
      tone: BadgeTone.positive,
    ),
    'rechazado' => (
      label: 'Solicitud rechazada',
      descripcion: 'Puedes elegir otro banco o comunicarte con SOZU.',
      tone: BadgeTone.negative,
    ),
    'expirada' => (
      label: 'Solicitud expirada',
      descripcion:
          'El plazo de respuesta del banco venció. Puedes elegir otro banco.',
      tone: BadgeTone.negative,
    ),
    'desistido' => (
      label: 'Solicitud desistida',
      descripcion: 'Cancelaste esta solicitud. Puedes elegir otro banco.',
      tone: BadgeTone.neutral,
    ),
    _ => (
      label: 'En proceso',
      descripcion: 'Tu asesor dará seguimiento al proceso con el banco.',
      tone: BadgeTone.pending,
    ),
  };

  /// "12.5" → "12.5", "12.0" → "12" (sin decimales de más).
  String _pct(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  /// Siglas de respaldo para el logo del banco (port de shortLabel).
  String _siglas(String nombre) {
    final limpio = nombre
        .replaceAll(RegExp(r'\s*(México|Banco)\s*', caseSensitive: false), '')
        .trim();
    final base = limpio.isEmpty ? nombre : limpio;
    return base.substring(0, math.min(4, base.length)).toUpperCase();
  }

  /// "#1464A5" / "1464A5" → Color; null/inválido → null.
  Color? _parseColor(String? hex) {
    if (hex == null) return null;
    final h = hex.replaceFirst('#', '').trim();
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }
}
