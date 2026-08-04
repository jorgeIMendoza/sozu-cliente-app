import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/products/ports/products_port.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Doble de [ProductsPort] con datos fijos en memoria: sin red, sin Supabase.
/// Se inyecta con `productsPortProvider.overrideWithValue`.
class FakeProductsPort implements ProductsPort {
  /// Fallo forzado de la PROXIMA operacion; se consume al usarse.
  ApiError? nextFailure;

  /// Nombres de los metodos llamados, en orden, para tests de secuencia.
  final List<String> log = [];

  void _throwIfFailing(String method) {
    log.add(method);
    final f = nextFailure;
    nextFailure = null;
    if (f != null) throw f;
  }

  @override
  Future<ClienteProductos> products() async {
    _throwIfFailing('products');
    return ClienteProductos.fromJson({
      'propiedades': [
        {'propiedad': '101', 'productos': []},
      ],
    });
  }
}
