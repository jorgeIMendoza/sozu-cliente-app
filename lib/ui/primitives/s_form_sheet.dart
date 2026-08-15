import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/ui/primitives/s_button.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Armazón de una hoja modal con formulario: encabezado con título y cierre,
/// cuerpo propio y pie con Cancelar / Guardar.
///
/// Es el chasis que comparten TODAS las modales de captura, incluida la de
/// carga de documentos ([SDocUploadLayout], que le pasa sus dos columnas como
/// cuerpo). Una modal que arme su propio encabezado y su propio pie termina
/// siendo otra piel.
///
/// Se presenta con `showSDocModal`, que decide diálogo centrado o hoja de
/// pantalla completa según el ancho.
class SFormSheet extends StatelessWidget {
  final String titulo;
  final String? descripcion;

  /// Contenido propio de la hoja. Trae su propio scroll si lo necesita.
  final Widget cuerpo;

  /// Estira [cuerpo] al alto disponible en vez de dejarlo crecer con su
  /// contenido. Lo necesita quien pinta una previsualización: con
  /// restricciones sueltas el visor resuelve a cero.
  final bool cuerpoAlAlto;

  final String etiquetaGuardar;
  final String? etiquetaGuardando;
  final String etiquetaCancelar;
  final bool guardando;

  /// `null` deshabilita Guardar.
  final VoidCallback? onGuardar;

  const SFormSheet({
    super.key,
    required this.titulo,
    required this.cuerpo,
    this.descripcion,
    this.cuerpoAlAlto = false,
    this.etiquetaGuardar = 'Guardar',
    this.etiquetaGuardando,
    this.etiquetaCancelar = 'Cancelar',
    this.guardando = false,
    this.onGuardar,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            t.space.lg,
            t.space.md,
            t.space.md,
            t.space.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: t.text.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tone.fg,
                      ),
                    ),
                    if (descripcion != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        descripcion!,
                        style: t.text.caption.copyWith(color: tone.fgMuted),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: guardando ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: tone.border),
        Flexible(
          fit: cuerpoAlAlto ? FlexFit.tight : FlexFit.loose,
          child: cuerpo,
        ),
        Divider(height: 1, thickness: 1, color: tone.border),
        Padding(
          padding: EdgeInsets.all(t.space.md),
          child: Row(
            children: [
              Expanded(
                child: SButton.secondary(
                  label: etiquetaCancelar,
                  onPressed: guardando
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ),
              SizedBox(width: t.space.sm),
              Expanded(
                child: SButton(
                  label: etiquetaGuardar,
                  loading: guardando,
                  loadingLabel: etiquetaGuardando,
                  onPressed: onGuardar,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
