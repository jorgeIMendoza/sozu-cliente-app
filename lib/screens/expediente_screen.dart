import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/open_media.dart';
import '../core/portal_theme.dart';
import '../core/theme.dart';
import '../data/api_client.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../providers/impersonation_provider.dart';
import '../widgets/common.dart';
import '../widgets/expediente_card.dart' show expedienteEstatusStyle;
import '../widgets/portal_widgets.dart';

const _maxArchivoBytes = 10 * 1024 * 1024; // 10 MB (límite del backend)

/// Expediente de identidad: lista numerada de documentos con estatus, subida
/// de archivos (validados por el backend) y visor in-app del documento.
/// Espejo de la vista "Expediente" del Perfil del Portal del cliente.
class ExpedienteScreen extends ConsumerStatefulWidget {
  const ExpedienteScreen({super.key});

  @override
  ConsumerState<ExpedienteScreen> createState() => _ExpedienteScreenState();
}

class _ExpedienteScreenState extends ConsumerState<ExpedienteScreen> {
  /// key del slot cuya subida está en curso (spinner en la fila).
  String? _subiendo;

  Future<void> _subirArchivo(ExpedienteSlot slot) async {
    final messenger = ScaffoldMessenger.of(context);
    // file_picker >= 11: API estática (ya no existe FilePicker.platform).
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions:
          slot.soloPdf ? ['pdf'] : ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true, // necesario para web (no hay path)
    );
    final file = result?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return; // cancelado

    if (bytes.length > _maxArchivoBytes) {
      messenger.showSnackBar(const SnackBar(
        content: Text('El archivo supera el límite de 10 MB.'),
      ));
      return;
    }

    setState(() => _subiendo = slot.key);
    try {
      final imp = ref.read(impersonationProvider).idPersona;
      final res = await subirDocumentoExpediente(
        tipoId: slot.tipoId,
        nombreArchivo: file.name,
        archivoBase64: base64Encode(bytes),
        contentType: _contentType(file.name),
        impersonate: imp,
      );
      ref.invalidate(clienteExpedienteProvider);
      ref.invalidate(clienteDocumentosProvider);
      if (!mounted) return;
      // CSF: si el backend detectó datos fiscales, se abre el diálogo de
      // confirmación (espejo de ConfirmDataModal del portal) para revisarlos y
      // guardarlos en el perfil. El documento ya quedó almacenado y aprobado.
      if (res.datosFiscales != null) {
        await _confirmarDatosFiscales(res.datosFiscales!);
      } else {
        messenger.showSnackBar(SnackBar(
          content: Text(res.estatus == 'aprobado'
              ? 'Documento verificado y aprobado'
              : 'Documento enviado para revisión'),
        ));
      }
    } on DocumentoInvalidoError catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(e.reason),
        duration: const Duration(seconds: 7),
      ));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('No se pudo subir el documento. Intenta de nuevo.'),
      ));
    } finally {
      if (mounted) setState(() => _subiendo = null);
    }
  }

  /// Diálogo de confirmación de datos fiscales de la CSF (sheet en angosto,
  /// diálogo centrado en ancho), espejo de ConfirmDataModal del portal.
  Future<void> _confirmarDatosFiscales(DatosFiscalesCSF datos) {
    final ancho = MediaQuery.sizeOf(context).width >= 768;
    final child = _ConfirmarDatosFiscales(datos: datos);
    if (ancho) {
      return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(child: child),
          ),
        ),
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _CsfSheetWrapper(child: child),
    );
  }

  String _contentType(String nombre) {
    final ext = nombre.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  void _volver() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/perfil');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    // Modo portal (web ≥1024): mismo contenido centrado tipo card grande del
    // portal, pero con la card y tipografía del portal y fondo del shell.
    final portal = isPortalMode(context);
    final exp = ref.watch(clienteExpedienteProvider);

    final cardBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Expediente',
            style: portal
                ? portalText(size: 18, weight: FontWeight.w700)
                : TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: tone.textPrimary)),
        const SizedBox(height: 4),
        Text('Sube cada documento; validamos los datos por ti.',
            style: portal
                ? portalText(
                    size: 13.5, color: PortalColors.mutedForeground)
                : TextStyle(fontSize: 13.5, color: tone.textSecondary)),
        const SizedBox(height: 18),
        _slots(exp),
      ],
    );

    return Scaffold(
      backgroundColor: portal ? Colors.transparent : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: portal
                  ? const EdgeInsets.only(top: 24, bottom: 32)
                  : const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // ── "← Volver al Perfil" ──
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _volver,
                    style: TextButton.styleFrom(
                      foregroundColor: portal
                          ? PortalColors.mutedForeground
                          : tone.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    icon: const Icon(Icons.arrow_back, size: 15),
                    label: const Text('Volver al Perfil'),
                  ),
                ),
                const SizedBox(height: 8),
                if (portal)
                  PortalCard(
                    padding: const EdgeInsets.all(22),
                    child: cardBody,
                  )
                else
                  AppCard(
                    padding: const EdgeInsets.all(22),
                    child: cardBody,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Lista numerada de documentos (compartida entre móvil y portal).
  Widget _slots(AsyncValue<ClienteExpediente> exp) {
    return exp.when(
                        loading: () => const Column(
                          children: [
                            Skeleton(height: 56),
                            SizedBox(height: 10),
                            Skeleton(height: 56),
                            SizedBox(height: 10),
                            Skeleton(height: 56),
                          ],
                        ),
                        error: (_, __) => ErrorCard(
                          title: 'No pudimos cargar tu expediente',
                          onRetry: () =>
                              ref.invalidate(clienteExpedienteProvider),
                        ),
                        data: (data) {
                          if (data.slots.isEmpty) {
                            return const EmptyCard(
                              icon: Icons.folder_open_outlined,
                              text:
                                  'Aún no hay documentos configurados en tu expediente.',
                            );
                          }
                          return Column(
                            children: [
                              for (var i = 0; i < data.slots.length; i++) ...[
                                _SlotRow(
                                  index: i + 1,
                                  slot: data.slots[i],
                                  subiendo: _subiendo == data.slots[i].key,
                                  bloqueado: _subiendo != null,
                                  onSubir: () => _subirArchivo(data.slots[i]),
                                ),
                                if (i < data.slots.length - 1)
                                  const SizedBox(height: 10),
                              ],
                            ],
                          );
                        },
                      );
  }
}

class _SlotRow extends StatelessWidget {
  final int index;
  final ExpedienteSlot slot;
  final bool subiendo;

  /// true si hay otra subida en curso (deshabilita este botón de subir).
  final bool bloqueado;
  final VoidCallback onSubir;

  const _SlotRow({
    required this.index,
    required this.slot,
    required this.subiendo,
    required this.bloqueado,
    required this.onSubir,
  });

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final st = expedienteEstatusStyle(slot.estatus, tone);
    final esOpcionalSinDoc = slot.estatus == 'opcional' && slot.fecha == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        border: Border.all(color: tone.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          // Número en círculo.
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: tone.surfaceAlt,
              border: Border.all(color: tone.border),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('$index',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: tone.textMuted)),
          ),
          const SizedBox(width: 10),
          // Punto de estado.
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: st.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slot.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tone.textPrimary)),
                if (slot.fecha != null) ...[
                  const SizedBox(height: 2),
                  Text('Subido el ${formatDate(slot.fecha)}',
                      style:
                          TextStyle(fontSize: 11.5, color: tone.textMuted)),
                ] else if (esOpcionalSinDoc) ...[
                  const SizedBox(height: 2),
                  Text('Opcional',
                      style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: tone.textMuted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Chip de estatus.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: st.bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(st.label,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: st.fg)),
          ),
          // Botón de subir (solo cuando el portal lo permite).
          if (slot.puedeSubir) ...[
            const SizedBox(width: 6),
            _IconBtn(
              tooltip: 'Subir archivo',
              onTap: (subiendo || bloqueado) ? null : onSubir,
              child: subiendo
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.upload_outlined,
                      size: 16, color: tone.textSecondary),
            ),
          ],
          // Botón de ver el documento subido (visor in-app).
          const SizedBox(width: 6),
          _IconBtn(
            tooltip: 'Ver documento',
            onTap: slot.urlFirmada == null
                ? null
                : () =>
                    openMedia(context, slot.urlFirmada, titulo: slot.nombre),
            child: Icon(Icons.visibility_outlined,
                size: 16,
                color: slot.urlFirmada == null
                    ? tone.textMuted.withValues(alpha: 0.4)
                    : tone.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onTap;
  final Widget child;

  const _IconBtn({
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: tone.surface,
            border: Border.all(color: tone.border),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

// ─── Confirmación de datos fiscales de la CSF (ConfirmDataModal del portal) ───

/// Envoltorio del bottom sheet (esquinas redondeadas + scroll).
class _CsfSheetWrapper extends StatelessWidget {
  final Widget child;
  const _CsfSheetWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return SafeArea(
      child: Container(
        margin: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: BoxDecoration(
          color: tone.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

class _ConfirmarDatosFiscales extends ConsumerStatefulWidget {
  final DatosFiscalesCSF datos;
  const _ConfirmarDatosFiscales({required this.datos});

  @override
  ConsumerState<_ConfirmarDatosFiscales> createState() =>
      _ConfirmarDatosFiscalesState();
}

class _ConfirmarDatosFiscalesState
    extends ConsumerState<_ConfirmarDatosFiscales> {
  late final TextEditingController _rfc;
  late final TextEditingController _curp;
  late final TextEditingController _nombre;
  late final TextEditingController _regimen;
  late final TextEditingController _cp;
  late final TextEditingController _calle;
  late final TextEditingController _numExt;
  late final TextEditingController _numInt;
  late final TextEditingController _colonia;

  PerfilCatalogos? _catalogos;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Prefill con lo detectado; si un campo vino vacío, se conserva lo que ya
    // existe en el perfil para no borrarlo.
    final p = ref.read(clientePerfilProvider).valueOrNull;
    final d = widget.datos;
    _rfc = TextEditingController(text: d.rfc ?? p?.rfc ?? '');
    _curp = TextEditingController(text: d.curp ?? p?.curp ?? '');
    _nombre = TextEditingController(text: d.nombre ?? p?.nombreLegal ?? '');
    _regimen =
        TextEditingController(text: d.regimen ?? p?.regimenDisplay ?? '');
    _cp = TextEditingController(text: d.codigoPostal ?? p?.cp ?? '');
    _calle = TextEditingController(text: d.calle ?? p?.calle ?? '');
    _numExt = TextEditingController(text: d.numExt ?? p?.numExt ?? '');
    _numInt = TextEditingController(text: d.numInt ?? p?.numInt ?? '');
    _colonia = TextEditingController(text: d.colonia ?? p?.colonia ?? '');
    _loadCatalogos();
  }

  Future<void> _loadCatalogos() async {
    try {
      final c = await fetchPerfilCatalogos(
        impersonate: ref.read(impersonationProvider).idPersona,
      );
      if (mounted) setState(() => _catalogos = c);
    } catch (_) {
      // Sin catálogo, el régimen se guarda tal cual (texto/código detectado).
    }
  }

  @override
  void dispose() {
    _rfc.dispose();
    _curp.dispose();
    _nombre.dispose();
    _regimen.dispose();
    _cp.dispose();
    _calle.dispose();
    _numExt.dispose();
    _numInt.dispose();
    _colonia.dispose();
    super.dispose();
  }

  /// Resuelve el texto del régimen al id del catálogo (código de 3 dígitos o
  /// coincidencia difusa del nombre), igual que handleConfirmDoc del portal.
  String? _resolverRegimen(String texto) {
    final cat = _catalogos?.regimen ?? const [];
    final t = texto.trim();
    if (t.isEmpty) return null;
    final code = RegExp(r'\b(\d{3})\b').firstMatch(t)?.group(1);
    if (code != null && cat.any((r) => r.id == code)) return code;
    final nText = t.toLowerCase();
    for (final r in cat) {
      final n = r.nombre.toLowerCase();
      if (n.length > 3 && (nText.contains(n) || n.contains(nText))) {
        return r.id;
      }
    }
    return null;
  }

  Future<void> _guardar() async {
    setState(() => _busy = true);
    try {
      final p = ref.read(clientePerfilProvider).valueOrNull;
      final imp = ref.read(impersonationProvider).idPersona;
      final nombre = _nombre.text.trim();
      final rfc = _rfc.text.trim();
      final curp = _curp.text.trim();
      await updatePerfilPersonal(
        nombreLegal: nombre.isNotEmpty ? nombre : (p?.nombreLegal ?? ''),
        rfc: rfc.isEmpty ? p?.rfc : rfc,
        curp: curp.isEmpty ? p?.curp : curp,
        clavePaisTelefono: p?.clavePaisTelefono,
        telefono: p?.telefono,
        impersonate: imp,
      );
      await updatePerfilFiscal(
        regimen: _resolverRegimen(_regimen.text) ?? p?.regimen,
        usoCfdi: p?.usoCfdi,
        codigoPostal: _cp.text.trim(),
        calle: _calle.text.trim(),
        numExt: _numExt.text.trim(),
        numInt: _numInt.text.trim(),
        colonia: _colonia.text.trim(),
        impersonate: imp,
      );
      ref.invalidate(clientePerfilProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(
        content: Text('Documento verificado y datos guardados en tu perfil'),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se pudieron guardar los datos. Intenta de nuevo.'),
      ));
    }
  }

  void _cancelar() {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Documento verificado y aprobado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Confirma tus datos fiscales',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: tone.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  'Extrajimos estos datos de tu documento. Verifica que sean '
                  'correctos; se guardarán en tu perfil.',
                  style: TextStyle(fontSize: 13, color: tone.textSecondary),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: tone.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _campo('RFC', _rfc, mono: true),
                _campo('CURP', _curp, mono: true),
                _campo('Nombre / Razón social', _nombre),
                _campo('Régimen fiscal', _regimen),
                _campo('Código postal', _cp,
                    keyboard: TextInputType.number, maxLength: 5),
                _campo('Calle', _calle),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _campo('Núm. exterior', _numExt)),
                    const SizedBox(width: 12),
                    Expanded(child: _campo('Núm. interior', _numInt)),
                  ],
                ),
                _campo('Colonia', _colonia),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _cancelar,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _guardar,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Sí, es correcta'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _campo(
    String label,
    TextEditingController c, {
    bool mono = false,
    TextInputType? keyboard,
    int? maxLength,
  }) {
    final tone = SozuTone.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: tone.textPrimary)),
          ),
          TextField(
            controller: c,
            keyboardType: keyboard,
            maxLength: maxLength,
            style: mono ? const TextStyle(fontFamily: 'monospace') : null,
            decoration: const InputDecoration(counterText: ''),
          ),
        ],
      ),
    );
  }
}
