import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Reglas de contraseña SOZU (mismas del portal admin):
/// min 8 + mayúscula + minúscula + número + símbolo.
class PasswordRule {
  final String label;
  final bool Function(String) test;
  const PasswordRule(this.label, this.test);
}

final passwordRules = <PasswordRule>[
  PasswordRule('Al menos 8 caracteres', (v) => v.length >= 8),
  PasswordRule('Una mayúscula', (v) => RegExp(r'[A-Z]').hasMatch(v)),
  PasswordRule('Una minúscula', (v) => RegExp(r'[a-z]').hasMatch(v)),
  PasswordRule('Un número', (v) => RegExp(r'[0-9]').hasMatch(v)),
  PasswordRule('Un símbolo especial', (v) => RegExp(r'[^A-Za-z0-9]').hasMatch(v)),
];

bool passwordValida(String v) => passwordRules.every((r) => r.test(v));

/// Checklist en vivo de las reglas.
class PasswordRulesChecklist extends StatelessWidget {
  final String value;

  const PasswordRulesChecklist({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in passwordRules)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  r.test(value) ? Icons.check_circle : Icons.circle_outlined,
                  size: 16,
                  color: r.test(value) ? SozuColors.emerald500 : tone.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  r.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: r.test(value) ? tone.positive : tone.textMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
