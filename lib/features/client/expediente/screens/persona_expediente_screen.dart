import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/features/client/expediente/components/expediente_documentos.dart';
import 'package:sozu_cliente_app/features/client/expediente/layouts/expediente_layout.dart';

/// Expediente de una persona ligada: el representante legal, un accionista, o
/// alguien más abajo del árbol.
///
/// Es la MISMA lista de documentos del titular, apuntada a otra persona con
/// `contexto`. Si esa persona es una empresa, trae además sus propias tarjetas
/// y desde ahí se sigue bajando, que es lo que pide beneficiario controlador.
class PersonaExpedienteScreen extends StatelessWidget {
  final int idPersona;
  final String nombre;

  /// `representante` | `accionista`. Solo para el subtítulo.
  final String rol;

  const PersonaExpedienteScreen({
    super.key,
    required this.idPersona,
    required this.nombre,
    required this.rol,
  });

  @override
  Widget build(BuildContext context) {
    return ExpedienteLayout(
      titulo: nombre,
      descripcion: rol == 'accionista'
          ? 'Documentos de este accionista. Súbelos en PDF, igual que los tuyos.'
          : 'Documentos de tu representante legal. Súbelos en PDF, igual que '
                'los tuyos.',
      onVolver: () => Navigator.of(context).pop(),
      child: ExpedienteDocumentos(
        contexto: idPersona,
        // La cuenta bancaria es del titular, no de cada persona ligada.
        onVerCuentas: null,
      ),
    );
  }
}
