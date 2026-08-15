import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/expediente/components/expediente_documentos.dart';
import 'package:sozu_cliente_app/features/client/expediente/components/expediente_personas.dart';
import 'package:sozu_cliente_app/features/client/expediente/layouts/expediente_layout.dart';
import 'package:sozu_cliente_app/features/client/expediente/providers/expediente_providers.dart';

/// Expediente de una persona ligada: el representante legal, un accionista, o
/// alguien más abajo del árbol.
///
/// Es la MISMA lista de documentos del titular, apuntada a otra persona con
/// `contexto`. Si esa persona es una EMPRESA, su pantalla vuelve a ser una
/// portada: sus documentos de empresa por un lado y sus propias personas
/// ligadas por otro, desde las que se sigue bajando hasta llegar a personas
/// físicas. Eso es lo que exige beneficiario controlador y por eso el recorrido
/// es recursivo: se detiene en la primera persona física, no antes.
class PersonaExpedienteScreen extends ConsumerWidget {
  final int idPersona;
  final String nombre;

  /// `empresa` | `representante` | `accionista`.
  final String rol;

  /// Esa persona es una empresa. Sale de la tarjeta que abrió esta pantalla,
  /// así que la portada se pinta sin esperar a la respuesta del backend.
  final bool esMoral;

  /// Solo en la ficha de la empresa: abre sus cuentas bancarias.
  final VoidCallback? onVerCuentas;

  const PersonaExpedienteScreen({
    super.key,
    required this.idPersona,
    required this.nombre,
    required this.rol,
    this.esMoral = false,
    this.onVerCuentas,
  });

  /// La ficha de la EMPRESA es la hoja de documentos y nada más: sus personas
  /// ligadas ya se pintan en la portada desde la que se entró, y repetirlas
  /// aquí sería el mismo árbol dos veces.
  bool get _esFichaDeEmpresa => rol == 'empresa';

  /// Una empresa del árbol repite el ciclo completo, así que su portada
  /// necesita el mismo botón de alta que la del titular.
  bool get _rehaceElCiclo => esMoral && !_esFichaDeEmpresa;

  void _abrirPersona(BuildContext context, ExpedientePersona p) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PersonaExpedienteScreen(
            idPersona: p.idPersona,
            nombre: p.nombre,
            rol: p.rol,
            esMoral: p.esMoral,
          ),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exp = _rehaceElCiclo
        ? ref.watch(personaExpedienteProvider(idPersona)).valueOrNull
        : null;

    return ExpedienteLayout(
      titulo: nombre,
      descripcion: switch (rol) {
        'empresa' =>
          'Documentos de tu empresa y sus datos bancarios. Súbelos en PDF.',
        _ when _rehaceElCiclo =>
          'Es una empresa: suben sus documentos y se registra a su '
              'representante legal y a sus accionistas, hasta llegar a '
              'personas físicas.',
        'accionista' =>
          'Documentos de este accionista. Súbelos en PDF, igual que los tuyos.',
        _ =>
          'Documentos de tu representante legal. Súbelos en PDF, igual que los '
              'tuyos.',
      },
      accion: exp != null
          ? ExpedientePersonas(
              personas: exp.personas,
              contexto: exp.contexto,
              umbral: exp.umbralAccionista,
              onAbrir: (p) => _abrirPersona(context, p),
              soloBoton: true,
            )
          : null,
      etiquetaVolver: 'Volver',
      onVolver: () => Navigator.of(context).pop(),
      child: ExpedienteDocumentos(
        contexto: idPersona,
        esMoral: esMoral,
        // La empresa (y cualquier persona física) va directo a su lista de
        // documentos; una empresa del árbol abre su portada y sigue bajando.
        modo: _rehaceElCiclo ? ExpedienteModo.auto : ExpedienteModo.documentos,
        // La cuenta bancaria es de la EMPRESA: se pinta en su ficha, no en la
        // de un representante ni la de un accionista.
        onVerCuentas: _esFichaDeEmpresa ? onVerCuentas : null,
      ),
    );
  }
}
