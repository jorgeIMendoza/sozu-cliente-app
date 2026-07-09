import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/api_client.dart';
import '../providers/data_providers.dart';
import '../providers/impersonation_provider.dart';
import '../widgets/common.dart';

const _bancos = [
  (id: 1, nombre: 'BBVA'),
  (id: 2, nombre: 'Santander'),
  (id: 3, nombre: 'Banorte'),
];

/// Flujo "Pago final" (espejo del portal-cliente de sozu-admin): el cliente
/// elige cómo liquidará su unidad — recursos propios (STP) o crédito
/// hipotecario (banco preferente u otro). La elección se persiste vía
/// cliente-pago-final; recursos propios continúa a instrucciones de pago.
class PagoFinalScreen extends ConsumerStatefulWidget {
  final int cuentaId;
  final String unidad;
  final String proyecto;
  final double saldo;

  /// Acuerdo pendiente al que van las instrucciones STP (null = sin pendiente).
  final int? acuerdoId;

  /// Método ya elegido (RECURSOS_PROPIOS/CREDITO_HIPOTECARIO) o null.
  final String? tipoFinanciamiento;

  const PagoFinalScreen({
    super.key,
    required this.cuentaId,
    required this.unidad,
    required this.proyecto,
    required this.saldo,
    this.acuerdoId,
    this.tipoFinanciamiento,
  });

  @override
  ConsumerState<PagoFinalScreen> createState() => _PagoFinalScreenState();
}

enum _Paso { seleccion, banco, estatusCredito }

class _PagoFinalScreenState extends ConsumerState<PagoFinalScreen> {
  _Paso _paso = _Paso.seleccion;
  String? _metodo; // RECURSOS_PROPIOS | CREDITO_HIPOTECARIO
  int? _idBanco; // null = otro banco
  bool _otroBanco = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    if (widget.tipoFinanciamiento == 'CREDITO_HIPOTECARIO') {
      _paso = _Paso.estatusCredito;
    }
  }

  Future<void> _continuar() async {
    if (_metodo == null) return;
    if (_metodo == 'CREDITO_HIPOTECARIO' && _paso == _Paso.seleccion) {
      setState(() => _paso = _Paso.banco);
      return;
    }
    await _guardar();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos guardar tu elección. Intenta de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
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
            _Paso.estatusCredito => _estatusCredito(tone),
          },
        ],
      ),
    );
  }

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
    for (final b in _bancos) ...[
      GestureDetector(
        onTap: () => setState(() {
          _idBanco = b.id;
          _otroBanco = false;
        }),
        child: AppCard(
          borderColor: !_otroBanco && _idBanco == b.id
              ? tone.primaryDark
              : null,
          child: Row(
            children: [
              Icon(
                !_otroBanco && _idBanco == b.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: !_otroBanco && _idBanco == b.id
                    ? tone.primaryDark
                    : tone.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  b.nombre,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tone.textPrimary,
                  ),
                ),
              ),
              StatusBadge(label: 'Preferente', tone: BadgeTone.positive),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
    ],
    GestureDetector(
      onTap: () => setState(() {
        _otroBanco = true;
        _idBanco = null;
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
      onPressed: (_idBanco == null && !_otroBanco) || _guardando
          ? null
          : _guardar,
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

  List<Widget> _estatusCredito(SozuTone tone) => [
    AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_outlined, size: 20, color: tone.primaryDark),
              const SizedBox(width: 8),
              Text(
                'Crédito hipotecario registrado',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: tone.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Registramos que liquidarás tu unidad con crédito hipotecario. '
            'Tu asesor dará seguimiento al proceso con el banco.',
            style: TextStyle(fontSize: 13, color: tone.textSecondary),
          ),
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
          for (final paso in const [
            'El banco evalúa y autoriza tu crédito.',
            'SOZU coordina con el banco el pago de tu unidad.',
            'Agendamos tu cita de escrituración y entrega.',
          ]) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 16, color: tone.primaryDark),
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
    OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Volver a mi propiedad'),
    ),
  ];
}
