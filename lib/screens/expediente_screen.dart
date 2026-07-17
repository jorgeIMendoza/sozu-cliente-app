import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/open_media.dart';
import '../core/theme.dart';
import '../data/api_client.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../providers/impersonation_provider.dart';
import '../widgets/common.dart';
import '../widgets/expediente_card.dart' show expedienteEstatusStyle;

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
      final estatus = await subirDocumentoExpediente(
        tipoId: slot.tipoId,
        nombreArchivo: file.name,
        archivoBase64: base64Encode(bytes),
        contentType: _contentType(file.name),
        impersonate: imp,
      );
      ref.invalidate(clienteExpedienteProvider);
      ref.invalidate(clienteDocumentosProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(estatus == 'aprobado'
            ? 'Documento verificado y aprobado'
            : 'Documento enviado para revisión'),
      ));
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
    final exp = ref.watch(clienteExpedienteProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // ── "← Volver al Perfil" ──
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _volver,
                    style: TextButton.styleFrom(
                      foregroundColor: tone.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    icon: const Icon(Icons.arrow_back, size: 15),
                    label: const Text('Volver al Perfil'),
                  ),
                ),
                const SizedBox(height: 8),
                AppCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Expediente',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: tone.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Sube cada documento; validamos los datos por ti.',
                          style: TextStyle(
                              fontSize: 13.5, color: tone.textSecondary)),
                      const SizedBox(height: 18),
                      exp.when(
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
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
        borderRadius: BorderRadius.circular(10),
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: tone.surface,
            border: Border.all(color: tone.border),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
