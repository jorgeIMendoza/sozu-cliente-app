import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/biometric_service.dart';
import '../core/theme.dart';
import 'common.dart';

/// Card de Perfil para activar/desactivar el inicio de sesión con biometría.
/// Autocontenida: se oculta (SizedBox.shrink) si el dispositivo no soporta
/// biometría (web incluido). Al activar pide autenticar y guarda el refresh
/// token de la sesión ACTUAL; al desactivar borra token + flag.
class BiometricSettingTile extends ConsumerStatefulWidget {
  const BiometricSettingTile({super.key});

  @override
  ConsumerState<BiometricSettingTile> createState() =>
      _BiometricSettingTileState();
}

class _BiometricSettingTileState extends ConsumerState<BiometricSettingTile> {
  bool _soportado = false;
  bool _habilitada = false;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final bio = BiometricService.instance;
    final soportado = await bio.soportado();
    final habilitada = soportado && await bio.habilitada();
    if (!mounted) return;
    setState(() {
      _soportado = soportado;
      _habilitada = habilitada;
    });
  }

  Future<void> _toggle(bool activar) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    final bio = BiometricService.instance;
    if (activar) {
      final ok = await bio.habilitar();
      if (!mounted) return;
      setState(() {
        _habilitada = ok;
        _ocupado = false;
      });
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo activar la biometría.'),
          ),
        );
      }
    } else {
      await bio.deshabilitar();
      if (!mounted) return;
      setState(() {
        _habilitada = false;
        _ocupado = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_soportado) return const SizedBox.shrink();
    final tone = SozuTone.of(context);
    // Margen propio: al colapsar en web no debe quedar hueco en Perfil.
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _card(tone),
    );
  }

  Widget _card(SozuTone tone) {
    return AppCard(
      child: Row(
        children: [
          const Icon(
            Icons.fingerprint,
            size: 20,
            color: SozuColors.emerald600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inicio de sesión con biometría',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: tone.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _habilitada
                      ? 'Entras con tu huella o rostro'
                      : 'Usa tu huella o rostro para entrar',
                  style: TextStyle(fontSize: 12, color: tone.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: _habilitada,
            activeTrackColor: SozuColors.emerald500,
            onChanged: _ocupado ? null : _toggle,
          ),
        ],
      ),
    );
  }
}
