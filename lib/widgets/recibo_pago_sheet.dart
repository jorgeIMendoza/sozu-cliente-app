import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../core/open_media.dart';
import '../core/theme.dart';
import '../data/api_client.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
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
  final String? producto; // nombre del producto (productName del portal)

  // — Campos ricos del recibo (espejo del PaymentReceiptModal del portal).
  //   Los provee cliente-pagos en `historial`; degradan a null en las tablas
  //   cuyo modelo no los expone (aplicaciones / pagos de estado de cuenta). —
  final String? rfc;
  final String? clabe; // CLABE enmascarada (solo últimos 4)
  final String? referenciaStp; // referencia STP (SOZU-<cuenta>)
  final double? saldo; // saldo pendiente de la propiedad
  final double? totalPagado; // total pagado acumulado
  final double? valorActivo; // valor total del activo

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
    this.producto,
    this.rfc,
    this.clabe,
    this.referenciaStp,
    this.saldo,
    this.totalPagado,
    this.valorActivo,
  });

  /// Desde el historial de pagos (cliente-pagos): trae los campos ricos del
  /// recibo (RFC, CLABE, referencia bancaria, resumen de la propiedad).
  ReciboPagoData.fromHistorial(HistorialPago p, {String? claveRastreo})
    : id = p.id,
      fechaPago = p.fechaPago,
      concepto = p.concepto,
      propiedad = p.propiedad,
      metodo = p.metodo,
      monto = p.monto,
      urlRecibo = p.urlRecibo,
      urlCep = p.urlCep,
      claveRastreo = claveRastreo ?? p.claveRastreo,
      producto = p.producto,
      rfc = p.rfc,
      clabe = p.clabe,
      referenciaStp = p.referenciaStp,
      saldo = p.saldo,
      totalPagado = p.totalPagado,
      valorActivo = p.valorActivo;

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
       claveRastreo = p.referencia,
       producto = null,
       rfc = null,
       clabe = null,
       referenciaStp = null,
       saldo = null,
       totalPagado = null,
       valorActivo = null;

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
       claveRastreo = a.claveRastreo,
       producto = null,
       rfc = null,
       clabe = null,
       referenciaStp = null,
       saldo = null,
       totalPagado = null,
       valorActivo = null;
}

/// Sheet de recibo in-app (espejo del PaymentReceiptModal del portal): folio
/// copiable, cliente/RFC, propiedad, concepto, método, CLABE vinculada y
/// referencia bancaria, monto grande, resumen actualizado de la propiedad
/// (valor del activo, total pagado, saldo y progreso) y acciones "Ver PDF"
/// (genera el recibo bajo demanda si no existe) y "CEP".
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

  /// Comparte un resumen del recibo (folio, concepto, monto, fecha, propiedad).
  /// En web `share_plus` cae al Web Share API; si no está disponible o falla
  /// mostramos un SnackBar en vez de romper. Si el recibo ya tiene URL firmada
  /// la incluimos en el texto para que el receptor pueda abrir el PDF.
  Future<void> _compartir() async {
    final p = widget.data;

    // Etiqueta de propiedad "Proyecto · U-###" si el proyecto está en caché.
    final props = ref.read(clientePropiedadesProvider).valueOrNull;
    String? proyecto;
    for (final c in [...?props?.enAdquisicion, ...?props?.patrimonioActivo]) {
      if (c.nombre == p.propiedad) {
        proyecto = c.proyecto;
        break;
      }
    }
    final propLabel = proyecto != null
        ? '$proyecto · U-${p.propiedad}'
        : 'U${p.propiedad}';

    final texto = <String>[
      'Recibo de pago SOZU',
      'Folio: $_folio',
      'Concepto: ${p.concepto}',
      if ((p.producto ?? '').isNotEmpty) 'Producto: ${p.producto}',
      'Propiedad: $propLabel',
      'Monto: ${formatMXN(p.monto)} MXN',
      'Fecha: ${_fechaConfirmacion(p.fechaPago)}',
      if ((p.urlRecibo ?? '').isNotEmpty) 'Recibo: ${p.urlRecibo}',
    ].join('\n');

    try {
      await Share.share(texto, subject: 'Recibo SOZU $_folio');
    } catch (_) {
      if (mounted) _snack('No se pudo compartir en este dispositivo.');
    }
  }

  /// Fecha de confirmación: si el dato trae hora la mostramos como
  /// "DD/MM/YYYY HH:mm"; si no, solo "DD/MM/YYYY".
  String _fechaConfirmacion(String? input) {
    if (input == null || input.isEmpty) return '—';
    final d = DateTime.tryParse(input);
    if (d == null) return formatDate(input);
    final tieneHora =
        input.contains('T') && (d.hour != 0 || d.minute != 0 || d.second != 0);
    if (!tieneHora) return formatDate(input);
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${formatDate(input)} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final p = widget.data;

    // Datos ricos del recibo (espejo del PaymentReceiptModal del portal). El
    // nombre del cliente y el proyecto se leen de la caché con valueOrNull: si
    // aún no están, cada fila degrada (se oculta) sin bloquear el recibo.
    final perfil = ref.watch(clientePerfilProvider).valueOrNull;
    final cliente = (perfil?.nombreLegal.trim().isNotEmpty ?? false)
        ? perfil!.nombreLegal
        : null;
    final rfc = (p.rfc?.trim().isNotEmpty ?? false)
        ? p.rfc
        : ((perfil?.rfc?.trim().isNotEmpty ?? false) ? perfil!.rfc : null);
    final props = ref.watch(clientePropiedadesProvider).valueOrNull;
    String? proyecto;
    for (final c in [...?props?.enAdquisicion, ...?props?.patrimonioActivo]) {
      if (c.nombre == p.propiedad) {
        proyecto = c.proyecto;
        break;
      }
    }
    final propiedadLabel = proyecto != null
        ? '$proyecto · U-${p.propiedad}'
        : 'U${p.propiedad}';

    // Resumen actualizado de la propiedad (solo cuando el backend lo expone).
    final tieneResumen =
        p.valorActivo != null || p.totalPagado != null || p.saldo != null;
    final valorActivo = p.valorActivo ?? 0;
    final progreso = valorActivo > 0
        ? ((p.totalPagado ?? 0) / valorActivo * 100).clamp(0, 100).toDouble()
        : 0.0;

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
                        'Fecha de emisión',
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
              Text(
                'Información del pago',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: tone.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: tone.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    if (cliente != null) ...[
                      _fila(tone, 'Cliente', cliente),
                      Divider(color: tone.border, height: 1),
                    ],
                    if (rfc != null) ...[
                      _fila(tone, 'RFC', rfc, mono: true),
                      Divider(color: tone.border, height: 1),
                    ],
                    _fila(tone, 'Propiedad', propiedadLabel),
                    if ((p.producto ?? '').isNotEmpty) ...[
                      Divider(color: tone.border, height: 1),
                      _fila(tone, 'Producto', p.producto!),
                    ],
                    Divider(color: tone.border, height: 1),
                    _fila(tone, 'Concepto', p.concepto),
                    Divider(color: tone.border, height: 1),
                    _fila(tone, 'Método de pago', p.metodo),
                    if ((p.clabe ?? '').isNotEmpty) ...[
                      Divider(color: tone.border, height: 1),
                      _fila(tone, 'CLABE vinculada', p.clabe!, mono: true),
                    ],
                    if ((p.claveRastreo ?? '').isNotEmpty) ...[
                      Divider(color: tone.border, height: 1),
                      _fila(
                        tone,
                        'Clave de rastreo',
                        p.claveRastreo!,
                        mono: true,
                        onCopiar: () => _copiar(
                          p.claveRastreo!,
                          'Clave de rastreo copiada',
                        ),
                      ),
                    ],
                    if ((p.referenciaStp ?? '').isNotEmpty) ...[
                      Divider(color: tone.border, height: 1),
                      _fila(
                        tone,
                        'Referencia STP',
                        p.referenciaStp!,
                        mono: true,
                        onCopiar: () => _copiar(
                          p.referenciaStp!,
                          'Referencia STP copiada',
                        ),
                      ),
                    ],
                    Divider(color: tone.border, height: 1),
                    _fila(
                      tone,
                      'Fecha de confirmación',
                      _fechaConfirmacion(p.fechaPago),
                    ),
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
              if (tieneResumen) ...[
                const SizedBox(height: 16),
                Text(
                  'Resumen actualizado de la propiedad',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: tone.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: tone.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _resumenRow(
                        tone,
                        'Valor total del activo',
                        formatMXN(p.valorActivo ?? 0),
                      ),
                      const SizedBox(height: 12),
                      _resumenRow(
                        tone,
                        'Total pagado acumulado',
                        formatMXN(p.totalPagado ?? 0),
                        color: tone.primaryDark,
                      ),
                      const SizedBox(height: 12),
                      _resumenRow(
                        tone,
                        'Saldo pendiente',
                        formatMXN(p.saldo ?? 0),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Progreso de pago',
                              style: TextStyle(
                                fontSize: 11,
                                color: tone.textSecondary,
                              ),
                            ),
                          ),
                          Text(
                            '${progreso.round()}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: tone.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progreso / 100,
                          minHeight: 6,
                          backgroundColor: tone.surfaceAlt,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            tone.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tone.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 14,
                      color: tone.primaryDark,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Este recibo fue generado automáticamente tras la '
                        'confirmación del pago por STP.',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.4,
                          color: tone.textSecondary,
                        ),
                      ),
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
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: _compartir,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(52, 52),
                      fixedSize: const Size(52, 52),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(color: tone.border),
                      foregroundColor: tone.textPrimary,
                    ),
                    child: const Icon(Icons.ios_share, size: 18),
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
    bool mono = false,
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
                fontFeatures: mono
                    ? const [FontFeature.tabularFigures()]
                    : null,
                letterSpacing: mono ? 0.3 : null,
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

  /// Fila del resumen de la propiedad: etiqueta a la izquierda, importe a la
  /// derecha (con color opcional para "Total pagado acumulado").
  Widget _resumenRow(
    SozuTone tone,
    String label,
    String value, {
    Color? color,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: tone.textSecondary),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color ?? tone.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
