import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/expediente/components/expediente_documentos.dart';
import 'package:sozu_cliente_app/features/client/expediente/components/expediente_personas.dart';
import 'package:sozu_cliente_app/features/client/expediente/providers/expediente_providers.dart';
import 'package:sozu_cliente_app/features/client/expediente/layouts/expediente_layout.dart';
import 'package:sozu_cliente_app/features/client/expediente/screens/persona_expediente_screen.dart';
import 'package:sozu_cliente_app/features/client/profile/screens/perfil_detalle_screens.dart'
    show PerfilCuentasScreen;
import 'package:sozu_cliente_app/widgets/portal_widgets.dart';

/// Expediente del cliente: los documentos que se le piden, agrupados según sea
/// persona física o moral, con su estatus y la carga de cada uno.
class ExpedienteScreen extends ConsumerWidget {
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

  void _abrirPersona(BuildContext context, ExpedientePersona p) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PersonaExpedienteScreen(
            idPersona: p.idPersona,
            nombre: p.nombre,
            rol: p.rol,
          ),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // El alta vive en el encabezado, a la derecha del "Volver": es la accion de
    // la pantalla y hundida entre las tarjetas habia que buscarla.
    final exp = ref.watch(identityFileProvider).valueOrNull;
    return ExpedienteLayout(
      titulo: 'Mis documentos',
      accion: exp != null && exp.esMoral
          ? ExpedientePersonas(
              personas: exp.personas,
              contexto: exp.contexto,
              umbral: exp.umbralAccionista,
              // Tras el alta se entra directo a subir sus documentos, así que
              // el botón del encabezado necesita a dónde abrir tanto como las
              // tarjetas.
              onAbrir: (p) => _abrirPersona(context, p),
              soloBoton: true,
            )
          : null,
      descripcion:
          'Súbelos en PDF y validamos los datos por ti. Antes de guardarlos '
          'te mostramos lo que leímos para que lo confirmes.',
      onVolver: () => _volver(context),
      child: ExpedienteDocumentos(onVerCuentas: () => _verCuentas(context)),
    );
  }
}
