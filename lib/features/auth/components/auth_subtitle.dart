import 'package:flutter/material.dart';
import 'package:sozu_cliente_app/features/auth/layouts/auth_layout.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Subtítulo de apoyo bajo [AuthTitle].
class AuthSubtitle extends StatelessWidget {
  const AuthSubtitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Text(
      text,
      textAlign: kAuthTextAlign,
      style: t.text.body.copyWith(color: t.color.fgMuted),
    );
  }
}
