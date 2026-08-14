import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/expediente/components/expediente_card.dart'
    show expedienteEstatusStyle;
import 'package:sozu_cliente_app/features/client/expediente/providers/expediente_providers.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Representantes legales y accionistas de una persona moral: una tarjeta por
/// persona y un botón para agregar.
///
/// Los documentos de cada uno NO se pintan aquí. Con dos accionistas eso eran
/// dieciocho filas en la misma pantalla; ahora cada quien tiene la suya, a la
/// que se entra desde su tarjeta.
class ExpedientePersonas extends ConsumerStatefulWidget {
  final List<ExpedientePersona> personas;

  /// De quién cuelgan: el titular, o la empresa cuya ficha se está viendo.
  final int contexto;

  /// Porcentaje mínimo que el backend exige a un accionista.
  final double umbral;

  /// Abre la ficha de esa persona.
  final void Function(ExpedientePersona) onAbrir;

  const ExpedientePersonas({
    super.key,
    required this.personas,
    required this.contexto,
    required this.umbral,
    required this.onAbrir,
  });

  @override
  ConsumerState<ExpedientePersonas> createState() => _ExpedientePersonasState();
}

class _ExpedientePersonasState extends ConsumerState<ExpedientePersonas> {
  bool _guardando = false;

  List<ExpedientePersona> get _representantes =>
      widget.personas.where((p) => !p.esAccionista).toList();
  List<ExpedientePersona> get _accionistas =>
      widget.personas.where((p) => p.esAccionista).toList();

  Future<void> _agregar() async {
    final alta = await showDialog<_AltaPersona>(
      context: context,
      builder: (_) => _AltaPersonaDialog(umbral: widget.umbral),
    );
    if (alta == null || !mounted) return;

    setState(() => _guardando = true);
    try {
      await ref
          .read(expedientePortProvider)
          .addPerson(
            rol: alta.rol,
            nombre: alta.nombre,
            tipoPersona: alta.tipoPersona,
            porcentaje: alta.porcentaje,
            contexto: widget.contexto,
          );
      ref.invalidate(identityFileProvider);
      _aviso('Listo, ya puedes subir sus documentos');
    } on DocumentoInvalidoError catch (e) {
      _aviso(e.reason, error: true);
    } on ApiError catch (e) {
      _aviso(_mensajeDe(e), error: true);
    } catch (_) {
      _aviso('No se pudo guardar. Intenta de nuevo.', error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _quitar(ExpedientePersona p) async {
    final ok = await showSConfirm(
      context,
      titulo: 'Quitar a ${p.nombre}',
      mensaje:
          'Se saca de tu expediente. Puedes volver a agregarla cuando quieras.',
      etiquetaAceptar: 'Quitar',
      tono: SConfirmTone.warning,
    );
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(expedientePortProvider)
          .removePerson(idPersona: p.idPersona, contexto: widget.contexto);
      ref.invalidate(identityFileProvider);
    } on DocumentoInvalidoError catch (e) {
      _aviso(e.reason, error: true);
    } on ApiError catch (e) {
      _aviso(_mensajeDe(e), error: true);
    }
  }

  String _mensajeDe(ApiError e) => switch (e.code) {
    'porcentaje_menor' =>
      'Solo hace falta el expediente de accionistas con más del '
          '${widget.umbral.toStringAsFixed(0)}%.',
    'tiene_documentos' =>
      'Ya subiste documentos suyos. Pídele a tu asesor que lo quite.',
    'ligada_por_asesor' =>
      'A esta persona la registró tu asesor. Pídele a él que la quite.',
    'solo_persona_moral' => 'Esto solo aplica a empresas.',
    'nombre_requerido' => 'Escribe el nombre completo.',
    'porcentaje_invalido' => 'El porcentaje debe estar entre 1 y 100.',
    'ciclo' => 'Esa empresa ya cuelga de esta.',
    _ => 'No se pudo guardar (${e.code}).',
  };

  void _aviso(String mensaje, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: Duration(seconds: error ? 7 : 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Titulo('Representante legal'),
        SizedBox(height: t.space.xs),
        if (_representantes.isEmpty)
          _Vacio(
            texto: 'Agrega a tu representante legal para subir sus documentos.',
          )
        else
          for (final p in _representantes) ...[
            _PersonaCard(
              persona: p,
              onAbrir: () => widget.onAbrir(p),
              onQuitar: p.puedeEliminar ? () => _quitar(p) : null,
            ),
            SizedBox(height: t.space.xs),
          ],

        SizedBox(height: t.space.md),
        _Titulo('Accionistas con más del ${widget.umbral.toStringAsFixed(0)}%'),
        SizedBox(height: t.space.xs),
        if (_accionistas.isEmpty)
          _Vacio(
            texto:
                'Agrega a los accionistas que superen el '
                '${widget.umbral.toStringAsFixed(0)}% de las acciones.',
          )
        else
          for (final p in _accionistas) ...[
            _PersonaCard(
              persona: p,
              onAbrir: () => widget.onAbrir(p),
              onQuitar: p.puedeEliminar ? () => _quitar(p) : null,
            ),
            SizedBox(height: t.space.xs),
          ],

        SizedBox(height: t.space.sm),
        SButton.secondary(
          label: 'Agregar persona',
          icon: Icons.person_add_alt_outlined,
          loading: _guardando,
          onPressed: _agregar,
        ),
      ],
    );
  }
}

class _Titulo extends StatelessWidget {
  final String texto;
  const _Titulo(this.texto);

  @override
  Widget build(BuildContext context) => Text(
    texto.toUpperCase(),
    style: context.s.text.overline.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: context.s.color.fgSubtle,
    ),
  );
}

class _Vacio extends StatelessWidget {
  final String texto;
  const _Vacio({required this.texto});

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.s.space.md,
        vertical: context.s.space.sm,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: tone.border),
        borderRadius: context.s.radius.smBorder,
        color: tone.surfaceAlt,
      ),
      child: Text(
        'Falta registrar $texto.',
        style: context.s.text.caption.copyWith(color: tone.fgMuted),
      ),
    );
  }
}

/// Tarjeta de una persona ligada: nombre, rol y cuánto lleva de su expediente.
class _PersonaCard extends StatelessWidget {
  final ExpedientePersona persona;
  final VoidCallback onAbrir;
  final VoidCallback? onQuitar;

  const _PersonaCard({
    required this.persona,
    required this.onAbrir,
    this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final st = expedienteEstatusStyle(
      persona.completo ? 'aprobado' : 'pendiente',
      tone,
    );
    final falta = persona.requeridosTotal - persona.requeridosAprobados;

    return SPressable(
      onTap: onAbrir,
      borderRadius: context.s.radius.smBorder,
      semanticLabel: 'Ver documentos de ${persona.nombre}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.s.space.md,
          vertical: context.s.space.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: tone.border),
          borderRadius: context.s.radius.smBorder,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tone.surfaceAlt,
                borderRadius: context.s.radius.mdBorder,
              ),
              alignment: Alignment.center,
              child: Icon(
                persona.esMoral
                    ? Icons.apartment_outlined
                    : Icons.person_outline,
                size: 17,
                color: tone.fgMuted,
              ),
            ),
            SizedBox(width: context.s.space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        persona.nombre,
                        style: context.s.text.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tone.fg,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: st.bg,
                          borderRadius: context.s.radius.fullBorder,
                        ),
                        child: Text(
                          persona.completo ? 'Completo' : 'Faltan $falta',
                          style: context.s.text.overline.copyWith(
                            fontWeight: FontWeight.w700,
                            color: st.fg,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (persona.porcentaje != null)
                        '${persona.porcentaje!.toStringAsFixed(persona.porcentaje! % 1 == 0 ? 0 : 2)}% de las acciones',
                      if (persona.esMoral) 'Empresa',
                    ].join(' · '),
                    style: context.s.text.caption.copyWith(
                      fontWeight: FontWeight.w500,
                      color: tone.fgSubtle,
                    ),
                  ),
                ],
              ),
            ),
            if (onQuitar != null)
              IconButton(
                tooltip: 'Quitar',
                iconSize: 17,
                color: tone.fgSubtle,
                icon: const Icon(Icons.delete_outline),
                onPressed: onQuitar,
              ),
            Icon(Icons.chevron_right, size: 20, color: tone.fgSubtle),
          ],
        ),
      ),
    );
  }
}

/// Lo que el cliente captura al agregar a alguien.
typedef _AltaPersona = ({
  String rol,
  String nombre,
  String tipoPersona,
  double? porcentaje,
});

/// Alta de una persona ligada. Se piden los datos mínimos: el resto sale de sus
/// documentos, igual que con el titular.
class _AltaPersonaDialog extends StatefulWidget {
  final double umbral;
  const _AltaPersonaDialog({required this.umbral});

  @override
  State<_AltaPersonaDialog> createState() => _AltaPersonaDialogState();
}

class _AltaPersonaDialogState extends State<_AltaPersonaDialog> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _porcentaje = TextEditingController();
  String _rol = 'representante';
  String _tipo = 'pf';

  @override
  void dispose() {
    _nombre.dispose();
    _porcentaje.dispose();
    super.dispose();
  }

  void _guardar() {
    if (_form.currentState?.validate() != true) return;
    Navigator.of(context).pop((
      rol: _rol,
      nombre: _nombre.text.trim(),
      tipoPersona: _tipo,
      porcentaje: _rol == 'accionista'
          ? double.tryParse(_porcentaje.text.trim().replaceAll(',', '.'))
          : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    return AlertDialog(
      title: const Text('Agregar persona'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SSelectField<String>(
                label: 'Rol',
                value: _rol,
                opciones: const [
                  (value: 'representante', label: 'Representante legal'),
                  (value: 'accionista', label: 'Accionista mayoritario'),
                ],
                onChanged: (v) => setState(() => _rol = v ?? 'representante'),
              ),
              SizedBox(height: t.space.sm),
              STextField(
                controller: _nombre,
                label: 'Nombre o razón social',
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().length < 3
                    ? 'Escribe el nombre completo'
                    : null,
              ),
              SizedBox(height: t.space.sm),
              SSelectField<String>(
                label: 'Tipo de persona',
                value: _tipo,
                opciones: const [
                  (value: 'pf', label: 'Persona física'),
                  (value: 'pm', label: 'Persona moral'),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? 'pf'),
              ),
              if (_rol == 'accionista') ...[
                SizedBox(height: t.space.sm),
                STextField(
                  controller: _porcentaje,
                  label: '% de acciones',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    final p = double.tryParse(
                      (v ?? '').trim().replaceAll(',', '.'),
                    );
                    if (p == null || p <= 0 || p > 100) {
                      return 'Un número entre 1 y 100';
                    }
                    if (p <= widget.umbral) {
                      return 'Solo se piden los que pasan del '
                          '${widget.umbral.toStringAsFixed(0)}%';
                    }
                    return null;
                  },
                ),
              ],
              if (_tipo == 'pm') ...[
                SizedBox(height: t.space.sm),
                Text(
                  'Al ser empresa, después habrá que registrar a su propio '
                  'representante y a sus accionistas.',
                  style: t.text.caption.copyWith(color: t.color.fgMuted),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Agregar')),
      ],
    );
  }
}
