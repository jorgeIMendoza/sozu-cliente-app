import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/ui/ui.dart';
import 'package:sozu_cliente_app/widgets/portal_widgets.dart';

const _kQrAsset = 'assets/images/sozu-qr-web.png';

/// Redirector (Cloudflare Worker) que detecta el SO y manda a la tienda
/// correcta. Es el MISMO destino que codifica el QR: una sola fuente de verdad.
const _kDownloadUrl = 'https://obtener-clientes-app.sozu.com';

/// Bloque "Descarga la app": encabezado opcional + instrucción + QR. Tonto:
/// no lee providers. Se usa en el login y dentro del modal del portal.
class AppQrPanel extends StatelessWidget {
  /// Lado del QR en px.
  final double size;

  /// Pinta el título "Descarga la app". En el modal lo pone el shell.
  final bool showHeading;

  const AppQrPanel({super.key, this.size = 188, this.showHeading = true});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHeading) ...[
          Text(
            'Descarga la app',
            style: t.text.h3,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: t.space.xs),
        ],
        Text(
          'Escanea el codigo con tu telefono para instalarla.',
          style: t.text.bodySmall.copyWith(color: t.color.fgMuted),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: t.space.md),
        Container(
          padding: EdgeInsets.all(t.space.sm),
          decoration: BoxDecoration(
            // El QR es negro sobre transparente: fondo blanco fijo para que
            // sea legible tambien en tema oscuro. No es un color de marca.
            color: Colors.white,
            borderRadius: BorderRadius.circular(t.radius.md),
            border: Border.all(color: t.color.border),
          ),
          child: Image.asset(
            _kQrAsset,
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}

/// Card compacta horizontal "Descarga la app" (QR + texto). Para el login en
/// escritorio, sobrepuesta al panel de marca.
class AppQrCard extends StatelessWidget {
  const AppQrCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Container(
      padding: EdgeInsets.all(t.space.md),
      decoration: BoxDecoration(
        color: t.color.surface,
        borderRadius: BorderRadius.circular(t.radius.lg),
        border: Border.all(color: t.color.border),
        boxShadow: t.shadow.lg,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(t.space.xs),
            decoration: BoxDecoration(
              // El QR es negro sobre transparente: fondo blanco fijo. No marca.
              color: Colors.white,
              borderRadius: BorderRadius.circular(t.radius.sm),
            ),
            child: Image.asset(
              _kQrAsset,
              width: 88,
              height: 88,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(width: t.space.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Descarga la app',
                  style: t.text.body.copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: t.space.xxs),
                Text(
                  'Escanea el codigo con tu telefono para instalarla.',
                  style: t.text.bodySmall.copyWith(color: t.color.fgMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Acción "Descargar app". En escritorio-web abre el QR (se escanea con el
/// teléfono); en móvil (incl. web en teléfono) va directo a la tienda del SO.
Future<void> showAppDownloadDialog(BuildContext context) {
  if (!isPortalMode(context)) return openAppStore(context);
  return showPortalDialog<void>(
    context,
    maxWidth: 380,
    child: const PortalDialogShell(
      title: 'Descarga la app',
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: AppQrPanel(showHeading: false),
      ),
    ),
  );
}

/// Botón "Descargar app" de la topbar: abre [showAppDownloadDialog].
class AppDownloadButton extends StatelessWidget {
  const AppDownloadButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SButton.secondary(
      label: 'Descargar app',
      icon: Icons.qr_code,
      size: SButtonSize.sm,
      fullWidth: false,
      tooltip: 'Descargar la app (QR)',
      onPressed: () => showAppDownloadDialog(context),
    );
  }
}

/// Franja "Descarga la app" del login en web-móvil. Teñida y sin relleno
/// sólido a propósito: un segundo botón primario competiría con "Iniciar
/// sesión". Sin tienda para el sistema actual informa en vez de navegar.
class AppStoreDownloadButton extends StatelessWidget {
  /// URLs del backend; `null` mientras la config no llega.
  final String? androidStoreUrl;
  final String? iosStoreUrl;

  const AppStoreDownloadButton({
    super.key,
    this.androidStoreUrl,
    this.iosStoreUrl,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;
    final destino = appDownloadTarget(
      androidStoreUrl: androidStoreUrl,
      iosStoreUrl: iosStoreUrl,
    );
    final pendiente = destino == null;

    // Sin tienda la franja se apaga: sigue visible, pero no promete un toque.
    final fondo = pendiente ? c.muted : c.primarySoft;
    final borde = pendiente ? c.borderSoft : c.primaryBorder;
    final acento = pendiente ? c.fgMuted : c.primaryHover;

    final contenido = Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.md,
        vertical: t.space.sm,
      ),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: t.radius.lgBorder,
        border: Border.all(color: borde),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: t.radius.mdBorder,
            ),
            child: Icon(
              pendiente ? Icons.schedule_outlined : Icons.phone_iphone_outlined,
              size: 22,
              color: acento,
            ),
          ),
          SizedBox(width: t.space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pendiente ? 'App para iPhone' : 'Descarga la app',
                  style: t.text.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.fg,
                    height: 1.2,
                  ),
                ),
                Text(
                  pendiente
                      ? 'Muy pronto en el App Store'
                      : 'Entra en un toque, sin escribir tu contraseña',
                  style: t.text.caption.copyWith(color: c.fgMuted),
                ),
              ],
            ),
          ),
          if (!pendiente) Icon(Icons.chevron_right, size: 20, color: acento),
        ],
      ),
    );

    if (pendiente) return contenido;
    return SPressable(
      onTap: () => openAppStore(
        context,
        androidStoreUrl: androidStoreUrl,
        iosStoreUrl: iosStoreUrl,
      ),
      borderRadius: t.radius.lgBorder,
      isNavigation: true,
      semanticLabel: 'Descargar la app de SOZU',
      child: contenido,
    );
  }
}

/// Respaldo si la config no llega. El `referrer` es el del redirector: partirlo
/// separaría la atribución del QR y la del login.
const _kPlayUrl =
    'https://play.google.com/store/apps/details?id=com.sozu.clientes_app'
    '&referrer=utm_source%3Dqr%26utm_medium%3Dimpreso';

String? _oNull(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

/// Tienda de ESTE dispositivo, o `null` si aún no publica la app.
///
/// Las URLs vienen de `app_cliente_config` vía el gate de versión: publicar iOS
/// es llenar una fila, sin recompilar. Sin config, Android cae en la constante
/// y iOS en "próximamente"; nunca un enlace muerto.
String? appDownloadTarget({String? androidStoreUrl, String? iosStoreUrl}) =>
    switch (defaultTargetPlatform) {
      TargetPlatform.android => _oNull(androidStoreUrl) ?? _kPlayUrl,
      TargetPlatform.iOS => _oNull(iosStoreUrl),
      _ => _kDownloadUrl,
    };

/// Abre la tienda que toca. Sin tienda para este sistema no hace nada: quien
/// llama ya pintó el aviso de "próximamente".
Future<void> openAppStore(
  BuildContext context, {
  String? androidStoreUrl,
  String? iosStoreUrl,
}) async {
  final destino = appDownloadTarget(
    androidStoreUrl: androidStoreUrl,
    iosStoreUrl: iosStoreUrl,
  );
  if (destino == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final ok = await launchUrl(
    Uri.parse(destino),
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No se pudo abrir la descarga.')),
    );
  }
}
