import 'package:flutter/material.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Ancho del campo Unidad en escritorio. No es espaciado: es el ancho de un
/// control de 3-4 dígitos.
const double _unitFieldWidth = 150;

/// Filtros "Ver como" del selector: Proyecto + Unidad. Componente tonto: recibe
/// valores y avisa por callbacks, no lee providers.
///
/// Proyecto se busca escribiendo ([SAutocompleteField]), no se despliega: el
/// catálogo tiene ~20 entradas. En teléfono los dos campos se apilan.
///
/// El catálogo llega de `admin-avisos-app` (action `catalogos`), que es el de
/// AVISOS, así que trae entradas que no son proyectos inmobiliarios. NO se
/// filtran por nombre aquí: es un problema de datos y hay una solicitud de
/// cambio pendiente (ver `docs/adr/ESTADO.md`).
class ClientFilters extends StatelessWidget {
  const ClientFilters({
    super.key,
    required this.projects,
    required this.projectId,
    required this.onProjectChanged,
    required this.unitController,
    required this.onUnitChanged,
    required this.onUnitCleared,
  });

  final List<CatalogoItem> projects;
  final int? projectId;
  final ValueChanged<int?> onProjectChanged;

  final TextEditingController unitController;
  final ValueChanged<String> onUnitChanged;
  final VoidCallback onUnitCleared;

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final isStacked = context.bp.isMobile;

    CatalogoItem? selected;
    for (final p in projects) {
      if (p.id == projectId) {
        selected = p;
        break;
      }
    }

    // Sin icono: el campo ya dice "Proyecto" y al escribir salen los proyectos.
    // Un icono de edificio no agrega informacion y roba ancho al nombre.
    final projectField = SAutocompleteField<CatalogoItem>(
      options: projects,
      value: selected,
      labelOf: (p) => p.nombre,
      labelText: 'Proyecto',
      hintText: 'Margot, Bottura, Daiku...',
      noResultsLabel: 'Ningún proyecto coincide con',
      enabled: projects.isNotEmpty,
      onSelected: (p) => onProjectChanged(p?.id),
    );

    final unitField = ValueListenableBuilder<TextEditingValue>(
      valueListenable: unitController,
      builder: (context, value, _) => STextField(
        controller: unitController,
        onChanged: onUnitChanged,
        keyboardType: TextInputType.number,
        label: 'Unidad',
        hint: '101',
        prefixIcon: Icons.home_outlined,
        size: STextFieldSize.md,
        suffix: value.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: t.color.fgSubtle,
                tooltip: 'Limpiar unidad',
                onPressed: onUnitCleared,
              ),
      ),
    );

    if (isStacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          projectField,
          SizedBox(height: t.space.xs),
          unitField,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: projectField),
        SizedBox(width: t.space.xs),
        SizedBox(width: _unitFieldWidth, child: unitField),
      ],
    );
  }
}
