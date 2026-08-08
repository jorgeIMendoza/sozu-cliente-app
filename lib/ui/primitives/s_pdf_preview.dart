import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import 'package:sozu_cliente_app/ui/theme/sozu_theme.dart';
import 'package:sozu_cliente_app/ui/tokens/color_roles.dart';

/// Previsualización de un PDF que aún está en memoria (no se ha subido).
///
/// Rasteriza **una página a la vez** a imagen y la pinta con `Image.memory`.
/// El visor con scroll continuo (`PdfViewPinch`) rasterizaba todas las páginas
/// mientras el usuario leía: en web eso traba la pestaña varios segundos, y su
/// scroll propio se peleaba con el de la hoja (bastaba rodar la rueda para que
/// la modal saltara al inicio). Una imagen no hace ninguna de las dos cosas.
class SPdfPreview extends StatefulWidget {
  final Uint8List bytes;

  /// Nombre del archivo, para la barra superior.
  final String? nombre;

  const SPdfPreview({super.key, required this.bytes, this.nombre});

  @override
  State<SPdfPreview> createState() => _SPdfPreviewState();
}

class _SPdfPreviewState extends State<SPdfPreview> {
  /// Ancho al que se rasteriza. Suficiente para leer un acta en pantalla sin
  /// pagar el coste de una resolución de impresión.
  static const double _anchoRender = 1240;

  PdfDocument? _doc;
  Uint8List? _imagen;
  int _pagina = 1;
  int _paginas = 0;
  bool _cargando = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _abrir();
  }

  @override
  void didUpdateWidget(SPdfPreview old) {
    super.didUpdateWidget(old);
    // Identidad, no contenido: comparar 10 MB byte a byte en cada rebuild
    // costaría más que reabrir el documento.
    if (!identical(old.bytes, widget.bytes)) {
      _cerrar();
      setState(() {
        _imagen = null;
        _pagina = 1;
        _paginas = 0;
        _cargando = true;
        _error = null;
      });
      _abrir();
    }
  }

  Future<void> _abrir() async {
    try {
      final doc = await PdfDocument.openData(widget.bytes);
      if (!mounted) {
        await doc.close();
        return;
      }
      _doc = doc;
      _paginas = doc.pagesCount;
      await _render(1);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _cargando = false;
        });
      }
    }
  }

  Future<void> _render(int n) async {
    final doc = _doc;
    if (doc == null) return;
    setState(() => _cargando = true);
    PdfPage? page;
    try {
      page = await doc.getPage(n);
      final alto = page.height / page.width * _anchoRender;
      final img = await page.render(
        width: _anchoRender,
        height: alto,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      if (!mounted) return;
      setState(() {
        _imagen = img?.bytes;
        _pagina = n;
        _cargando = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _cargando = false;
        });
      }
    } finally {
      await page?.close();
    }
  }

  void _cerrar() {
    _doc?.close();
    _doc = null;
  }

  @override
  void dispose() {
    _cerrar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return Container(
      decoration: BoxDecoration(
        color: tone.muted,
        borderRadius: context.s.radius.mdBorder,
        border: Border.all(color: tone.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (_paginas > 1) _barra(tone),
          Expanded(child: _cuerpo(tone)),
        ],
      ),
    );
  }

  Widget _barra(SozuColorRoles tone) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: context.s.space.xs,
      vertical: context.s.space.xxs,
    ),
    color: tone.surfaceAlt,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Página anterior',
          onPressed: _pagina > 1 && !_cargando
              ? () => _render(_pagina - 1)
              : null,
          icon: const Icon(Icons.chevron_left, size: 18),
        ),
        Text(
          '$_pagina de $_paginas',
          style: context.s.text.caption.copyWith(color: tone.fgMuted),
        ),
        IconButton(
          tooltip: 'Página siguiente',
          onPressed: _pagina < _paginas && !_cargando
              ? () => _render(_pagina + 1)
              : null,
          icon: const Icon(Icons.chevron_right, size: 18),
        ),
      ],
    ),
  );

  Widget _cuerpo(SozuColorRoles tone) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.s.space.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 30,
                color: tone.fgSubtle,
              ),
              SizedBox(height: context.s.space.xs),
              Text(
                'No pudimos mostrar este PDF. El archivo puede estar dañado; '
                'elige otro.',
                textAlign: TextAlign.center,
                style: context.s.text.caption.copyWith(color: tone.fgMuted),
              ),
            ],
          ),
        ),
      );
    }
    final img = _imagen;
    if (img == null) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            maxScale: 4,
            child: Image.memory(img, fit: BoxFit.contain),
          ),
        ),
        if (_cargando)
          const Positioned(
            top: 8,
            right: 8,
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}
