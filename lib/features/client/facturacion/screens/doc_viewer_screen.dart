import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

import 'package:sozu_cliente_app/core/file_download.dart';
import 'package:sozu_cliente_app/core/media_cache.dart';
import 'package:sozu_cliente_app/core/open_document.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:sozu_cliente_app/widgets/network_image.dart';

enum _MediaKind { image, pdf, xml, unknown }

const _imageExts = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic'};

/// Visor in-app de imágenes (zoom/pan) y PDFs (scroll de páginas), con cache.
/// El tipo se infiere por la extensión del path; si no hay, se consulta el
/// header Content-Type. Si aun así no se reconoce, se ofrece abrir externo.
class DocViewerScreen extends StatefulWidget {
  final String url;
  final String titulo;

  const DocViewerScreen({super.key, required this.url, required this.titulo});

  @override
  State<DocViewerScreen> createState() => _DocViewerScreenState();
}

class _DocViewerScreenState extends State<DocViewerScreen> {
  late Future<_MediaKind> _kind;

  @override
  void initState() {
    super.initState();
    _kind = _detectKind();
  }

  Future<_MediaKind> _detectKind() async {
    final ext = fileExtensionOf(widget.url);
    if (ext == 'pdf') return _MediaKind.pdf;
    if (ext == 'xml') return _MediaKind.xml;
    if (_imageExts.contains(ext)) return _MediaKind.image;
    // Sin extensión reconocible: preguntar por Content-Type.
    try {
      final res = await http.head(Uri.parse(widget.url));
      final ct = (res.headers['content-type'] ?? '').toLowerCase();
      if (ct.contains('pdf')) return _MediaKind.pdf;
      if (ct.contains('xml')) return _MediaKind.xml;
      if (ct.startsWith('image/')) return _MediaKind.image;
    } catch (_) {
      /* cae a unknown */
    }
    return _MediaKind.unknown;
  }

  /// Nombre de archivo para la descarga: título saneado + extensión detectada.
  String _downloadName() {
    final base = widget.titulo.trim().isEmpty
        ? 'documento'
        : widget.titulo.trim().replaceAll(RegExp(r'\s+'), '-');
    final ext = fileExtensionOf(widget.url);
    return ext.isEmpty ? '$base.pdf' : '$base.$ext';
  }

  Future<void> _descargar() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await downloadFile(widget.url, _downloadName());
    if (!ok && mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo descargar el documento.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.s.text.label,
            ),
            Text(
              'Vista previa',
              // Barra oscura fija: el blanco atenuado no sale de los roles.
              style: context.s.text.caption.copyWith(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Descargar',
            icon: const Icon(Icons.download_outlined),
            onPressed: _descargar,
          ),
          IconButton(
            tooltip: 'Abrir en navegador',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => openDoc(context, widget.url),
          ),
        ],
      ),
      body: FutureBuilder<_MediaKind>(
        future: _kind,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          switch (snap.data!) {
            case _MediaKind.image:
              return PhotoView(
                imageProvider: cachedImageProvider(widget.url),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 4,
                loadingBuilder: (_, __) =>
                    const Center(child: CircularProgressIndicator()),
                errorBuilder: (_, __, ___) => _fallback(tone),
              );
            case _MediaKind.pdf:
              // En web el iframe del navegador: `pdfx` rasteriza cada
              // pagina en un canvas y traba la pestana. El documento sigue
              // dentro de la plataforma, es un embed.
              if (kIsWeb) return SPdfFrame(url: widget.url);
              return _PdfView(url: widget.url, onError: () {});
            case _MediaKind.xml:
              return _XmlView(url: widget.url, onError: () => _fallback(tone));
            case _MediaKind.unknown:
              return _fallback(tone);
          }
        },
      ),
    );
  }

  Widget _fallback(SozuColorRoles tone) => Center(
    child: Padding(
      padding: EdgeInsets.all(context.s.space.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.insert_drive_file_outlined,
            size: 48,
            color: Colors.white70,
          ),
          const SizedBox(height: 16),
          const Text(
            'No pudimos mostrar este archivo aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => openDoc(context, widget.url),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Abrir en navegador'),
          ),
        ],
      ),
    ),
  );
}

/// Renderiza un PDF con cache (bytes de SozuCacheManager). Si falla, fallback.
class _PdfView extends StatefulWidget {
  final String url;
  final VoidCallback onError;

  const _PdfView({required this.url, required this.onError});

  @override
  State<_PdfView> createState() => _PdfViewState();
}

class _PdfViewState extends State<_PdfView> {
  PdfControllerPinch? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await _pdfBytes(widget.url);
      if (!mounted) return;
      setState(() {
        _controller = PdfControllerPinch(document: PdfDocument.openData(bytes));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<Uint8List> _pdfBytes(String url) async {
    final key = cacheKeyFor(url);
    final cached = await SozuCacheManager.instance.getFileFromCache(key);
    if (cached != null) return cached.file.readAsBytes();
    final file = await SozuCacheManager.instance.getSingleFile(url, key: key);
    return file.readAsBytes();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.s.space.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.picture_as_pdf_outlined,
                size: 48,
                color: Colors.white70,
              ),
              const SizedBox(height: 16),
              const Text(
                'No pudimos mostrar el PDF aquí.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => openDoc(context, widget.url),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir en navegador'),
              ),
            ],
          ),
        ),
      );
    }
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return PdfViewPinch(controller: _controller!);
  }
}

/// Muestra el XML como texto seleccionable. Un CFDI no se "renderiza": lo que
/// el cliente necesita es verlo sin salir de la app y poder copiarlo o
/// descargarlo, que es lo que ofrece esta vista mas el boton de la barra.
class _XmlView extends StatefulWidget {
  final String url;

  /// Que pintar si el archivo no se pudo leer (CORS, red, 404).
  final Widget Function() onError;

  const _XmlView({required this.url, required this.onError});

  @override
  State<_XmlView> createState() => _XmlViewState();
}

class _XmlViewState extends State<_XmlView> {
  late final Future<String> _texto = _cargar();

  Future<String> _cargar() async {
    final res = await http.get(Uri.parse(widget.url));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('status ${res.statusCode}');
    }
    return utf8.decode(res.bodyBytes, allowMalformed: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return FutureBuilder<String>(
      future: _texto,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || snap.data == null) return widget.onError();
        return SingleChildScrollView(
          padding: EdgeInsets.all(t.space.md),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              snap.data!,
              style: t.text.caption.copyWith(
                color: Colors.white,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }
}
