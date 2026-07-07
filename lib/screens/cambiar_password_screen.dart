import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/password_rules.dart';

/// Cambio voluntario de contraseña: exige la contraseña ACTUAL.
class CambiarPasswordScreen extends ConsumerStatefulWidget {
  const CambiarPasswordScreen({super.key});

  @override
  ConsumerState<CambiarPasswordScreen> createState() =>
      _CambiarPasswordScreenState();
}

class _CambiarPasswordScreenState extends ConsumerState<CambiarPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _pwd = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;
  String? _formError;
  String _pwdValue = '';

  @override
  void dispose() {
    _current.dispose();
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
      await ref.read(authProvider).changePassword(_current.text, _pwd.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tu contraseña se actualizó correctamente.')));
      context.pop();
    } on WrongCurrentPasswordError {
      setState(() {
        _formError = 'La contraseña actual es incorrecta.';
        _submitting = false;
      });
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
      appBar: AppBar(
        backgroundColor: tone.surface,
        title: const Text('Cambiar contraseña'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Contraseña actual', style: _label(tone)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _current,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: '••••••••'),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Ingresa tu contraseña actual'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text('Nueva contraseña', style: _label(tone)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _pwd,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: '••••••••'),
                    onChanged: (v) => setState(() => _pwdValue = v),
                    validator: (v) {
                      if (!passwordValida(v ?? '')) return 'Cumple todas las reglas';
                      if (v == _current.text) {
                        return 'La nueva contraseña debe ser distinta a la actual';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  PasswordRulesChecklist(value: _pwdValue),
                  const SizedBox(height: 16),
                  Text('Confirmar nueva contraseña', style: _label(tone)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _confirm,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: '••••••••'),
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
                      child: Text(_formError!,
                          style:
                              TextStyle(fontSize: 14, color: tone.negative)),
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
                        : const Text('Actualizar contraseña'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _label(SozuTone tone) => TextStyle(
      fontSize: 14, fontWeight: FontWeight.w600, color: tone.textSecondary);
}
