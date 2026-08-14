import 'package:flutter/widgets.dart';

/// Fuera de web no hay iframe: el visor in-app de `pdfx` es el bueno ahi.
/// Este stub nunca se construye; existe para que el import condicional resuelva.
class SPdfFrame extends StatelessWidget {
  final String url;
  const SPdfFrame({super.key, required this.url});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
