import 'package:sozu_cliente_app/data/models.dart';

/// Categorías de complemento que SÍ entran a la escritura del departamento.
/// Son las únicas con metraje propio (`categorias_producto.tiene_metraje`), y
/// por eso las únicas que un banco puede financiar.
const _categoriasEscriturables = {'estacionamiento', 'bodega'};

/// Palabras del nombre del producto que delatan la categoría cuando el backend
/// no manda `categoria`. Los nombres de catálogo son "Bodegas Bottura",
/// "Estacionamientos Daiku": categoría en plural más proyecto.
const _nombresEscriturables = {'bodega', 'estacionamiento', 'cajon', 'cajón'};

/// Reparto de una propiedad entre lo que entra a la escritura y lo que no.
///
/// Lo escriturable es el departamento más el estacionamiento y la bodega
/// comprados; el resto (condensadoras, muebles, persianas) se paga aparte y
/// nunca suma al valor que se escritura.
class Escrituracion {
  final double precioDepartamento;
  final double restanteDepartamento;

  /// Complementos que entran a la escritura, en el orden que los manda el
  /// backend.
  final List<ProductoDetalle> escriturables;

  /// Complementos que se pagan aparte y no se escrituran.
  final List<ProductoDetalle> noEscriturables;

  const Escrituracion({
    required this.precioDepartamento,
    required this.restanteDepartamento,
    required this.escriturables,
    required this.noEscriturables,
  });

  factory Escrituracion.de(PropiedadDetalle d) {
    final escriturables = <ProductoDetalle>[];
    final noEscriturables = <ProductoDetalle>[];
    for (final p in d.productos) {
      (esEscriturable(p) ? escriturables : noEscriturables).add(p);
    }
    return Escrituracion(
      precioDepartamento: _nonNeg(d.montoEfectivo),
      restanteDepartamento: _nonNeg(d.saldoPendienteEfectivo),
      escriturables: escriturables,
      noEscriturables: noEscriturables,
    );
  }

  /// Valor que se escritura: departamento más los complementos escriturables.
  /// Es el monto que el cliente cubre con recursos propios o crédito.
  double get precioTotal =>
      precioDepartamento +
      escriturables.fold<double>(0, (s, p) => s + _nonNeg(p.monto));

  /// Lo que falta pagar de ese valor.
  double get restanteTotal =>
      restanteDepartamento +
      escriturables.fold<double>(0, (s, p) => s + restanteDe(p));

  /// Restante de un complemento = precio × (1 − avance%). El detalle no expone
  /// `saldo_pendiente` por producto, se deriva del avance.
  static double restanteDe(ProductoDetalle p) =>
      (p.monto * (1 - (p.avance / 100)))
          .clamp(0.0, _nonNeg(p.monto))
          .toDouble();

  /// Usa `categoria` cuando el backend la manda; si no, cae al nombre.
  static bool esEscriturable(ProductoDetalle p) {
    final categoria = p.categoria?.trim().toLowerCase();
    if (categoria != null && categoria.isNotEmpty) {
      return _categoriasEscriturables.any(categoria.contains);
    }
    final nombre = p.nombre.toLowerCase();
    return _nombresEscriturables.any(nombre.contains);
  }

  static double _nonNeg(double v) => v < 0 ? 0.0 : v;
}
