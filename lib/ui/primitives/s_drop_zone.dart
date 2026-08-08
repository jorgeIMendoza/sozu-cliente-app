import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/core/file_drop.dart';
import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';

/// Zona de carga de un archivo: se puede arrastrar sobre ella (web) o abrir el
/// selector del sistema.
///
/// Es tonta: no sabe qué documento es ni a dónde va. Recibe los textos y qué
/// hacer con el archivo.
///
/// El arrastre solo existe en web; en móvil queda el toque, y la instrucción
/// cambia sola.
class SDropZone extends StatefulWidget {
  /// Acción principal ("Adjuntar PDF").
  final String titulo;

  /// Qué se acepta, en una línea ("Solo PDF, escaneado y legible").
  final String? subtitulo;

  /// Nombre del archivo ya adjunto; null mientras no haya ninguno.
  final String? archivo;

  /// Abre el selector del sistema. Devuelve el archivo, o null si se canceló.
  final Future<({String nombre, Uint8List bytes})?> Function() onSeleccionar;

  /// Recibe el archivo, venga del selector o del arrastre.
  final void Function(String nombre, Uint8List bytes) onArchivo;

  /// Trabajo en curso: bloquea la zona y muestra el progreso.
  final bool ocupado;
  final bool habilitado;

  const SDropZone({
    super.key,
    required this.titulo,
    required this.onSeleccionar,
    required this.onArchivo,
    this.subtitulo,
    this.archivo,
    this.ocupado = false,
    this.habilitado = true,
  });

  @override
  State<SDropZone> createState() => _SDropZoneState();
}

class _SDropZoneState extends State<SDropZone> {
  final _zona = GlobalKey();
  Object? _suscripcion;
  bool _encima = false;

  @override
  void initState() {
    super.initState();
    _suscripcion = registerFileDrop(
      rect: _rect,
      onHover: (encima) {
        final activo = encima && widget.habilitado && !widget.ocupado;
        if (activo != _encima && mounted) setState(() => _encima = activo);
      },
      onFile: (nombre, bytes) {
        if (!widget.habilitado || widget.ocupado) return;
        widget.onArchivo(nombre, bytes);
      },
    );
  }

  @override
  void dispose() {
    cancelFileDrop(_suscripcion);
    super.dispose();
  }

  /// Rectángulo de la zona en coordenadas de pantalla. Fuera del árbol (aún no
  /// montada) devuelve uno vacío, que no contiene ningún punto.
  Rect _rect() {
    final box = _zona.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return Rect.zero;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _seleccionar() async {
    final archivo = await widget.onSeleccionar();
    if (archivo == null) return;
    widget.onArchivo(archivo.nombre, archivo.bytes);
  }

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final activo = widget.habilitado && !widget.ocupado;
    final adjunto = widget.archivo;
    final borde = _encima
        ? tone.primary
        : (adjunto != null ? tone.primaryBorder : tone.border);

    return InkWell(
      key: _zona,
      onTap: activo ? _seleccionar : null,
      borderRadius: context.s.radius.lgBorder,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: context.s.space.md,
          vertical: context.s.space.lg,
        ),
        decoration: BoxDecoration(
          color: _encima
              ? tone.primarySoft
              : (adjunto != null ? tone.primarySoft : tone.surfaceAlt),
          border: Border.all(color: borde, width: _encima ? 2 : 1),
          borderRadius: context.s.radius.lgBorder,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.ocupado)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                adjunto != null
                    ? Icons.picture_as_pdf_outlined
                    : Icons.file_upload_outlined,
                size: 26,
                color: adjunto != null || _encima ? tone.primary : tone.fgMuted,
              ),
            SizedBox(height: context.s.space.xs),
            Text(
              adjunto ?? widget.titulo,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.s.text.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: tone.fg,
              ),
            ),
            SizedBox(height: context.s.space.xxs),
            Text(
              adjunto != null
                  ? 'Toca para cambiar el archivo'
                  : (widget.subtitulo ??
                        (_suscripcion != null
                            ? 'Arrastra el PDF aquí o selecciónalo'
                            : 'Selecciona el PDF')),
              textAlign: TextAlign.center,
              style: context.s.text.caption.copyWith(color: tone.fgSubtle),
            ),
          ],
        ),
      ),
    );
  }
}
