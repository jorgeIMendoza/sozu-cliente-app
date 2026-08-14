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

  /// `empresa` | `representante` | `accionista`.
  final String rol;

  /// Solo en la ficha de la empresa: abre sus cuentas bancarias.
  final VoidCallback? onVerCuentas;

  const PersonaExpedienteScreen({
    super.key,
    required this.idPersona,
    required this.nombre,
    required this.rol,
    this.onVerCuentas,
  });

  @override
  Widget build(BuildContext context) {
    return ExpedienteLayout(
      titulo: nombre,
      descripcion: switch (rol) {
        'empresa' =>
          'Documentos de tu empresa y sus datos bancarios. Súbelos en PDF.',
        'accionista' =>
          'Documentos de este accionista. Súbelos en PDF, igual que los tuyos.',
        _ =>
          'Documentos de tu representante legal. Súbelos en PDF, igual que los '
              'tuyos.',
      },
      onVolver: () => Navigator.of(context).pop(),
      child: ExpedienteDocumentos(
        contexto: idPersona,
        modo: ExpedienteModo.documentos,
        // La cuenta bancaria es de la EMPRESA: se pinta en su ficha, no en la
        // de un representante ni la de un accionista.
        onVerCuentas: rol == 'empresa' ? onVerCuentas : null,
      ),
    );
  }
}
