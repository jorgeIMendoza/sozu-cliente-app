import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/open_media.dart';
import '../core/theme.dart';
import '../data/api_client.dart';
import '../data/models.dart';
import '../providers/impersonation_provider.dart';
import 'common.dart';

/// Datos que el recibo in-app necesita, desacoplados del modelo de origen para
/// poder alimentarlo desde HistorialPago, PagoRealizado o AplicacionPago
/// (cada tabla del portal trae uno u otro). Los campos que un modelo no expone
/// (concepto/propiedad) los aporta la pantalla; el resto degrada a '—'.
class ReciboPagoData {
  final int id;
  final String? fechaPago;
  final String concepto;
  final String propiedad;
  final String metodo;
  final double monto;
  final String? urlRecibo;
  final String? urlCep;
  final String? claveRastreo;

  const ReciboPagoData({
    required this.id,
    required this.fechaPago,
    required this.concepto,
    required this.propiedad,
    required this.metodo,
    required this.monto,
    this.urlRecibo,
    this.urlCep,
    this.claveRastreo,
  });

  /// Desde el historial de pagos (cliente-pagos). No trae clave de rastreo.
  ReciboPagoData.fromHistorial(HistorialPago p, {this.claveRastreo})
    : id = p.id,
      fechaPago = p.fechaPago,
      concepto = p.concepto,
      propiedad = p.propiedad,
      metodo = p.metodo,
      monto = p.monto,
      urlRecibo = p.urlRecibo,
      urlCep = p.urlCep;

  /// Desde un pago del estado de cuenta (sin plan de pagos). El concepto y la
  /// propiedad los aporta la pantalla; degradan a lo disponible.
  ReciboPagoData.fromPagoRealizado(
    PagoRealizado p, {
    String? concepto,
    required this.propiedad,
  }) : id = p.id,
       fechaPago = p.fecha,
       concepto = concepto ?? p.metodo,
       metodo = p.metodo,
       monto = p.monto,
       urlRecibo = p.urlRecibo,
       urlCep = p.urlCep,
       claveRastreo = p.referencia;

  /// Desde una aplicación de pago (abono a un acuerdo). El concepto del acuerdo
  /// y la propiedad los aporta la pantalla.
  ReciboPagoData.fromAplicacion(
    AplicacionPago a, {
    required this.concepto,
    required this.propiedad,
  }) : id = a.idPago,
       fechaPago = a.fecha,
       metodo = a.metodo ?? 'Pago',
       monto = a.monto,
       urlRecibo = a.urlRecibo,
       urlCep = a.urlCep,
       claveRastreo = a.claveRastreo;
}

/// Sheet de recibo in-app (espejo simplificado del PaymentReceiptModal del
/// portal admin): folio copiable, datos del pago, monto grande y acciones
/// "Ver PDF" (genera el recibo bajo demanda si no existe) y "CEP".
Future<void> showReciboPagoSheet(
  BuildContext context, {
  required HistorialPago pago,
  String? claveRastreo,
}) {
  return showReciboPagoDataSheet(
    context,
    data: ReciboPagoData.fromHistorial(pago, claveRastreo: claveRastreo),
  );
}

/// Igual que [showReciboPagoSheet] pero desde un [ReciboPagoData] ya armado
/// (para tablas cuyo modelo no es HistorialPago).
Future<void> showReciboPagoDataSheet(
  BuildContext context, {
  required ReciboPagoData data,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ReciboPagoSheet(data: data),
  );
}

class ReciboPagoSheet extends ConsumerStatefulWidget {
  final ReciboPagoData data;

  const ReciboPagoSheet({super.key, required this.data});

  @override
  ConsumerState<ReciboPagoSheet> createState() => _ReciboPagoSheetState();
}

class _ReciboPagoSheetState extends ConsumerState<ReciboPagoSheet> {
  bool _generando = false;

  String get _folio => 'SOZU-${widget.data.id}';

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _copiar(String texto, String mensaje) async {
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    _snack(mensaje);
  }

  /// Abre el PDF del recibo; si aún no existe, pide al backend generarlo.
  Future<void> _verPdf() async {
    final p = widget.data;
    if ((p.urlRecibo ?? '').isNotEmpty) {
      await openMedia(context, p.urlRecibo, titulo: 'Recibo');
      return;
    }
    if (_generando) return;
    setState(() => _generando = true);
    try {
      final imp = ref.read(impersonationProvider).idPersona;
      final url = await fetchReciboPagoUrl(p.id, impersonate: imp);
      if (!mounted) return;
      if (url == null) {
        _snack('No pudimos generar el recibo. Intenta de nuevo.');
      } else {
        await openMedia(context, url, titulo: 'Recibo');
      }
    } catch (_) {
      if (mounted) _snack('No pudimos generar el recibo. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final p = widget.data;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tone.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 22,
                    color: SozuColors.emerald600,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recibo de pago',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: tone.textPrimary,
                          ),
                        ),
                        Text(
                          'Comprobante electrónico',
                          style: TextStyle(
                            fontSize: 12,
                            color: tone.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const StatusBadge(label: 'Aplicado', tone: BadgeTone.positive),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: tone.border, height: 1),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Folio',
                          style: TextStyle(
                            fontSize: 11,
                            color: tone.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                _folio,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                  color: tone.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _copiar(_folio, 'Folio copiado'),
                              child: Icon(
                                Icons.copy_outlined,
                                size: 14,
                                color: SozuColors.emerald600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Fecha de pago',
                        style: TextStyle(fontSize: 11, color: tone.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatDate(p.fechaPago),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tone.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: tone.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _fila(tone, 'Concepto', p.concepto),
                    Divider(color: tone.border, height: 1),
                    _fila(tone, 'Propiedad', 'U${p.propiedad}'),
                    Divider(color: tone.border, height: 1),
                    _fila(tone, 'Método de pago', p.metodo),
                    if ((p.claveRastreo ?? '').isNotEmpty) ...[
                      Divider(color: tone.border, height: 1),
                      _fila(
                        tone,
                        'Clave de rastreo',
                        p.claveRastreo!,
                        onCopiar: () => _copiar(
                          p.claveRastreo!,
                          'Clave de rastreo copiada',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: tone.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Monto pagado',
                      style: TextStyle(fontSize: 11, color: tone.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatMXN(p.monto),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: tone.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'MXN',
                      style: TextStyle(fontSize: 11, color: tone.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _generando ? null : _verPdf,
                      icon: _generando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: Text(_generando ? 'Generando…' : 'Ver PDF'),
                    ),
                  ),
                  if ((p.urlCep ?? '').isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            openMedia(context, p.urlCep, titulo: 'CEP'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(color: tone.border),
                          foregroundColor: tone.textPrimary,
                        ),
                        icon: const Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                        ),
                        label: const Text('CEP'),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cerrar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tone.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fila(
    SozuTone tone,
    String label,
    String value, {
    VoidCallback? onCopiar,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: tone.textMuted)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tone.textPrimary,
              ),
            ),
          ),
          if (onCopiar != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onCopiar,
              child: Icon(
                Icons.copy_outlined,
                size: 14,
                color: SozuColors.emerald600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
