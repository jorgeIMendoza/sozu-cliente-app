import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sozu_cliente_app/core/version.dart';
import 'package:sozu_cliente_app/features/app_download/components/app_download.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/shared/providers/shared_providers.dart';
import 'package:sozu_cliente_app/shared/providers/update_prompt_provider.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// "Version gate" de la app NATIVA (Android/iOS): aviso o forzado de
/// actualización según lo que entregue la edge function `cliente-app-version`.
///
/// - En WEB no aplica nunca (`kIsWeb`): la web se auto-actualiza por hosting.
/// - Forzado (bloqueante) si `force_update` o la versión actual < `min_version`.
/// - Sugerencia (aviso descartable) si la versión actual < `latest_version`.
/// - Ante error/loading (provider null) => deja pasar el `child` sin cambios.
///
/// **Los dos niveles son deliberadamente distintos.** El forzado no tiene
/// salida: es la palanca de negocio (`min_version`) para sacar del campo a los
/// muy rezagados. El suave sale UNA vez, se puede posponer y se calla hasta el
/// día siguiente o hasta que haya una versión más nueva
/// ([UpdatePromptStore]). Antes era una franja fija en todas las pantallas sin
/// manera de descartarla: lo peor de los dos mundos, molestaba siempre y no
/// obligaba a nada.
///
/// Nota: se monta como `builder:` del MaterialApp.router, ARRIBA del Navigator.
/// Por eso el aviso se pinta como capa en el árbol y no con `showDialog`, que
/// requeriría un Navigator ancestro que aquí no existe.
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
    if (suggest) {
      return _SoftUpdatePrompt(info: info, latest: latest, child: child);
    }

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

/// Aviso de versión nueva: capa modal sobre la app, con salida.
///
/// Sale al abrir y solo si [UpdatePromptStore] lo permite. "Ahora no" lo calla
/// hasta el día siguiente o hasta que salga una versión posterior; no lo apaga
/// para siempre, que es lo que haría inútil el aviso.
///
/// Capa en el árbol y no `showDialog`: aquí no hay Navigator ancestro.
class _SoftUpdatePrompt extends ConsumerStatefulWidget {
  const _SoftUpdatePrompt({
    required this.info,
    required this.latest,
    required this.child,
  });

  final AppVersionInfo info;
  final String latest;
  final Widget child;

  @override
  ConsumerState<_SoftUpdatePrompt> createState() => _SoftUpdatePromptState();
}

class _SoftUpdatePromptState extends ConsumerState<_SoftUpdatePrompt> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _visible = _debeSalir();
  }

  @override
  void didUpdateWidget(_SoftUpdatePrompt old) {
    super.didUpdateWidget(old);
    // Si el backend publica una version posterior con la app abierta, el aviso
    // tiene que volver: sin esto `_visible` se decidia solo en el primer
    // montaje y posponer una version callaba tambien a la siguiente hasta
    // reiniciar la app.
    if (old.latest != widget.latest) {
      setState(() => _visible = _debeSalir());
    }
  }

  bool _debeSalir() => ref
      .read(updatePromptStoreProvider)
      .shouldPrompt(widget.latest, today: DateTime.now());

  Future<void> _ahoraNo() async {
    setState(() => _visible = false);
    await ref
        .read(updatePromptStoreProvider)
        .snooze(widget.latest, today: DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return widget.child;

    final t = context.s;
    final c = t.color;
    final url = _destinoDeActualizacion(widget.info);
    final msg = widget.info.updateMessage?.isNotEmpty == true
        ? widget.info.updateMessage!
        : 'Ya está disponible una versión nueva de la app, con las últimas '
              'mejoras y correcciones.';

    return Stack(
      children: [
        widget.child,
        // El velo aísla el aviso del fondo y ademas se come los toques: sin el,
        // se puede seguir usando la app por debajo con el aviso encima.
        ModalBarrier(color: c.overlay, dismissible: false),
        Center(
          child: Padding(
            padding: EdgeInsets.all(t.space.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Material(
                color: c.surface,
                borderRadius: t.radius.lgBorder,
                child: Padding(
                  padding: EdgeInsets.all(t.space.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.system_update_rounded,
                        size: 40,
                        color: c.primary,
                      ),
                      t.space.gapMd,
                      Text(
                        'Hay una versión nueva',
                        textAlign: TextAlign.center,
                        style: t.text.h3.copyWith(color: c.fg),
                      ),
                      t.space.gapXs,
                      Text(
                        msg,
                        textAlign: TextAlign.center,
                        style: t.text.body.copyWith(color: c.fgMuted),
                      ),
                      t.space.gapLg,
                      SButton(
                        label: 'Actualizar',
                        size: SButtonSize.lg,
                        icon: Icons.download_rounded,
                        onPressed: () => _openStore(url),
                      ),
                      t.space.gapXs,
                      SButton.ghost(label: 'Ahora no', onPressed: _ahoraNo),
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
