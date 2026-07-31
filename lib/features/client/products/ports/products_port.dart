import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Area de productos adicionales del menu.
///
/// La instancia queda atada al cliente que se esta viendo (el propio, o el
/// impersonado por un super admin), asi que ningun metodo recibe ese target.
/// Todos los metodos lanzan [ApiError].
abstract interface class ProductsPort {
  /// Productos adicionales agrupados por propiedad.
  Future<ClienteProductos> products();
}
