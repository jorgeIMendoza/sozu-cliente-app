import 'package:flutter/material.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Filtros "Ver como" del selector de super admin: Proyecto + Unidad.
///
/// Componente **tonto**: recibe el catálogo de proyectos y los valores actuales,
/// y avisa por callbacks. No lee providers.
///
/// **Proyecto se busca escribiendo, no se despliega.** Antes era un
/// `DropdownButtonFormField` que volcaba el catálogo entero: veinte entradas
/// -varias con nombres que no son proyectos inmobiliarios, ver nota abajo- en un
/// menú donde había que cazar la correcta. Ahora se escriben dos letras y se
/// filtra. Ver [SAutocompleteField].
///
/// Responsive: en teléfono los dos campos se apilan. En `Row` con la Unidad fija
/// en 150 px, a 360 px de ancho el nombre del proyecto se truncaba siempre.
///
/// ---
///
/// **Nota sobre el catálogo:** los proyectos vienen de la edge function
/// `admin-avisos-app` (action `catalogos`), que es el catálogo de **avisos** - no
/// está acotado a proyectos inmobiliarios, así que trae entradas como "Productos"
/// o "Mutuo Vive" que no aplican a "Ver como". Este componente NO las filtra por
/// nombre a propósito: una lista negra hardcodeada se desincroniza en cuanto
/// alguien agrega una entrada nueva y esconde el problema real, que es de datos.
/// Solicitud de cambio en `Ejecuciones_manuales/`.
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

    final projectField = SAutocompleteField<CatalogoItem>(
      options: projects,
      value: selected,
      labelOf: (p) => p.nombre,
      labelText: 'Proyecto',
      hintText: 'Escribe el nombre…',
      prefixIcon: Icons.apartment_outlined,
      noResultsLabel: 'Ningún proyecto coincide con',
      enabled: projects.isNotEmpty,
      onSelected: (p) => onProjectChanged(p?.id),
    );

    final unitField = ValueListenableBuilder<TextEditingValue>(
      valueListenable: unitController,
      builder: (context, value, _) => TextField(
        controller: unitController,
        onChanged: onUnitChanged,
        keyboardType: TextInputType.number,
        style: t.text.body.copyWith(color: t.color.fg),
        decoration: InputDecoration(
          labelText: 'Unidad',
          hintText: 'Ej. 411',
          isDense: true,
          prefixIcon: Icon(
            Icons.home_outlined,
            size: 20,
            color: t.color.fgSubtle,
          ),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: t.color.fgSubtle,
                  tooltip: 'Limpiar unidad',
                  onPressed: onUnitCleared,
                ),
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
        SizedBox(width: 150, child: unitField),
      ],
    );
  }
}
