import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/properties/services/escrituracion.dart';

ProductoDetalle _producto({
  required String nombre,
  String? categoria,
  double monto = 0,
  double avance = 0,
}) => ProductoDetalle.fromJson({
  'id': 1,
  'nombre': nombre,
  'monto': monto,
  'avance': avance,
  if (categoria != null) 'categoria': categoria,
});

PropiedadDetalle _propiedad({
  double monto = 0,
  double pagado = 0,
  List<ProductoDetalle> productos = const [],
}) => PropiedadDetalle.fromJson({
  'id': 1,
  'nombre': 'U-709',
  'monto': monto,
  'pagado': pagado,
  'productos': [
    for (final p in productos)
      {
        'id': p.id,
        'nombre': p.nombre,
        'monto': p.monto,
        'avance': p.avance,
        if (p.categoria != null) 'categoria': p.categoria,
      },
  ],
});

void main() {
  group('esEscriturable', () {
    test('la categoria del backend manda sobre el nombre', () {
      expect(
        Escrituracion.esEscriturable(
          _producto(nombre: 'Lo que sea', categoria: 'Bodega'),
        ),
        isTrue,
      );
      expect(
        Escrituracion.esEscriturable(
          _producto(nombre: 'Bodegas Bottura', categoria: 'Condensadora'),
        ),
        isFalse,
      );
    });

    test('sin categoria cae al nombre del catalogo', () {
      for (final nombre in [
        'Bodegas Bottura',
        'Estacionamientos Daiku',
        'Estacionamientos Monócolo',
        'Cajón de estacionamiento',
      ]) {
        expect(
          Escrituracion.esEscriturable(_producto(nombre: nombre)),
          isTrue,
          reason: nombre,
        );
      }
      for (final nombre in [
        'Condensadoras Bottura',
        'Paquete amueblado Soft',
        'Persianas/cortinas Kind',
        'Retiro e Instalacion de Puerta',
      ]) {
        expect(
          Escrituracion.esEscriturable(_producto(nombre: nombre)),
          isFalse,
          reason: nombre,
        );
      }
    });
  });

  group('Escrituracion.de', () {
    test('el total es departamento + bodega + estacionamiento', () {
      final e = Escrituracion.de(
        _propiedad(
          monto: 2000000,
          pagado: 1500000,
          productos: [
            _producto(nombre: 'Bodegas Bottura', monto: 200000, avance: 50),
            _producto(
              nombre: 'Estacionamientos Bottura',
              monto: 300000,
              avance: 0,
            ),
          ],
        ),
      );

      expect(e.escriturables.length, 2);
      expect(e.noEscriturables, isEmpty);
      expect(e.precioTotal, 2500000);
      expect(e.restanteTotal, 500000 + 100000 + 300000);
    });

    test('lo no escriturable no suma al total y sale aparte', () {
      final e = Escrituracion.de(
        _propiedad(
          monto: 2493621.51,
          pagado: 1649314.27,
          productos: [
            _producto(nombre: 'Condensadoras Bottura'),
            _producto(nombre: 'Paquete amueblado Soft', monto: 150000),
          ],
        ),
      );

      expect(e.escriturables, isEmpty);
      expect(e.noEscriturables.length, 2);
      expect(e.precioTotal, 2493621.51);
      expect(e.restanteTotal, closeTo(844307.24, 0.01));
    });

    test('montos negativos del backend se tratan como cero', () {
      final e = Escrituracion.de(_propiedad(monto: -10, pagado: -5));
      expect(e.precioTotal, 0);
      expect(e.restanteTotal, 0);
    });

    test('el restante de un complemento pagado es cero', () {
      final p = _producto(nombre: 'Bodegas Daiku', monto: 120000, avance: 100);
      expect(Escrituracion.restanteDe(p), 0);
    });
  });
}
