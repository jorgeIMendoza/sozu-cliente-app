import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/features/client/expediente/components/expediente_documentos.dart';
import 'package:sozu_cliente_app/features/client/expediente/layouts/expediente_layout.dart';
import 'package:sozu_cliente_app/features/client/profile/screens/perfil_detalle_screens.dart'
    show PerfilCuentasScreen;
import 'package:sozu_cliente_app/widgets/portal_widgets.dart';

/// Expediente del cliente: los documentos que se le piden, agrupados según sea
/// persona física o moral, con su estatus y la carga de cada uno.
class ExpedienteScreen extends StatelessWidget {
  const ExpedienteScreen({super.key});

  void _volver(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/perfil');
    }
  }

  /// Vista (solo lectura) de cuentas bancarias: diálogo centrado en el portal
  /// ancho, pantalla en móvil.
  void _verCuentas(BuildContext context) {
    if (isPortalMode(context)) {
      showPortalDialog<void>(context, child: const PerfilCuentasScreen());
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PerfilCuentasScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExpedienteLayout(
      titulo: 'Mis documentos',
      descripcion:
          'Súbelos en PDF y validamos los datos por ti. Antes de guardarlos '
          'te mostramos lo que leímos para que lo confirmes.',
      onVolver: () => _volver(context),
      child: ExpedienteDocumentos(onVerCuentas: () => _verCuentas(context)),
    );
  }
}
