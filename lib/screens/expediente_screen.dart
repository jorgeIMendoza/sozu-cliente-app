import 'dart:convert';

import 'package:file_selector/file_selector.dart';
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
import '../widgets/perfil_sheets.dart' show showCuentaBancariaSheet;
import '../widgets/portal_widgets.dart';
import 'perfil_detalle_screens.dart' show PerfilCuentasScreen;

const _maxArchivoBytes = 10 * 1024 * 1024; // 10 MB (límite del backend)

// Grupos del expediente (títulos EXACTOS del portal, DOC_GROUPS de
// ClientePerfil.tsx): "Personales" y "Fiscal y financiero", en ese orden. Se
// renderizan en mayúsculas ("PERSONALES" / "FISCAL Y FINANCIERO").
const _grupoPersonal = 'personal';
const _grupoFinanciero = 'financiero';

/// Grupo de cada slot por su `key` (espejo del campo `cat` de SLOTS del portal).
const _slotGrupo = <String, String>{
  'ine_frente': _grupoPersonal,
  'ine_reverso': _grupoPersonal,
  'pasaporte': _grupoPersonal,
  'acta_nacimiento': _grupoPersonal,
  'curp': _grupoPersonal,
  'domicilio': _grupoPersonal,
  'matrimonio': _grupoPersonal,
  'csf': _grupoFinanciero,
};

/// Documentos que se capturan por cámara (icono cámara), igual que el portal:
/// INE frente/reverso y pasaporte. El resto se sube (icono subir).
bool _esCamara(String key) =>
    key == 'ine_frente' || key == 'ine_reverso' || key == 'pasaporte';

/// Normaliza para ordenar alfabéticamente (minúsculas + sin acentos), igual
/// que el `localeCompare('es')` del portal.
String _normLabel(String s) => s.toLowerCase().replaceAllMapped(
      RegExp('[áàäâéèëêíìïîóòöôúùüûñ]'),
      (m) => const {
        'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
        'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
        'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
        'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
        'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
        'ñ': 'n',
      }[m[0]]!,
    );

/// Expediente de identidad: documentos agrupados ("Personales" / "Fiscal y
/// financiero"), con estatus, subida/captura de archivos (validados por el
/// backend) y visor in-app. Espejo EXACTO de la vista "Documentos" del Perfil
/// del Portal del cliente (ClientePerfil.tsx).
class ExpedienteScreen extends ConsumerStatefulWidget {
  const ExpedienteScreen({super.key});

  @override
  ConsumerState<ExpedienteScreen> createState() => _ExpedienteScreenState();
}

class _ExpedienteScreenState extends ConsumerState<ExpedienteScreen> {
  /// key del slot cuya subida está en curso (spinner en la fila).
  String? _subiendo;

  Future<void> _subirArchivo(ExpedienteSlot slot, {bool camara = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    // Cámara → solo imágenes (captura de foto). Subir → PDF o imagen según el
    // tipo (los que exigen PDF original: solo PDF).
    final extensiones = camara
        ? ['jpg', 'jpeg', 'png', 'webp']
        : (slot.soloPdf ? ['pdf'] : ['pdf', 'jpg', 'jpeg', 'png', 'webp']);
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: 'Documentos', extensions: extensiones),
      ],
    );
    if (file == null) return; // cancelado
    final bytes = await file.readAsBytes();

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
      // El backend extrae los datos del documento (CSF, CURP o Acta) y los
      // devuelve para confirmarlos en el perfil (espejo de ConfirmDataModal
      // del portal). El documento ya quedó almacenado y aprobado.
      if (res.datosFiscales != null) {
        await _confirmarDatosFiscales(res.datosFiscales!);
      } else if (res.datosCurp != null) {
        await _confirmarIdentidad(curp: res.datosCurp);
      } else if (res.datosActa != null) {
        await _confirmarIdentidad(acta: res.datosActa);
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

  /// Diálogo de confirmación de datos de la CSF (sheet en angosto, diálogo
  /// centrado en ancho), espejo de ConfirmDataModal del portal.
  Future<void> _confirmarDatosFiscales(DatosFiscalesCSF datos) =>
      _mostrarConfirmacion(_ConfirmarDatosFiscales(datos: datos));

  /// Diálogo de confirmación de datos de la CURP o del Acta de nacimiento.
  Future<void> _confirmarIdentidad({DatosCURP? curp, DatosActa? acta}) =>
      _mostrarConfirmacion(_ConfirmarDatosIdentidad(curp: curp, acta: acta));

  /// Presenta el contenido como bottom sheet (angosto) o diálogo centrado
  /// (ancho), no descartable (el usuario debe confirmar o cancelar).
  Future<void> _mostrarConfirmacion(Widget child) {
    final ancho = MediaQuery.sizeOf(context).width >= 768;
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

  /// Abre la vista (solo lectura) de cuentas bancarias del perfil. Diálogo
  /// centrado en modo portal (web ≥1024) o pantalla en móvil.
  void _verCuentas() {
    if (isPortalMode(context)) {
      showPortalDialog<void>(context, child: const PerfilCuentasScreen());
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PerfilCuentasScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    // Modo portal (web ≥1024): mismo contenido centrado tipo card grande del
    // portal, pero con la card y tipografía del portal y fondo del shell.
    final portal = isPortalMode(context);
    final exp = ref.watch(clienteExpedienteProvider);
    // Cuentas bancarias del perfil: alimentan la fila estructurada "Cuenta
    // bancaria" (bajo los documentos financieros), espejo del portal.
    final cuentas =
        ref.watch(clientePerfilProvider).valueOrNull?.cuentasBancarias ??
            const <CuentaBancariaPerfil>[];

    final cardBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Documentos',
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
        _grupos(exp, cuentas),
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

  /// Grupos del expediente ("Personales" / "Fiscal y financiero") con sus
  /// documentos en orden alfabético; la fila "Cuenta bancaria" va bajo el grupo
  /// financiero. Espejo del render de DOC_GROUPS del portal.
  Widget _grupos(
    AsyncValue<ClienteExpediente> exp,
    List<CuentaBancariaPerfil> cuentas,
  ) {
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
        onRetry: () => ref.invalidate(clienteExpedienteProvider),
      ),
      data: (data) {
        if (data.slots.isEmpty) {
          return const EmptyCard(
            icon: Icons.folder_open_outlined,
            text: 'Aún no hay documentos configurados en tu expediente.',
          );
        }

        List<ExpedienteSlot> deGrupo(String grupo) => data.slots
            .where((s) => (_slotGrupo[s.key] ?? _grupoPersonal) == grupo)
            .toList()
          ..sort((a, b) => _normLabel(a.nombre).compareTo(_normLabel(b.nombre)));

        final grupos = <({String titulo, String key})>[
          (titulo: 'PERSONALES', key: _grupoPersonal),
          (titulo: 'FISCAL Y FINANCIERO', key: _grupoFinanciero),
        ];

        final secciones = <Widget>[];
        for (var g = 0; g < grupos.length; g++) {
          final grupo = grupos[g];
          final slots = deGrupo(grupo.key);
          if (slots.isEmpty && grupo.key != _grupoFinanciero) continue;
          if (g > 0) secciones.add(const SizedBox(height: 18));
          secciones.add(_GrupoHeader(titulo: grupo.titulo));
          secciones.add(const SizedBox(height: 10));
          for (var i = 0; i < slots.length; i++) {
            secciones.add(_SlotRow(
              slot: slots[i],
              subiendo: _subiendo == slots[i].key,
              bloqueado: _subiendo != null,
              onSubir: () => _subirArchivo(slots[i],
                  camara: _esCamara(slots[i].key)),
            ));
            secciones.add(const SizedBox(height: 10));
          }
          // Cuenta bancaria: fila estructurada al final del grupo financiero
          // (banco, número, CLABE/SWIFT, titular, evidencia). Alta disponible
          // también al impersonar (la impersonación es admin-only).
          if (grupo.key == _grupoFinanciero) {
            secciones.add(_CuentaBancariaRow(
              cuentas: cuentas,
              onSubir: () => showCuentaBancariaSheet(context),
              onVer: cuentas.any((c) => c.evidencia != null)
                  ? () => _verCuentas()
                  : null,
            ));
          } else {
            // Quita el SizedBox sobrante tras el último documento del grupo.
            secciones.removeLast();
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: secciones,
        );
      },
    );
  }
}

/// Encabezado de grupo (uppercase gris), espejo de DOC_GROUPS del portal.
class _GrupoHeader extends StatelessWidget {
  final String titulo;
  const _GrupoHeader({required this.titulo});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Text(
      titulo,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: tone.textMuted,
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final ExpedienteSlot slot;
  final bool subiendo;

  /// true si hay otra subida en curso (deshabilita este botón).
  final bool bloqueado;
  final VoidCallback onSubir;

  const _SlotRow({
    required this.slot,
    required this.subiendo,
    required this.bloqueado,
    required this.onSubir,
  });

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    // Badge: 'opcional' se muestra como 'Pendiente' (neutro), igual que el
    // portal (documentos faltantes → "Pendiente").
    final estatusBadge = slot.estatus == 'opcional' ? 'pendiente' : slot.estatus;
    final st = expedienteEstatusStyle(estatusBadge, tone);
    final esCamara = _esCamara(slot.key);
    final tieneDoc = slot.fecha != null;
    final puedeVer = slot.urlFirmada != null;
    // Acción principal habilitada solo cuando el backend permite subir y no hay
    // otra subida en curso (espejo de canUpload del portal).
    final puedeActuar = slot.puedeSubir && !subiendo && !bloqueado;

    // Icono de la acción principal (espejo EXACTO del portal):
    // subiendo → spinner; cámara → cámara; con doc → lápiz (reemplazar);
    // sin doc → subir.
    Widget iconoAccion() {
      if (subiendo) {
        return const SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      }
      final color =
          puedeActuar ? tone.textSecondary : tone.textMuted.withValues(alpha: 0.4);
      if (esCamara) {
        return Icon(Icons.photo_camera_outlined, size: 16, color: color);
      }
      return Icon(tieneDoc ? Icons.edit_outlined : Icons.upload_outlined,
          size: 16, color: color);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        border: Border.all(color: tone.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          // Icono de documento en caja redondeada (espejo del portal).
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tone.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.description_outlined,
                size: 17, color: tone.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título + badge de estatus al lado (misma posición que el
                // portal).
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(slot.nombre,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: tone.textPrimary)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: st.bg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(st.label,
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: st.fg)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  tieneDoc ? 'Subido el ${formatDateEsMX(slot.fecha)}' : 'Sin cargar',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: tone.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Acción principal: cámara (INE/pasaporte) o lápiz/subir (resto).
          _IconBtn(
            tooltip: esCamara
                ? 'Capturar con cámara'
                : tieneDoc
                    ? 'Reemplazar documento'
                    : 'Subir documento',
            onTap: puedeActuar ? onSubir : null,
            child: iconoAccion(),
          ),
          // Ver el documento subido (visor in-app).
          if (puedeVer) ...[
            const SizedBox(width: 6),
            _IconBtn(
              tooltip: 'Ver documento',
              onTap: () =>
                  openMedia(context, slot.urlFirmada, titulo: slot.nombre),
              child: Icon(Icons.visibility_outlined,
                  size: 16, color: tone.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fila estructurada "Cuenta bancaria" del expediente (bajo los documentos
/// financieros): abre el formulario de alta y, si hay evidencia, permite ver
/// las cuentas. Espejo del slot financiero "Cuenta bancaria" del portal.
class _CuentaBancariaRow extends StatelessWidget {
  final List<CuentaBancariaPerfil> cuentas;

  /// Abre el sheet de alta de cuenta.
  final VoidCallback onSubir;

  /// Abre la vista de cuentas (null si aún no hay evidencia que mostrar).
  final VoidCallback? onVer;

  const _CuentaBancariaRow({
    required this.cuentas,
    required this.onSubir,
    required this.onVer,
  });

  /// Badge agregado, igual que el portal: sin cuentas → Pendiente; si alguna no
  /// tiene carátula → Incompleto; todas validadas (estatus 2) → Validada; el
  /// resto → En revisión.
  (String, Color, Color) _badge(SozuTone tone) {
    if (cuentas.isEmpty) {
      return ('Pendiente', tone.surfaceAlt, tone.textSecondary);
    }
    final todasEvidencia = cuentas.every((c) => c.evidencia != null);
    if (!todasEvidencia) {
      return ('Incompleto', tone.negative.withValues(alpha: 0.1), tone.negative);
    }
    if (cuentas.every((c) => c.estatus == 2)) {
      return ('Validada', tone.primarySoft, tone.primaryDark);
    }
    return ('En revisión', tone.pendingSoft, SozuColors.amber600);
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final (label, bg, fg) = _badge(tone);
    final n = cuentas.length;
    final subtitulo = n > 0
        ? '$n cuenta${n > 1 ? 's' : ''} registrada${n > 1 ? 's' : ''}'
        : 'Banco, número de cuenta, CLABE y titular';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        border: Border.all(color: tone.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tone.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.credit_card_outlined,
                size: 17, color: tone.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text('Cuenta bancaria',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: tone.textPrimary)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(label,
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: fg)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: tone.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _IconBtn(
            tooltip: 'Agregar cuenta bancaria',
            onTap: onSubir,
            child: Icon(Icons.upload_outlined,
                size: 16, color: tone.textSecondary),
          ),
          if (onVer != null) ...[
            const SizedBox(width: 6),
            _IconBtn(
              tooltip: 'Ver cuentas',
              onTap: onVer,
              child: Icon(Icons.visibility_outlined,
                  size: 16, color: tone.textSecondary),
            ),
          ],
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
          width: 36,
          height: 36,
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

// ─── Confirmación de datos extraídos (ConfirmDataModal del portal) ───────────

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

/// Campo editable del diálogo de confirmación (label + TextField).
class _CampoConfirm extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool mono;
  final TextInputType? keyboard;
  final int? maxLength;

  const _CampoConfirm({
    required this.label,
    required this.controller,
    this.mono = false,
    this.keyboard,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
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
            controller: controller,
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

/// Cabecera + botones del diálogo de confirmación (compartido).
class _ConfirmShell extends StatelessWidget {
  final String titulo;
  final List<Widget> campos;
  final bool busy;
  final VoidCallback onCancelar;
  final VoidCallback onGuardar;

  const _ConfirmShell({
    required this.titulo,
    required this.campos,
    required this.busy,
    required this.onCancelar,
    required this.onGuardar,
  });

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
                Text(titulo,
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
              children: campos,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onCancelar,
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
                    onPressed: busy ? null : onGuardar,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: busy
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
    return _ConfirmShell(
      titulo: 'Confirma tus datos fiscales',
      busy: _busy,
      onCancelar: _cancelar,
      onGuardar: _guardar,
      campos: [
        _CampoConfirm(label: 'RFC', controller: _rfc, mono: true),
        _CampoConfirm(label: 'CURP', controller: _curp, mono: true),
        _CampoConfirm(label: 'Nombre / Razón social', controller: _nombre),
        _CampoConfirm(label: 'Régimen fiscal', controller: _regimen),
        _CampoConfirm(
            label: 'Código postal',
            controller: _cp,
            keyboard: TextInputType.number,
            maxLength: 5),
        _CampoConfirm(label: 'Calle', controller: _calle),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child:
                    _CampoConfirm(label: 'Núm. exterior', controller: _numExt)),
            const SizedBox(width: 12),
            Expanded(
                child:
                    _CampoConfirm(label: 'Núm. interior', controller: _numInt)),
          ],
        ),
        _CampoConfirm(label: 'Colonia', controller: _colonia),
      ],
    );
  }
}

/// Confirmación de datos de la CURP o del Acta de nacimiento. Los datos
/// editables (CURP, nombre) se guardan en el perfil (update_personal); fecha,
/// sexo y lugar de nacimiento son informativos (no se guardan), igual que el
/// portal (personaCol null).
class _ConfirmarDatosIdentidad extends ConsumerStatefulWidget {
  final DatosCURP? curp;
  final DatosActa? acta;
  const _ConfirmarDatosIdentidad({this.curp, this.acta});

  @override
  ConsumerState<_ConfirmarDatosIdentidad> createState() =>
      _ConfirmarDatosIdentidadState();
}

class _ConfirmarDatosIdentidadState
    extends ConsumerState<_ConfirmarDatosIdentidad> {
  late final TextEditingController _curp;
  late final TextEditingController _nombre;
  late final TextEditingController _fecha;
  late final TextEditingController _sexo;
  late final TextEditingController _lugar;

  bool get _esActa => widget.acta != null;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = ref.read(clientePerfilProvider).valueOrNull;
    final c = widget.curp;
    final a = widget.acta;
    _curp = TextEditingController(
        text: c?.curp ?? a?.curp ?? p?.curp ?? '');
    _nombre = TextEditingController(
        text: c?.nombre ?? a?.nombre ?? p?.nombreLegal ?? '');
    _fecha = TextEditingController(
        text: c?.fechaNacimiento ?? a?.fechaNacimiento ?? '');
    _sexo = TextEditingController(
        text: c?.sexoLabel ?? a?.sexoLabel ?? '');
    _lugar = TextEditingController(text: a?.lugarNacimiento ?? '');
  }

  @override
  void dispose() {
    _curp.dispose();
    _nombre.dispose();
    _fecha.dispose();
    _sexo.dispose();
    _lugar.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _busy = true);
    try {
      final p = ref.read(clientePerfilProvider).valueOrNull;
      final imp = ref.read(impersonationProvider).idPersona;
      final nombre = _nombre.text.trim();
      final curp = _curp.text.trim();
      // Solo CURP y nombre se guardan en el perfil (personaCol del portal).
      await updatePerfilPersonal(
        nombreLegal: nombre.isNotEmpty ? nombre : (p?.nombreLegal ?? ''),
        rfc: p?.rfc,
        curp: curp.isEmpty ? p?.curp : curp,
        clavePaisTelefono: p?.clavePaisTelefono,
        telefono: p?.telefono,
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
    return _ConfirmShell(
      titulo: _esActa
          ? 'Confirma los datos de tu acta'
          : 'Confirma los datos de tu CURP',
      busy: _busy,
      onCancelar: _cancelar,
      onGuardar: _guardar,
      campos: [
        _CampoConfirm(label: 'CURP', controller: _curp, mono: true),
        _CampoConfirm(label: 'Nombre completo', controller: _nombre),
        _CampoConfirm(label: 'Fecha de nacimiento', controller: _fecha),
        _CampoConfirm(label: 'Sexo', controller: _sexo),
        if (_esActa)
          _CampoConfirm(label: 'Lugar de nacimiento', controller: _lugar),
      ],
    );
  }
}
