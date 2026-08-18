import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/features/admin/providers/client_filters_provider.dart';

/// El store existe para que los filtros SOBREVIVAN a salir del selector y
/// volver. Eran campos del `State` de la pantalla y se perdian al navegar a
/// avisos o al entrar como un cliente y regresar.
void main() {
  test('nace vacio y sin nada que limpiar', () {
    final f = ClientFiltersController();
    expect(f.query, '');
    expect(f.projectId, isNull);
    expect(f.unit, '');
    expect(f.isDirty, isFalse);
  });

  test('cualquiera de los tres filtros lo ensucia', () {
    for (final poner in <void Function(ClientFiltersController)>[
      (f) => f.setQuery('alex'),
      (f) => f.setProjectId(7),
      (f) => f.setUnit('402'),
    ]) {
      final f = ClientFiltersController();
      poner(f);
      expect(f.isDirty, isTrue);
    }
  });

  test('clear deja los TRES en blanco de una vez', () {
    // Es lo que hace util al boton global: antes habia que vaciar el buscador,
    // quitar el proyecto y borrar la unidad por separado.
    final f = ClientFiltersController()
      ..setQuery('alex')
      ..setProjectId(7)
      ..setUnit('402');

    f.clear();

    expect(f.query, '');
    expect(f.projectId, isNull);
    expect(f.unit, '');
    expect(f.isDirty, isFalse);
  });

  test('avisa a quien escucha, y solo cuando el valor CAMBIA', () {
    var avisos = 0;
    final f = ClientFiltersController()..addListener(() => avisos++);

    f.setQuery('alex');
    expect(avisos, 1);

    // Mismo valor: sin notificar. Sin esta guarda, cada pulsacion que no cambia
    // el texto (flechas, teclas muertas) reconstruye la lista de clientes.
    f.setQuery('alex');
    expect(avisos, 1);

    f.setProjectId(7);
    expect(avisos, 2);
  });

  test('clear sin nada puesto no notifica', () {
    var avisos = 0;
    final f = ClientFiltersController()..addListener(() => avisos++);
    f.clear();
    expect(avisos, 0);
  });
}
