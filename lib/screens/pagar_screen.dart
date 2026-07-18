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
    final tone = SozuTone.of(context);
    final portal = isPortalMode(context);
    final titulo = _instrucciones ? 'Datos para pago' : 'Pagar';
    final cuerpo = FutureBuilder<DatosPago>(
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
        return _instrucciones ? _paso2(tone, d) : _paso1(tone, d);
      },
    );
    // Modo portal: sin AppBar propio (el shell pinta "Pagar" en la topbar);
    // el flujo se presenta centrado a máx. 640px, como los sheets/diálogos
    // de pago del portal en escritorio. Contenido idéntico al móvil.
    if (portal) {
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
                      Text(
                        titulo,
                        style: portalText(size: 15, weight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Expanded(child: cuerpo),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: cuerpo,
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
