import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/password_rules.dart';

/// Cambio OBLIGATORIO de contraseña temporal (debe_cambiar_password=true).
class ChangePasswordForcedScreen extends ConsumerStatefulWidget {
  const ChangePasswordForcedScreen({super.key});

  @override
  ConsumerState<ChangePasswordForcedScreen> createState() =>
      _ChangePasswordForcedScreenState();
}

class _ChangePasswordForcedScreenState
    extends ConsumerState<ChangePasswordForcedScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pwd = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;
  String? _formError;
  String _pwdValue = '';

  @override
  void dispose() {
    _pwd.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _formError = null;
    });
    try {
      await ref.read(authProvider).updatePassword(_pwd.text);
      if (mounted) context.go('/inicio');
    } catch (_) {
      setState(() {
        _formError = 'No pudimos actualizar la contraseña. Intenta de nuevo.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Scaffold(
      backgroundColor: tone.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: tone.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock_outline,
                              color: SozuColors.emerald600, size: 26),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Crea tu contraseña',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: tone.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tu acceso es temporal. Define una contraseña personal '
                          'para continuar.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 14, color: tone.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _pwd,
                      obscureText: true,
                      decoration:
                          const InputDecoration(hintText: 'Nueva contraseña'),
                      onChanged: (v) => setState(() => _pwdValue = v),
                      validator: (v) =>
                          passwordValida(v ?? '') ? null : 'Cumple todas las reglas',
                    ),
                    const SizedBox(height: 12),
                    PasswordRulesChecklist(value: _pwdValue),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirm,
                      obscureText: true,
                      decoration:
                          const InputDecoration(hintText: 'Confirmar contraseña'),
                      validator: (v) =>
                          v == _pwd.text ? null : 'Las contraseñas no coinciden',
                    ),

                    if (_formError != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tone.negative.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _formError!,
                          style: TextStyle(fontSize: 14, color: tone.negative),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('Guardar y continuar'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () async {
                        await ref.read(authProvider).signOut();
                        if (context.mounted) context.go('/login');
                      },
                      child: Text(
                        'Cancelar y salir',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: tone.textSecondary,
                        ),
                      ),
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
