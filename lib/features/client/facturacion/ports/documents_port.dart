import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Documentos y facturas que la empresa entrega al cliente.
///
/// El expediente que el cliente SUBE es otro puerto
/// (`features/client/expediente/ports/expediente_port.dart`): son dos
/// direcciones distintas del mismo menu y tenerlas juntas obligaba a la
/// pantalla de facturas a arrastrar la subida de documentos.
///
/// La instancia queda atada al cliente que se esta viendo (el propio, o el
/// impersonado por un super admin), asi que ningun metodo recibe ese target.
/// Todos los metodos lanzan [ApiError].
abstract interface class DocumentsPort {
  /// Documentos y facturas del cliente.
  Future<ClienteDocumentos> documents();
}
