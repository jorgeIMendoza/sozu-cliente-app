import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/features/client/expediente/components/expediente_documentos.dart';
import 'package:sozu_cliente_app/features/client/expediente/layouts/expediente_layout.dart';

/// Todos los anexos de una empresa, en su propia pantalla.
///
/// Son abiertos por naturaleza: reformas, protocolizaciones y lo que pida
/// legal, y pueden pasar de diez. Como filas sueltas entre los requisitos
/// tapaban lo que sí es obligatorio.
class AnexosScreen extends StatelessWidget {
  /// Persona a la que pertenecen. Puede no ser el titular: una empresa
  /// accionista tiene los suyos.
  final int contexto;
  final String titulo;

  const AnexosScreen({super.key, required this.contexto, required this.titulo});

  @override
  Widget build(BuildContext context) => ExpedienteLayout(
    titulo: titulo,
    descripcion:
        'Sube los que te pidan. Ponle a cada uno una descripción para '
        'distinguirlos, y agrega los que necesites.',
    onVolver: () => Navigator.of(context).pop(),
    child: ExpedienteDocumentos(
      contexto: contexto,
      modo: ExpedienteModo.anexos,
    ),
  );
}
