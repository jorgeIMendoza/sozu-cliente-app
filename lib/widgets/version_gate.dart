import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/version.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';

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
    final mustForce = info.forceUpdate ||
        (min != null && compareSemver(appVersionBase, min) < 0);
    if (mustForce) return _ForcedUpdateScreen(info: info);

    final latest = info.latestVersion;
    final suggest =
        latest != null && compareSemver(appVersionBase, latest) < 0;
    if (suggest) return _SoftUpdateBanner(info: info, child: child);

    return child;
  }
}

/// URL de la store para la plataforma nativa actual (web-safe:
/// `defaultTargetPlatform` no usa `dart:io`). Null si no hay URL para esta
/// plataforma o si no es Android/iOS.
String? _storeUrlFor(AppVersionInfo info) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return info.androidStoreUrl;
    case TargetPlatform.iOS:
      return info.iosStoreUrl;
    default:
      return null;
  }
}

Future<void> _openStore(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    final theme = Theme.of(context);
    final url = _storeUrlFor(info);
    final msg = info.updateMessage?.isNotEmpty == true
        ? info.updateMessage!
        : 'Debes actualizar la app para continuar.';

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.system_update_rounded,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Actualización requerida',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      msg,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (url != null) ...[
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _openStore(url),
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Actualizar'),
                        ),
                      ),
                    ],
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

/// Banner soft descartable (una sola vez por sesión de arranque) sobre el
/// `child` normal. Usa un flag de estado para no reaparecer en cada rebuild.
class _SoftUpdateBanner extends StatefulWidget {
  final AppVersionInfo info;
  final Widget child;

  const _SoftUpdateBanner({required this.info, required this.child});

  @override
  State<_SoftUpdateBanner> createState() => _SoftUpdateBannerState();
}

class _SoftUpdateBannerState extends State<_SoftUpdateBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return widget.child;

    final theme = Theme.of(context);
    final url = _storeUrlFor(widget.info);
    final msg = widget.info.updateMessage?.isNotEmpty == true
        ? widget.info.updateMessage!
        : 'Hay una nueva versión disponible.';

    return Column(
      children: [
        Expanded(child: widget.child),
        Material(
          color: theme.colorScheme.secondaryContainer,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  Icon(
                    Icons.system_update_rounded,
                    size: 20,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      msg,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  if (url != null)
                    TextButton(
                      onPressed: () => _openStore(url),
                      child: const Text('Actualizar'),
                    ),
                  IconButton(
                    tooltip: 'Ahora no',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: theme.colorScheme.onSecondaryContainer,
                    onPressed: () => setState(() => _dismissed = true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
