import 'package:flutter/material.dart';

import '../core/version.dart';

/// Cintillo superior "PREVIEW" visible solo en builds que no son de
/// producción (ver [isPreviewBuild] en core/version.dart). Los deploys
/// productivos compilan con `--dart-define=APP_ENV=prod` y no lo muestran.
class PreviewBanner extends StatelessWidget {
  final Widget child;

  const PreviewBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!isPreviewBuild) return child;

    return Column(
      children: [
        Material(
          color: const Color(0xFFB45309),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.construction_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'PREVIEW · build de desarrollo · $appVersionLabel',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
