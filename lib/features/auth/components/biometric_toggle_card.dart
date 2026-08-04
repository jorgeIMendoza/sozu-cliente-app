import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/features/auth/services/biometric_service.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Card de Perfil con el interruptor de acceso por huella / Face ID.
///
/// Se llamaba `BiometricSettingTile`: "tile" es jerga de Material (una fila de
/// lista) y no decía ni que fuera una card ni que llevara un interruptor.
/// Autocontenida: se oculta (SizedBox.shrink) si el dispositivo no soporta
/// biometría (web incluido). Al activar pide autenticar y guarda el refresh
/// token de la sesión ACTUAL; al desactivar borra token + flag.
///
/// API PÚBLICA de la feature `auth`: vive aquí porque la biometría es de auth,
/// pero la consume `screens/perfil_screen.dart`, que es de otra pantalla. Se usa
/// tal cual, sin alias ni copia.
class BiometricToggleCard extends ConsumerStatefulWidget {
  const BiometricToggleCard({super.key});

  @override
  ConsumerState<BiometricToggleCard> createState() =>
      _BiometricToggleCardState();
}

class _BiometricToggleCardState extends ConsumerState<BiometricToggleCard> {
  bool _isSupported = false;
  bool _isEnabled = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bio = BiometricService.instance;
    final isSupported = await bio.isSupported();
    final isEnabled = isSupported && await bio.isEnabled();
    if (!mounted) return;
    setState(() {
      _isSupported = isSupported;
      _isEnabled = isEnabled;
    });
  }

  Future<void> _toggle(bool enable) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    final bio = BiometricService.instance;
    if (enable) {
      final ok = await bio.enable();
      if (!mounted) return;
      setState(() {
        _isEnabled = ok;
        _isBusy = false;
      });
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo activar la biometría.')),
        );
      }
    } else {
      await bio.disable();
      if (!mounted) return;
      setState(() {
        _isEnabled = false;
        _isBusy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Solo clientes: la biometría guarda el refresh token de la sesión ACTUAL, y
    // la de un administrador puede impersonar a cualquier cliente. La
    // impersonación queda cubierta sola porque NO cambia la sesión de Supabase:
    // el perfil sigue siendo el del administrador, así que `hasPortalAccess` es
    // false.
    if (!_isSupported || !ref.watch(authProvider).hasPortalAccess) {
      return const SizedBox.shrink();
    }
    final t = context.s;
    // Margen propio: al colapsar en web no debe quedar hueco en Perfil.
    return Padding(
      padding: EdgeInsets.only(top: t.space.sm),
      child: _card(t),
    );
  }

  Widget _card(SozuTheme t) {
    final tone = t.color;
    return SCard(
      child: Row(
        children: [
          Icon(Icons.fingerprint, size: 20, color: tone.positive),
          SizedBox(width: t.space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inicio de sesión con biometría',
                  style: t.text.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tone.fg,
                  ),
                ),
                SizedBox(height: t.space.xxs),
                Text(
                  _isEnabled
                      ? 'Entras con tu huella o rostro'
                      : 'Usa tu huella o rostro para entrar',
                  style: t.text.caption.copyWith(color: tone.fgMuted),
                ),
              ],
            ),
          ),
          Switch(
            value: _isEnabled,
            activeTrackColor: tone.primary,
            onChanged: _isBusy ? null : _toggle,
          ),
        ],
      ),
    );
  }
}
