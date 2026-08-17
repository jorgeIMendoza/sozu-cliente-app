import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sozu_cliente_app/core/version.dart';
import 'package:sozu_cliente_app/features/app_download/components/app_download.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/shared/providers/shared_providers.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// "Version gate" de la app NATIVA (Android/iOS): aviso o forzado de
/// actualización según lo que entregue la edge function `cliente-app-version`.
///
/// - En WEB no aplica nunca (`kIsWeb`): la web se auto-actualiza por hosting.
/// - Forzado (bloqueante) si `force_update` o la versión actual < `min_version`.
/// - Sugerencia (banner descartable) si la versión actual < `latest_version`.
/// - Ante error/loading (provider null) => deja pasar el `child` sin cambios.
///
/// Nota: se monta como `builder:` del MaterialApp.router, ARRIBA del Navigator.
/// Por eso el aviso soft es un banner en el árbol (no `showDialog`, que
/// requeriría un Navigator ancestro que aquí no existe).
class VersionGate extends ConsumerWidget {
  final Widget child;

  const VersionGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // La web no gatea (y además evita tocar plataforma nativa).
    if (kIsWeb) return child;

    final info = ref.watch(appVersionGateProvider).value;
    if (info == null) return child; // loading o error => sin gate

    final min = info.minVersion;
    final mustForce =
        info.forceUpdate ||
        (min != null && compareSemver(appVersionBase, min) < 0);
    if (mustForce) return _ForcedUpdateScreen(info: info);

    final latest = info.latestVersion;
    final suggest = latest != null && compareSemver(appVersionBase, latest) < 0;
    if (suggest) return _SoftUpdateBanner(info: info, child: child);

    return child;
  }
}

/// A dónde manda el aviso de actualización. Nunca null: si la config no trae
/// tienda para esta plataforma (hoy `ios_store_url` está vacío), cae en el
/// redirector, que detecta el sistema del lado del servidor.
///
/// Un aviso sin destino es peor que no avisar: dice que hay algo nuevo y deja
/// al usuario sin manera de bajarlo.
String _destinoDeActualizacion(AppVersionInfo info) =>
    appDownloadTarget(
      androidStoreUrl: info.androidStoreUrl,
      iosStoreUrl: info.iosStoreUrl,
    ) ??
    kAppDownloadUrl;

/// Esquema nativo de la tienda para un enlace `https`, o null si no aplica.
///
/// Con la URL web, Android abre PRIMERO el navegador y de ahi salta a Play:
/// dos toques y una pantalla intermedia. `market://` entra directo a la tienda.
/// El id sale del propio enlace en vez de una constante, para que no haya dos
/// sitios que puedan discrepar sobre cual es el paquete.
Uri? _esquemaNativoDeTienda(String url) {
  final u = Uri.tryParse(url);
  if (u == null) return null;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      final id = u.queryParameters['id'];
      // El referrer de la URL web no se traslada, y da igual: sirve para
      // atribuir instalaciones, y aqui la app ya esta instalada.
      return (id == null || id.isEmpty)
          ? null
          : Uri.parse('market://details?id=$id');
    case TargetPlatform.iOS:
      // itms-apps abre la App Store sin pasar por Safari.
      return u.host.contains('apps.apple.com')
          ? u.replace(scheme: 'itms-apps')
          : null;
    default:
      return null;
  }
}

/// Abre la tienda en UN toque. Intenta el esquema nativo y cae al enlace web
/// si no hay tienda instalada que lo atienda (emulador, dispositivo sin Play).
Future<void> _openStore(String url) async {
  final web = Uri.tryParse(url);
  if (web == null) return;

  final nativo = _esquemaNativoDeTienda(url);
  if (nativo != null) {
    try {
      if (await launchUrl(nativo, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Sin tienda que atienda el esquema: se intenta el enlace web.
    }
  }
  try {
    await launchUrl(web, mode: LaunchMode.externalApplication);
  } catch (_) {
    // best-effort: si no se puede abrir, no rompemos la UI.
  }
}

/// Pantalla completa bloqueante (sin botón atrás, no descartable).
class _ForcedUpdateScreen extends StatelessWidget {
  final AppVersionInfo info;

  const _ForcedUpdateScreen({required this.info});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;
    final url = _destinoDeActualizacion(info);
    final msg = info.updateMessage?.isNotEmpty == true
        ? info.updateMessage!
        : 'Debes actualizar la app para continuar.';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: t.space.lg,
                  vertical: t.space.xl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(t.space.lg),
                      decoration: BoxDecoration(
                        color: c.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.system_update_rounded,
                        size: 40,
                        color: c.primary,
                      ),
                    ),
                    t.space.gapLg,
                    Text(
                      'Actualización requerida',
                      textAlign: TextAlign.center,
                      style: t.text.h2.copyWith(color: c.fg),
                    ),
                    t.space.gapSm,
                    Text(
                      msg,
                      textAlign: TextAlign.center,
                      style: t.text.body.copyWith(color: c.fgMuted),
                    ),
                    t.space.gapXl,
                    SButton(
                      label: 'Actualizar',
                      size: SButtonSize.lg,
                      icon: Icons.download_rounded,
                      fullWidth: true,
                      onPressed: () => _openStore(url),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Franja de aviso sobre el `child` normal: hay versión nueva y se puede
/// actualizar. No se descarta - toda ella es un solo destino, la tienda.
class _SoftUpdateBanner extends StatelessWidget {
  final AppVersionInfo info;
  final Widget child;

  const _SoftUpdateBanner({required this.info, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final c = t.color;
    final url = _destinoDeActualizacion(info);
    final msg = info.updateMessage?.isNotEmpty == true
        ? info.updateMessage!
        : 'Hay una nueva versión disponible.';

    return Column(
      children: [
        Expanded(child: child),
        Material(
          color: c.primarySoft,
          // Un solo InkWell sobre toda la franja, sin botones anidados dentro:
          // con varios blancos de toque hay que atinarle a uno, y "Actualizar"
          // como botón aparte compite con el propio aviso. Así cualquier punto
          // de la franja hace lo mismo y basta un toque. La pastilla verde de
          // la derecha es SOLO pintura: sin gesto propio, para no partir el
          // blanco en dos.
          child: InkWell(
            onTap: () => _openStore(url),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.primaryBorder)),
              ),
              // En pantallas curvas el borde inferior no siempre trae inset del
              // sistema, y sin él la franja queda pegada a la curva. `minimum`
              // es un PISO, no una suma: los teléfonos que sí traen barra de
              // gestos conservan su inset y no se les añade nada encima.
              child: SafeArea(
                top: false,
                minimum: EdgeInsets.only(bottom: t.space.sm),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    t.space.md,
                    t.space.sm,
                    t.space.md,
                    t.space.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.system_update_rounded,
                        size: 20,
                        color: c.primary,
                      ),
                      SizedBox(width: t.space.sm),
                      Expanded(
                        child: Text(
                          msg,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.text.bodySmall.copyWith(
                            color: c.fg,
                            height: 1.3,
                          ),
                        ),
                      ),
                      SizedBox(width: t.space.sm),
                      // Enlace, no botón: la franja entera ya es el blanco de
                      // toque, así que una pastilla sólida prometía un segundo
                      // destino que no existe. Mismo verde subrayado que
                      // "¿Olvidaste tu contraseña?" y "Regístrala" del login.
                      Text(
                        'Actualizar',
                        style: t.text.label.copyWith(
                          color: c.primaryHover,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: c.primaryHover,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
