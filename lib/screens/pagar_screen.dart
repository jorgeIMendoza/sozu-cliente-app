import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/portal_theme.dart';
import '../core/theme.dart';
import '../data/api_client.dart';
import '../data/models.dart';
import '../providers/impersonation_provider.dart';
import '../widgets/common.dart';
import '../widgets/portal_widgets.dart';

/// Pagar un acuerdo (réplica del flujo del portal admin, sin crédito
/// hipotecario): paso 1 = saldo a liquidar + método "Recursos propios (STP)";
/// paso 2 = "Datos para pago" (monto, vencimiento, CLABE, beneficiario,
/// concepto, con botones de copiar).
class PagarScreen extends ConsumerStatefulWidget {
  final String? referencia; // id del acuerdo de pago

  const PagarScreen({super.key, this.referencia});

  @override
  ConsumerState<PagarScreen> createState() => _PagarScreenState();
}

class _PagarScreenState extends ConsumerState<PagarScreen> {
  late final Future<DatosPago> _datos;
  bool _instrucciones = false;

  @override
  void initState() {
    super.initState();
    final id = int.tryParse(widget.referencia ?? '') ?? 0;
    final imp = ref.read(impersonationProvider).idPersona;
    _datos = fetchDatosPago(id, impersonate: imp);
  }

  Future<void> _copiar(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              size: 18, color: SozuColors.emerald400),
          const SizedBox(width: 8),
          Expanded(child: Text('$label copiado.')),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final portal = isPortalMode(context);

    Widget cuerpo(SozuTone tone) => FutureBuilder<DatosPago>(
      future: _datos,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || snap.data == null) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ErrorCard(
                title: 'No pudimos cargar los datos de pago',
                onRetry: () => setState(() {
                  final id = int.tryParse(widget.referencia ?? '') ?? 0;
                  final imp = ref.read(impersonationProvider).idPersona;
                  // ignore: unused_result
                  _datos = fetchDatosPago(id, impersonate: imp);
                }),
              ),
            ],
          );
        }
        final d = snap.data!;
        // Portal: sin el paso de método único (recursos propios); va directo
        // a las instrucciones de transferencia STP, como el portal admin.
        if (portal) return _portalInstrucciones(tone, d);
        return _instrucciones ? _paso2(tone, d) : _paso1(tone, d);
      },
    );

    // Modo portal: fuerza el tema claro del portal (evita cards oscuras dentro
    // del shell claro, igual que pago_final_screen) y presenta el flujo
    // centrado a máx. 640px, como el sheet de pago del portal en escritorio.
    if (portal) {
      return Theme(
        data: sozuLightTheme(),
        child: Builder(
          builder: (context) {
            final tone = SozuTone.of(context);
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
                        child: Row(
                          children: [
                            PortalIconBtn(
                              icon: Icons.arrow_back,
                              tooltip: 'Regresar',
                              onTap: () => Navigator.of(context).maybePop(),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Instrucciones de pago',
                                  style: portalText(
                                    size: 15,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Transferencia interbancaria',
                                  style: portalText(
                                    size: 12,
                                    color: PortalColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: cuerpo(tone)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    final tone = SozuTone.of(context);
    final titulo = _instrucciones ? 'Datos para pago' : 'Pagar';
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: cuerpo(tone),
    );
  }

  // Instrucciones de pago STP (modo portal): réplica de ClientePropiedadPago
  // del portal admin — banner de confirmación automática, monto/vencimiento,
  // CLABE, banco receptor STP, beneficiario, concepto, CTA "Copiar CLABE",
  // nota "Conexión segura" y footer "Procesado por STP".
  Widget _portalInstrucciones(SozuTone tone, DatosPago d) {
    final sinClabe = (d.clabe ?? '').isEmpty;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Banner: el pago se refleja al confirmarlo el banco.
        AppCard(
          borderColor: tone.primaryDark.withValues(alpha: 0.25),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 20, color: tone.primaryDark),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Realiza la transferencia desde tu banca en línea utilizando '
                  'esta CLABE única vinculada a tu propiedad. El pago se '
                  'reflejará automáticamente una vez confirmado por el banco.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: tone.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Monto + vencimiento.
        AppCard(
          child: Column(
            children: [
              Text(
                d.concepto.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: tone.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatMXN(d.saldoPendiente),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: tone.textPrimary,
                  ),
                ),
              ),
              if (d.fechaPago != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Vencimiento: ${formatDate(d.fechaPago)}',
                  style: TextStyle(fontSize: 13, color: tone.textSecondary),
                ),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () =>
                    _copiar(d.saldoPendiente.toStringAsFixed(2), 'Monto'),
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: const Text('Copiar monto'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (sinClabe)
          AppCard(
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: tone.pending),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'La CLABE de pago aún no está configurada. '
                    'Contacta a tu asesor.',
                    style: TextStyle(fontSize: 13, color: tone.textSecondary),
                  ),
                ),
              ],
            ),
          )
        else ...[
          _portalDataRow(
            tone,
            'CLABE interbancaria',
            d.clabe!,
            mono: true,
            onCopy: () => _copiar(d.clabe!, 'CLABE'),
          ),
          const SizedBox(height: 10),
          _portalDataRow(
            tone,
            'Banco receptor',
            'STP (Sistema de Transferencias y Pagos)',
          ),
          if ((d.beneficiario ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            _portalDataRow(tone, 'Beneficiario', d.beneficiario!),
          ],
          const SizedBox(height: 10),
          _portalDataRow(
            tone,
            'Concepto / Referencia',
            d.concepto,
            onCopy: () => _copiar(d.concepto, 'Concepto'),
          ),
          const SizedBox(height: 16),
          // CTA full-width: copiar la CLABE.
          FilledButton.icon(
            onPressed: () => _copiar(d.clabe!, 'CLABE'),
            icon: const Icon(Icons.copy_outlined, size: 18),
            label: const Text('Copiar CLABE'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
        const SizedBox(height: 16),
        // Nota de seguridad.
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 20, color: tone.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conexión segura',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: tone.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Esta CLABE está vinculada exclusivamente a tu propiedad.',
                      style: TextStyle(fontSize: 12, color: tone.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'PROCESADO POR STP',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: tone.textMuted,
          ),
        ),
      ],
    );
  }

  // Fila de dato (portal): label uppercase con tracking + valor y copiar
  // opcional, en card blanca (espejo del DataRow de ClientePropiedadPago).
  Widget _portalDataRow(
    SozuTone tone,
    String label,
    String value, {
    VoidCallback? onCopy,
    bool mono = false,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: tone.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: mono ? 'monospace' : null,
                    color: tone.textPrimary,
                  ),
                ),
              ),
              if (onCopy != null)
                IconButton(
                  tooltip: 'Copiar',
                  iconSize: 16,
                  icon: Icon(Icons.copy_outlined, color: tone.textMuted),
                  onPressed: onCopy,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Paso 1: saldo + método de pago (solo recursos propios).
  Widget _paso1(SozuTone tone, DatosPago d) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${d.concepto} · U${d.propiedad}',
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
              Text(
                '${formatMXN(d.saldoPendiente)} MXN',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: tone.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '¿Cómo realizarás tu pago?',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: tone.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        AppCard(
          borderColor: tone.primaryDark,
          child: Row(
            children: [
              Icon(
                Icons.radio_button_checked,
                size: 20,
                color: tone.primaryDark,
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.account_balance_outlined,
                size: 20,
                color: tone.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recursos propios',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tone.textPrimary,
                      ),
                    ),
                    Text(
                      'Transferencia interbancaria por STP',
                      style: TextStyle(fontSize: 12, color: tone.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => setState(() => _instrucciones = true),
          icon: const Icon(Icons.chevron_right),
          label: const Text('Ver instrucciones de pago'),
        ),
      ],
    );
  }

  // Paso 2: datos para pago (CLABE, beneficiario, concepto).
  Widget _paso2(SozuTone tone, DatosPago d) {
    final sinClabe = (d.clabe ?? '').isEmpty;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'U${d.propiedad}',
          style: TextStyle(fontSize: 13, color: tone.textMuted),
        ),
        const SizedBox(height: 12),
        // Monto + vencimiento.
        AppCard(
          child: Column(
            children: [
              Text(
                d.concepto.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: tone.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatMXN(d.saldoPendiente),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: tone.textPrimary,
                  ),
                ),
              ),
              if (d.fechaPago != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Vencimiento: ${formatDate(d.fechaPago)}',
                  style: TextStyle(fontSize: 13, color: tone.textSecondary),
                ),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () =>
                    _copiar(d.saldoPendiente.toStringAsFixed(2), 'Monto'),
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: const Text('Copiar monto'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (sinClabe)
          AppCard(
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: tone.pending),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'La CLABE de pago aún no está configurada. '
                    'Contacta a tu asesor.',
                    style: TextStyle(fontSize: 13, color: tone.textSecondary),
                  ),
                ),
              ],
            ),
          )
        else
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INSTRUCCIONES DE TRANSFERENCIA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: tone.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                _filaCopiable(tone, 'CLABE', d.clabe!, mono: true),
                Divider(color: tone.border, height: 20),
                if ((d.beneficiario ?? '').isNotEmpty) ...[
                  _filaCopiable(tone, 'Beneficiario', d.beneficiario!),
                  Divider(color: tone.border, height: 20),
                ],
                _filaCopiable(tone, 'Concepto', d.concepto),
              ],
            ),
          ),
        const SizedBox(height: 12),
        AppCard(
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: tone.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Realiza la transferencia desde tu banca en línea. '
                  'El pago se reflejará en 24–48 horas hábiles.',
                  style: TextStyle(fontSize: 13, color: tone.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => setState(() => _instrucciones = false),
          child: const Text('Regresar'),
        ),
      ],
    );
  }

  Widget _filaCopiable(
    SozuTone tone,
    String label,
    String value, {
    bool mono = false,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: tone.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: mono ? 'monospace' : null,
              color: tone.textPrimary,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Copiar',
          iconSize: 16,
          icon: Icon(Icons.copy_outlined, color: tone.textMuted),
          onPressed: () => _copiar(value, label),
        ),
      ],
    );
  }
}
